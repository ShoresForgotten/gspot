extends Node
## The gspot client implementation for interacting with a buttplug.io server.
##
## This client implementation handles all message communication with the buttplug.io server it 
## connects to and relays messages back to the developer via signals. This is the main interface for
## requesting devices ([method request_device_list]) and sending commands to activate features 
## [method send_feature].
##
## @tutorial(Spec Reference): https://buttplug-spec.docs.buttplug.io/docs/spec

## The spec version this client is compatible with.
const PROTOCOL_VERSION_MAJOR: int = 4
const PROTOCOL_VERSION_MINOR: int = 0
## The default server host to connect to.
const DEFAULT_HOST: String = "127.0.0.1"
## The default server port to connect to.
const DEFAULT_PORT: int = 12345
## The default ping time.
const DEFAULT_PING_TIME: int = 1000 * 30 # 30 seconds
## The subdirectory where extensions are loaded from.
const EXTENSIONS_DIR: String = "extensions"

## Enumerates possible client states.
enum ClientState {
	## THe client is attempting to connect to the server.
	CONNECTING,
	## The client has connected to the server and passing initial information.
	HANDSHAKING,
	## The client has completed handshaking and is connected.
	CONNECTED,
	## The client is disconnected from the server.
	DISCONNECTED,
}

## Enumerates possible server error codes.
enum ErrorCode {
	UNKNOWN = 0,
	INIT = 1,
	PING = 2,
	MSG = 3,
	DEVICE = 4,
}

## Enumerates available logging levels.
enum LogLevel {
	VERBOSE,
	DEBUG,
	WARN,
	ERROR,
}

## Emitted when the client connection state has changed.
signal client_connection_changed(connected: bool)
## Emitted when a device has been added to the device list.
signal client_device_added(device: GSDevice)
## Emitted when a device list has been received from the server.
signal client_device_list_received(devices: Array[GSDevice])
## Emitted when a device has been removed from the device list.
signal client_device_removed(device: GSDevice)
## Emitted when a client error has occurred.
signal client_error(error: int, message: String)
## Emitted when frame data has been received from the server.
signal client_frame_received(frame: String)
## Emitted when the client sends a message.
signal client_message(message: String)
## Emitted when a device scan has finished and [method get_devices] can be called.
signal client_scan_finished()
## Emitted when a value has returned from [method read_input], or when a subscribed input sends a
## reading.
signal client_input_reading(
	id: int, 
	device_index: int, 
	feature_index: int, 
	input_type: String, 
	data: PackedInt32Array
)
## Emitted when a server error has occurred.
signal server_error(id: int, error: int, message: String)

## Defines the subdirectory where extensions are loaded from.
var extensions_dir: String = EXTENSIONS_DIR
var _hostname: String = DEFAULT_HOST
var _port: int = 12345
var _server_name: String
var _protocol_version_major: int
var _protocol_version_minor: int
var _max_ping_time: int
var _ack_map: Dictionary = {}
var _device_map: Dictionary = {}
var _id: int = 1
var _message_handlers: Dictionary = {}
var _peer: WebSocketPeer = WebSocketPeer.new()
var _ping: float = 0.0
var _scanning: bool = false
var _state: ClientState = ClientState.DISCONNECTED
var _timeout: float = 0.0
var _durations: Dictionary = {}
var _log_level: LogLevel = LogLevel.VERBOSE
var _extension_map: Dictionary = {}

func _init() -> void:
	add_message_handler(GSMessage.MESSAGE_TYPE_OK, _on_message_ok)
	add_message_handler(GSMessage.MESSAGE_TYPE_ERROR, _on_message_error)
	add_message_handler(GSMessage.MESSAGE_TYPE_SERVER_INFO, _on_message_server_info)
	add_message_handler(GSMessage.MESSAGE_TYPE_DEVICE_LIST, _on_message_device_list)
	add_message_handler(GSMessage.MESSAGE_TYPE_SCANNING_FINISHED, _on_message_scanning_finished)
	add_message_handler(GSMessage.MESSAGE_TYPE_INPUT_READING, _on_message_sensor_reading)


func _enter_tree() -> void:
	init_extensions()
	load_extensions()


func _exit_tree() -> void:
	unload_extensions()


func _process(delta: float) -> void:
	_check_ping(delta)
	_process_peer(delta)


## Returns the client name as specified in the project settings. Defaults to 
## [constant GSConstants.CLIENT_NAME].
func get_client_name() -> String:
	return GSUtil.get_project_value(GSConstants.PROJECT_SETTING_CLIENT_NAME, GSConstants.CLIENT_NAME)


