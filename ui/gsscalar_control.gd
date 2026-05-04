extends VBoxContainer
class_name GSScalarControl

var device: GSDevice
var feature: GSFeature

@onready var _actuator_type: Label = %ActuatorType
@onready var _index: Label = %Index
@onready var _scalar: HSlider = %Scalar


func _ready() -> void:
	var actuator_type_string= feature.outputs.keys()[0]
	_actuator_type.text = actuator_type_string
	_index.text = str(feature.feature_index)
	var output_range = feature.outputs[actuator_type_string].value_range
	var step_count = output_range.range_max - output_range.range_min
	_scalar.min_value = output_range.range_min
	_scalar.max_value = output_range.range_max
	_scalar.step_count = step_count


func _on_scalar_value_changed(value: float) -> void:
	value = clampf(0.0 if _scalar.max_value == 0.0 else value / _scalar.max_value, 0.0, 1.0)
	GSClient.send_feature(feature, feature.outputs.keys().front(), value)
