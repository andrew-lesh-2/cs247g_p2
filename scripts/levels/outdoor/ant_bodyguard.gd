extends Node2D

@onready var area = $Area2D
var timer: Timer

func _ready():
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

	# Create and setup timer
	timer = Timer.new()
	timer.one_shot = true
	add_child(timer)

func _on_body_entered(body):
	if body is Player:
		body.disable_player_input = true
		print("disabling player input")
		timer.start(1)
		await timer.timeout
		body.input_virtual_dir(Vector2.RIGHT)

func _on_body_exited(body):
	if body is Player:
		timer.start(.2)
		await timer.timeout

		body.input_virtual_dir_pulse(Vector2.LEFT)
		timer.start(1.0)
		await timer.timeout
		print("enabling player input")
		body.disable_player_input = false
