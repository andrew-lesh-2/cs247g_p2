# DialogSystem.gd
extends CanvasLayer

signal dialog_finished(npc_id)
signal dialog_started(npc_id)

var current_dialog = []
var current_line = 0
var is_active = false
var typing = false
var typing_tween = null
var current_npc_id = ""

# UI Node references
var dialog_panel
var name_label
var text_label
var hint_label

# Font reference
var pixel_font

# Sound effect
var voice_sound_player = null
var default_voice_sound = null
var current_voice_sound = null
var last_character_time = 0

# Adjustable parameters
@export_category("Dialog Box Dimensions")
@export_range(0, 1.0) var dialog_width: float = .75  # Width of dialog box in pixels
@export_range(0, 1.0) var dialog_height: float = .35  # Height of dialog box in pixels
@export_range(1, 10) var border_thickness: int = 10  # Border thickness in pixels
@export_range(5, 30) var inner_padding: int = 10  # Padding inside the dialog box

@export_category("Text Settings")
@export_range(8, 32) var font_size_name: int = 100  # Font size for character name
@export_range(8, 32) var font_size_text: int = 100  # Font size for dialog text
@export_range(8, 32) var font_size_hint: int = 50  # Font size for hint text
@export_range(0.01, 0.2) var type_speed: float = 0.03  # Seconds per character

@export_category("Voice Settings")
@export var default_voice_sound_path: String = "res://audio/voices/dialog_blip.wav"  # Default voice sound
@export_range(0.0, 1.0) var voice_volume: float = 0.5  # Voice sound volume
@export_range(0.5, 2.0) var voice_pitch: float = 1.0  # Voice sound pitch
@export var play_sound_for_spaces: bool = false  # Whether to play sound for space characters
@export var character_sound_cooldown: float = 0.03  # Min time between sounds in seconds

@export_category("Colors")
@export var panel_color: Color = Color(0, 0, 0, 0.9)  # Black background
@export var border_color: Color = Color(1, 1, 1, 1)  # White border
@export var text_color: Color = Color(1, 1, 1, 1)  # White text
@export var hint_color: Color = Color(0.8, 0.8, 0.8, 1)  # Light gray hint text

# Internal variables
var panel_size = Vector2(0, 0)
var panel_position = Vector2(0, 0)
var hint_text = "Press E or Space to continue"
var last_line_hint_text = "Press E or Space to close"  # Different hint for last line

var zoom = 1.0

func _ready():
	var camera = get_viewport().get_camera_2d()
	if camera:
		zoom = camera.zoom.x
	# Load the PixelOperator font
	load_font()

	# Load the default voice sound
	setup_voice_player()

	# Set a high layer number to ensure dialog appears on top
	layer = 100

	# Create UI elements programmatically
	call_deferred("create_dialog_ui")

	print("DialogSystem initialized successfully")

func load_font():
	# Try to load the font
	var font_path = "res://fonts/PixelOperator.ttf"

	if ResourceLoader.exists(font_path):
		pixel_font = load(font_path)
		print("Successfully loaded PixelOperator font")
	else:
		push_error("Failed to load PixelOperator font at: " + font_path)
		print("Font will fall back to default")

func setup_voice_player():
	# Create audio player for voice sounds
	voice_sound_player = AudioStreamPlayer.new()
	voice_sound_player.volume_db = linear_to_db(voice_volume)
	voice_sound_player.pitch_scale = voice_pitch
	add_child(voice_sound_player)

	# Load default voice sound
	if ResourceLoader.exists(default_voice_sound_path):
		default_voice_sound = load(default_voice_sound_path)
		current_voice_sound = default_voice_sound
		voice_sound_player.stream = default_voice_sound
		print("Successfully loaded default voice sound: ", default_voice_sound_path)
	else:
		push_error("Failed to load default voice sound at: " + default_voice_sound_path)

