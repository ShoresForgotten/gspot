class_name GSDisconnect
extends GSMessage

func _init(message_id: int) -> void:
	super._init(message_id)
	message_type = MESSAGE_TYPE_DISCONNECT
