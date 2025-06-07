extends Control

@onready var fade_rect: ColorRect = $ScreenFade
var fade_duration := 3  # seconds

func _ready() -> void:
	fade_rect.visible = false
	fade_rect.color = Color.BLACK  # Solid black base color
	fade_rect.self_modulate.a = 0.0  # Start fully transparent

func _on_start_pressed() -> void:
	print("Start pressed: beginning fade")
	fade_to_black_then_start()

func _on_about_pressed() -> void:
	pass

func _on_exit_pressed() -> void:
	get_tree().quit()

func fade_to_black_then_start() -> void:
	fade_rect.visible = true
	fade_rect.self_modulate.a = 0.0  # Reset just in case

	var tween := get_tree().create_tween()
	tween.tween_property(fade_rect, "self_modulate:a", 1.0, fade_duration)
	tween.tween_callback(Callable(self, "_load_next_scene"))

func _load_next_scene() -> void:
	print("Fade complete: loading scene")
	get_tree().change_scene_to_file("res://scenes/introduction/introduction.tscn")