## Returns the client version as specified in the project settings. Defaults to 
## [constant GSConstants.CLIENT_VERSION].
func get_client_version() -> String:
	return GSUtil.get_project_value(GSConstants.PROJECT_SETTING_CLIENT_VERSION, GSConstants.CLIENT_VERSION)


## Returns a formatted client value in the format of: GSClient v2.1.
func get_client_string() -> String:
	return "%s v%s" % [ get_client_name(), get_client_version() ]


## Returns the connected hostname.
func get_hostname() -> String:
	return _hostname


## Returns the connected port.
func get_port() -> int:
	return _port


## Returns the connected server's name.
func get_server_name() -> String:
	return _server_name


## Returns the connected server's protocol major version.
func get_protocol_version_major() -> int:
	return _protocol_version_major


## Returns the connected server's protocol minor version.
func get_protocol_version_minor() -> int:
	return _protocol_version_minor


## Returns the connected server's max ping time.
func get_max_ping_time() -> int:
	return _max_ping_time


## Returns the current [enum ClientState].
func get_client_state() -> ClientState:
	return _state


## Determines if the client is currently connected to a server.
func is_client_connected() -> bool:
	return get_client_state() == ClientState.CONNECTED


## Adds a message handler to handle the specified message type. This allows the developer to
## override specific message functionality without needing to modify the GSClient itself.
func add_message_handler(message_type: String, handler: Callable):
	_message_handlers[message_type] = handler


## Removes the message handler for the specified message type. Returns [code]true[/code] if it was 
## removed successfully.
func remove_message_handler(message_type: String) -> bool:
	return _message_handlers.erase(message_type)


## Sets the current [enum LogLevel]. Any logged messages below this level will not be sent via 
## [signal client_message].
func set_log_level(level: LogLevel) -> void:
	_log_level = level


## Gets the current [enum LogLevel].
func get_log_level() -> LogLevel:
	return _log_level


## Logs a [enum LogLevel.VERBOSE] message.
func logv(message: String) -> void:
	_log(LogLevel.VERBOSE, message)


## Logs a [enum LogLevel.DEBUG] message.
func logd(message: String) -> void:
	_log(LogLevel.DEBUG, message)


## Logs a [enum LogLevel.WARN] message.
func logw(message: String) -> void:
	_log(LogLevel.WARN, message)


## Logs a [enum LogLevel.ERROR] message with an optional [enum Error] code.
func loge(message: String, error: Error = FAILED) -> void:
	_error(error, message)


## Starts the client and connects to the specified server hostname and port. If the connection does 
## not happen within the specified [param timeout] value an error will be raised. If any 
## [param options] are defined then a secure connection will be attempted.
func start(
	hostname: String = DEFAULT_HOST, 
	port: int = DEFAULT_PORT, 
	timeout: int = 60, 
	options: TLSOptions = null
) -> Error:
	logv("%s starting..." % get_client_string())
	logd("Attempting to connect to %s on port %d..." % [ hostname, port ])
	var protocol: String = "ws" if not options else "wss"
	_hostname = hostname
	_port = port
	_timeout = float(timeout)
	var resp: Error = _peer.connect_to_url("%s://%s:%d" % [ protocol, hostname, port ], options)
	if resp != OK:
		loge("Unable to connect to server.", resp)
		set_process(false)
		_state = ClientState.DISCONNECTED
	else:
		set_process(true)
		_state = ClientState.CONNECTING
	return resp


## Stops the client and disconnects from a connected server.
func stop() -> void:
	if _state == ClientState.CONNECTED:
		send(GSDisconnect.new(_get_message_id()))
	_peer.close(1000, "Client requested shutdown.")
	_state = ClientState.DISCONNECTED
	logv("%s stopping..." % get_client_string())


## Begins a device scan. Any devices found will be emitted via [signal client_device_added].
func scan_start() -> void:
	logd("Starting device scan...")
	send(GSStartScanning.new(_get_message_id()))
	_scanning = true


## Stops an active device scan.
func scan_stop() -> void:
	if not _scanning:
		return
	logd("Ending device scan...")
	send(GSStopScanning.new(_get_message_id()))


## Requests the server's known device list. The list is returned via 
## [signal client_device_list_received].
func request_device_list() -> void:
	send(GSRequestDeviceList.new(_get_message_id()))
	logd("Requesting device list...")


