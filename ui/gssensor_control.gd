extends GridContainer
class_name GSSensorControl

#TODO: Update sensor reading for the expanded capabilities of buttplug v4.

var device: GSDevice
var feature: GSFeature
var input_type: String

@onready var _input_type_label: Label = %InputType
@onready var _index: Label = %Index
@onready var _value: Label = %Value
@onready var _label4: Label = $Label4
@onready var _read_input: Button = %ReadInput
@onready var _subscribe: Button = %Subscribe
@onready var _unsubscribe: Button = %Unsubscribe


func _ready() -> void:
	input_type = feature.inputs.keys().front()
	feature.input_value_read.connect(_on_feature_input_value_read)
	_input_type_label.text = input_type
	_index.text = str(feature.feature_index)
	_setup_buttons()


func _setup_buttons():
	if feature.inputs[input_type].commands.has("Subscribe"): #TODO: This is a hardcoded string
		_subscribe.visible = true
		_unsubscribe.visible = true
		_label4.visible = false
		_read_input.visible = false
	else:
		_subscribe.visible = false
		_unsubscribe.visible = false
		_label4.visible = true
		_read_input.visible = true


func _on_read_input_pressed() -> void:
	feature.read_input(input_type)


func _on_feature_input_value_read(_feature: GSFeature, data: Dictionary):
	if data.size() > 0:
		_value.text = "%d" % data[input_type].values().front() #TODO: Make this extract the value better


func _on_subscribe_pressed() -> void:
	GSClient.send_input_subscribe(device.device_index, feature.feature_index, feature.sensor_type)


func _on_unsubscribe_pressed() -> void:
	GSClient.send_input_unsubscribe(device.device_index, feature.feature_index, feature.sensor_type)
