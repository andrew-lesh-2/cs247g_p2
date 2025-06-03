# EnemySpawner.gd - Attach this to a Node in your scene
extends Node

@export var dust_mite_scene : PackedScene  # Drag your DustMiteEnemy.tscn here
@export var spawn_count : int = 8          # Number of enemies to spawn
@export var spawn_area_width : float = 800  # How wide the spawn area is
@export var spawn_area_height : float = 10  # Keep this VERY small to stay on ground level
@export var spawn_y_position : float = 308  # Use the SAME Y as your player (from debug: -56.0, 308.9991)
@export var spawn_center_x : float = 400    # Center X position for spawning
@export var min_distance_between_enemies : float = 150 # Increased to prevent overlapping

func _ready():
	# Wait a moment for the scene to fully load
	await get_tree().create_timer(0.1).timeout
	
	# Wait for dialog to finish before spawning enemies
	print("Enemy spawner waiting for dialog to finish...")
	await wait_for_dialog_completion()
	
	# Now spawn the enemies
	spawn_enemies()

# Wait for the combat intro dialog to complete
func wait_for_dialog_completion():
	# Check if DialogSystem exists
	if not has_node("/root/DialogSystem"):
		print("No DialogSystem found, spawning enemies immediately")
		return
	
	# Wait until dialog is no longer active
	while DialogSystem.is_active:
		await get_tree().create_timer(0.1).timeout
	
	# Add a small delay after dialog ends for dramatic effect
	await get_tree().create_timer(0.5).timeout
	print("Dialog finished, now spawning enemies!")

func spawn_enemies():
	if not dust_mite_scene:
		print("ERROR: No dust mite scene assigned! Drag DustMiteEnemy.tscn to the Dust Mite Scene property.")
		return
	
	print("Spawning ", spawn_count, " dust mites...")
	
	var spawned_positions = []
	
	for i in range(spawn_count):
		var attempts = 0
		var spawn_position = Vector2.ZERO
		var valid_position = false
		
		# Try to find a position that's not too close to other enemies
		while not valid_position and attempts < 50:
			# Random position around the spawn center
			var spawn_x = spawn_center_x + randf_range(-spawn_area_width/2, spawn_area_width/2)
			var spawn_y = spawn_y_position + randf_range(-spawn_area_height/2, spawn_area_height/2)
			spawn_position = Vector2(spawn_x, spawn_y)
			
			# Check if this position is far enough from other enemies
			valid_position = true
			for existing_pos in spawned_positions:
				if spawn_position.distance_to(existing_pos) < min_distance_between_enemies:
					valid_position = false
					break
			
			attempts += 1
		
		# Create new dust mite
		var dust_mite = dust_mite_scene.instantiate()
		dust_mite.global_position = spawn_position
		
		# Make sure it's in the enemies group
		dust_mite.add_to_group("enemies")
		
		# Add to scene
		get_parent().add_child(dust_mite)
		spawned_positions.append(spawn_position)
		
		print("Spawned dust mite #", i+1, " at: ", dust_mite.global_position)
		print("  - Enemy name: ", dust_mite.name)
		print("  - Enemy groups: ", dust_mite.get_groups())
	
	print("Successfully spawned ", spawn_count, " dust mites!")
