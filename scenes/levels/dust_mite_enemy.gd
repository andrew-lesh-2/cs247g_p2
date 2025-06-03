extends CharacterBody2D

# This script goes on the DustMiteEnemy node
@onready var area = $Area2D
@onready var sprite = $AnimatedSprite2D

# Basic properties
var speed = 100
var direction = 1
var move_distance = 200
var traveled_distance = 0
var is_dying = false

# Timer-based direction changes
var direction_change_timer = 0.0
var next_direction_change_time = 2.0

# Anti-stuck system
var last_position = Vector2.ZERO
var stuck_timer = 0.0
var stuck_threshold = 1.0  # If stuck for 1 second, change direction

# Floor detection
var ground_level = 308.0  # Adjust this to match your ground Y position
var max_fall_distance = 50.0  # How far below ground before correction

# Randomization ranges
var min_speed = 60
var max_speed = 140
var min_move_distance = 100
var max_move_distance = 400

signal collided_with_player

func _ready():
	# Randomize each dust mite's properties
	randomize_properties()
	
	if area:
		area.connect("body_entered", Callable(self, "_on_body_entered"))
		print("Area2D signal connected successfully")
	else:
		print("ERROR: No Area2D found on ", name)
	
	add_to_group("enemies")
	print(name, " dust mite ready - Speed: ", speed, ", Direction: ", direction, ", Move Distance: ", move_distance)

func randomize_properties():
	# Random speed
	speed = randi_range(min_speed, max_speed)
	
	# Random starting direction
	direction = 1 if randf() > 0.5 else -1
	
	# Random move distance before turning
	move_distance = randi_range(min_move_distance, max_move_distance)
	
	# Random time before first direction change (1-4 seconds)
	next_direction_change_time = randf_range(1.0, 4.0)
	
	# Random starting position in movement cycle
	traveled_distance = randf() * move_distance
	
	# Add visual variety
	add_visual_variety()
	
	print("Randomized dust mite: Speed=", speed, " MoveDistance=", move_distance, " Direction=", direction)

func add_visual_variety():
	# Random scale (80% to 120% of normal size)
	var scale_factor = randf_range(0.8, 1.2)
	scale = Vector2(scale_factor, scale_factor)
	
	# Random tint (subtle color variations)
	var color_variation = randf_range(0.8, 1.1)
	modulate = Color(
		color_variation,
		color_variation * randf_range(0.9, 1.1),
		color_variation * randf_range(0.8, 1.0),
		1.0
	)
	
	# Random animation speed (faster mites move with faster animation)
	if sprite and sprite.sprite_frames:
		var anim_speed_factor = speed / 100.0  # Base speed is 100
		# Set animation speed based on movement speed
		sprite.speed_scale = anim_speed_factor * randf_range(0.8, 1.2)

# Use _physics_process instead of _process to prevent flying
func _physics_process(delta):
	if is_dying:
		return
		
	if sprite and sprite.sprite_frames:
		sprite.play("Walk")
	
	velocity.x = speed * direction
	velocity.y = 0  # Force y velocity to zero to prevent flying
	move_and_slide()
	traveled_distance += abs(velocity.x) * delta
	
	# Floor correction - prevent getting stuck underground
	correct_floor_position()
	
	# Anti-stuck detection
	check_if_stuck(delta)
	
	# Update direction change timer
	direction_change_timer += delta
	
	# Check for random direction changes based on timer
	if direction_change_timer >= next_direction_change_time:
		random_direction_change()
	
	# Check if the DustMiteEnemy should turn around (distance-based)
	elif traveled_distance >= move_distance:
		distance_based_direction_change()

func correct_floor_position():
	# If dust mite has fallen too far below ground level, correct it
	if global_position.y > ground_level + max_fall_distance:
		print(name, " fell through floor! Correcting position from ", global_position.y, " to ", ground_level)
		global_position.y = ground_level
		velocity.y = 0
	
	# Also prevent floating too high above ground
	elif global_position.y < ground_level - 20:
		global_position.y = ground_level

