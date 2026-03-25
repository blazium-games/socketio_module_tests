extends GutTest

func before_each():
	SocketIOClient.close()

func after_each():
	SocketIOClient.close()

func test_001_initial_state():
	assert_eq(SocketIOClient.get_connection_state(), SocketIOClient.STATE_DISCONNECTED, "Client should start DISCONNECTED.")
	assert_false(SocketIOClient.is_socket_connected(), "Socket should not be actively linked initially.")
	assert_eq(SocketIOClient.get_engine_io_session_id(), "", "Session ID empty before handshake.")

func test_002_namespace_creation():
	var root_ns = SocketIOClient.create_namespace("/")
	assert_not_null(root_ns, "Root namespace natively valid.")
	assert_eq(root_ns.get_namespace_path(), "/", "Proper path generated.")
	
	var custom_ns = SocketIOClient.create_namespace("/chat")
	assert_not_null(custom_ns, "Custom namespaces generate cleanly.")
	
	assert_true(SocketIOClient.has_namespace("/chat"), "Namespace tree maps structures.")
	assert_eq(SocketIOClient.get_namespace("/chat"), custom_ns, "Retrieved identical namespace correctly.")

func test_003_connect_url_formatting():
	# Attempting to track url modifications explicitly applied by SocketIO internally (socket.io/?EIO=4...)
	var err = SocketIOClient.connect_to_url("ws://localhost:9091")
	assert_eq(err, OK, "Connection sequence initiates safely.")
	
	assert_eq(SocketIOClient.get_connection_state(), SocketIOClient.STATE_CONNECTING, "State progresses explicitly to CONNECTING.")
	
	var url = SocketIOClient.get_connection_url()
	assert_true(url.begins_with("ws://localhost:9091"), "Original URL persists.")
