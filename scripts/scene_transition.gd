# scene_transition.gd
extends Node

# Remember player data for transitions
var player_data = {
	"position": Vector2.ZERO,
	"velocity": Vector2.ZERO,
	"has_double_jumped": false
}

# Track which direction the player exited
var exit_direction = {
	"left": false,
	"right": false,
	"top": false,
	"bottom": false
}

# Transition to a new scene
func transition_to_scene(scene_path: String):
	print("SceneTransition: Transitioning to scene:", scene_path)
	
	# Store current player data if available
	store_player_data()
	
	# Load and change to the new scene
	if ResourceLoader.exists(scene_path):
		print("Scene exists, changing scenes...")
		call_deferred("_deferred_transition", scene_path)
	else:
		push_error("Cannot transition: Scene not found at " + scene_path)

func _deferred_transition(scene_path: String):
	print("Starting deferred transition to:", scene_path)
	
	# This is called deferred to avoid changing scenes during physics processing
	var new_scene = load(scene_path).instantiate()
	
	# Change the scene
	var tree = get_tree()
	var current_scene = tree.current_scene
	
	print("Removing current scene:", current_scene.name)
	tree.root.remove_child(current_scene)
	current_scene.queue_free()
	
	print("Adding new scene")
	tree.root.add_child(new_scene)
	tree.current_scene = new_scene
	
	# Restore player data in the new scene
	call_deferred("restore_player_data")
	
	print("Transition complete")

func store_player_data():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player_data.position = player.position
		
		if player.has_method("get_velocity"):
			player_data.velocity = player.get_velocity()
		elif player is CharacterBody2D:
			player_data.velocity = player.velocity
			
		if "has_double_jumped" in player:
			player_data.has_double_jumped = player.has_double_jumped
		
		print("Stored player data:", player_data)
	else:
		print("No player found to store data from")

func restore_player_data():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		print("Found player to restore data to")
		
		# Wait a frame to ensure the scene is fully loaded
		await get_tree().process_frame
		
		var current_scene_name = get_tree().current_scene.name
		print("Current scene for player positioning:", current_scene_name)
		
		# Position player based on scene type
		if current_scene_name == "Box":
			# Position player in box based on exit direction from room
			var viewport_size = get_viewport().get_visible_rect().size
			var center_x = viewport_size.x / 2
			var center_y = viewport_size.y / 2
			
			# Default to center
			player.position = Vector2(center_x, center_y)
			
			# If we know exit direction, adjust position
			if exit_direction.top:
				player.position.y = center_y - 50
			elif exit_direction.bottom:
				player.position.y = center_y + 50
			
			print("Positioned player in Box scene")
		
		elif current_scene_name == "Room":
			print("Positioning player in Room scene")
			# Find a reasonable position in the room
			var room = get_tree().current_scene
			
			if room.has_method("get_boundaries"):
				var boundaries = room.get_boundaries()
				var center_x = (boundaries.left + boundaries.right) / 2
				
				# Position based on exit direction from box
				if exit_direction.top:
					player.position = Vector2(center_x, boundaries.bottom - 50)
				elif exit_direction.bottom:
					player.position = Vector2(center_x, boundaries.top + 50)
				elif exit_direction.left:
					player.position = Vector2(boundaries.right - 50, (boundaries.top + boundaries.bottom) / 2)
				elif exit_direction.right:
					player.position = Vector2(boundaries.left + 50, (boundaries.top + boundaries.bottom) / 2)
				else:
					# Default center positioning
					player.position = Vector2(center_x, (boundaries.top + boundaries.bottom) / 2)
			else:
				# Fallback to viewport center
				var viewport_size = get_viewport().get_visible_rect().size
				player.position = Vector2(viewport_size.x / 2, viewport_size.y / 2)
		
		print("Restored player at position:", player.position)
	else:
		print("No player found in scene to restore data to")

# Reset exit direction info (optional - call this if you want to clear the exit data)
func reset_exit_direction():
	exit_direction = {
		"left": false,
		"right": false,
		"top": false,
		"bottom": false
	}
