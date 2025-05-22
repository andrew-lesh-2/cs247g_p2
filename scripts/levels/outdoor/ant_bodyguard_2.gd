extends Node2D

@onready var area = $Area2D
var timer: Timer

var npc_id = "ant_bodyguard_2"
var npc_name = "Ant Bodyguard"
var name_color = Color(1, 0.8, 0.1)
var voice_sound_path: String = "res://audio/voices/voice_Papyrus.wav"

var last_exited_body: Player = null

@onready var story_manager = get_parent()


func _ready():
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

	# Create and setup timer
	timer = Timer.new()
	timer.one_shot = true
	add_child(timer)

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
		print("Connecting ant bodyguard to dialog system...")
		DialogSystem.connect("dialog_finished", Callable(self, "_on_dialog_finished"))
	else:
		print("Ant bodyguard already connected to dialog system")

func _on_dialog_finished(finished_npc_id):
	print("Ant bodyguard received dialog_finished signal for npc_id:", finished_npc_id)
	if finished_npc_id == npc_id:
		story_manager.can_enter_anthill = true
	# Check if this dialog was for this NPC


func start_dialog():
	print("Grasshopper: Starting dialog")
	# Call the global dialog system
	if has_node("/root/DialogSystem"):
		DialogSystem.start_dialog({
			"name": npc_name,
			"lines": ["What?!?!?", "You really made it through the collapsed tunnels?!?!?", "-- I mean the visitors center", "You must be one tough bug", "You're cool enough to hang with the Ants!"],
			"name_color": name_color,
			"voice_sound_path": voice_sound_path
		}, npc_id)
	else:
		push_error("Cannot start dialog: DialogSystem not found!")

func _on_body_entered(body):
	if body is Player and not story_manager.can_enter_anthill:
		start_dialog()

func _on_body_exited(body):
	pass
