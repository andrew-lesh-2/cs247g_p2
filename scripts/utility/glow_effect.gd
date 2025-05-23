# grasshopper.gd
extends Node2D

# Glow effect settings
@export_range(0.0, 1.0) var glow_intensity: float = 0.15  # Maximum glow intensity
@export var glow_color: Color = Color(1, 1, 0.5, 0.8)  # Yellow-white glow color
@export var glow_pulse_speed: float = 1.0  # Speed of the pulsing effect
@export var enabled: bool = false

@export var modulate_color: Color = Color(1, 1, 1, 1)  # Yellow-white glow color


var glow_time: float = 0.0
# Shader for glowing effect
var glow_shader = null
var glow_material = null

@onready var sprite = get_parent().get_node("AnimatedSprite2D")

func _ready():
	# Create shader material
	glow_material = ShaderMaterial.new()

	# Create shader
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

	# Assign shader to material
	glow_material.shader = glow_shader

	# Set initial uniform values
	glow_material.set_shader_parameter("glow_color", glow_color)
	glow_material.set_shader_parameter("glow_amount", 0.0)
	glow_material.set_shader_parameter("modulate_color", modulate_color)

	# Apply material to animated sprite
	sprite.material = glow_material

func _process(delta):
	if not enabled:
		if glow_material:
			glow_material.set_shader_parameter("glow_amount", 0)

		return

	# Update glow time
	glow_time += delta * glow_pulse_speed

	# Calculate pulsing glow amount using sine wave
	var pulse_factor = (sin(glow_time * PI) + 1.0) / 2.0  # Oscillates between 0 and 1
	var current_intensity = pulse_factor * glow_intensity

	# Update shader parameter
	if glow_material:
		glow_material.set_shader_parameter("glow_amount", current_intensity)
