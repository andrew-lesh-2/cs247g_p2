extends Control
var resource = load("res://scenes/scene_zero/introduction.dialogue")
var dialogue_line = await DialogueManager.get_next_dialogue_line(resource, "start")
