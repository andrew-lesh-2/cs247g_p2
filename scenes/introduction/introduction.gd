extends Node2D

@onready var rich_text_label = $Control/RichTextLabel # left page
@onready var rich_text_label2 = $Control/RichTextLabel2 # right page
@onready var fade_rect = $Control/Screen_Fade  # screen fade colorrect

var typing_speed := 0.06
var fast_typing_speed := 0.01
var is_speeding_up := false
var typing_finished := false

func _ready() -> void:
	fade_rect.visible = false
	fade_rect.modulate.a = 0.0
	call_deferred("_start_typing_sequence")

func _start_typing_sequence() -> void:
	await get_tree().create_timer(1.5).timeout # wait 1.5 seconds before typing
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
	var tween := get_tree().create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 2.0)
	tween.tween_callback(Callable(self, "go_to_next_scene"))

func go_to_next_scene() -> void:
	get_tree().change_scene_to_file("res://scenes/levels/test2_sidescroll.tscn")
