# room.gd
extends Node2D

# Room properties
@export var tile_size: Vector2 = Vector2(128, 128)  # Size of each tile
@export var room_width: int = 4  # Number of tiles (bed, window, toys, door)
@export var zoom_level: int = 12  # Same scale as box scene

# Room boundaries
var left_boundary: float = 0
var right_boundary: float = 0
var top_boundary: float = 0
var bottom_boundary: float = 0

# References to tile nodes
@onready var tile_container = $tilecontainer

# Reference to player (will find in _ready)
var player = null
var is_initialized = false

# Mask elements
var mask_layer
var masks = []

func _ready():
	# Set black background
	RenderingServer.set_default_clear_color(Color(0, 0, 0, 1))
	
	# Find player
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_error("Player not found! Make sure it's added to the scene and in the 'player' group")
	
	# Calculate room boundaries
	calculate_boundaries()
	
	# Set up looping boundaries
	setup_boundaries()
	
	# Create black mask
	create_mask()
	
	# Connect to signals
	connect_signals()
	
	# Wait a moment for everything to initialize
	await get_tree().create_timer(0.2).timeout
	is_initialized = true
	
	print("Room initialized with width:", room_width, "tiles")

func calculate_boundaries():
	# The boundaries are determined by the positions and sizes of the tiles
	# Calculate the actual boundaries based on zoom level and positions
	
	# If tile container exists
	if tile_container:
		# Get the leftmost and rightmost positions
		var leftmost = INF
		var rightmost = -INF
		var topmost = INF
		var bottommost = -INF
		
		# Go through each tile and find the extremes
		for child in tile_container.get_children():
			if child is Node2D and child.get_child_count() > 0:
				var visual = null
				
				# Find the TextureRect
				for grandchild in child.get_children():
					if grandchild is TextureRect:
						visual = grandchild
						break
				
				if visual:
					# Calculate global bounds
					var left = child.global_position.x
					var top = child.global_position.y
					var right = left + visual.size.x
					var bottom = top + visual.size.y
					
					# Update extremes
					leftmost = min(leftmost, left)
					rightmost = max(rightmost, right)
					topmost = min(topmost, top)
					bottommost = max(bottommost, bottom)
		
		# Set boundaries
		if leftmost != INF and rightmost != -INF:
			left_boundary = leftmost
			right_boundary = rightmost
			top_boundary = topmost
			bottom_boundary = bottommost
			
			print("Room boundaries calculated from tiles:")
			print("- Left:", left_boundary)
			print("- Right:", right_boundary)
			print("- Top:", top_boundary)
			print("- Bottom:", bottom_boundary)
		else:
			# Fallback - estimate boundaries
			fallback_boundary_calculation()
	else:
		# Fallback - estimate boundaries
		fallback_boundary_calculation()

func fallback_boundary_calculation():
	# If we couldn't determine boundaries from tiles, estimate them
	var viewport_size = get_viewport_rect().size
	var scaled_tile_size = tile_size * zoom_level
	var total_width = scaled_tile_size.x * room_width
	
	var center = viewport_size / 2
	
	left_boundary = center.x - (total_width / 2)
	right_boundary = center.x + (total_width / 2)
	top_boundary = center.y - (scaled_tile_size.y / 2)
	bottom_boundary = center.y + (scaled_tile_size.y / 2)
	
	print("Room boundaries estimated (fallback):")
	print("- Left:", left_boundary)
	print("- Right:", right_boundary)
	print("- Top:", top_boundary)
	print("- Bottom:", bottom_boundary)

func get_boundaries():
	# Helper function to expose boundaries to SceneTransition
	return {
		"left": left_boundary,
		"right": right_boundary,
		"top": top_boundary,
		"bottom": bottom_boundary
	}

func setup_boundaries():
	# Create areas for horizontal looping and vertical scene transition
	
	# Left boundary
	var left_area = create_boundary_area("LoopLeft", Vector2(left_boundary - 10, top_boundary), Vector2(20, bottom_boundary - top_boundary))
	left_area.connect("body_entered", Callable(self, "_on_left_boundary_entered"))
	
	# Right boundary
	var right_area = create_boundary_area("LoopRight", Vector2(right_boundary - 10, top_boundary), Vector2(20, bottom_boundary - top_boundary))
	right_area.connect("body_entered", Callable(self, "_on_right_boundary_entered"))
	
	# Top boundary
	var top_area = create_boundary_area("ExitTop", Vector2(left_boundary, top_boundary - 50), Vector2(right_boundary - left_boundary, 40))
	top_area.connect("body_entered", Callable(self, "_on_exit_boundary_entered"))
	
	# Bottom boundary
	var bottom_area = create_boundary_area("ExitBottom", Vector2(left_boundary, bottom_boundary + 10), Vector2(right_boundary - left_boundary, 40))
	bottom_area.connect("body_entered", Callable(self, "_on_exit_boundary_entered"))

func create_boundary_area(name: String, position: Vector2, size: Vector2) -> Area2D:
	var area = Area2D.new()
	area.name = name
	area.position = position
	
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	
	area.add_child(collision)
	add_child(area)
	
	return area

