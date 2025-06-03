# indoor_to_outdoor.gd
# Attach this to your Portal node (which must be a Node2D)
extends Node2D

# In the Inspector, point this at the .tscn you want to load:
@export var target_scene_path: String = "res://scenes/levels/Outdoor Level.tscn"

func _ready() -> void:
	# If your Area2D child is named something else, change “Area2D” below.
	$Area2D.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	# Make sure it’s actually the Player who entered:
	if body is Player:
		# In Godot 4, use change_scene_to_file (or change_scene_to).        
		get_tree().change_scene_to_file(target_scene_path)
		# (Any code after this line will not run, since the scene switches immediately.)
