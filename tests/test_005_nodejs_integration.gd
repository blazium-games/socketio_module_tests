extends AutoworkTest

var client_connected: bool = false
var ns_connected: String = ""
var received_events: Array = []
var ack_status: bool = false
var ack_payload: String = ""

func before_each():
	SocketIOClient.close()
	SocketIOClient.connected.connect(_on_client_connected)
	SocketIOClient.namespace_connected.connect(_on_namespace_connected)

func after_each():
	SocketIOClient.close()
	if SocketIOClient.connected.is_connected(_on_client_connected):
		SocketIOClient.connected.disconnect(_on_client_connected)
	if SocketIOClient.namespace_connected.is_connected(_on_namespace_connected):
		SocketIOClient.namespace_connected.disconnect(_on_namespace_connected)
	
	client_connected = false
	ns_connected = ""
	received_events.clear()
	ack_status = false
	ack_payload = ""

func _on_client_connected(session_id: String):
	client_connected = true

func _on_namespace_connected(namespace_path: String):
	ns_connected = namespace_path

func _on_chat_message(data: Array):
	if data.size() > 0 and data[0] is Dictionary:
		received_events.append({"type": "chat_message", "data": data[0]})

func _on_ack_received(data: Array):
	ack_status = true
	if data.size() > 0 and data[0] is Dictionary:
		ack_payload = data[0].get("payload", "")

func test_007_nodejs_integration():
	# Connect to Node.js server
	var err = SocketIOClient.connect_to_url("ws://localhost:3000")
	assert_eq(err, OK, "Connection triggers safely to global Node.js bindings.")
	
	# Bind event listeners early to prevent race conditions missing immediate Server emissions!
	var root_ns = SocketIOClient.get_namespace("/")
	root_ns.on("chat_message", _on_chat_message)
	
	# Wait for WebSocket and Socket.IO handshake
	var time_waited = 0.0
	while time_waited < 3.0:
		SocketIOClient.poll()
		if client_connected:
			break
		OS.delay_msec(50)
		time_waited += 0.05
		
	assert_true(client_connected, "Signal connected explicitly fired against Node.js.")
	assert_true(SocketIOClient.is_socket_connected(), "WebSocket confirms native connection limit.")
	
	if client_connected:
		# Allow time for initial chat_message triggered natively on Node.js socket connect
		time_waited = 0.0
		while time_waited < 1.0:
			SocketIOClient.poll()
			if received_events.size() > 0:
				break
			OS.delay_msec(50)
			time_waited += 0.05
		assert_true(received_events.size() > 0, "Node.js standard initial `chat_message` parsed securely (Size: %d)." % received_events.size())
		if received_events.size() > 0:
			assert_eq(received_events[0].data.get("user", ""), "admin", "Dictionary maps string matches exactly.")
			
		# Test emitting to Node.js
		root_ns.emit("client_event", [{"message": "hello from godot!"}])
		
		# Test ACK callbacks
		root_ns.emit_with_ack("request_data", [{"query": "fetch"}], _on_ack_received, 5.0)
		
		time_waited = 0.0
		while time_waited < 1.0:
			SocketIOClient.poll()
			if ack_status:
				break
			OS.delay_msec(50)
			time_waited += 0.05
			
		assert_true(ack_status, "ACK callback natively executed triggered securely by Node.js responder.")
		assert_eq(ack_payload, "Ack processed", "ACK string cleanly matches mapped server replies.")
		
		# Test Lobby namespace multiplexing
		var lobby_ns = SocketIOClient.create_namespace("/lobby")
		lobby_ns.connect_to_namespace()
		
		time_waited = 0.0
		while time_waited < 1.5:
			SocketIOClient.poll()
			if ns_connected == "/lobby":
				break
			OS.delay_msec(50)
			time_waited += 0.05
			
		assert_eq(ns_connected, "/lobby", "Custom /lobby namespace successfully triggered bridging constraints perfectly.")
