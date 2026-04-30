class_name GSOutput
extends RefCounted

var feature: GSFeature
var output_type: String
var value_range: GSRange
var duration_range: GSRange

static func deserialize(output_type: String, data: Dictionary) -> GSOutput:
	var output := GSOutput.new()
	output.output_type = output_type
	if data.has(GSMessage.MESSAGE_FIELD_VALUE):
		var value_range_raw: Array = data[GSMessage.MESSAGE_FIELD_VALUE]
		if (value_range_raw.size() == 2):
			output.value_range = GSRange.new(value_range_raw[0], value_range_raw[1])
	if data.has(GSMessage.MESSAGE_FIELD_DURATION) && output_type == GSOutputType.HW_POSITION_WITH_DURATION:
		var duration_range_raw: Array[int] = data[GSMessage.MESSAGE_FIELD_DURATION]
		if (duration_range_raw.size() == 2):
			output.duration_range = GSRange.new(duration_range_raw[0], duration_range_raw[1])
	return output
