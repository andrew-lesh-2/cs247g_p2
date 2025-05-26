extends Sprite2D

@export var frequency: float = 1.0  # Oscillations per second
@export var amplitude: float = 10.0  # Distance in pixels

var start_position: Vector2
var _is_in_dialog: bool = false
var player_nearby: bool = false

func _ready():
	start_position = position

func _process(delta):
	# Calculate the vertical offset using a sine wave
	var time = Time.get_ticks_msec() / 1000.0  # Convert to seconds
	var vertical_offset = sin(time * frequency * TAU) * amplitude

	# Apply the offset to the original position
	position.y = start_position.y + vertical_offset
