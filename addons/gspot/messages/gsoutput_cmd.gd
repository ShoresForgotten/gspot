class_name GSOutputCmd
extends GSMessage

func _init(message_id: int, device_index: int, feature_index: int, command_type: String, value: int, extra: Dictionary[String, int] = {}) -> void:
	super._init(message_id)
	message_type = MESSAGE_TYPE_OUTPUT_CMD
	fields[MESSAGE_FIELD_DEVICE_INDEX] = device_index
	fields[MESSAGE_FIELD_FEATURE_INDEX] = feature_index
	var command_field: Dictionary[String, int] = {}
	command_field.assign(extra)
	command_field[MESSAGE_FIELD_VALUE] = value
	fields[MESSAGE_FIELD_COMMAND] = {command_type: command_field}
	
