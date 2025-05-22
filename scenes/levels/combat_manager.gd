extends Node

# Very simple combat manager to start with

func _ready():
	# Just print a message for now
	print("Combat Manager initialized")
	
	# Make sure the player and enemies exist
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		print("Found player in scene")
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	print("Found ", enemies.size(), " enemies in scene")
