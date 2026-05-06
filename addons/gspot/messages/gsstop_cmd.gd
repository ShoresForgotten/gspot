class_name GSStopCmd
extends GSMessage

func _init(message_id: int, device_index = -1, feature_index = -1, inputs = true, outputs = true) -> void:
	super._init(message_id)
	message_type = GSMessage.MESSAGE_TYPE_STOP_CMD
	if device_index >= 0:
		fields[MESSAGE_FIELD_DEVICE_INDEX] = device_index
		if feature_index >= 0:
			fields[MESSAGE_FIELD_FEATURE_INDEX] = feature_index
	if !inputs:
		fields[MESSAGE_FIELD_STOPCMD_INPUTS] = inputs
	if !outputs:
		fields[MESSAGE_FIELD_STOPCMD_OUTPUTS] = outputs
