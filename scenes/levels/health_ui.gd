extends Control

# Health UI - simple health display for combat
@export var heart_full_texture: Texture2D  # Optional - can use drawn hearts instead
@export var heart_empty_texture: Texture2D  # Optional - can use drawn hearts instead
@export var heart_size: Vector2 = Vector2(32, 32)
@export var heart_spacing: int = 5
@export var use_textures: bool = false  # Set to true if you have heart textures

var hearts: Array = []
var current_health: int = 0
var max_health: int = 0

func _ready():
	# Position in top left corner
	position = Vector2(20, 20)

func setup_hearts(max_h: int):
	# Clear any existing hearts
	for heart in hearts:
		if is_instance_valid(heart):
			heart.queue_free()
	hearts.clear()
	
	# Create new hearts
	for i in range(max_h):
		if use_textures and heart_full_texture and heart_empty_texture:
			# Use texture-based hearts if textures are provided
			var heart = TextureRect.new()
			heart.texture = heart_full_texture
			heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			heart.custom_minimum_size = heart_size
			heart.position = Vector2(i * (heart_size.x + heart_spacing), 0)
			add_child(heart)
			hearts.append(heart)
		else:
			# Use drawn hearts if no textures are provided
			var heart = HeartNode.new()
			heart.size = heart_size
			heart.position = Vector2(i * (heart_size.x + heart_spacing), 0)
			heart.full = true
			add_child(heart)
			hearts.append(heart)
	
	max_health = max_h

func update_health(new_health: int, max_h: int = -1):
	# Update max health if provided
	if max_h > 0 and max_h != max_health:
		setup_hearts(max_h)
	
	# Update current health
	current_health = new_health
	
	# Update heart display
	for i in range(hearts.size()):
		if use_textures and heart_full_texture and heart_empty_texture:
			if i < current_health:
				hearts[i].texture = heart_full_texture
			else:
				hearts[i].texture = heart_empty_texture
		else:
			# For drawn hearts
			hearts[i].full = (i < current_health)
			hearts[i].queue_redraw()

# Custom heart drawing class
class HeartNode extends Control:
	var full: bool = true
	
	func _init():
		custom_minimum_size = size
	
	func _draw():
		var heart_color = Color(1, 0, 0) if full else Color(0.5, 0, 0, 0.5)
		var center = size / 2
		var radius = min(size.x, size.y) / 2 - 2
		
		if full:
			# Draw full heart
			var points = []
			var segments = 16
			
			# Draw heart shape
			for i in range(segments):
				var angle = i * TAU / segments
				var x = sin(angle) * radius
				var y = -cos(angle) * radius
				
				# Indent the bottom
				if angle > PI * 0.75 and angle < PI * 1.25:
					y *= 0.8
				
				# Create the top bumps
				if angle > PI * 1.75 or angle < PI * 0.25:
					x *= 0.8
					y *= 1.2
				
				points.append(Vector2(center.x + x, center.y + y))
			
			draw_colored_polygon(PackedVector2Array(points), heart_color)
		else:
			# Draw empty heart (outline)
			var points = []
			var segments = 16
			
			for i in range(segments + 1):
				var angle = i * TAU / segments
				var x = sin(angle) * radius
				var y = -cos(angle) * radius
				
				# Indent the bottom
				if angle > PI * 0.75 and angle < PI * 1.25:
					y *= 0.8
				
				# Create the top bumps
				if angle > PI * 1.75 or angle < PI * 0.25:
					x *= 0.8
					y *= 1.2
				
				points.append(Vector2(center.x + x, center.y + y))
			
			for i in range(segments):
				draw_line(points[i], points[i+1], heart_color, 2.0)
