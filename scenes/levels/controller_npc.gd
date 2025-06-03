extends Node2D

var timer: Timer

var npc_id = "controller"
var npc_name = ""
var name_color = Color(1, 0.8, 0.1)
var voice_sound_path: String = "res://audio/voices/voice_Papyrus.wav"

var last_exited_body: Player = null

@onready var story_manager = get_parent()
@onready var interact_icon  = get_node("interact_icon")
#@onready var mission_icon  = get_node("mission_icon")
@onready var grasshopper_node  = get_node("Controller")
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
		print("Connecting firetruck controller to dialog system...")
		DialogSystem.connect("dialog_finished", Callable(self, "_on_dialog_finished"))
	else:
		print("Firetruck controller already connected to dialog system")

func _on_dialog_finished(finished_npc_id):
	print("Firetruck controller received dialog_finished signal for npc_id:", finished_npc_id)
	if finished_npc_id == npc_id:
		is_in_dialog = false
		# mission_icon.visible = false
		if player_nearby:
			interact_icon.visible = true
		else:
			interact_icon.visible = false
		in_cutscene = false

func have_spoken():
	return (story_manager.found_controller)

func start_dialog():
	is_in_dialog = true
	interact_icon.visible = false
	# mission_icon.visible = false
	# Call the global dialog system
	if not has_node("/root/DialogSystem"):
		push_error("Cannot start dialog: DialogSystem not found!")
		return
	if (not have_spoken() and not story_manager.spoke_bedmite):
		DialogSystem.start_dialog({
			"name": npc_name,
			"lines": [
				"Something about this object calls to you.",
				"Unfortunately, it is absolutely caked with dust.",
				"It's a shame you don't like eating dust."],
			"name_color": name_color,
			"voice_sound_path": voice_sound_path
		}, npc_id)
		story_manager.found_controller = true
	elif (not have_spoken() and story_manager.spoke_bedmite):
		DialogSystem.start_dialog({
			"name": npc_name,
			"lines": [
				"Something about this object calls to you.",
				"Unfortunately, it is absolutely caked with dust.",
				"Perhaps the dust mite would enjoy eating this."],
			"name_color": name_color,
			"voice_sound_path": voice_sound_path
		}, npc_id)
		story_manager.found_controller = true
	elif (have_spoken() and story_manager.spoke_bedmite):
		DialogSystem.start_dialog({
			"name": npc_name,
			"lines": [
				"Still looking for a good stick?", 
				"There are usually good ones under the tree"],
			"name_color": name_color,
			"voice_sound_path": voice_sound_path
		}, npc_id)
	elif story_manager.stick_mission_active:
		DialogSystem.start_dialog({
			"name": npc_name,
			"lines": [
				"Wow! What a great stick you've brought me!",
				"Thank you so much.",
				"Now I can finally get back to my working on my masterpiece!"],
			"name_color": name_color,
			"voice_sound_path": voice_sound_path
		}, npc_id)
		story_manager.stick_mission_active = false
		story_manager.is_carrying_stick = false
		story_manager.stick_mission_completed = true
	else:
		var line_options = [
			["Back again, I see. Everything going smoothly?"],
			["You’ve proven yourself to be quite the asset around here."],
			["I can see why they trust you. You’ve earned your place."],
			["Well, well, if it isn’t the ladybug of the hour. How’s the world treating you?"],
			["Looks like you're fitting right in with us ants."],
			["You’ve been a real help around here. We appreciate it."],
			["Ah, you’re back. The anthill’s a bit brighter with you around."],
			["I’ve seen a lot of newcomers, but you stand out."],
			["You know, it’s not often we get someone as reliable as you."],
			["What’s the latest news from the surface? I’m always curious."],
			["The work here gets easier with you around. Keep it up."],
			["I trust you’re not causing any trouble, right? You’re on our side now."],
			["You’ve adapted quickly. I have to respect that."],
			["Another day, another good deed. You’ve made yourself valuable."],
			["Good to see you again. Ready for whatever comes next?"],
			["I see the others have warmed up to you. Not an easy feat."],
			["You're more than capable, I can tell. Keep it up."],
			["Every time you show up, things get a little smoother around here."],
			["You're not just a guest anymore, you’re part of the team."],
			["Welcome back. The anthill’s always better with you in it."]
		]
		var lines = line_options[randi() % line_options.size()]
		DialogSystem.start_dialog({
			"name": npc_name,
			"lines": lines,
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
