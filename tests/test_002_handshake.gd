extends GutTest

var tcp_server: TCPServer
var mock_server_peer: WebSocketPeer
var client_connected: bool = false
var captured_session_id: String = ""

const TEST_PORT = 9092

func before_each():
	SocketIOClient.close()
	SocketIOClient.connected.connect(_on_client_connected)
	
	tcp_server = TCPServer.new()
	var err = tcp_server.listen(TEST_PORT)
	assert_eq(err, OK, "Mock TCPServer limits allocated safely.")

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
	captured_session_id = ""

func _on_client_connected(session_id: String):
	client_connected = true
	captured_session_id = session_id

func test_004_engine_io_handshake():
	var err = SocketIOClient.connect_to_url("ws://127.0.0.1:%d" % TEST_PORT)
	assert_eq(err, OK, "Client fires targeting local sequence.")
	
	var stream: StreamPeerTCP = null
	
	# Wait for TCP connection
	var time_waited = 0.0
	while time_waited < 2.0:
		if tcp_server.is_connection_available():
			stream = tcp_server.take_connection()
			break
		await get_tree().create_timer(0.05).timeout
		time_waited += 0.05
		SocketIOClient.poll()
		
	assert_not_null(stream, "TCP Socket bridged correctly over the mock layer.")
	
	if stream:
		mock_server_peer = WebSocketPeer.new()
		var accept_err = mock_server_peer.accept_stream(stream)
		assert_eq(accept_err, OK, "WebSocket safely accepts the underlying stream natively.")
		
		# Allow WebSocket handshake fully
		time_waited = 0.0
		while time_waited < 2.0 and mock_server_peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
			mock_server_peer.poll()
			SocketIOClient.poll()
			await get_tree().create_timer(0.05).timeout
			time_waited += 0.05
			
		assert_eq(mock_server_peer.get_ready_state(), WebSocketPeer.STATE_OPEN, "Handshake completed securely.")
		
		# Wait for Engine.IO packet evaluation natively
		time_waited = 0.0
		var received_connect_request = false
		while time_waited < 1.0:
			mock_server_peer.poll()
			SocketIOClient.poll()
			
			if mock_server_peer.get_available_packet_count() > 0:
				var pkt = mock_server_peer.get_packet().get_string_from_utf8()
				print("MOCK Received: ", pkt)
				# Socket.IO client should immediately send CONNECT packet to '/' namespace: "0"
				if pkt.begins_with("0"):
					received_connect_request = true
					# Respond with Server-Side CONNECT ack (0 + Array holding dictionary with sid)
					mock_server_peer.send_text("0[{\"sid\":\"mock-123\"}]")
			
			if client_connected:
				break
				
			await get_tree().create_timer(0.05).timeout
			time_waited += 0.05
			
		assert_true(received_connect_request, "Target engine dispatched namespace CONNECT signature natively.")
		assert_true(client_connected, "Signal connected explicitly fired.")
		assert_eq(captured_session_id, "mock-123", "Session token decoded exactly from payloads.")
		assert_true(SocketIOClient.is_socket_connected(), "Native connectivity properties engaged.")
