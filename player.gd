extends CharacterBody2D

const SPEED = 50.0
const JUMP_VELOCITY = -250.0

# Get the gravity from the project settings to be synced with RigidBody nodes
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var default_gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var slow_fall_gravity = default_gravity * 0.2  # Adjust this multiplier to control how slow the fall is

# Double jump variables
var has_double_jumped = false
var coyote_time = 0.1  # Gives player a small window to jump after leaving platform
var coyote_timer = 0.0

# Dialog control variable
var can_move = true

# Jump sound variables
@onready var jump_sound_player = AudioStreamPlayer.new()
@export var jump_sound_path: String = "res://audio/effects/bounce.wav"
@export_range(0.0, 1.0) var jump_sound_volume: float = 0.5
@export_range(0.5, 2.0) var jump_sound_pitch: float = 1.0
@export var play_sound_for_double_jump: bool = true

func _ready():
	# Add to player group for NPC detection
	add_to_group("player")
	
	# Connect to dialog system signals
	if has_node("/root/DialogSystem"):
		DialogSystem.connect("dialog_started", Callable(self, "_on_dialog_started"))
		DialogSystem.connect("dialog_finished", Callable(self, "_on_dialog_finished"))
	else:
		print("Warning: DialogSystem not found, dialog pause functionality disabled")
	
	# Set up jump sound
	setup_jump_sound()

func setup_jump_sound():
	# Add the audio player as a child of the player
	add_child(jump_sound_player)
	
	# Set volume and default pitch
	jump_sound_player.volume_db = linear_to_db(jump_sound_volume)
	jump_sound_player.pitch_scale = jump_sound_pitch
	
	# Load the jump sound
	if ResourceLoader.exists(jump_sound_path):
		var sound = load(jump_sound_path)
		jump_sound_player.stream = sound
		print("Successfully loaded jump sound: ", jump_sound_path)
	else:
		push_error("Failed to load jump sound at: " + jump_sound_path)

# Play jump sound with slight pitch variation
func play_jump_sound(is_double_jump: bool = false):
	if jump_sound_player and jump_sound_player.stream:
		# Stop any currently playing jump sound
		jump_sound_player.stop()
		
		# Add pitch variation for double jump if enabled
		if is_double_jump and play_sound_for_double_jump:
			jump_sound_player.pitch_scale = jump_sound_pitch * 1.2  # Slightly higher pitch for double jump
		else:
			jump_sound_player.pitch_scale = jump_sound_pitch
		
		# Play the sound
		jump_sound_player.play()

func _physics_process(delta):
	# Skip movement processing if dialog is active
	if not can_move:
		# Keep the character in place during dialog
		$AnimatedSprite2D.play("idle")
		return
		
	# Determine which gravity to use based on player input and vertical velocity
	if not is_on_floor():
		if velocity.y > 0 and Input.is_action_pressed("ui_accept"):
			# Slow fall when holding jump while falling
			velocity.y += slow_fall_gravity * delta
		else:
			# Normal gravity otherwise
			velocity.y += default_gravity * delta
		coyote_timer += delta
	else:
		# Reset double jump when touching the floor
		has_double_jumped = false
		coyote_timer = 0.0

	# Handle jumps (with double jump)
	if Input.is_action_just_pressed("ui_accept"):
		if is_on_floor() or coyote_timer < coyote_time:
			# First jump
			velocity.y = JUMP_VELOCITY
			coyote_timer = coyote_time  # Prevent "coyote jumps" after intentional jump
			play_jump_sound(false)  # Play regular jump sound
		elif not has_double_jumped:
			# Double jump
			velocity.y = JUMP_VELOCITY * 0.8  # Slightly reduced height for double jump
			has_double_jumped = true
			play_jump_sound(true)  # Play double jump sound

	# Get the input direction and handle the movement/deceleration
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
		if is_on_floor():  # Only play walk animation when on ground
			$AnimatedSprite2D.play("walk")
		# Flip the sprite based on direction
		$AnimatedSprite2D.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		if is_on_floor():  # Only play idle animation when on ground
			$AnimatedSprite2D.play("idle")
	
	# Handle jumping animation
	if not is_on_floor():
		$AnimatedSprite2D.play("jump")

	move_and_slide()

func _on_dialog_started(_npc_id):
	# Freeze player movement when dialog starts
	print("Player: Movement paused for dialog")
	can_move = false
	
	# Optional: Stop any ongoing movement
	velocity = Vector2.ZERO

func _on_dialog_finished(_npc_id):
	# Restore player movement when dialog ends
	print("Player: Movement restored after dialog")
	can_move = true