## Gets a list of all known devices.
func get_devices() -> Array[GSDevice]:
	var list: Array[GSDevice] = []
	list.assign(_device_map.values())
	return list


## Gets a device at the specified index.
func get_device(device_index: int) -> GSDevice:
	if _device_map.has(device_index):
		return _device_map[device_index]
	return null


## Attempts to find a device by its display name. See [method GSDevice.get_display_name].
func get_device_by_name(device_name: String) -> GSDevice:
	var devices = get_devices().filter(func(device: GSDevice): return device.get_display_name() == device_name)
	if devices.size() > 0:
		return devices.front()
	return null


## Sends a feature output activation to the server. See also [method GSClient.send_value],
## [method GSClient.send_value_with_duration], and [method GSClient.send_value_with_direction] for
## more accurate control, at the cost of having to check the minimum and maximum output ranges for
## outputs and use milliseconds for durations.
## [br][br]
## [param feature] is the feature to activate.
## [br]
## [param value] is a value between [code]0.0[/code] and [code]1.0[/code] where [code]0.0[/code] 
## is no activation and [code]1.0[/code] is max activation.
## [br]
## [param duration] sets the duration, in seconds. A value of [code]0.0[/code] is always on. For 
## linear outputs this will instead control how fast the output reaches the target position.
## Currently this behavior only exists for features controlled with the
## [constant GSOutputType.HW_POSITION_WITH_DURATION] command.
## [br]
## [param clockwise] sets the direction of rotation. Only applicable for rotation outputs used with
## the [constant GSOutputType.ROTATION_WITH_DIRECTION] command.
## [br][br]
## If the command is [constant GSOutputType.HW_POSITION_WITH_DURATION] (and the device supports the
## command), this function can be awaited on. Be aware of [member GSDevice.device_message_timing_gap]
## when attempting to send more messages when the motion is done, as additional commands may be
## ignored.
func send_feature(
	feature: GSFeature, 
	command: String,
	value: float, 
	duration: float = 0.0, 
	clockwise: bool = true,
) -> void:
	if not feature or not feature.device:
		return
		
	var range: GSRange = feature.outputs[command].value_range
	var int_value: int = (range.range_max - range.range_min) * value + range.range_min
	match command:
		GSOutputType.ROTATION_WITH_DIRECTION:
			send_value_with_clockwise(
				feature.device.device_index,
				feature.feature_index,
				int_value,
				clockwise,
				command
			)
			if duration > 0.0:
				_create_feature_duration(feature, duration)
		GSOutputType.HW_POSITION_WITH_DURATION:
			await send_value_with_duration(
				feature.device.device_index,
				feature.feature_index,
				int_value,
				floor(duration * 1000),
				command
			)
		_:
			send_value(
				feature.device.device_index, 
				feature.feature_index, 
				int_value,
				command
			)
			if duration > 0.0:
				_create_feature_duration(feature, duration)

## Sends a command with only a value to the server.
## [br][br]
## [param device_index] is the device's index.
## [br]
## [param feature_index] is the feature index on the device.
## [br]
## [param value] is a value between the minimum and maximum values (inclusive) of the targeted 
## output.
## [br]
## [param command_type] is the type of command to send to the feature.
func send_value(
	device_index: int,
	feature_index: int,
	value: int,
	command_type: String,
) -> void:
	send(GSOutputCmd.new(_get_message_id(), device_index, feature_index, command_type, value))


## Sends a command with a value and a duration to the server. This is mainly used for strokers,
## where value gives the position and duration gives the time to reach the position
## [br][br]
## [param device_index] is the device's index.
## [br]
## [param feature_index] is the feature index on the device.
## [br]
## [param value] is a value between the minimum and maximum values of the feature output.
## [br]
## [param duration] sets the duration, in milliseconds, that it should take for the device to reach
## the specified [param position].
## [br]
## [param command] is the command type to be sent. Currently only
## [constant GSOutputType.HW_POSITION_WITH_DURATION] has a duration field
## [br] [br]
## Can be awaited on, but be aware of [member GSDevice.device_message_timing_gap] when trying to
## send more commands when the current motion is finished, as additional commands may be ignored.
func send_value_with_duration(
	device_index: int,
	feature_index: int,
	value: int,
	duration: int,
	command: String = GSOutputType.HW_POSITION_WITH_DURATION
) -> void:
	send(GSOutputCmd.new(
			_get_message_id(),
			device_index,
			feature_index,
			command,
			value,
			{"Duration": duration}
		))
	await create_tween().tween_interval(float(duration) / 1000.0).finished


