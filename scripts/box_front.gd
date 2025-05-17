extends Sprite2D

@onready var area = $Area2D
@export var fade_frames: int = 10

var bodies_in_area = 0
var fade_progress = 0.0
var target_alpha = 1.0
var current_alpha = 1.0

func _ready():
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	modulate.a = current_alpha

func _process(delta):
	if fade_progress < 1.0:
		fade_progress += 1.0 / fade_frames
		current_alpha = lerp(current_alpha, target_alpha, fade_progress)
		modulate.a = current_alpha
		if fade_progress >= 1.0:
			fade_progress = 0.0

func _on_body_entered(body):
	bodies_in_area += 1
	print("body entered box area")
	if bodies_in_area == 1:  # Only start fade if this is the first body
		target_alpha = 0.0
		fade_progress = 0.0

func _on_body_exited(body):
	print("body exited box area")
	bodies_in_area -= 1
	if bodies_in_area == 0:  # Only start fade if this was the last body
		target_alpha = 1.0
		fade_progress = 0.0
