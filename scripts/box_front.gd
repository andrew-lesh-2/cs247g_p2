extends Sprite2D   
  
@onready var area = $Area2D
@export var fade_frames: int = 10
@export var keep_hidden: bool = false

var bodies_in_area = 0
var current_alpha = 0.0
var target_alpha = 1.0

func _ready():
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	modulate.a = current_alpha

func _process(delta):
	var alpha_shift = 1.0 / fade_frames
	if bodies_in_area > 0 or keep_hidden:
		target_alpha = 0.0
	else:
		target_alpha = 1.0
	
	if target_alpha > current_alpha:
		current_alpha += alpha_shift
	elif target_alpha < current_alpha:
		current_alpha -= alpha_shift
	modulate.a = current_alpha

func _on_body_entered(body):
	print("_on_body_entered")
	bodies_in_area += 1

func _on_body_exited(body):
	print("_on_body_exited")
	bodies_in_area -= 1