func create_dialog_ui():
	print("Creating dialog UI elements...")

	# Calculate panel dimensions
	calculate_dialog_dimensions()

	# Create the panel
	dialog_panel = Panel.new()
	dialog_panel.position = panel_position
	dialog_panel.size = panel_size
	dialog_panel.z_index = 1000
	dialog_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_panel.top_level = true

	var zoomed_border_thickness = border_thickness / zoom
	var zoomed_inner_padding = inner_padding / zoom

	var zoomed_font_size_name = font_size_name / zoom
	var zoomed_font_size_text = font_size_text / zoom
	var zoomed_font_size_hint = font_size_hint / zoom

	# Create the panel style
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = panel_color
	panel_style.border_width_left = max(1, zoomed_border_thickness)
	panel_style.border_width_top = max(1, zoomed_border_thickness)
	panel_style.border_width_right = max(1, zoomed_border_thickness)
	panel_style.border_width_bottom = max(1, zoomed_border_thickness)
	panel_style.border_color = border_color
	dialog_panel.add_theme_stylebox_override("panel", panel_style)

	# Create name label with proper padding
	name_label = Label.new()
	name_label.position = Vector2(zoomed_inner_padding, zoomed_inner_padding)
	name_label.size = Vector2(panel_size.x - zoomed_inner_padding*2, zoomed_font_size_name + 4)

	# Apply custom font
	if pixel_font:
		name_label.add_theme_font_override("font", pixel_font)
	name_label.add_theme_font_size_override("font_size", zoomed_font_size_name)

	dialog_panel.add_child(name_label)

	# Create text label with proper padding
	text_label = RichTextLabel.new()
	text_label.position = Vector2(zoomed_inner_padding, name_label.position.y + name_label.size.y + 5)
	text_label.size = Vector2(
		panel_size.x - zoomed_inner_padding*2,
		panel_size.y - name_label.size.y - zoomed_font_size_hint - zoomed_inner_padding*3 - 10
	)
	text_label.add_theme_color_override("default_color", text_color)

	if pixel_font:
		text_label.add_theme_font_override("normal_font", pixel_font)
	text_label.add_theme_font_size_override("normal_font_size", zoomed_font_size_text)

	text_label.bbcode_enabled = true
	text_label.scroll_active = false
	text_label.fit_content = true
	dialog_panel.add_child(text_label)

	# Create hint label with proper padding
	hint_label = Label.new()
	hint_label.text = hint_text
	hint_label.add_theme_color_override("font_color", hint_color)

	# Set the proper font and size for hint label
	if pixel_font:
		hint_label.add_theme_font_override("font", pixel_font)
	hint_label.add_theme_font_size_override("font_size", zoomed_font_size_hint)

	# Use a fixed width based on the hint text length and font size
	var estimated_width = hint_text.length() * (zoomed_font_size_hint * 0.6)

	hint_label.position = Vector2(
		panel_size.x - estimated_width - zoomed_inner_padding,  # Right-aligned with padding
		panel_size.y - zoomed_font_size_hint - zoomed_inner_padding  # Bottom aligned with padding
	)
	hint_label.size = Vector2(estimated_width, (zoomed_font_size_hint + 4))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	dialog_panel.add_child(hint_label)

	# Add panel to canvas layer
	add_child(dialog_panel)
	print("Dialog UI created with panel size:", panel_size, "at position:", panel_position)

	# Initially hide the panel
	dialog_panel.hide()

func calculate_dialog_dimensions():
	# Get viewport size
	var camera = get_viewport().get_camera_2d()
	if camera:
		zoom = camera.zoom.x

	var viewport_size = get_viewport().get_visible_rect().size

	# Use direct dialog_width parameter
	panel_size = Vector2(viewport_size.x * dialog_width, viewport_size.y * dialog_height)

	# Position the panel at the bottom of the visible area
	panel_position = Vector2(
		viewport_size.x * (1 - dialog_width) / 2,  # Centered horizontally
		viewport_size.y * (1 - dialog_height) - 20  # 20 pixels from bottom
	)

	print("Dialog dimensions calculated:")
	print("- Viewport size:", viewport_size)
	print("- Panel size:", panel_size)
	print("- Panel position:", panel_position)

