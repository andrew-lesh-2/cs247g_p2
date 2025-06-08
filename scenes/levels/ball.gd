extends RigidBody2D

@export var max_speed: float = 200.0
@export var bounce: float = 0.2

# Anti-stuck settings - FASTER RESPONSE
@export var anti_stuck_enabled: bool = true
@export var stuck_check_interval: float = 0.05  # Much more frequent checks (was 0.2)
@export var stuck_velocity_threshold: float = 15.0  # Velocity threshold
@export var stuck_position_threshold: float = 10.0  # Position threshold
@export var escape_impulse_strength: float = 150.0  # Impulse strength
@export var max_stuck_time: float = 0.15  # MUCH shorter time before response (was 0.6)

# Sleep parameters for visual smoothness
@export var custom_damping: float = 0.5  # Custom damping value

var last_position: Vector2
var last_check_time: float = 0.0
var player_detected: bool = false
var contact_bodies = []
var player_stuck_time: float = 0.0  # Track how long player might be stuck

func _ready():
	# Critical physics settings
	gravity_scale = 1.0
	contact_monitor = true
	max_contacts_reported = 4  
	mass = 2.0  # Not too heavy, not too light
	
	# Apply physics material with some bounce and low friction
	var physics_material = PhysicsMaterial.new()
	physics_material.friction = 0.2
	physics_material.bounce = bounce
	physics_material_override = physics_material
	
	# Make sure these are NOT set
	freeze = false
	
	# IMPORTANT: Set damping properties correctly
	# Use built-in properties rather than trying to redefine them
	linear_damp_mode = RigidBody2D.DAMP_MODE_COMBINE
	angular_damp_mode = RigidBody2D.DAMP_MODE_COMBINE
	linear_damp = custom_damping
	angular_damp = custom_damping
	
	# Important: Use continuous collision detection for better interactions
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	
	# Initialize position tracking
	last_position = global_position
	
	# Connect signals for collision detection
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	# If the body is the player, mark that we've detected the player
	if body.name == "Player" or (body.get_parent() and body.get_parent().name == "Player"):
		player_detected = true
		
		# Start checking immediately when player collides
		check_player_directly_under(0.05)
	
	# Add to our contact list
	if not contact_bodies.has(body):
		contact_bodies.append(body)

func _on_body_exited(body: Node) -> void:
	# Remove from our contact list
	if contact_bodies.has(body):
		contact_bodies.erase(body)
	
	# If player exits, reset stuck time
	if body.name == "Player" or (body.get_parent() and body.get_parent().name == "Player"):
		player_stuck_time = 0.0

func _physics_process(delta):
	# Make the ball visually roll based on its velocity
	var ball_radius = $CollisionShape2D.shape.radius
	if ball_radius > 0:
		angular_velocity = -linear_velocity.x / ball_radius
	
	# Cap maximum speed
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed
	
	# Check for stuck conditions
	if anti_stuck_enabled:
		check_player_stuck(delta)

# ONLY check if player is stuck under the ball - don't mess with resting balls
func check_player_stuck(delta: float) -> void:
	# Only run checks if player has been detected (performance optimization)
	if !player_detected:
		return
		
	# Increment check timer
	last_check_time += delta
	
	# Only run checks periodically to save performance
	if last_check_time < stuck_check_interval:
		return
	
	last_check_time = 0.0
	
	# ONLY check for player being trapped under the ball
	check_player_directly_under(delta)
	
	# Update last position for next check
	last_position = global_position

# Check if player is trapped under ball
func check_player_directly_under(delta: float) -> void:
	var space_state = get_world_2d().direct_space_state
	
	# Cast rays in multiple directions slightly below the ball
	var ray_directions = [
		Vector2(0, 1),     # Directly down
		Vector2(-0.5, 1),  # Diagonally down-left
		Vector2(0.5, 1),   # Diagonally down-right
	]
	
	var player_found = false
	var player_pos = null
	
	for dir in ray_directions:
		var query = PhysicsRayQueryParameters2D.create(
			global_position,
			global_position + dir.normalized() * 50,
			1,  # Collision mask
			[self]  # Exclude self
		)
		
		var result = space_state.intersect_ray(query)
		if result and result.has("collider"):
			var collider = result["collider"]
			if collider.name == "Player" or (collider.get_parent() and collider.get_parent().name == "Player"):
				player_found = true
				player_pos = result["position"]
				break
	
	# If player found below
	if player_found:
		# Check if player is actually stuck
		if is_player_stuck(player_pos):
			player_stuck_time += delta
			
			# FASTER RESPONSE: If player has been stuck for a short time, force an escape
			if player_stuck_time >= max_stuck_time:
				print("Player trapped under ball! Forcing escape.")
				apply_unstuck_impulse(player_pos)
				player_stuck_time = 0.0  # Reset timer
		else:
			# Gradually reduce stuck time if player is moving
			player_stuck_time = max(0.0, player_stuck_time - delta)
	else:
		# Reset timer if player not detected
		player_stuck_time = 0.0

# Check if the player is actually stuck and not moving
func is_player_stuck(player_pos: Vector2) -> bool:
	# Try to get player's velocity
	var player_is_stuck = false
	
	# Try to find player node
	var player_node = null
	for body in contact_bodies:
		if body.name == "Player":
			player_node = body
			break
		elif body.get_parent() and body.get_parent().name == "Player":
			player_node = body.get_parent()
			break
	
	if player_node and player_node.has_method("get_velocity"):
		# Check if player is barely moving horizontally
		var player_velocity = player_node.get_velocity()
		player_is_stuck = abs(player_velocity.x) < 20.0
		
		# NEW: Also check if player is trying to move but can't
		if player_node.has_method("is_trying_to_move"):
			var trying_to_move = player_node.is_trying_to_move()
			if trying_to_move and abs(player_velocity.x) < 20.0:
				# If player is trying to move but can't, definitely stuck
				player_is_stuck = true
	else:
		# If we can't get velocity, check if ball is barely moving
		# (since player would move the ball if they weren't stuck)
		player_is_stuck = linear_velocity.length() < stuck_velocity_threshold
	
	return player_is_stuck

# Stronger, directed impulse when we know player is trapped
func apply_unstuck_impulse(player_position) -> void:
	print("Player trapped! Applying escape impulse.")
	
	var impulse_dir = Vector2.ZERO
	
	# Push away from player position
	impulse_dir = (global_position - player_position).normalized()
	
	# Add more upward component
	impulse_dir += Vector2(0, -1.5)
	impulse_dir = impulse_dir.normalized()
	
	# Apply a stronger impulse for escaping from player trap
	apply_central_impulse(impulse_dir * escape_impulse_strength)
	
	# Add some torque to help break free
	apply_torque(randf_range(-200, 200))
