class_name GSFeature
extends RefCounted
## Represents a buttplug.io device feature.
##
## GSFeature contains information about a device feature such as a vibration actuator or a battery
## sensor. 
##
## @tutorial(Spec Reference): https://buttplug.io/docs/spec/device_information

## Emitted when a sensor value has been read after calling [method read_sensor].
## [br][br]
## [param feature] is the sensor feature.
## [br]
## [param data] is the sensor data.
signal sensor_value_read(feature: GSFeature, data: PackedInt32Array)

## The [GSDevice] that owns this feature.
var device: GSDevice
## The feature index in the device's feature list.
var feature_index: int = -1
## The feature descriptor is a text description of the feature, if available.
var feature_descriptor: String
## The outputs (actuators) belonging to the feature
var outputs: Dictionary[String, GSOutput] = {}
## The inputs (sensors) belonging to the feature
var inputs: Dictionary[String, GSInput] = {}

var _read_sensor_id: int = -1

func _init() -> void:
	GSClient.client_sensor_reading.connect(
		func(
			id: int, 
			device_index: int, 
			feature_index: int, 
			output_type: String, 
			data: PackedInt32Array
		):
			if(
				_read_sensor_id == id
				and device_index == device.device_index
				and feature_index == self.feature_index
				and outputs.has(output_type)
			):
				sensor_value_read.emit(self, data)
				_read_sensor_id = -1
	)


## Deserializes the given dictionary into a new [GSFeature] instance.
static func deserialize(data: Dictionary) -> GSFeature:
	var feature := GSFeature.new()
	if data.has(GSMessage.MESSAGE_FIELD_FEATURE_INDEX):
		feature.feature_index = data[GSMessage.MESSAGE_FIELD_FEATURE_INDEX]
	if data.has(GSMessage.MESSAGE_FIELD_FEATURE_DESCRIPTOR):
		feature.feature_descriptor = data[GSMessage.MESSAGE_FIELD_FEATURE_DESCRIPTOR]
	if data.has(GSMessage.MESSAGE_FIELD_OUTPUT):
		var outputs: Dictionary = data[GSMessage.MESSAGE_FIELD_OUTPUT]
		for output_type: String in outputs.keys():
			var output: GSOutput = GSOutput.deserialize(output_type, outputs[output_type])
			output.feature = feature
			feature.outputs[output_type] = output
	if data.has(GSMessage.MESSAGE_FIELD_INPUT):
		var inputs: Dictionary = data[GSMessage.MESSAGE_FIELD_INPUT]
		for input_type: String in inputs.keys():
			var input: GSInput = GSInput.deserialize(input_type, inputs[input_type])
			input.feature = feature
			feature.inputs[input_type] = input
	return feature


## Returns the [member feature_descriptor], if set. If not it attempts to return the 
## [member acuator_type], if set. Otherwise, it returns the [member feature_command].
func get_display_name() -> String:
	if not GSUtil.ne(feature_descriptor) and feature_descriptor != "NA":
		return feature_descriptor
	if not outputs.is_empty():
		return outputs.keys().front()
	if not inputs.is_empty():
		return inputs.keys().front()
	return ""


## Starts the feature for the given output type (if it has it)
## [br][br]
## [param value] is a value between [code]0.0[/code] and [code]1.0[/code] where [code]0.0[/code] 
## is no activation and [code]1.0[/code] is max activation.
## [br]
## [param duration] sets the duration, in seconds. A value of [code]0.0[/code] is always on.
## [br]
## [param clockwise] sets the direction of rotation. Only applicable for rotation actuators.
## [br][br]
## If the feature is a LinearCmd this method can be awaited on.
func start(value: float, output_type: String, duration: float = 0.0, clockwise: bool = true) -> void:
	if outputs.is_empty() || !outputs.has(output_type):
		return
	await GSClient.send_feature(self, output_type, clampf(value, 0.0, 1.0), duration, clockwise)


## Stops the feature.
func stop() -> void:
	GSClient.stop_feature(self)


## Requests the feature value if it has a sensor type. This does nothing for actuator features. The 
## value will be returned via [signal sensor_value_read].
func read_sensor() -> void:
	if inputs.is_empty():
		return
	# This doesn't account for multiple inputs on a feature
	_read_sensor_id = GSClient.read_sensor(device.device_index, feature_index, inputs.keys().front())
