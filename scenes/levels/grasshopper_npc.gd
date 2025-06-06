extends Node2D

var timer: Timer

var npc_id = "grasshopper"
var npc_name = "Grasshopper"
var name_color = Color(1, 0.8, 0.1)
var voice_sound_path: String = "res://audio/voices/voice_Papyrus.wav"

var last_exited_body: Player = null

@onready var story_manager = StoryManager
@onready var interact_icon  = get_node("interact_icon")
#@onready var mission_icon  = get_node("mission_icon")
@onready var grasshopper_node  = get_node("Grasshopper")
@onready var interaction_area = $InteractionArea

var in_cutscene: bool = false
var player_nearby: bool = false
var player: Player = null

var is_in_dialog: bool = false

func _ready():
	interaction_area.body_entered.connect(_on_interaction_area_body_entered)
	interaction_area.body_exited.connect(_on_interaction_area_body_exited)

	interact_icon.visible = false
	# mission_icon.visible = not have_spoken()

	_ensure_dialog_connection()
	


func _ensure_dialog_connection():
	# Check if DialogSystem exists
	if not has_node("/root/DialogSystem"):
		push_error("DialogSystem autoload not found! Make sure it's added in Project Settings.")
		return

	# Check if we're already connected to avoid duplicate connections
	var connections = []

	if DialogSystem.has_signal("dialog_finished"):
		connections = DialogSystem.get_signal_connection_list("dialog_finished")
	else:
		push_error("DialogSystem doesn't have a 'dialog_finished' signal!")
		return

	var already_connected = false

	for connection in connections:
		if connection.callable.get_object() == self and connection.callable.get_method() == "_on_dialog_finished":
			already_connected = true
			break

	if not already_connected:
		print("Connecting grasshopper to dialog system...")
		DialogSystem.connect("dialog_finished", Callable(self, "_on_dialog_finished"))
	else:
		print("Grasshopper already connected to dialog system")

func _on_dialog_finished(finished_npc_id):
	print("Grasshopper received dialog_finished signal for npc_id:", finished_npc_id)
	if finished_npc_id == npc_id:
		is_in_dialog = false
		# mission_icon.visible = false
		if player_nearby:
			interact_icon.visible = true
		else:
			interact_icon.visible = false
		in_cutscene = false

func have_spoken():
	return (story_manager.spoke_grasshopper)

func start_dialog():
	is_in_dialog = true
	interact_icon.visible = false
	# mission_icon.visible = false
	# Call the global dialog system
	if not has_node("/root/DialogSystem"):
		push_error("Cannot start dialog: DialogSystem not found!")
		return
	if not have_spoken():
		DialogSystem.start_dialog({
			"name": npc_name,
			"lines": [
				"Hello there, subject. You were unconscious for quite some time.",
				"Welcome to my castle.  The giant one brought you here to entertain me, I presume.",
				"I've earned the giant one's favor, you see.  It bestowed me with this miraculous fortress.",
				"It also provides me with the finest of leaves, truly fit for a nobleman like myself.",
				"Oh, you want to leave?  Why?  This is a paradise!"],
			"name_color": name_color,
			"voice_sound_path": voice_sound_path
		}, npc_id)
		story_manager.spoke_grasshopper = true
	elif (have_spoken() and story_manager.spoke_bedmite and not story_manager.insulted_bedmite):
		DialogSystem.start_dialog({
			"name": npc_name,
			"lines": [
				"Oh, so you've met that notorious dust mite, have you?",
				"Well I don't mean to be rude, but are you not aware that dust mites eat dust?",
				"Absolutely uncivilized!  I mean can you imagine?!  Dust instead of leaves?!",
				"You really ought to think more carefully about the company you keep."],
			"name_color": name_color,
			"voice_sound_path": voice_sound_path
		}, npc_id)
		story_manager.insulted_bedmite = true
	elif (have_spoken()):
		DialogSystem.start_dialog({
			"name": npc_name,
			"lines": [
				"Have you come to your senses?  Stay, stay!"],
			"name_color": name_color,
			"voice_sound_path": voice_sound_path
		}, npc_id)
	

func _on_body_entered(body):
	if body is Player and not story_manager.can_enter_anthill:
		start_dialog()

func _on_body_exited(body):
	pass

func _on_interaction_area_body_entered(body):
	if body is Player:
		player = body
		player_nearby = true
		interact_icon.visible = true
		# mission_icon.visible = false

func _on_interaction_area_body_exited(body):
	if body is Player:
		player_nearby = false
		interact_icon.visible = false
		# mission_icon.visible = (not story_manager.stick_mission_active 
		#						and 
		#						not have_spoken())

func _process(delta):
	if player_nearby:
		# Get player node
		#if player:
			# Compare x positions to determine direction
		#	var direction_to_player = player.global_position.x - grasshopper_node.global_position.x
			# Flip sprite based on player position
		#	grasshopper_node.scale.x = -1 if direction_to_player < 0 else 1

		if Input.is_action_just_pressed("interact") and !is_in_dialog:
			start_dialog()
	#else:
		# Return to default orientation
	#	grasshopper_node.scale.x = 1
