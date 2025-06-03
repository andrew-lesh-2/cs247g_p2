# CombatIntroManager.gd - Simple version that always shows
extends Node

var npc_id = "combat_intro"
var npc_name = "Ladybug's Inner Voice"
var name_color = Color(0.3, 0.8, 0.3)
var voice_sound_path: String = "res://audio/voices/voice_gentle.wav"

var player: Player = null

func _ready():
	# Wait for scene to load
	await get_tree().create_timer(0.5).timeout
	
	# Find the player
	player = get_tree().get_first_node_in_group("player")
	if not player:
		print("ERROR: Could not find player for combat intro")
		return
	
	# Always show the intro dialog
	_ensure_dialog_connection()
	start_intro_dialog()

func _ensure_dialog_connection():
	if not has_node("/root/DialogSystem"):
		push_error("DialogSystem autoload not found!")
		return

	if not DialogSystem.is_connected("dialog_finished", Callable(self, "_on_dialog_finished")):
		DialogSystem.connect("dialog_finished", Callable(self, "_on_dialog_finished"))

func start_intro_dialog():
	print("Starting combat scene intro dialog")
	
	# Disable player input during intro
	if player:
		player.disable_player_input = true
	
	# Start the dialog
	DialogSystem.start_dialog({
		"name": npc_name,
		"lines": [
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
		"name_color": name_color,
		"voice_sound_path": voice_sound_path
	}, npc_id)

func _on_dialog_finished(finished_npc_id):
	if finished_npc_id == npc_id:
		print("Combat intro dialog finished")
		
		# Re-enable player input
		if player:
			player.disable_player_input = false
		
		# Visual feedback
		show_tutorial_complete_effect()

func show_tutorial_complete_effect():
	print("Ready for combat!")
	
	if player:
		var tween = create_tween()
		tween.tween_property(player, "modulate", Color(1.2, 1.2, 1.2), 0.2)
		tween.tween_property(player, "modulate", Color(1, 1, 1), 0.2)
