extends Camera2D

var shake_amount = 0.0
var shake_decay = 5.0

var original_position = Vector2.ZERO

func _ready():
	original_position = position

func start_shake(amount):
	shake_amount = amount

func _process(delta):
	if shake_amount > 0:
		# Random offset
		var offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amount
		position = original_position + offset

		# Decay the shake
		shake_amount = max(0, shake_amount - delta * shake_decay)
	else:
		position = original_position
