extends "res://scripts/player.gd"

# Don't override the existing player functionality
# Just add health tracking and ground pound
@export var max_health = 3
var current_health = 3
@onready var ground_pound_ability = $GroundPoundAbility
var is_ground_pounding = false

# Bounce back variables
var invincible = false
var bounce_force = 300

# Sound effect setup
@onready var bump_sound_player = AudioStreamPlayer.new()
@export var bump_sound_path : String = "res://audio/effects/bump.wav"  # Change this to your sound file
@export_range(0.0, 1.0) var bump_sound_volume : float = 0.7
@export_range(0.5, 2.0) var bump_sound_pitch : float = 1.0

func _ready():
	# Call parent _ready first
	super._ready()
	
	# CORRECT collision setup - player should detect ground layer
	collision_layer = 1  # Player is on layer 1
	collision_mask = 4   # Detect layer 3 (ground) - this is 2^2 = 4, not 3!
	
	# Setup bump sound
	setup_bump_sound()
	
	# Initialize health
	current_health = max_health
	print("Player health system ready")
	print("Player collision_layer: ", collision_layer)
	print("Player collision_mask: ", collision_mask)

func setup_bump_sound():
	add_child(bump_sound_player)
	bump_sound_player.volume_db = linear_to_db(bump_sound_volume)
	bump_sound_player.pitch_scale = bump_sound_pitch
	
	# Try to load the sound file
	if ResourceLoader.exists(bump_sound_path):
		bump_sound_player.stream = load(bump_sound_path)
		print("Bump sound loaded successfully")
	else:
		print("Bump sound not found at: ", bump_sound_path, " - will play without sound")

func play_bump_sound():
	if bump_sound_player.stream:
		bump_sound_player.stop()
		bump_sound_player.play()
	else:
		print("No bump sound available")

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

# Function to take damage with gentle bounce back
func take_damage(amount = 1, attacker = null):
	# Don't take damage if ground pounding or already invincible
	if is_ground_pounding or invincible:
		print("Ladybug is ground pounding or invincible - no damage taken")
		return
	
	print("Ladybug got bumped! Bouncing back...")
	
	# Play bump sound effect
	play_bump_sound()
	
	# Start invincibility period
	invincible = true
	
	# Calculate bounce direction based on attacker position
	var bounce_direction = Vector2.ZERO
	
	if attacker and is_instance_valid(attacker):
		# Calculate direction away from the attacker
		bounce_direction = (global_position - attacker.global_position).normalized()
		print("Bouncing away from attacker at: ", attacker.global_position)
		print("Player position: ", global_position)
		print("Bounce direction: ", bounce_direction)
	else:
		# Fallback: use sprite facing direction
		bounce_direction = Vector2(-1, 0) if $AnimatedSprite2D.flip_h else Vector2(1, 0)
		print("No attacker provided, using fallback bounce direction: ", bounce_direction)
	
	# Apply bounce force in calculated direction
	velocity.x = bounce_direction.x * bounce_force  # Horizontal bounce away from enemy
	velocity.y = -100  # Always bounce up regardless of enemy position
	
	print("Applied bounce: velocity is now ", velocity)
	
	# Visual feedback - gentle flash with scale bounce
	var tween = create_tween()
	
	# Scale bounce effect
	tween.tween_property(self, "scale", Vector2(1.2, 0.8), 0.1)  # Squash
	tween.tween_property(self, "scale", Vector2(0.9, 1.1), 0.1)  # Stretch
	tween.tween_property(self, "scale", Vector2(1, 1), 0.1)      # Back to normal
	
	# Flashing effect (parallel to scale)
	var flash_tween = create_tween()
	for i in range(4):  # Flash 4 times
		flash_tween.tween_property($AnimatedSprite2D, "modulate", Color(1, 1, 1, 0.3), 0.15)
		flash_tween.tween_property($AnimatedSprite2D, "modulate", Color(1, 1, 1, 1), 0.15)
	
	# Optional: Reduce health for tracking (but don't die)
	# current_health -= amount
	# print("Player health: ", current_health)
	
	# End invincibility after 1.2 seconds
	await get_tree().create_timer(1.2).timeout
	invincible = false
	print("Ladybug is ready for more adventure!")

func perform_simple_ground_pound():
	print("=== GROUND POUND DETECTION STARTED ===")
	var ground_pound_radius = 150  # Increased radius for easier testing
	var enemies = get_tree().get_nodes_in_group("enemies")
	print("Found ", enemies.size(), " enemies for ground pound check")
	print("Player position: ", global_position)
	
	if enemies.size() == 0:
		print("ERROR: No enemies found in 'enemies' group!")
		return
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
			
		var distance = global_position.distance_to(enemy.global_position)
		print("Checking enemy at: ", enemy.global_position, " - Distance: ", distance)
		
		if distance <= ground_pound_radius:
			print("*** ENEMY IN RANGE - DESTROYING! ***")
			if enemy.has_method("take_damage"):
				enemy.take_damage()
				print("Successfully called take_damage on enemy")
			else:
				print("ERROR: Enemy doesn't have take_damage method")
		else:
			print("Enemy too far (needs to be within ", ground_pound_radius, ")")
	
	print("=== GROUND POUND DETECTION COMPLETE ===")
