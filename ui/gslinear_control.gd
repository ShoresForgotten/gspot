extends GridContainer
class_name GSLinearControl

var device: GSDevice
var feature: GSFeature

@onready var _index: Label = %Index
@onready var _duration: SpinBox = %Duration
@onready var _position: HSlider = %Position


func _ready() -> void:
	_index.text = str(feature.feature_index)
	var value_range = feature.outputs[GSOutputType.HW_POSITION_WITH_DURATION].value_range
	_position.min_value = value_range.range_min
	_position.max_range = value_range.range_max
	var duration_range = feature.outputs[GSOutputType.HW_POSITION_WITH_DURATION].duration_range
	_duration.min_value = duration_range.range_min
	_duration.max_value = duration_range.range_max

func _on_position_value_changed(value: float) -> void:
	await GSClient.send_feature(
		feature,
		GSOutputType.HW_POSITION_WITH_DURATION,
		value,
		_duration.value,
	)
