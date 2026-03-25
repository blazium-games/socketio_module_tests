extends GutTest

var tcp_server: TCPServer
var mock_server_peer: WebSocketPeer
var client_connected: bool = false
var ns_connected: String = ""

const TEST_PORT = 9094

func before_each():
	SocketIOClient.close()
	SocketIOClient.connected.connect(_on_client_connected)
	SocketIOClient.namespace_connected.connect(_on_namespace_connected)
	
	tcp_server = TCPServer.new()
	var err = tcp_server.listen(TEST_PORT)
	assert_eq(err, OK, "Mock TCPServer allocated safely.")

func after_each():
	SocketIOClient.close()
	if SocketIOClient.connected.is_connected(_on_client_connected):
		SocketIOClient.connected.disconnect(_on_client_connected)
	if SocketIOClient.namespace_connected.is_connected(_on_namespace_connected):
		SocketIOClient.namespace_connected.disconnect(_on_namespace_connected)
	
	if tcp_server:
		tcp_server.stop()
	if mock_server_peer:
		mock_server_peer.close()
		mock_server_peer = null
	client_connected = false
	ns_connected = ""

func _on_client_connected(session_id: String):
	client_connected = true

func _on_namespace_connected(namespace_path: String):
	ns_connected = namespace_path

func test_006_socketio_namespaces():
	var sent_eio_open = false
	
	var err = SocketIOClient.connect_to_url("ws://127.0.0.1:%d" % TEST_PORT)
	assert_eq(err, OK, "Client fires targeting local sequence.")
	
	var stream: StreamPeerTCP = null
	var time_waited = 0.0
	while time_waited < 2.0:
		if tcp_server.is_connection_available():
			stream = tcp_server.take_connection()
			break
		await get_tree().create_timer(0.05).timeout
		time_waited += 0.05
		SocketIOClient.poll()
		
	if stream:
		mock_server_peer = WebSocketPeer.new()
		mock_server_peer.accept_stream(stream)
		
		# Handshake
		time_waited = 0.0
		while time_waited < 2.0 and mock_server_peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
			mock_server_peer.poll()
			SocketIOClient.poll()
			await get_tree().create_timer(0.05).timeout
			time_waited += 0.05
			
		# Wait for '/' connect request natively
		time_waited = 0.0
		while time_waited < 1.0:
			SocketIOClient.poll()
			if tcp_server.is_connection_available():
				var temp_peer = tcp_server.take_connection()
				mock_server_peer = WebSocketPeer.new()
				mock_server_peer.accept_stream(temp_peer)
				
			if mock_server_peer != null:
				mock_server_peer.poll()
				
				if mock_server_peer.get_ready_state() == WebSocketPeer.STATE_OPEN and not sent_eio_open:
					mock_server_peer.send_text("0{\"sid\":\"mock-engine-sid\",\"upgrades\":[],\"pingInterval\":25000,\"pingTimeout\":20000}")
					sent_eio_open = true
					
				if mock_server_peer.get_available_packet_count() > 0:
					var pkt = mock_server_peer.get_packet().get_string_from_utf8()
					if pkt.begins_with("40"):
						mock_server_peer.send_text("40[{\"sid\":\"mock-123\"}]")
			if client_connected:
				break
			await get_tree().create_timer(0.05).timeout
			time_waited += 0.05
			
		assert_true(client_connected, "Signal connected explicitly fired.")
		
		# Create custom namespace and attempt connection explicitly
		var lobby_ns = SocketIOClient.create_namespace("/lobby")
		var lobby_err = lobby_ns.connect_to_namespace()
		assert_eq(lobby_err, OK, "Namespace trigger returned cleanly.")
		
		# Wait for '/lobby' connect request natively
		time_waited = 0.0
		var received_lobby_req = false
		while time_waited < 1.0:
			mock_server_peer.poll()
			SocketIOClient.poll()
			if mock_server_peer.get_available_packet_count() > 0:
				var pkt = mock_server_peer.get_packet().get_string_from_utf8()
				# The client should send something tracking "/lobby" like "40/lobby,"
				if pkt.contains("40/lobby"):
					received_lobby_req = true
					# Respond matching explicit sequence standard 40/lobby,...
					mock_server_peer.send_text("40/lobby,[{\"sid\":\"mock-123\"}]")
			if ns_connected == "/lobby":
				break
			await get_tree().create_timer(0.05).timeout
			time_waited += 0.05
			
		assert_true(received_lobby_req, "Custom namespace mapping parsed securely.")
		assert_eq(ns_connected, "/lobby", "Target explicit signals emitted successfully mapping custom definitions.")
		assert_true(lobby_ns.is_namespace_connected(), "The state maps securely connected.")