## Sends a command to the server with a value and a clock direction. If specifying a clock direction
## is unnecessary, use [method GSClient.send_value] instead. As of version 4.0 every device with a
## [constant GSOutputType.ROTATION_WITH_DIRECTION] output should also support
## [constant GSOutputType.ROTATION] commands.
## [br][br]
## [param device_index] is the device's index.
## [br]
## [param feature_index] is the feature index on the device.
## [br]
## [param value] is a value between the minimum and maximum values of the 
## targeted output.
## [br]
## [param clockwise] sets the direction of rotation.
## [br]
## [param command] is the command type to send. Currently only 
## [constant GSOutputType.ROTATION_WITH_DIRECTION] includes a clockwise direction field.
func send_value_with_clockwise(
	device_index: int,
	feature_index: int,
	value: int,
	clockwise: bool,
	command: String = GSOutputType.ROTATION_WITH_DIRECTION
) -> void:
	send(GSOutputCmd.new(
		_get_message_id(),
		device_index,
		feature_index,
		command,
		value,
		{"Clockwise": clockwise}
	))


## Begins an input read of the specified device input feature. The read value will be returned via 
## [signal client_input_reading].
## [br][br]
## This function returns the message ID that was sent to the server requesting the sensor value. 
## This can be matched up with the ID value returned in [signal client_input_reading].
## [br][br]
## [param device_index] is the device's index.
## [br]
## [param feature_index] is the feature index on the device.
## [br]
## [param input_type] is the input type to read.
func read_input(device_index: int, feature_index: int, input_type: String) -> int:
	var id = _get_message_id()
	send(GSInputCmd.new(id, device_index, feature_index, input_type, "Read"))
	return id


## Subscribes to a stream of data from the specified device input. The read values will be 
## returned via [signal client_input_reading]. Will only work if the corresponding
## [member GSInput.commands] contains "Subscribe".
## [br][br]
## [param device_index] is the device's index.
## [br]
## [param input_index] is the input index on the device.
## [br]
## [param input_type] is the input type to read.
func send_input_subscribe(device_index: int, feature_index: int, input_type: String) -> void:
	send(GSInputCmd.new(_get_message_id(), device_index, feature_index, input_type, "Subscribe"))


## Unsubscribes from a stream of data from the specified device input.
## [br][br]
## [param device_index] is the device's index.
## [br]
## [param feature_index] is the feature index on the device.
## [br]
## [param input_type] is the input type to read.
func send_input_unsubscribe(device_index: int, feature_index: int, input_type: String) -> void:
	send(GSInputCmd.new(_get_message_id(), device_index, feature_index, input_type, "Unsubscribe"))


## Stops the specified device feature.
func stop_feature(feature: GSFeature) -> void:
	if not feature or not feature.device:
		return
	send(GSStopCmd.new(_get_message_id(), feature.device.device_index, feature.feature_index))


## Stops all features of the specified device index.
func stop_device(device_index: int) -> void:
	send(GSStopCmd.new(_get_message_id(), device_index))


## Stops all active devices.
func stop_all_devices() -> void:
	send(GSStopCmd.new(_get_message_id()))


## Sends the specified message to the server.
func send(message: GSMessage) -> void:
	_ack_map[message.get_id()] = message
	logv("Sending message: %s" % message)
	_peer.send_text(JSON.stringify([ message.serialize() ]))


## Determines if the specified extension has been loaded.
func has_ext(extension_name: String) -> bool:
	return _extension_map.has(extension_name)


## Returns the specified extension object.
func ext(extension_name: String) -> Variant:
	if has_ext(extension_name):
		return _extension_map[extension_name]
	return null


## Calls a method on the specified extension. Returns [code]null[/code] if the extension or 
## specified method does not exist.
func ext_call(extension_name: String, method_name: String, args: Array = []) -> Variant:
	var extension = ext(extension_name)
	if not extension or not extension.has_method(method_name):
		return null
	return extension.callv(method_name, args)


## Locates and maps available extensions. Called automatically during [method Node._enter_tree].
func init_extensions() -> void:
	_extension_map.clear()
	var script: Script = get_script()
	var script_path := script.resource_path.get_base_dir()
	_populate_extension_map(script_path, extensions_dir)


