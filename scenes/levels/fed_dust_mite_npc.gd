# fed_dust_mite_npc.gd
extends Node2D

var timer: Timer

var npc_id    = "bedmite"
var npc_name  = "Dust Mite"
var name_color = Color(1, 0.8, 0.1)
var voice_sound_path: String = "res://audio/voices/voice_Papyrus.wav"

var last_exited_body: Player = null

@onready var story_manager = StoryManager
@onready var interact_icon    = $interact_icon
@onready var dust_mite_sprite : AnimatedSprite2D = $"Dust Mite/Dust Mite Sprite"
@onready var interaction_area = $InteractionArea

var in_cutscene: bool = false
var player_nearby: bool = false
var player: Player = null

var is_in_dialog: bool = false

# Make sure we only depart once - keeping this for compatibility
var _has_departed: bool = false

func _ready():
	# Wait a frame to ensure all nodes are properly initialized
	await get_tree().process_frame
	
	interaction_area.body_entered.connect(_on_interaction_area_body_entered)
	interaction_area.body_exited.connect(_on_interaction_area_body_exited)

	interact_icon.visible = false
	_ensure_dialog_connection()
	
	# Initially check visibility based on story state
	_update_visibility()

# Update visibility every frame to respond to story changes
func _process(delta):
	_update_visibility()
	
	# Handle interaction
	if player_nearby and Input.is_action_just_pressed("interact") and not is_in_dialog:
		start_dialog()

# Control visibility based on the fed_bedmite story flag
func _update_visibility():
	# Safety check - don't try to update if not ready
	if not is_inside_tree():
		return
		
	var should_be_visible = story_manager.fed_bedmite
	
	# Use modulate instead of visible property to avoid null instance errors
	if should_be_visible:
		# Make visible
		modulate.a = 1.0
		# Enable interaction
		if interaction_area:
			interaction_area.monitoring = true
			interaction_area.monitorable = true
	else:
		# Make invisible
		modulate.a = 0.0
		# Disable interaction
		if interaction_area:
			interaction_area.monitoring = false
			interaction_area.monitorable = false
		
		# If becoming invisible while player is nearby, clean up
		if player_nearby:
			player_nearby = false
			if interact_icon:
				interact_icon.visible = false
			
	# Debug output
	#print("Fed dust mite visibility updated to: ", should_be_visible)

func _ensure_dialog_connection():
	# We rely on DialogSystem existing at /root/DialogSystem
	if not has_node("/root/DialogSystem"):
		push_error("DialogSystem autoload not found! Make sure it's added in Project Settings.")
		return

	# Connect to dialog_finished if not already connected
	if DialogSystem.has_signal("dialog_finished"):
		var connections = DialogSystem.get_signal_connection_list("dialog_finished")
		var already_connected = false
		for conn in connections:
			if conn.callable.get_object() == self and conn.callable.get_method() == "_on_dialog_finished":
				already_connected = true
				break
		if not already_connected:
			print("Connecting bedmite to DialogSystem.dialog_finished …")
			DialogSystem.connect("dialog_finished", Callable(self, "_on_dialog_finished"))
	else:
		push_error("DialogSystem doesn't have a 'dialog_finished' signal!")


func _on_dialog_finished(finished_npc_id):
	# Only un‐pause our own dialogue if the ID matches
	if finished_npc_id == npc_id:
		is_in_dialog = false
		# Restore the interact icon if the player is still nearby
		if interact_icon:
			interact_icon.visible = player_nearby
		in_cutscene = false


func start_dialog():
	is_in_dialog = true
	if interact_icon:
		interact_icon.visible = false

	if not has_node("/root/DialogSystem"):
		push_error("Cannot start dialog: DialogSystem not found!")
		return

	# Choose which dialog to run and (possibly) set fed_bedmite = true
	if (story_manager.fed_bedmite and not story_manager.spoke_fed_bedmite):
		DialogSystem.start_dialog({
			"name": npc_name,
			"lines": [
				"That dust was absolutely delectable!",
				"Thank you again for the dust trade, friend.",
				"Now if you don't mind, I'm going to relax here indefinitely."
			],
			"name_color": name_color,
			"voice_sound_path": voice_sound_path
		}, npc_id)
		story_manager.spoke_fed_bedmite = true

	elif (story_manager.spoke_fed_bedmite):
		DialogSystem.start_dialog({
			"name": npc_name,
			"lines": [
				"Best dust ever."
			],
			"name_color": name_color,
			"voice_sound_path": voice_sound_path
		}, npc_id)
		story_manager.spoke_bedmite = true
		story_manager.fed_bedmite = true   # Mark "fed" right now, but departure waits until dialog ends

	else:
		var line_options = [
			["Back again, I see. Everything going smoothly?"],
			["You've proven yourself to be quite the asset around here."],
			["I can see why they trust you. You've earned your place."],
			["Well, well, if it isn't the ladybug of the hour. How's the world treating you?"],
			["Looks like you're fitting right in with us ants."],
			["You've been a real help around here. We appreciate it."],
			["Ah, you're back. The anthill's a bit brighter with you around."],
			["I've seen a lot of newcomers, but you stand out."],
			["You know, it's not often we get someone as reliable as you."],
			["What's the latest news from the surface? I'm always curious."],
			["The work here gets easier with you around. Keep it up."],
			["I trust you're not causing any trouble, right? You're on our side now."],
			["You've adapted quickly. I have to respect that."],
			["Another day, another good deed. You've made yourself valuable."],
			["Good to see you again. Ready for whatever comes next?"],
			["I see the others have warmed up to you. Not an easy feat."],
			["You're more than capable, I can tell. Keep it up."],
			["Every time you show up, things get a little smoother around here."],
			["You're not just a guest anymore, you're part of the team."],
			["Welcome back. The anthill's always better with you in it."]
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
	# Only allow interaction if we're currently visible (using alpha)
	if body is Player and modulate.a > 0.5:  # If more than 50% visible
		player = body
		player_nearby = true
		if interact_icon:
			interact_icon.visible = true


func _on_interaction_area_body_exited(body):
	if body is Player:
		player_nearby = false
		if interact_icon:
			interact_icon.visible = false
