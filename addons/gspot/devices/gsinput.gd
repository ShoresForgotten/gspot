class_name GSInput
extends RefCounted

var feature: GSFeature
var input_type: String
var commands: Array[String]
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
