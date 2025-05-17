# box.gd - Direct fix for position tracking and transition issue
extends Node2D

@onready var background = $Background  # Reference to background TextureRect

# Mask UI elements
var mask_layer
var masks = []
var fixed_bg_size
var ignore_next_frame = false
var transition_disabled = false
var override_timer = null

# Debug visualization
var debug_draw = true

func _ready():
	# Set the default clear color to black
	RenderingServer.set_default_clear_color(Color(0, 0, 0, 1))
	
	# Add interaction key if it doesn't exist
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var event = InputEventKey.new()
		event.keycode = KEY_E
		InputMap.action_add_event("interact", event)
	
	# Detect the zoom level
	var zoom_level = detect_zoom_level()
	
	# Set the background size based on the zoom level
	fixed_bg_size = Vector2(128 * zoom_level, 128 * zoom_level)
	
	# Create black mask now and update on window resize
	create_centered_mask()
	
	# Add a timer to re-enable transitions
	override_timer = Timer.new()
	override_timer.wait_time = 1.0
	override_timer.one_shot = true
	override_timer.timeout.connect(enable_transitions)
	add_child(override_timer)
	
	# CRITICAL: Modify the size_changed connection
	get_viewport().size_changed.connect(disable_transitions)
	
	print("Box scene initialized with zoom level:", zoom_level)

func _process(delta):
	# Debug drawing
	return
	if debug_draw:
		queue_redraw()
	
	# Skip boundary check if transitions are disabled
	if transition_disabled:
		return
		
	# Active boundary checking
	#check_player_outside_boundaries()

func disable_transitions():
	print("WINDOW RESIZE - DISABLING TRANSITIONS")
	transition_disabled = true
	call_deferred("create_centered_mask")
	override_timer.start() # Start the timer to re-enable transitions

func enable_transitions():
	print("Re-enabling transitions after delay")
	transition_disabled = false

func _draw():
	if debug_draw:
		# Get viewport center and calculate background rectangle
		var viewport_size = get_viewport_rect().size
		var center = viewport_size / 2
		var bg_rect = Rect2(center - fixed_bg_size/2, fixed_bg_size)
		
		# Draw red outline of the background area
		draw_rect(bg_rect, Color(1, 0, 0, 0.5), false, 2)
		
		# Get player and draw their collision shape
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_node("CollisionShape2D"):
			var collision = player.get_node("CollisionShape2D")
			var shape = collision.shape
			
			if shape is CapsuleShape2D:
				# Draw player outline based on capsule
				var player_rect = Rect2(
					player.position.x - shape.radius,
					player.position.y - shape.height/2 - shape.radius,
					shape.radius * 2,
					shape.height + shape.radius * 2
				)
				
				# Draw green outline for player collision area
				draw_rect(player_rect, Color(0, 1, 0, 0.2), true)
				draw_rect(player_rect, Color(0, 1, 0, 0.7), false, 2)
				
				# Check if player is inside or outside background area
				var inside_status = "OUTSIDE" if !bg_rect.intersects(player_rect) else "INSIDE"
				var text_color = Color.RED if inside_status == "OUTSIDE" else Color.GREEN
				
				# Draw status text
				draw_string(
					ThemeDB.fallback_font,
					player.position + Vector2(0, -20),
					inside_status,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					16,
					text_color
				)
				
				# Show transition status
				if transition_disabled:
					draw_string(
						ThemeDB.fallback_font,
						Vector2(20, 50),
						"TRANSITIONS DISABLED - RESIZE COOLDOWN",
						HORIZONTAL_ALIGNMENT_LEFT,
						-1,
						16,
						Color.YELLOW
					)
					
					# Show remaining time
					if override_timer.time_left > 0:
						draw_string(
							ThemeDB.fallback_font,
							Vector2(20, 70),
							"Cooldown: " + str(override_timer.time_left).pad_decimals(1) + "s",
							HORIZONTAL_ALIGNMENT_LEFT,
							-1,
							16,
							Color.YELLOW
						)

func check_player_outside_boundaries():
	# Skip if transitions are disabled
	if transition_disabled:
		return
		
	# Find player
	var player = get_tree().get_first_node_in_group("player")
	if not player or not player.has_node("CollisionShape2D"):
		return
	
	# Get collision shape
	var collision = player.get_node("CollisionShape2D")
	var shape = collision.shape
	
	# Get viewport center and calculate background rectangle
	var viewport_size = get_viewport_rect().size
	var center = viewport_size / 2
	var bg_rect = Rect2(center - fixed_bg_size/2, fixed_bg_size)
	
	# Calculate player bounds based on collision shape
	var player_rect = Rect2()
	
	if shape is CapsuleShape2D:
		player_rect = Rect2(
			player.position.x - shape.radius,
			player.position.y - shape.height/2 - shape.radius,
			shape.radius * 2,
			shape.height + shape.radius * 2
		)
	elif shape is RectangleShape2D:
		player_rect = Rect2(
			player.position.x - shape.size.x/2,
			player.position.y - shape.size.y/2,
			shape.size.x,
			shape.size.y
		)
	else:
		# Default fallback for other shapes
		player_rect = Rect2(player.position.x - 10, player.position.y - 10, 20, 20)
	
	# Check if player is completely outside the background
	if not bg_rect.intersects(player_rect):
		print("Player COMPLETELY outside background - transitioning to room")
		
		# Disable transitions to prevent multiple triggers
		transition_disabled = true
		
		# Calculate exit direction
		var exit_data = {
			"left": player.position.x < bg_rect.position.x,
			"right": player.position.x > bg_rect.position.x + bg_rect.size.x,
			"top": player.position.y < bg_rect.position.y,
			"bottom": player.position.y > bg_rect.position.y + bg_rect.size.y
		}
		
		# Transition to room scene
		if has_node("/root/SceneTransition"):
			SceneTransition.exit_direction = exit_data
			SceneTransition.transition_to_scene("res://room.tscn")
		else:
			push_error("SceneTransition singleton not found!")
			# Re-enable transitions if transition fails
			transition_disabled = false

func detect_zoom_level():
	# Try to get the background size
	if background and background.texture:
		var tex_size = background.texture.get_size()
		var displayed_size = background.size
		
		# Calculate the zoom as an integer (nearest whole number)
		var zoom = round(displayed_size.x / tex_size.x)
		print("Detected integer zoom level:", zoom)
		return int(zoom)
	
	# Default to 12 if detection fails
	print("Using default zoom level: 12")
	return 12

func create_centered_mask():
	# Remove any existing mask
	if mask_layer:
		mask_layer.queue_free()
		masks.clear()
	
	# Create a new CanvasLayer for our masks
	mask_layer = CanvasLayer.new()
	mask_layer.name = "MaskLayer"
	mask_layer.layer = 100  # Very high layer
	add_child(mask_layer)
	
	# Calculate the center of the viewport
	var viewport_size = get_viewport_rect().size
	var center = viewport_size / 2
	
	# The background should be centered, so calculate its position
	var bg_pos = center - (fixed_bg_size / 2)
	var bg_size = fixed_bg_size
	
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
	
	print("Mask created - visible hole from", bg_pos, "to", bg_pos + bg_size)