func _process(delta):
	# Handle dialog input
	if is_active and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept")):
		# Critical fix: Always check if we're on the last line when not typing
		if !typing and current_line >= current_dialog.size() - 1:
			print("Dialog: Last line already shown, closing dialog")
			end_dialog()
			return  # Important: return immediately

		# Normal processing for other cases
		if typing:
			# Immediately show the entire text
			skip_typing()
		else:
			next_line()

	# Play sound for each character typed during dialog
	if typing and text_label and text_label.visible_characters > 0:
		# Check if we're showing a new character
		if text_label.visible_characters != text_label.get_total_character_count():
			var current_time = Time.get_ticks_msec() / 1000.0

			# Only play sound if enough time has passed since last sound
			if current_time - last_character_time >= character_sound_cooldown:
				# Get the current character being displayed
				var current_char = ""
				if text_label.visible_characters <= text_label.text.length():
					current_char = text_label.text[text_label.visible_characters - 1]

				# Don't play sound for spaces unless configured to do so
				if current_char != " " or play_sound_for_spaces:
					play_character_sound()

				last_character_time = current_time

# Play the character sound
func play_character_sound():
	if voice_sound_player and current_voice_sound:
		# Stop any currently playing sound
		voice_sound_player.stop()

		# Play the sound with a small random pitch variation for natural feel
		voice_sound_player.pitch_scale = voice_pitch * randf_range(0.95, 1.05)
		voice_sound_player.play()

func skip_typing():
	print("Dialog: Skipping typing animation")

	# Stop any active tween
	if typing_tween and typing_tween.is_valid():
		typing_tween.kill()

	# Show the full text immediately
	if text_label:
		text_label.visible_characters = -1

	typing = false

func start_dialog(dialog_data, npc_id = ""):
	print("DialogSystem: start_dialog called with npc_id:", npc_id)

	is_active = true

	# Emit signal to pause player movement
	emit_signal("dialog_started", npc_id)

	show_dialog()
	current_npc_id = npc_id

	# Set NPC name and color
	if name_label:
		name_label.text = dialog_data.name
		if dialog_data.has("name_color"):
			name_label.add_theme_color_override("font_color", dialog_data.name_color)
		else:
			name_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))

	# Set custom voice if provided
	if dialog_data.has("voice_sound_path"):
		set_voice_sound(dialog_data.voice_sound_path)
	else:
		# Otherwise use default voice
		current_voice_sound = default_voice_sound
		if voice_sound_player:
			voice_sound_player.stream = default_voice_sound

	# Store dialog lines
	current_dialog = dialog_data.lines
	current_line = 0

	# Show first line
	show_line()

# Set a custom voice sound for the current dialog
func set_voice_sound(sound_path: String):
	if ResourceLoader.exists(sound_path):
		var voice = load(sound_path)
		current_voice_sound = voice
		if voice_sound_player:
			voice_sound_player.stream = voice
		print("Set custom voice: ", sound_path)
	else:
		push_error("Failed to load voice sound at: " + sound_path)
		# Fallback to default voice
		current_voice_sound = default_voice_sound
		if voice_sound_player:
			voice_sound_player.stream = default_voice_sound

func show_line():
	if current_line < current_dialog.size() and text_label:
		typing = true
		text_label.text = current_dialog[current_line]
		text_label.visible_characters = 0

		print("Dialog: Showing line", current_line + 1, "of", current_dialog.size())

		# Check if this is the last line and update hint text accordingly
		update_hint_text()

		# Type out the text character by character
		typing_tween = create_tween()
		typing_tween.tween_property(text_label, "visible_characters", text_label.text.length(), text_label.text.length() * type_speed)
		typing_tween.connect("finished", Callable(self, "_on_typing_finished"))
	else:
		# Ensure we definitely close the dialog if we try to show a line past the end
		print("Dialog: No more lines, closing dialog")
		end_dialog()

