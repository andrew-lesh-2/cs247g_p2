extends Control

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_load_next_scene()

func _load_next_scene() -> void:
	get_tree().change_scene_to_file("res://main menu/main_menu.tscn")
