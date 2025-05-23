# grasshopper.gd
extends Node2D

signal dialog_started(dialog_data)
signal dialog_ended

@export var npc_id = "grasshopper_npc"  # Unique ID for this NPC

# Detection settings
@export var detection_distance: float = 30.0  # Distance for interaction
@export var boundary_offset: float = 10.0  # Extra detection distance from sprite boundary
@export var show_detection_area: bool = false  # Debug option to visualize detection area

# Dialog settings
@export var name_color: Color = Color(0.5, 0.9, 0.5, 1)  # Light green for grasshopper

@export var dialog_lines_stage0 = [
	"Hello there, subject. You were unconscious for quite some time.",
	"Welcome to my castle.  The giant one brought you here to entertain me, I presume.",
	"I've earned the giant one's favor, you see.  It bestowed me with this miraculous fortress.",
	"It also provides me with the finest of leaves, truly fit for a nobleman like myself.",
	"Oh, you want to leave?  Why?  This is a paradise!"
]

@export var dialog_lines_stage1 = [
	"Have you come to your senses?  Stay, stay!"
]

@export var npc_name: String = "Grasshopper"
@export var voice_sound_path: String = "res://audio/voices/voice_Papyrus.wav"  # Path to custom voice sound

# Glow effect settings
@export_range(0.0, 1.0) var glow_intensity: float = 0.6  # Maximum glow intensity
@export var glow_color: Color = Color(1, 1, 0.5, 0.8)  # Yellow-white glow color
@export var glow_pulse_speed: float = 1.0  # Speed of the pulsing effect

# Sprite settings
@export var face_left: bool = true

var player_in_range: bool = false
var is_in_dialog: bool = false
var player_node: Node2D = null
var glow_time: float = 0.0

# Shader for glowing effect
var glow_shader = null
var glow_material = null

func _ready():
	# Start idle animation
	$AnimatedSprite2D.play("idle")

	# Apply horizontal flip setting
	$AnimatedSprite2D.flip_h = face_left

	# Create glow shader material
	setup_glow_shader()

	# Find player node
	await get_tree().process_frame
	player_node = get_tree().get_first_node_in_group("player")
	if player_node == null:
		push_error("Player node not found! Make sure your player is in the 'player' group.")

	# Display debug info if enabled
	if show_detection_area:
		queue_redraw()



	# Connect to dialog system with error handling
	_ensure_dialog_connection()

	# Set up input mapping if needed
	_ensure_input_mapping()

func _ensure_dialog_connection():
	# Check if DialogSystem exists
	if not has_node("/root/DialogSystem"):
		push_error("DialogSystem autoload not found! Make sure it's added in Project Settings.")
		return

	# Check if we're already connected to avoid duplicate connections
	var connections = []

	if DialogSystem.has_signal("dialog_finished"):
		connections = DialogSystem.get_signal_connection_list("dialog_finished")
	else:
		push_error("DialogSystem doesn't have a 'dialog_finished' signal!")
		return

	var already_connected = false

	for connection in connections:
		if connection.callable.get_object() == self and connection.callable.get_method() == "_on_dialog_finished":
			already_connected = true
			break

	if not already_connected:
		print("Connecting grasshopper to dialog system...")
		DialogSystem.connect("dialog_finished", Callable(self, "_on_dialog_finished"))
	else:
		print("Grasshopper already connected to dialog system")

func _ensure_input_mapping():
	# Define interaction key if it doesn't exist
	if not InputMap.has_action("interact"):
		print("Adding 'interact' input action")
		InputMap.add_action("interact")
		var event = InputEventKey.new()
		event.keycode = KEY_E
		InputMap.action_add_event("interact", event)
	else:
		print("'interact' action already exists")

func setup_glow_shader():
	# Create shader material
	glow_material = ShaderMaterial.new()

	# Create shader
	glow_shader = Shader.new()
	glow_shader.code = """
	shader_type canvas_item;

	uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 0.5, 0.8);
	uniform float glow_amount : hint_range(0.0, 1.0) = 0.0;

	void fragment() {
		vec4 original_color = texture(TEXTURE, UV);

		// Only glow non-transparent pixels
		if (original_color.a > 0.0) {
			// Mix the original color with the glow color based on glow amount
			COLOR = mix(original_color, glow_color, glow_amount);

			// Ensure we keep the original alpha
			COLOR.a = original_color.a;
		} else {
			COLOR = original_color;
		}
	}
	"""

	# Assign shader to material
	glow_material.shader = glow_shader

	# Set initial uniform values
	glow_material.set_shader_parameter("glow_color", glow_color)
	glow_material.set_shader_parameter("glow_amount", 0.0)

	# Apply material to animated sprite
	$AnimatedSprite2D.material = glow_material

func _process(delta):
	# Skip if player not found
	if player_node == null:
		return

	# Check if player is in range using boundary-based detection
	var was_in_range = player_in_range
	player_in_range = is_player_in_range()

	# Handle player entering/exiting range
	if player_in_range != was_in_range:
		if player_in_range:
			_on_player_entered()
		else:
			_on_player_exited()

	# Check for interaction when in range
	if player_in_range and Input.is_action_just_pressed("interact") and !is_in_dialog:
		start_dialog()

	# Update glow effect when player is in range
	if player_in_range and !is_in_dialog:
		update_glow(delta)

	# Redraw debug visualization if enabled
	if show_detection_area:
		queue_redraw()

