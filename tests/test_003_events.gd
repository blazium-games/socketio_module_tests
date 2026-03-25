extends GutTest

var tcp_server: TCPServer
var mock_server_peer: WebSocketPeer
var client_connected: bool = false
var event_received: String = ""
var event_data: Dictionary = {}

const TEST_PORT = 9093

func before_each():
	SocketIOClient.close()
	SocketIOClient.connected.connect(_on_client_connected)
	
	tcp_server = TCPServer.new()
	var err = tcp_server.listen(TEST_PORT)
	assert_eq(err, OK, "Mock TCPServer allocated safely.")

func after_each():
	SocketIOClient.close()
	if SocketIOClient.connected.is_connected(_on_client_connected):
		SocketIOClient.connected.disconnect(_on_client_connected)
	
	if tcp_server:
		tcp_server.stop()
	if mock_server_peer:
		mock_server_peer.close()
		mock_server_peer = null
	client_connected = false
	event_received = ""
	event_data = {}

func _on_client_connected(session_id: String):
	client_connected = true

func _on_chat_message(data: Array):
	event_received = "chat_message"
	if data.size() > 0 and data[0] is Dictionary:
		event_data = data[0]

func test_005_socketio_events():
	var received_connect_request = false
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
		
	assert_not_null(stream, "TCP Socket bridged correctly.")
	
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
			
		# Wait for connect request
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
						received_connect_request = true
						mock_server_peer.send_text("40[{\"sid\":\"mock-123\"}]")
			if client_connected:
				break
			await get_tree().create_timer(0.05).timeout
			time_waited += 0.05
			
		assert_true(client_connected, "Signal connected explicitly fired.")
		
		# Listen to events on root namespace
		var root_ns = SocketIOClient.get_namespace("/")
		root_ns.on("chat_message", _on_chat_message)
		
		# Send an event from Mock Server: Type 4 (Engine.IO Message), Type 2 (Event), Array payloads: ["chat_message", {"user":"admin", "text":"hello world"}]
		# Format according to standard Socket.io packets over WebSocket
		var mock_event_payload = "42[\"chat_message\", {\"user\":\"admin\", \"text\":\"hello world\"}]"
		mock_server_peer.send_text(mock_event_payload)
		
		# Wait up to 1s for the client to parse it natively
		time_waited = 0.0
		while time_waited < 1.0:
			mock_server_peer.poll()
			SocketIOClient.poll()
			
			if event_received == "chat_message":
				break
			await get_tree().create_timer(0.05).timeout
			time_waited += 0.05
			
		assert_eq(event_received, "chat_message", "Custom generic event retrieved actively mapping payloads exactly.")
		assert_eq(event_data.get("user", ""), "admin", "Nested dictionary values processed natively.")
		assert_eq(event_data.get("text", ""), "hello world", "Extended dictionary scopes matched correctly.")
