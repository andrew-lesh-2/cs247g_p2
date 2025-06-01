# multi_sprite_glow_effect.gd
extends Node2D

# Glow effect settings
@export_range(0.0, 1.0) var glow_intensity: float = 0.15  # Maximum glow intensity
@export var glow_color: Color = Color(1, 1, 0.5, 0.8)  # Yellow-white glow color
@export var glow_pulse_speed: float = 1.0  # Speed of the pulsing effect
@export var enabled: bool = false:
	set(value):
		enabled = value
		if enabled and glow_shader:
			find_target_sprites()
			create_glow_shader()
			setup_glow_materials()

@export var modulate_color: Color = Color(1, 1, 1, 1)  # Yellow-white glow color

var glow_time: float = 0.0
# Shader for glowing effect
var glow_shader = null
var target_sprites: Array = []
var original_materials: Array = []

func _ready():

	await get_tree().create_timer(0.2).timeout

	# Find all Sprite2D and AnimatedSprite2D children of parent
	find_target_sprites()

	# Create shader
	create_glow_shader()

	# Apply glow materials to all target sprites
	setup_glow_materials()

func find_target_sprites():
	target_sprites.clear()
	original_materials.clear()

	var parent_node = get_parent()
	# Recursively find all Sprite2D and AnimatedSprite2D descendants
	find_sprites_recursive(parent_node)

func find_sprites_recursive(node: Node):
	# Check if current node is a target sprite type
	if node is Sprite2D or node is AnimatedSprite2D:
		target_sprites.append(node)
		# Store original material for potential restoration
		original_materials.append(node.material)

	# Recursively check all children
	for child in node.get_children():
		find_sprites_recursive(child)

func create_glow_shader():
	glow_shader = Shader.new()
	glow_shader.code = """
	shader_type canvas_item;

	uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 0.5, 0.8);
	uniform float glow_amount : hint_range(0.0, 1.0) = 0.0;
	uniform vec4 modulate_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

	void fragment() {
		vec4 original_color = texture(TEXTURE, UV);
		vec4 modulated_color = modulate_color * original_color;

		// Only glow non-transparent pixels
		if (original_color.a > 0.0) {
			// Mix the original color with the glow color based on glow amount
			COLOR = mix(modulated_color, glow_color, glow_amount);

			// Ensure we keep the original alpha
			COLOR.a = original_color.a;
		} else {
			COLOR = modulated_color;
		}
	}
	"""

func setup_glow_materials():
	for i in range(target_sprites.size()):
		var sprite = target_sprites[i]

		# Create new shader material for each sprite
		var glow_material = ShaderMaterial.new()
		glow_material.shader = glow_shader

		# Set initial uniform values
		glow_material.set_shader_parameter("glow_color", glow_color)
		glow_material.set_shader_parameter("glow_amount", 0.0)
		glow_material.set_shader_parameter("modulate_color", modulate_color)

		# Apply material to sprite
		sprite.material = glow_material

func _process(delta):
	if not enabled:
		# Set glow amount to 0 for all sprites
		for sprite in target_sprites:
			if sprite and sprite.material:
				sprite.material.set_shader_parameter("glow_amount", 0)
		return

	# Update glow time
	glow_time += delta * glow_pulse_speed

	# Calculate pulsing glow amount using sine wave
	var pulse_factor = (sin(glow_time * PI) + 1.0) / 2.0  # Oscillates between 0 and 1
	var current_intensity = pulse_factor * glow_intensity

	# Update shader parameter for all target sprites
	for sprite in target_sprites:
		if sprite and sprite.material:
			sprite.material.set_shader_parameter("glow_amount", current_intensity)

func restore_original_materials():
	# Utility function to restore original materials if needed
	for i in range(target_sprites.size()):
		if i < original_materials.size():
			target_sprites[i].material = original_materials[i]
