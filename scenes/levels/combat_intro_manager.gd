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
			"Maybe we will get a better view from the tops of the trees",
			"And then we can find your way back home!",
			"Oh no! I see a bunch of dust mites up here",
			"You'll need to clear them out to continue your journey.",
			"Remember: you can use your GROUND POUND attack to defeat them safely.",
			"Jump into the air and press DOWN to perform a ground pound.",
			"The dust mites will turn red and disappear when hit.",
			"If they touch you, don't worry - you'll just bounce back harmlessly.",
			"Clear out all the dust mites to make the trees safe again!",
			"Be brave, little ladybug!"
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
