# indoor_to_outdoor.gd
extends Node2D

# Scene to load
@export var target_scene_path: String = "res://scenes/levels/Outdoor Level.tscn"

# Fade settings
@export_group("Fade Settings")
@export var fade_duration: float = 1.5
@export var hold_black_time: float = 0.5
@export var fade_color: Color = Color.BLACK

# Reference to the fade overlay
var fade_overlay: ColorRect
var fade_tween: Tween
var transition_in_progress: bool = false

func _ready() -> void:
	# Connect the area entry signal
	$Area2D.body_entered.connect(_on_body_entered)
	
	# Set up the fade overlay
	_setup_fade_overlay()

# Set up the fade overlay
func _setup_fade_overlay() -> void:
	# Create a ColorRect that covers the entire viewport
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color(fade_color.r, fade_color.g, fade_color.b, 0)  # Start transparent
	
	# Make sure it covers the entire viewport regardless of resolution
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't intercept mouse events
	
	# Create a CanvasLayer to ensure it's drawn on top
	var overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 128  # High layer number to be on top
	overlay_layer.add_child(fade_overlay)
	
	# Add to scene
	add_child(overlay_layer)
	
	# Initially hide the overlay
	fade_overlay.visible = false

func _on_body_entered(body: Node) -> void:
	# Make sure it's the Player and we're not already transitioning
	if body is Player and not transition_in_progress:
		# Disable player movement if possible
		if body.has_method("disable_input"):
			body.disable_input(true)
		else:
			# Alternative method
			body.disable_player_input = true
			body.velocity = Vector2.ZERO
		
		# Start the fade out transition
		start_fade_out(body)

# Start the fade to black transition
func start_fade_out(player: Player) -> void:
	transition_in_progress = true
	
	# Make the overlay visible
	fade_overlay.visible = true
	
	# Cancel any existing tween
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	
	# Create a new tween
	fade_tween = create_tween()
	fade_tween.set_ease(Tween.EASE_IN)
	fade_tween.set_trans(Tween.TRANS_SINE)  # Match the fade-in transition
	
	# Tween from transparent to opaque
	fade_tween.tween_property(fade_overlay, "color", 
		Color(fade_color.r, fade_color.g, fade_color.b, 1), 
		fade_duration)
	
	# Hold at black
	fade_tween.tween_interval(hold_black_time)
	
	# Then load the next scene
	fade_tween.tween_callback(func():
		# If using custom SceneTransition autoload
		if Engine.has_singleton("SceneTransition"):
			# Use the existing SceneTransition system but now the screen is already black
			SceneTransition.transition_to_scene(target_scene_path)
		else:
			# Direct scene change
			get_tree().change_scene_to_file(target_scene_path)
	)
