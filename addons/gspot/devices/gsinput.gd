class_name GSInput
extends RefCounted
## The attributes for an input (sensor) that a feature supports.

## The [GSFeature] this input describes.
var feature: GSFeature
## The type of input this object describes.
var input_type: String
## The commands this input allows. Can include "Read", "Subscribe", and "Unsubscribe".
## If "Subscribe" is present, so should "Unsubscribe".
var commands: Array[String] #TODO: Make corresponding consts
## Range of possible values reading the input can return.
var value_range: GSRange

static func deserialize(input_type: String, data: Dictionary) -> GSInput:
	var input := GSInput.new()
	input.input_type = input_type
	if data.has(GSMessage.MESSAGE_FIELD_COMMAND):
		for command: String in data[GSMessage.MESSAGE_FIELD_COMMAND]:
			input.commands.append(command)
	if data.has(GSMessage.MESSAGE_FIELD_VALUE):
		var value_range = data[GSMessage.MESSAGE_FIELD_VALUE]
		if (value_range.size() == 2):
			input.value_range = GSRange.new(value_range[0], value_range[1])
	return input
