extends AnimatedSprite2D

@onready var area = $Area2D

@export var frames_per_update: int = 10
@onready var pixels_per_second = 60.0 / frames_per_update
var iteration = 0

var bodies_on_platform = 0
var play_direction = -1  # 1 = forward, -1 = backward

func _ready():
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

	animation = "default"
	pause()
	frame = 0

func _on_body_entered(body):
	if bodies_on_platform == 0:
		play_direction = 1
	bodies_on_platform += 1

func _on_body_exited(body):
	bodies_on_platform -= 1
	if bodies_on_platform == 0:
		play_direction = -1

func _physics_process(delta):
	iteration = (iteration + 1) % frames_per_update
	if iteration != 0:
		return


	var last_frame = sprite_frames.get_frame_count(animation) - 1
	frame += play_direction
	if frame < 0:
		frame = 0
	elif frame > last_frame:
		frame = last_frame


	#print(sprite.frame)
