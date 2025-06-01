extends Node2D

@export var enable_visualization: bool = false

@onready var enabler: VisibleOnScreenEnabler2D = $VisibleOnScreenEnabler2D

func _draw():
	if enable_visualization and enabler:
		var rect = enabler.rect
		draw_rect(rect, Color.RED, false, 2)
