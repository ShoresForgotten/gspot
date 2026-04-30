class_name GSRequestServerInfo
extends GSMessage


func _init(message_id: int) -> void:
	super._init(message_id)
	message_type = MESSAGE_TYPE_REQUEST_SERVER_INFO
	fields[MESSAGE_FIELD_CLIENT_NAME] = GSClient.get_client_string()
	fields[MESSAGE_FIELD_PROTOCOL_VERSION_MAJOR] = GSClient.PROTOCOL_VERSION_MAJOR
	fields[MESSAGE_FIELD_PROTOCOL_VERSION_MINOR] = GSClient.PROTOCOL_VERSION_MINOR
