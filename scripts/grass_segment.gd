extends Node2D

@export_range(0, 26) var GRASS_SEGMENT_INDEX : int = 0:
	set(value):
		GRASS_SEGMENT_INDEX = value
		if is_node_ready():
			$AnimatedSprite2D.frame = value

const NUM_GRASS_SEGMENTS = 27

static func get_num_grass_segments():
	return NUM_GRASS_SEGMENTS

func _ready():
	$AnimatedSprite2D.play()
	$AnimatedSprite2D.frame = GRASS_SEGMENT_INDEX
	$AnimatedSprite2D.pause()
