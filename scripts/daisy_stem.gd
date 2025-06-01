extends Node2D

@export_range(0, 3) var STEM_SEGMENT_INDEX : int = 0:
	set(value):
		STEM_SEGMENT_INDEX = value
		if is_node_ready():
			$AnimatedSprite2D.frame = value

func _ready():
	$AnimatedSprite2D.play()
	$AnimatedSprite2D.frame = STEM_SEGMENT_INDEX
	$AnimatedSprite2D.pause()
