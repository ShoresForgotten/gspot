class_name GSOutput
extends RefCounted
## The attributes for an output (actuator) command type that a feature supports.

## The [GSFeature] this output describes the commands for.
var feature: GSFeature
## The command type that this output describes.
var command_type: String
## The range of possible values this output accepts.
var value_range: GSRange
## The range of possible durations this value accepts. Only exists if [member GSOutput.command_type]
## is [constant GSOutputType.HW_POSITION_WITH_DURATION].
var duration_range: GSRange

static func deserialize(output_type: String, data: Dictionary) -> GSOutput:
	var output := GSOutput.new()
	output.command_type = output_type
	if data.has(GSMessage.MESSAGE_FIELD_VALUE):
		var value_range_raw: Array = data[GSMessage.MESSAGE_FIELD_VALUE]
		if (value_range_raw.size() == 2):
			output.value_range = GSRange.new(value_range_raw[0], value_range_raw[1])
	if data.has(GSMessage.MESSAGE_FIELD_DURATION) && output_type == GSOutputType.HW_POSITION_WITH_DURATION:
		var duration_range_raw: Array[int] = data[GSMessage.MESSAGE_FIELD_DURATION]
		if (duration_range_raw.size() == 2):
			output.duration_range = GSRange.new(duration_range_raw[0], duration_range_raw[1])
	return output
