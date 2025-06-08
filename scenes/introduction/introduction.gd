extends Node2D

@onready var rich_text_label = $Control/RichTextLabel # left page
@onready var rich_text_label2 = $Control/RichTextLabel2 # right page
@onready var fade_rect = $Control/Screen_Fade  # screen fade colorrect
@onready var music_player = $AudioStreamPlayer2D  # direct reference to the AudioStreamPlayer2D

var typing_speed := 0.06
var fast_typing_speed := 0.01
var is_speeding_up := false
var typing_finished := false

# Fade-in settings
@export_group("Fade Settings")
@export var initial_hold_time: float = 0.5  # Time to stay black before starting fade
@export var fade_in_duration: float = 1.5   # How long the actual fade takes
@export var fade_out_duration: float = 2.0  # How long the fade to black takes
var fade_tween: Tween

func _ready() -> void:
	# Set up initial fade state
	fade_rect.visible = true
	fade_rect.modulate.a = 1.0  # Start fully black
	
	# Start fade-in sequence
	_start_fade_in()
	
	# Call the typing sequence after the fade completes
	call_deferred("_start_typing_sequence")

func _start_fade_in() -> void:
	# Cancel any existing tween
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	
	# Create new tween
	fade_tween = create_tween()
	fade_tween.set_ease(Tween.EASE_OUT)
	fade_tween.set_trans(Tween.TRANS_SINE)  # Smoother sine transition
	
	# First hold at full black for the specified time
	if initial_hold_time > 0:
		fade_tween.tween_interval(initial_hold_time)
	
	# Then animate the alpha from 1 to 0 over the fade duration
	fade_tween.tween_property(fade_rect, "modulate:a", 0.0, fade_in_duration)
	
	# After fade completes, keep the overlay available but invisible
	fade_tween.tween_callback(func():
		fade_rect.visible = true  # Keep it in the scene tree but transparent
	)

func _start_typing_sequence() -> void:
	await get_tree().create_timer(1.5 + initial_hold_time + fade_in_duration).timeout # wait after fade completes
	await type_text_sequence()

func _process(_delta: float) -> void:
	is_speeding_up = Input.is_action_pressed("ui_accept")

	if typing_finished and Input.is_action_just_pressed("ui_accept"):
		start_fade_to_black()

func type_text_sequence() -> void:
	typing_finished = false
	await type_text(rich_text_label, "Once upon a time, there was a small but mighty ladybug who loved to play -- using 'A' and 'D' to run around and play tag, 'Space' to double dutch blades of grass, and sometimes double clicking or holding 'Space' to see who can fly the highest!")
	await get_tree().create_timer(0.5).timeout
	await type_text(rich_text_label2, "One day, during hide and seek the ladybug was searching for one of its friends, when suddenly... STOMP. STOMP. STOMP. The ladybug felt the world shake, and soon, everything was dark... \n But just as quickly as the darkness came, a strange warmth followed... and a mysterious light began to bloom in the shadows.")

	typing_finished = true

func type_text(label: RichTextLabel, text: String) -> void:
	label.clear()
	label.bbcode_enabled = true
	for char in text:
		label.append_text(char)
		var delay = fast_typing_speed if is_speeding_up else typing_speed
		await get_tree().create_timer(delay).timeout

func start_fade_to_black() -> void:
	fade_rect.visible = true
	
	# Use the same tween pattern for consistency
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	
	fade_tween = create_tween()
	fade_tween.set_ease(Tween.EASE_IN)
	fade_tween.set_trans(Tween.TRANS_SINE)
	fade_tween.set_parallel(true) # Allow multiple properties to animate at once
	
	# Animate from transparent to black
	fade_tween.tween_property(fade_rect, "modulate:a", 1.0, fade_out_duration)
	
	# Fade out the music if it exists and is playing
	if music_player and music_player.playing:
		var original_volume = music_player.volume_db
		
		# Fade out music during the transition
		fade_tween.tween_property(music_player, "volume_db", -80, fade_out_duration)
	
	# Create a sequential tween for the scene transition
	fade_tween.chain()
	
	# Add a small hold time at black
	fade_tween.tween_interval(0.3)
	
	# Then change scene
	fade_tween.tween_callback(Callable(self, "go_to_next_scene"))

# Simpler approach without creating singletons
func go_to_next_scene() -> void:
	get_tree().change_scene_to_file("res://scenes/levels/test2_sidescroll.tscn")
