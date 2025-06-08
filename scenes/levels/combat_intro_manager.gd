# CombatIntroManager.gd - Simple version that always shows
extends Node

var player: Player = null
@onready var dialog = get_parent().get_node('Dialog')

func _ready():
	# Wait for scene to load
	await get_tree().create_timer(0.5).timeout

	# Find the player
	player = get_tree().get_first_node_in_group("player")
	if not player:
		print("ERROR: Could not find player for combat intro")
		return

func start_intro_dialog():
	print("Starting combat scene intro dialog")

	# Start the dialog
	dialog.display_dialog(
		'Ladybug\'s Inner Voice',
		'ladybug',
		[
			"Finally, I'm at the top of the tree!",
			"Now I can get a good view of the yard, and find my family.",
			"Oh no! I see a bunch of angry aphids up here",
			"I'll need to clear them out to get to the vantage point to the right.",
			"Remember: I can use my GROUND POUND attack to defeat them safely.",
			"Jump into the air and press DOWN to perform a ground pound.",
			"The aphids will turn red and disappear when hit.",
			"If they touch me, I don't need to worry - Aphids can't hurt me",
			"I'm almost home! Here I come!"
		],
	)

	_on_dialog_finished()

func _on_dialog_finished():
	print("Combat intro dialog finished")

		# Visual feedback
	show_tutorial_complete_effect()

func show_tutorial_complete_effect():

	if player:
		var tween = create_tween()
		tween.tween_property(player, "modulate", Color(1.2, 1.2, 1.2), 0.2)
		tween.tween_property(player, "modulate", Color(1, 1, 1), 0.2)
