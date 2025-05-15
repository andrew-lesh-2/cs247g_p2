extends Node

# Called when the autoload script is loaded
func _ready():
	# Wait a frame to ensure all nodes are ready
	await get_tree().process_frame
	
	# First, find all StaticBody2D nodes and add them to the group
	add_all_platforms_to_group()
	
	# Then configure them as one-way platforms
	configure_all_platforms()
	
	print("One-way platforms configured successfully")

func add_all_platforms_to_group():
	# Find all StaticBody2D nodes in the scene
	var static_bodies = []
	find_all_staticbody2d(get_tree().get_root(), static_bodies)
	
	# Add them to the one_way_platform group
	for platform in static_bodies:
		if not platform.is_in_group("one_way_platform"):
			platform.add_to_group("one_way_platform")
			print("Added " + platform.name + " to one_way_platform group")

func find_all_staticbody2d(node, result_array):
	# Recursively search for all StaticBody2D nodes
	if node is StaticBody2D:
		result_array.append(node)
	
	for child in node.get_children():
		find_all_staticbody2d(child, result_array)

func configure_all_platforms():
	# Find all StaticBody2D nodes that should be one-way platforms
	var platforms = get_tree().get_nodes_in_group("one_way_platform")
	
	for platform in platforms:
		# Apply one-way platform properties
		setup_platform(platform)
		print("Configured " + platform.name + " as one-way platform")

func setup_platform(platform):
	# Make sure the player is in a group
	ensure_player_in_group()
	
	# Add a child node with a script to handle the one-way collision
	var handler = Node.new()
	handler.name = "OneWayCollisionHandler"
	platform.add_child(handler)
	
	var script = GDScript.new()
	script.source_code = """
	extends Node
	
	var player
	var platform
	
	func _ready():
		platform = get_parent()
		# Store original collision layer for restoration
		platform.set_meta("original_layer", platform.collision_layer)
		
		# Wait a moment to find the player
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			push_error("Player node not found! Make sure your player is in the 'player' group.")
	
	func _physics_process(_delta):
		if player == null:
			# Try again to find player
			player = get_tree().get_first_node_in_group("player")
			return
			
		# Allow player to pass through when moving upward
		if player.global_position.y > platform.global_position.y and player.velocity.y < 0:
			# Disable collision when player is below and moving up
			platform.collision_layer = 0
		else:
			# Enable collision in all other cases
			platform.collision_layer = platform.get_meta("original_layer", 1)
			
		# Allow player to drop through platform by pressing down + jump
		if player.is_on_floor() and player.global_position.y < platform.global_position.y:
			if Input.is_action_pressed("ui_down") and Input.is_action_just_pressed("ui_accept"):
				platform.collision_layer = 0
				# Re-enable collision after a short delay
				await get_tree().create_timer(0.3).timeout
				platform.collision_layer = platform.get_meta("original_layer", 1)
	"""
	
	handler.set_script(script)

func ensure_player_in_group():
	# Try to find the player node - this assumes you have a node named "Player"
	var player_nodes = []
	find_nodes_by_name("Player", get_tree().get_root(), player_nodes)
	
	if player_nodes.size() > 0:
		var player = player_nodes[0]
		if not player.is_in_group("player"):
			player.add_to_group("player")
			print("Added " + player.name + " to player group")

func find_nodes_by_name(name_to_find, node, result_array):
	# Recursively search for nodes with a specific name
	if node.name == name_to_find:
		result_array.append(node)
	
	for child in node.get_children():
		find_nodes_by_name(name_to_find, child, result_array)