func connect_signals():
	# Connect to window resize signal
	get_viewport().size_changed.connect(Callable(self, "on_window_resized"))

func on_window_resized():
	# Recalculate boundaries and update when window is resized
	calculate_boundaries()
	
	# Update boundary positions
	update_boundary_positions()
	
	# Update mask
	update_mask()

func update_boundary_positions():
	# Update the collision areas to match new boundaries
	var loop_left = get_node_or_null("LoopLeft")
	var loop_right = get_node_or_null("LoopRight")
	var exit_top = get_node_or_null("ExitTop")
	var exit_bottom = get_node_or_null("ExitBottom")
	
	if loop_left:
		loop_left.position = Vector2(left_boundary - 10, top_boundary)
		var collision = loop_left.get_child(0)
		if collision and collision is CollisionShape2D:
			var shape = collision.shape as RectangleShape2D
			if shape:
				shape.size.y = bottom_boundary - top_boundary
	
	if loop_right:
		loop_right.position = Vector2(right_boundary - 10, top_boundary)
		var collision = loop_right.get_child(0)
		if collision and collision is CollisionShape2D:
			var shape = collision.shape as RectangleShape2D
			if shape:
				shape.size.y = bottom_boundary - top_boundary
	
	if exit_top:
		exit_top.position = Vector2(left_boundary, top_boundary - 50)
		var collision = exit_top.get_child(0)
		if collision and collision is CollisionShape2D:
			var shape = collision.shape as RectangleShape2D
			if shape:
				shape.size.x = right_boundary - left_boundary
	
	if exit_bottom:
		exit_bottom.position = Vector2(left_boundary, bottom_boundary + 10)
		var collision = exit_bottom.get_child(0)
		if collision and collision is CollisionShape2D:
			var shape = collision.shape as RectangleShape2D
			if shape:
				shape.size.x = right_boundary - left_boundary

func _on_left_boundary_entered(body):
	if body == player and is_initialized:
		print("Player crossed left boundary, looping to right")
		# Move player to right side of room
		player.position.x += (right_boundary - left_boundary) - 20

func _on_right_boundary_entered(body):
	if body == player and is_initialized:
		print("Player crossed right boundary, looping to left")
		# Move player to left side of room
		player.position.x -= (right_boundary - left_boundary) - 20

func _on_exit_boundary_entered(body):
	if body == player and is_initialized:
		var area_name = body.get_parent().name
		print("Player exited room via", area_name)
		
		# Store exit direction information
		var exit_data = {
			"left": false,
			"right": false,
			"top": area_name == "ExitTop",
			"bottom": area_name == "ExitBottom"
		}
		
		# Transition to box scene
		if has_node("/root/SceneTransition"):
			# Store exit direction
			SceneTransition.exit_direction = exit_data
			SceneTransition.transition_to_scene("res://box.tscn")
		else:
			push_error("SceneTransition singleton not found!")

# Mask creation for black border outside the room
func create_mask():
	# Remove any existing mask
	if mask_layer:
		mask_layer.queue_free()
		masks.clear()
	
	# Create a new CanvasLayer for our masks
	mask_layer = CanvasLayer.new()
	mask_layer.name = "MaskLayer"
	mask_layer.layer = 100  # Very high layer
	add_child(mask_layer)
	
	# Calculate mask positions based on room boundaries
	var viewport_size = get_viewport_rect().size
	
	# Room boundaries in actual pixels
	var bg_pos = Vector2(left_boundary, top_boundary)
	var bg_size = Vector2(right_boundary - left_boundary, bottom_boundary - top_boundary)
	
	# Use black masks
	var black = Color(0, 0, 0, 1.0)
	
	# Top mask
	var top_mask = ColorRect.new()
	top_mask.name = "TopMask"
	top_mask.color = black
	top_mask.position = Vector2(0, 0)
	top_mask.size = Vector2(viewport_size.x, bg_pos.y)
	mask_layer.add_child(top_mask)
	masks.append(top_mask)
	
	# Bottom mask
	var bottom_mask = ColorRect.new()
	bottom_mask.name = "BottomMask"
	bottom_mask.color = black
	bottom_mask.position = Vector2(0, bg_pos.y + bg_size.y)
	bottom_mask.size = Vector2(viewport_size.x, viewport_size.y - (bg_pos.y + bg_size.y))
	mask_layer.add_child(bottom_mask)
	masks.append(bottom_mask)
	
	# Left mask
	var left_mask = ColorRect.new()
	left_mask.name = "LeftMask"
	left_mask.color = black
	left_mask.position = Vector2(0, bg_pos.y)
	left_mask.size = Vector2(bg_pos.x, bg_size.y)
	mask_layer.add_child(left_mask)
	masks.append(left_mask)
	
	# Right mask
	var right_mask = ColorRect.new()
	right_mask.name = "RightMask"
	right_mask.color = black
	right_mask.position = Vector2(bg_pos.x + bg_size.x, bg_pos.y)
	right_mask.size = Vector2(viewport_size.x - (bg_pos.x + bg_size.x), bg_size.y)
	mask_layer.add_child(right_mask)
	masks.append(right_mask)

func update_mask():
	# Just recreate the mask when window is resized
	call_deferred("create_mask")
