# SimpleWinManager.gd - Simpler version that just counts enemies in scene
extends Node

var player: Player = null
var victory_achieved = false
var right_side_threshold = 950  # Close to right boundary (1000)

var check_timer = 0.0
var check_interval = 0.5  # Check every half second

@onready var dialog = get_parent().get_node('Dialog')

func _ready():
	player = get_tree().get_first_node_in_group("player")
	if not player:
		print("ERROR: Win manager cannot find player!")
		return

	print("Simple Win Manager ready - Kill all enemies and reach X=", right_side_threshold)

func _process(delta):
	if victory_achieved:
		return

	# Only check conditions periodically for performance
	check_timer += delta
	if check_timer >= check_interval:
		check_timer = 0.0
		check_win_conditions()

func check_win_conditions():
	# Count remaining enemies
	var remaining_enemies = get_tree().get_nodes_in_group("enemies").size()
	var all_enemies_defeated = (remaining_enemies == 0)

	# Check player position
	var reached_right_side = false
	if player:
		reached_right_side = (player.global_position.x >= right_side_threshold)

	# Debug info
	if remaining_enemies > 0:
		print("Enemies remaining: ", remaining_enemies, " | Player X: ", player.global_position.x if player else "No player")

	# Check win condition
	if reached_right_side:
		trigger_victory()

func trigger_victory():
	victory_achieved = true
	print("=== VICTORY ACHIEVED! ===")
	print("All enemies defeated and reached right side!")

	# Disable player input during victory dialog
	if player:
		player.disable_player_input = true

	# Start victory dialog
	start_victory_dialog()

func start_victory_dialog():
	print("Starting victory dialog")
	dialog.follow_player = false
	dialog.position.x = 650
	dialog.display_dialog(
		'Ladybug\'s Inner Voice',
		'ladybug',
		[
			"Fantastic work, brave little ladybug!",
			"You've successfully cleared all the dust mites from the treetops!",
			"Your ground pound technique was perfect!",
			"The trees are safe once again thanks to your efforts.",
			"You've proven yourself to be a true hero!",
			"Well done! You can be proud of what you've accomplished today.",
			"Wait...",
			"What is that I see over there.....?",
			"We are so high up now!",
			"I believe we have finally spotted your ladybug family!",
			"Go! Reunite with them!",
			"Good work little ladybug."
		],
	)
	_on_dialog_finished()

func _on_dialog_finished():
	print("Victory dialog finished!")

	show_victory_effects()

func show_victory_effects():
	print("🎉 LEVEL COMPLETE! 🎉")

	if player:
		# Victory celebration effect
		var tween = create_tween()
		tween.set_loops(4)
		tween.tween_property(player, "modulate", Color(1.5, 1.5, 0.5), 0.2)
		tween.tween_property(player, "modulate", Color(1, 1, 1), 0.2)

		# Wait for celebration to finish, then fade to black
		await tween.finished
		fade_to_black()

func fade_to_black():
	print("Starting fade to black and music fade out...")

	# Find and fade out music
	fade_out_music()

	# Create a black overlay
	var fade_overlay = ColorRect.new()
	fade_overlay.color = Color(0, 0, 0, 0)  # Start transparent
	fade_overlay.size = get_viewport().get_visible_rect().size
	fade_overlay.position = Vector2.ZERO
	fade_overlay.z_index = 1000  # Make sure it's on top of everything

	# Add to the scene
	get_tree().current_scene.add_child(fade_overlay)

	# Fade to black over 2 seconds
	var fade_tween = create_tween()
	fade_tween.tween_property(fade_overlay, "color", Color(0, 0, 0, 1), 2.0)

	await fade_tween.finished
	print("Fade to black complete!")

	# Optional: Add a delay before doing anything else
	await get_tree().create_timer(1.0).timeout

	# You could add scene transition here, or just leave it black
	get_tree().change_scene_to_file('res://scenes/outro/outro.tscn')
	print("Scene ready for transition or restart")

func fade_out_music():
	# Try to find music players in various common locations
	var music_players = []

	# Look for AudioStreamPlayer nodes (for 2D music)
	var all_audio_players = []
	find_audio_players(get_tree().current_scene, all_audio_players)

	# Also check for global/autoload music managers
	if has_node("/root/MusicManager"):
		var music_manager = get_node("/root/MusicManager")
		find_audio_players(music_manager, all_audio_players)

	if has_node("/root/AudioManager"):
		var audio_manager = get_node("/root/AudioManager")
		find_audio_players(audio_manager, all_audio_players)

	print("Found ", all_audio_players.size(), " audio players")

	# Fade out all found music players
	for player in all_audio_players:
		if player.playing:
			print("Fading out music: ", player.name)
			fade_audio_player(player)

func find_audio_players(node, list):
	# Recursively find all AudioStreamPlayer and AudioStreamPlayer2D nodes
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D:
		list.append(node)

	for child in node.get_children():
		find_audio_players(child, list)

func fade_audio_player(audio_player):
	# Get current volume
	var start_volume = audio_player.volume_db

	# Create tween to fade volume down over 2 seconds
	var audio_tween = create_tween()
	audio_tween.tween_property(audio_player, "volume_db", -60, 2.0)  # -60 dB is essentially silent

	# Stop the player after fade completes
	audio_tween.connect("finished", Callable(self, "_on_audio_fade_finished").bind(audio_player, start_volume))

func _on_audio_fade_finished(audio_player, original_volume):
	# Stop the music and restore original volume for next time
	audio_player.stop()
	audio_player.volume_db = original_volume
	print("Music fade complete and stopped")

# Debug function - force victory for testing
func force_victory():
	trigger_victory()
