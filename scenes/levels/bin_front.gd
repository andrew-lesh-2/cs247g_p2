extends Sprite2D

@onready var area = $Area2D

@export var fade_frames: int = 10
@export var keep_hidden: bool = false

# We start fully visible (alpha = 1.0)
var current_alpha: float = 1.0
var target_alpha: float = 1.0
var bodies_in_area: int = 0

func _ready():
	if not area:
		push_error("❌ bin-front script: could not find Area2D as a direct child!")
		return

	# Turn on monitoring just to be sure
	area.monitoring = true
	area.body_entered.connect(Callable(self, "_on_body_entered"))
	area.body_exited.connect(Callable(self, "_on_body_exited"))


	# Initialize as fully opaque
	current_alpha = 1.0
	modulate.a = current_alpha
	print("✅ bin-front ready, starting alpha=", current_alpha)


func _process(_delta):
	var alpha_shift = 1.0 / fade_frames

	# Decide where we want to head: 0.0 if someone is in the area (or keep_hidden), else 1.0
	if bodies_in_area > 0 or keep_hidden:
		target_alpha = 0.0
	else:
		target_alpha = 1.0

	# Move current_alpha toward target_alpha
	if current_alpha < target_alpha:
		current_alpha = min(current_alpha + alpha_shift, target_alpha)
	elif current_alpha > target_alpha:
		current_alpha = max(current_alpha - alpha_shift, target_alpha)

	modulate.a = current_alpha
	# (Optional) print once when we change state:
	# if is_equal_approx(current_alpha, target_alpha):
		# only print when we actually finish a fade
		#print("bin-front _process: reached target_alpha=", target_alpha)

func _on_body_entered(body):
	# Only count the player (assuming your player is in a "player" group)
	if body.is_in_group("player"):
		bodies_in_area += 1
		print("▶ Entered: ", body.name, "   count=", bodies_in_area)
	else:
		# Other things (tiles, other Areas) should NOT increment
		#print("▶ Ignored non-player body: ", body.name)
		pass

func _on_body_exited(body):
	if body.is_in_group("player"):
		bodies_in_area = max(0, bodies_in_area - 1)
		print("◀ Exited:  ", body.name, "   count=", bodies_in_area)
	else:
		pass
