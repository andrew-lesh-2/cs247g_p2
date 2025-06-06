# indoor_to_outdoor.gd
extends Node2D

# Scene to load
@export var target_scene_path: String = "res://scenes/levels/Outdoor Level.tscn"

# Transition settings (these won't be used directly if your autoload doesn't support them)
@export var transition_duration: float = 1.5
@export var transition_color: Color = Color.BLACK

func _ready() -> void:
	# Connect the area entry signal
	$Area2D.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	# Make sure it's the Player
	if body is Player:
		# Just call the transition with only the required parameter
		SceneTransition.transition_to_scene(target_scene_path)