# Update the hint text based on whether this is the last line
func update_hint_text():
	var is_last_line = (current_line == current_dialog.size() - 1)

	if is_last_line:
		hint_label.text = last_line_hint_text
	else:
		hint_label.text = hint_text

	# Recalculate size and position
	var estimated_width = hint_label.text.length() * (font_size_hint * 0.6)
	hint_label.position.x = panel_size.x - estimated_width - inner_padding
	hint_label.size.x = estimated_width

func _on_typing_finished():
	typing = false
	print("Dialog: Finished typing")

func next_line():
	print("Dialog: Moving to next line")
	current_line += 1

	# Critical fix: ALWAYS end dialog if we're at or past the last line
	if current_line >= current_dialog.size():
		print("Dialog: Last line reached, closing dialog")
		end_dialog()
		return  # Important: return immediately to prevent further processing

	# Only show the next line if we didn't end the dialog
	show_line()

func show_dialog():
	# Recalculate dimensions to ensure proper centering
	calculate_dialog_dimensions()

	# Update panel position and size
	if dialog_panel:
		dialog_panel.position = panel_position
		dialog_panel.size = panel_size

		# Update text and hint label sizes/positions with proper padding
		if name_label:
			name_label.position = Vector2(inner_padding, inner_padding)
			name_label.size.x = panel_size.x - inner_padding*2

		if text_label:
			text_label.position.x = inner_padding
			text_label.size.x = panel_size.x - inner_padding*2

		if hint_label:
			# Use estimated width based on text length
			var estimated_width = hint_label.text.length() * (font_size_hint * 0.6)
			hint_label.position.x = panel_size.x - estimated_width - inner_padding
			hint_label.position.y = panel_size.y - font_size_hint - inner_padding
			hint_label.size.x = estimated_width

	print("DialogSystem: Showing dialog panel")

	# Ensure dialog panel exists
	if not dialog_panel:
		push_error("Dialog panel not found!")
		return

	# Make it visible
	dialog_panel.visible = true
	dialog_panel.show()

	# Force child elements to be visible too
	if name_label:
		name_label.show()
	if text_label:
		text_label.show()
	if hint_label:
		hint_label.show()

func hide_dialog():
	print("DialogSystem: Hiding dialog panel")
	if dialog_panel:
		dialog_panel.visible = false

func end_dialog():
	print("DialogSystem: Ending dialog for NPC:", current_npc_id)

	# Guard against double-ending
	if !is_active:
		print("Dialog already ended, ignoring")
		return

	is_active = false
	hide_dialog()

	# Store the NPC ID before clearing it
	var npc_id_to_notify = current_npc_id

	# Clear dialog data BEFORE emitting the signal
	current_dialog = []
	current_line = 0
	current_npc_id = ""

	# Force clear any pending input to prevent immediately restarting dialog
	get_viewport().set_input_as_handled()

	# Pass back the NPC ID so we know which NPC to notify
	# Using deferred call to ensure we're not in the middle of processing
	call_deferred("emit_signal", "dialog_finished", npc_id_to_notify)

# Handle window resize
func _on_viewport_size_changed():
	# Recalculate dimensions
	calculate_dialog_dimensions() 

	# Update panel position and size
	if dialog_panel:
		dialog_panel.position = panel_position
		dialog_panel.size = panel_size

		# Update all child elements with proper padding
		if name_label:
			name_label.position = Vector2(inner_padding, inner_padding)
			name_label.size.x = panel_size.x - inner_padding*2

		if text_label:
			text_label.position.x = inner_padding
			text_label.size.x = panel_size.x - inner_padding*2

		if hint_label:
			# Use estimated width for hint text
			var estimated_width = hint_label.text.length() * (font_size_hint * 0.6)
			hint_label.position.x = panel_size.x - estimated_width - inner_padding
			hint_label.position.y = panel_size.y - font_size_hint - inner_padding
			hint_label.size.x = estimated_width
