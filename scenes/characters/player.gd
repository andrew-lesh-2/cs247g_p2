extends "res://scripts/player.gd"

# Don't override the existing player functionality
# Just add health tracking and ground pound
@export var max_health = 3
var current_health = 3
@onready var ground_pound_ability = $GroundPoundAbility
var is_ground_pounding = false

func _ready():
	# Call parent _ready first
	super._ready()
	# Initialize health
	current_health = max_health
	print("Player health system ready")

# Override the physics process to add ground pound logic
func _physics_process(delta):
	# Call the parent's physics process first
	super._physics_process(delta)

	# Add ground pound logic
	# Handle ground pound
	if Input.is_action_just_pressed("ui_down") and not is_on_floor() and not is_ground_pounding:
		is_ground_pounding = true
		velocity.y = 800  # Fast downward velocity
		velocity.x = 0    # Stop horizontal movement
		# Visual feedback
		modulate = Color(1, 0.5, 0.5)
		await get_tree().create_timer(0.1).timeout
		modulate = Color(1, 1, 1)

	# Check if ground pound finished (when we hit the ground)
	if is_ground_pounding and is_on_floor():
		print("Ground pound landed!")
		is_ground_pounding = false
		if ground_pound_ability:
			ground_pound_ability.activate_ground_pound()

# Simple function to take damage
func take_damage(amount = 1):
	current_health -= amount
	print("Player took damage! Health: ", current_health)

	# Visual feedback for taking damage
	modulate = Color(1, 0.5, 0.5)  # Flash red
	await get_tree().create_timer(0.2).timeout
	modulate = Color(1, 1, 1)  # Back to normal

	if current_health <= 0:
		print("Player died!")
		# Implement game over logic later