## Attempts to load available extensions. Called automatically during [method Node._enter_tree].
func load_extensions() -> void:
	var extensions: Array[GSExtension] = _prioritize_extensions()
	for ext: GSExtension in extensions:
		logv("Loading '%s'..." % ext.get_extension_name())
		if not ext.load_extension(self):
			logw("!! Extension load failed and removed from extension list.")
			_extension_map.erase(ext.get_extension_name())
		else:
			logv("** Extension loaded!")


## Unloads previously loaded extensions. Called automatically during [method Node._exit_tree].
func unload_extensions() -> void:
	var extensions: Array[GSExtension] = _prioritize_extensions()
	for i in range(extensions.size() - 1, -1, -1):
		logv("Unloading extension %s..." % extensions[i].get_extension_name())
		extensions[i].unload_extension(self)

func _log(level: LogLevel, message: String) -> void:
	if level >= _log_level:
		client_message.emit(message)


func _error(error: Error, message: String) -> void:
	_log(LogLevel.ERROR, message)
	client_error.emit(error, message)


func _check_ping(delta: float) -> void:
	if _max_ping_time <= 0.0:
		return
	if get_client_state() != ClientState.CONNECTED:
		return
	_ping -= delta
	if _ping <= 0.0:
		_ping = float(_max_ping_time) / 1000.0
		send(GSPing.new(_get_message_id()))


func _process_peer(delta: float) -> void:
	_peer.poll()
	match _peer.get_ready_state():
		WebSocketPeer.STATE_CONNECTING:
			_on_peer_connecting(delta)
		WebSocketPeer.STATE_OPEN:
			if _state == ClientState.CONNECTING:
				_handshake()
			_consume_peer_packets()
		WebSocketPeer.STATE_CLOSING:
			if _state in [ ClientState.CONNECTING, ClientState.CONNECTED ]:
				_on_peer_closing()
		WebSocketPeer.STATE_CLOSED:
			if _state in [ ClientState.CONNECTING, ClientState.CONNECTED ]:
				_on_peer_closed()


func _on_connect_timeout() -> void:
	if _state == ClientState.CONNECTING:
		set_process(false)
		_state = ClientState.DISCONNECTED
		_peer.close(1001, "Client connection timeout.")
		loge("Connection timed out!", ERR_TIMEOUT)
		client_connection_changed.emit(false)


func _get_message_id() -> int:
	var id: int = _id
	_id += 1
	return id


func _handshake() -> void:
	send(GSRequestServerInfo.new(_get_message_id()))
	_state = ClientState.HANDSHAKING


func _consume_peer_packets() -> void:
	while _peer.get_available_packet_count():
		var frame: String = _peer.get_packet().get_string_from_utf8()
		client_frame_received.emit(frame)
		var data := JSON.parse_string(frame) as Array
		if data == null:
			logw("Invalid data frame received from server: %s" % frame)
			continue
		for msg: Dictionary in data:
			var message = GSMessage.deserialize(msg)
			_on_handle_message(message)


func _on_message_ok(message: GSMessage) -> void:
	_ack(message.get_id())


func _on_message_error(message: GSMessage) -> void:
	_ack(message.get_id())
	var error_code: int = message.fields[GSMessage.MESSAGE_FIELD_ERROR_CODE]
	var error_message: String = message.fields[GSMessage.MESSAGE_FIELD_ERROR_MESSAGE]
	server_error.emit(message.get_id(), error_code, error_message)


func _on_message_server_info(message: GSMessage) -> void:
	if _state == ClientState.HANDSHAKING:
		_ack(1)
		_state = ClientState.CONNECTED
		_server_name = message.fields[GSMessage.MESSAGE_FIELD_SERVER_NAME]
		_protocol_version_major = int(message.fields[GSMessage.MESSAGE_FIELD_PROTOCOL_VERSION_MAJOR])
		_protocol_version_minor = int(message.fields[GSMessage.MESSAGE_FIELD_PROTOCOL_VERSION_MINOR])
		_max_ping_time = int(message.fields[GSMessage.MESSAGE_FIELD_MAX_PING_TIME])
		if _max_ping_time <= 0:
			_max_ping_time = DEFAULT_PING_TIME
		logv("%s connected to %s!" % [ get_client_string(), _server_name ])
		client_connection_changed.emit(true)


func _on_message_device_list(message: GSMessage) -> void:
	_ack(message.get_id())
	for device_data: Dictionary in message.fields[GSMessage.MESSAGE_FIELD_DEVICES].values():
		var device: GSDevice = GSDevice.deserialize(device_data)
		_device_map[device.device_index] = device
	var list: Array[GSDevice] = []
	list.assign(_device_map.values())
	client_device_list_received.emit(list)

