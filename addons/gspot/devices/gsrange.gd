class_name GSRange
extends RefCounted
## Represents the valid range of an input or output value.

## The minimum range value.
var range_min: int = -1
## The maximum range value.
var range_max: int = -1


func _init(min: int = 0, max: int = 0) -> void:
	range_min = min
	range_max = max
