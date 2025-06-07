# combat_scene_fade.gd
extends Node2D

# Fade settings
@export_group("Fade Settings")
@export var fade_color: Color = Color(0, 0, 0, 1)  # Black
@export var initial_hold_time: float = 0.5  # Time to stay black before starting fade
@export var fade_in_duration: float = 1.5   # How long the actual fade takes

# Fade overlay
var fade_overlay: ColorRect
var fade_tween: Tween

func _ready() -> void:
	# Create and set up the fade overlay
	_setup_fade_overlay()
	
	# Start the fade-in effect immediately
	_start_fade_in()

# Set up the fade overlay
func _setup_fade_overlay() -> void:
	# Create a ColorRect that covers the entire viewport
	fade_overlay = ColorRect.new()
	fade_overlay.color = fade_color  # Start fully black
	
	# Make sure it covers the entire viewport regardless of resolution
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't intercept mouse events
	
	# Create a CanvasLayer to ensure it's drawn on top
	var overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 128  # High layer number to be on top
	overlay_layer.add_child(fade_overlay)
	
	# Add to scene
	add_child(overlay_layer)

# Start the fade-in animation with initial hold time
func _start_fade_in() -> void:
	# Cancel any existing tween
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	
	# Create a new tween
	fade_tween = create_tween()
	fade_tween.set_ease(Tween.EASE_OUT)
	fade_tween.set_trans(Tween.TRANS_SINE)  # Smoother sine transition
	
	# First hold at full black for the specified time
	if initial_hold_time > 0:
		fade_tween.tween_interval(initial_hold_time)
	
	# Then animate the alpha from 1 to 0 over the fade duration
	fade_tween.tween_property(fade_overlay, "color", 
		Color(fade_color.r, fade_color.g, fade_color.b, 0), 
		fade_in_duration)
	
	# Hide the overlay when the fade completes
	fade_tween.tween_callback(func():
		fade_overlay.visible = false
	)

# Optional: Public method to fade out (for transitions to other levels)
func fade_out(duration: float = 1.5, hold_time: float = 0.5, callback: Callable = Callable()) -> void:
	# Make sure the overlay is visible
	fade_overlay.visible = true
	
	# Cancel any existing tween
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	
	# Create a new tween
	fade_tween = create_tween()
	fade_tween.set_ease(Tween.EASE_IN)
	fade_tween.set_trans(Tween.TRANS_SINE)
	
	# Animate the alpha from 0 to 1
	fade_tween.tween_property(fade_overlay, "color", 
		Color(fade_color.r, fade_color.g, fade_color.b, 1), 
		duration)
	
	# Hold at black if specified
	if hold_time > 0:
		fade_tween.tween_interval(hold_time)
	
	# Execute the callback when the fade completes
	if callback.is_valid():
		fade_tween.tween_callback(callback)