func _on_message_scanning_finished(message: GSMessage) -> void:
	_scanning = false
	client_scan_finished.emit()


func _on_message_sensor_reading(message: GSMessage) -> void:
	_ack(message.get_id())
	var id: int = message.get_id()
	var device_index: int = message.fields[GSMessage.MESSAGE_FIELD_DEVICE_INDEX]
	var feature_index: int = message.fields[GSMessage.MESSAGE_FIELD_FEATURE_INDEX]
	var input_type: String = message.fields[GSMessage.MESSAGE_FIELD_INPUT_TYPE]
	var input_data: PackedInt32Array = message.fields[GSMessage.MESSAGE_FIELD_DATA]
	client_input_reading.emit(id, device_index, feature_index, input_type, input_data)

func _on_handle_message(message: GSMessage) -> void:
	if not _message_handlers.has(message.message_type):
		_on_unhandled_message(message)
		return
	var handler: Callable = _message_handlers[message.message_type]
	handler.call(message)


func _on_unhandled_message(message: GSMessage) -> void:
	logw("Unrecognized message type: %s" % message.message_type)


func _ack(ack_id: int) -> void:
	if _ack_map.has(ack_id):
		_ack_map.erase(ack_id)


func _on_peer_connecting(delta: float) -> void:
	if _timeout <= 0.0:
		return
	_timeout -= delta
	if _timeout <= 0.0:
		_timeout = 0.0
		_on_connect_timeout()


func _on_peer_closing() -> void:
	# NOP
	pass


func _on_peer_closed() -> void:
	var code: int = _peer.get_close_code()
	var reason: String = _peer.get_close_reason()
	logd("%s closed with code %d, reason: %s" % [ get_client_string(), code, reason ])
	set_process(false)
	_reset()
	client_connection_changed.emit(false)


func _reset() -> void:
	_ack_map.clear()
	_device_map.clear()
	_id = 1
	_ping = 0.0
	_scanning = false
	_timeout = 0.0
	_state = ClientState.DISCONNECTED


func _get_feature_key(feature: GSFeature) -> int:
	return feature.device.device_index * 1000 + feature.feature_index


func _get_feature_duration(feature: GSFeature) -> GSFeatureDuration:
	var key: int = _get_feature_key(feature)
	var duration: GSFeatureDuration = _durations.get(key, null)
	if not duration:
		duration = GSFeatureDuration.new()
		duration.feature = feature
		_durations[key] = duration
		add_child(duration)
	return duration


func _create_feature_duration(feature: GSFeature, duration: float) -> void:
	var feature_duration: GSFeatureDuration = _get_feature_duration(feature)
	feature_duration.duration = duration


func _populate_extension_map(current_dir: String, ext_dir: String) -> void:
	var extension_path := "%s/%s" % [ current_dir, ext_dir ]
	
	var dir := DirAccess.open(extension_path)
	if not dir:
		return
	
	logv("Loading extensions from %s..." % extension_path)
	
	dir.list_dir_begin()
	var filename: String = dir.get_next()
	while filename != "":
		if dir.current_is_dir():
			_populate_extension_map(extension_path, filename)
		else:
			if filename.contains(".gd") and not filename.contains(".uid"):
				var res = ResourceLoader.load("%s/%s" % [ extension_path, filename ])
				if res is Script:
					var ext_script = res.new()
					if ext_script is GSExtension and not ext_script.get_script() == GSExtension:
						logv("Found extension %s." % filename)
						_extension_map[ext_script.get_extension_name()] = ext_script
		filename = dir.get_next()


func _prioritize_extensions() -> Array[GSExtension]:
	var extensions: Array[GSExtension] = []
	extensions.assign(_extension_map.values())
	extensions.sort_custom(
		func(a: GSExtension, b: GSExtension):
			return a.get_extension_priority() > b.get_extension_priority()
	)
	
	return extensions


class GSFeatureDuration extends Node:
	var feature: GSFeature
	var duration: float = 0.0
	
	
	func _ready() -> void:
		name = "FeatureDuration-%s-%s" % [ feature.device.get_display_name(), feature.get_display_name() ]
	
	
	func _process(delta: float) -> void:
		if  not feature:
			return
		if duration > 0.0:
			duration -= delta
			if duration <= 0.0:
				GSClient.stop_feature(feature)
				kill()
	
	
	func kill() -> void:
		duration = 0.0
		var key = GSClient._get_feature_key(feature)
		GSClient._durations.erase(key)
		queue_free()
