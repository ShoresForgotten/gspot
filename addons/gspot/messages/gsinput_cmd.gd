class_name GSInputCmd
extends GSMessage

# Command could probably be turned into an enum, it's unlikely that more types will exist
func _init(message_id: int, device_index: int, feature_index: int, input_type: String, command: String) -> void:
	super._init(message_id)
	message_type = MESSAGE_TYPE_INPUT_CMD
	fields[MESSAGE_FIELD_DEVICE_INDEX] = device_index
	fields[MESSAGE_FIELD_FEATURE_INDEX] = feature_index
	fields[MESSAGE_FIELD_INPUT_TYPE] = input_type
	fields[MESSAGE_FIELD_COMMAND] = command