func check_if_stuck(delta):
	# Check if we're moving (compare to last position)
	var movement = global_position.distance_to(last_position)
	
	if movement < 5.0:  # If we moved less than 5 pixels
		stuck_timer += delta
		if stuck_timer >= stuck_threshold:
			print(name, " appears to be stuck, changing direction")
			unstuck_behavior()
	else:
		stuck_timer = 0.0  # Reset if we're moving
	
	last_position = global_position

func unstuck_behavior():
	# Reverse direction
	direction *= -1
	sprite.flip_h = direction == -1
	
	# Much smaller random movement - reduced from 20 to 3
	var random_push = Vector2(randf_range(-3, 3), 0)
	global_position += random_push
	
	# IMPORTANT: Ensure we stay on ground level
	global_position.y = ground_level
	
	# Reset all timers
	stuck_timer = 0.0
	direction_change_timer = 0.0
	next_direction_change_time = randf_range(0.5, 1.5)
	traveled_distance = 0.0
	
	print(name, " gently unstuck and corrected to ground level")

func random_direction_change():
	print(name, " changing direction due to timer")
	direction *= -1
	sprite.flip_h = direction == -1
	
	# Reset timer and set next random change time
	direction_change_timer = 0.0
	next_direction_change_time = randf_range(2.0, 6.0)  # 2-6 seconds until next change
	
	# Reset distance counter
	traveled_distance = 0.0

func distance_based_direction_change():
	print(name, " changing direction due to distance")
	direction *= -1
	traveled_distance = 0
	sprite.flip_h = direction == -1
	
	# Also reset the timer to add some unpredictability
	direction_change_timer = 0.0
	next_direction_change_time = randf_range(1.5, 4.0)

func _on_body_entered(body):
	print("Dust mite detected collision with: ", body.name)
	
	if is_dying:
		print("Dust mite is dying, ignoring collision")
		return
	
	# Handle collisions with other enemies - push away instead of ignoring
	if body.is_in_group("enemies"):
		handle_enemy_collision(body)
		return
		
	if body.is_in_group("player"):
		print("Player collided with dust mite!")
		print("Dust mite position: ", global_position)
		print("Player position: ", body.global_position)
		emit_signal("collided_with_player")
		
		# Only damage player if they're not ground pounding
		if body.has_method("take_damage"):
			print("Calling take_damage on player")
			body.take_damage(1, self)  # Pass the enemy that hit the player
		else:
			print("Player doesn't have take_damage method")

func handle_enemy_collision(other_enemy):
	# Calculate direction away from other enemy
	var push_direction = (global_position - other_enemy.global_position).normalized()
	
	# If enemies are exactly on top of each other, use random direction
	if push_direction.length() < 0.1:
		push_direction = Vector2(randf_range(-1, 1), 0).normalized()
	
	# Change direction away from the other enemy
	if push_direction.x > 0:
		direction = 1  # Move right
	else:
		direction = -1  # Move left
	
	sprite.flip_h = direction == -1
	
	# MUCH smaller push to separate enemies - reduced from 30 to 5
	var separation_push = push_direction * 5
	separation_push.y = 0  # Don't push vertically
	global_position += separation_push
	
	# Ensure we stay on ground level after push
	global_position.y = ground_level
	
	# Reset timers to prevent immediate direction change
	direction_change_timer = 0.0
	next_direction_change_time = randf_range(1.0, 2.0)
	traveled_distance = 0.0
	
	print(name, " gently pushed away from ", other_enemy.name)

func take_damage():
	print("=== TAKE_DAMAGE CALLED ON ", name, " ===")
	
	if is_dying:
		print("Already dying, ignoring damage")
		return
	
	is_dying = true
	print("Setting is_dying to true, stopping movement")
	
	# Visual feedback
	modulate = Color(1, 0, 0)  # Turn red
	print("Changed color to red")
	
	# Disable collision to prevent further interactions
	if area:
		area.monitoring = false
		area.monitorable = false
	
	# Simple fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 0, 0, 0), 0.3)
	print("Started fade tween")
	
	# Remove after animation
	await tween.finished
	print("Tween finished, calling queue_free")
	queue_free()