# Check if player is within interaction range using sprite boundary plus offset
func is_player_in_range() -> bool:
	if player_node == null:
		return false

	# Get sprite dimensions
	var sprite_width = get_sprite_width()
	var sprite_height = get_sprite_height()

	# Calculate distance from center to boundaries
	var half_width = sprite_width / 2.0
	var half_height = sprite_height / 2.0

	# Calculate boundary box with offset
	var boundary = Rect2(
		global_position.x - half_width - boundary_offset,
		global_position.y - half_height - boundary_offset,
		sprite_width + (boundary_offset * 2),
		sprite_height + (boundary_offset * 2)
	)

	# First check: is player's center point within extended boundary?
	if boundary.has_point(player_node.global_position):
		return true

	# Second check: basic distance check from center as fallback
	var distance = global_position.distance_to(player_node.global_position)
	return distance < detection_distance

func update_glow(delta):
	# Update glow time
	glow_time += delta * glow_pulse_speed

	# Calculate pulsing glow amount using sine wave
	var pulse_factor = (sin(glow_time * PI) + 1.0) / 2.0  # Oscillates between 0 and 1
	var current_intensity = pulse_factor * glow_intensity

	# Update shader parameter
	if glow_material:
		glow_material.set_shader_parameter("glow_amount", current_intensity)

# Draw debug visualization if enabled
func _draw():
	if show_detection_area:
		# Get sprite dimensions
		var sprite_width = get_sprite_width()
		var sprite_height = get_sprite_height()

		# Calculate distance from center to boundaries
		var half_width = sprite_width / 2.0
		var half_height = sprite_height / 2.0

		# Draw sprite boundary in green
		var sprite_rect = Rect2(
			-half_width, -half_height,
			sprite_width, sprite_height
		)
		draw_rect(sprite_rect, Color(0, 1, 0, 0.3), false, 2.0)

		# Draw detection boundary in blue
		var detection_rect = Rect2(
			-half_width - boundary_offset,
			-half_height - boundary_offset,
			sprite_width + (boundary_offset * 2),
			sprite_height + (boundary_offset * 2)
		)
		draw_rect(detection_rect, Color(0, 0, 1, 0.3), false, 2.0)

		# Draw circle for the distance-based detection as yellow
		draw_circle(Vector2.ZERO, detection_distance, Color(1, 1, 0, 0.1))
		draw_arc(Vector2.ZERO, detection_distance, 0, TAU, 32, Color(1, 1, 0, 0.3), 2.0)

# Get the width of the sprite
func get_sprite_width() -> float:
	if $AnimatedSprite2D.sprite_frames:
		var frame_texture = $AnimatedSprite2D.sprite_frames.get_frame_texture("idle", 0)
		if frame_texture:
			return frame_texture.get_width() * abs($AnimatedSprite2D.scale.x)

	# Fallback value
	return 32.0

# Get the height of the sprite
func get_sprite_height() -> float:
	if $AnimatedSprite2D.sprite_frames:
		var frame_texture = $AnimatedSprite2D.sprite_frames.get_frame_texture("idle", 0)
		if frame_texture:
			return frame_texture.get_height() * abs($AnimatedSprite2D.scale.y)

	# Fallback value
	return 32.0

func _on_player_entered():
	print("Player entered interaction range with Grasshopper")
	# Reset glow time when player enters range
	glow_time = 0.0

	# Make sure shader is active
	if $AnimatedSprite2D.material != glow_material:
		$AnimatedSprite2D.material = glow_material

func _on_player_exited():
	print("Player exited interaction range")
	# Turn off glow when player exits range
	if glow_material:
		glow_material.set_shader_parameter("glow_amount", 0.0)

func start_dialog():
	print("Grasshopper: Starting dialog")
	is_in_dialog = true

	# Turn off glow during dialog
	if glow_material:
		glow_material.set_shader_parameter("glow_amount", 0.0)

	# Get the current dialog stage
	var current_stage = DialogTracker.get_dialog_stage(npc_id)

	# Get appropriate dialog lines based on stage
	var dialog_lines_to_use = []

	match current_stage:
		0:
			dialog_lines_to_use = dialog_lines_stage0
			# Will advance to stage 1 after this dialog
		1:
			dialog_lines_to_use = dialog_lines_stage1
			# Will stay at stage 1 for subsequent interactions
		_:
			dialog_lines_to_use = dialog_lines_stage1  # Fallback to stage 1 for any higher stage

	# Call the global dialog system
	if has_node("/root/DialogSystem"):
		print("Grasshopper: Calling DialogSystem.start_dialog with stage", current_stage, "dialog")
		DialogSystem.start_dialog({
			"name": npc_name,
			"lines": dialog_lines_to_use,
			"name_color": name_color,
			"voice_sound_path": voice_sound_path
		}, npc_id)
	else:
		push_error("Cannot start dialog: DialogSystem not found!")
		is_in_dialog = false

func _on_dialog_finished(finished_npc_id):
	print("Grasshopper received dialog_finished signal for npc_id:", finished_npc_id)

	# Check if this dialog was for this NPC
	if finished_npc_id == npc_id:
		end_dialog()

		# Advance dialog stage if currently at stage 0
		var current_stage = DialogTracker.get_dialog_stage(npc_id)
		if current_stage == 0:
			DialogTracker.advance_dialog_stage(npc_id)  # Advance to stage 1
	else:
		print("Dialog was for a different NPC")

func end_dialog():
	print("Grasshopper: Ending dialog")
	is_in_dialog = false

	# Reset glow cycle if player is still in range
	if player_in_range:
		glow_time = 0.0
