extends Area2D

# This script goes on the GroundPoundAbility node

func _ready():
	# Connect the body_entered signal
	connect("body_entered", Callable(self, "_on_body_entered"))
	
	# FORCE correct collision settings
	collision_layer = 5  # Ground pound layer
	collision_mask = 2   # Detect enemies on layer 2
	
	# Start with monitoring disabled
	monitoring = false
	print("GroundPoundAbility ready")
	print("Collision layer: ", collision_layer)
	print("Collision mask: ", collision_mask)

# FIXED: Changed from *on*body_entered to _on_body_entered
func _on_body_entered(body):
	print("GroundPoundAbility detected: ", body.name, " (Groups: ", body.get_groups(), ")")
	if body.is_in_group("enemies"):
		print("Body is in enemies group!")
		if body.has_method("take_damage"):
			print("Body has take_damage method - calling it now")
			body.take_damage()
		else:
			print("ERROR: Body does not have take_damage method!")
	else:
		print("Body is NOT in enemies group")

# Function to activate ground pound detection
func activate_ground_pound():
	print("=== GROUND POUND ACTIVATED ===")
	
	# Use distance-based detection instead of Area2D collision
	var ground_pound_radius = 30
	var player = get_parent()  # Get the player (parent of this GroundPoundAbility)
	
	if not player:
		print("ERROR: Could not find player!")
		return
	
	print("Player position: ", player.global_position)
	
	# Get all enemies and check distances
	var enemies = get_tree().get_nodes_in_group("enemies")
	print("Found ", enemies.size(), " enemies to check")
	
	var destroyed_count = 0
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
			
		var distance = player.global_position.distance_to(enemy.global_position)
		print("Enemy at ", enemy.global_position, " - Distance: ", distance)
		
		if distance <= ground_pound_radius:
			print("*** DESTROYING ENEMY (within ", ground_pound_radius, ") ***")
			if enemy.has_method("take_damage"):
				enemy.take_damage()
				destroyed_count += 1
			else:
				print("ERROR: Enemy missing take_damage method")
		else:
			print("Enemy too far away")
	
	print("=== GROUND POUND COMPLETE - Destroyed ", destroyed_count, " enemies ===")
