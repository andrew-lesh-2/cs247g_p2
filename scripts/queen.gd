extends Node2D

var timer: Timer

var npc_id = "ant_bodyguard"
var npc_name = "Ant Bodyguard"
var name_color = Color(1, 0.8, 0.1)
var voice_sound_path: String = "res://audio/voices/voice_Papyrus.wav"

var last_exited_body: Player = null

@onready var story_manager = StoryManager
@onready var ant_node  = get_node("Ant")
@onready var interact_icon  = get_node("interact_icon")
@onready var area = $Area2D
@onready var interaction_area = $InteractionArea

var in_cutscene: bool = false
var player_nearby: bool = false
var player: Player = null

var met_before_tunnels: bool = false
var spoke_after_tunnels: bool = false

var is_in_dialog: bool = false

func _ready():
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	interaction_area.body_entered.connect(_on_interaction_area_body_entered)
	interaction_area.body_exited.connect(_on_interaction_area_body_exited)

	# Create and setup timer
	timer = Timer.new()
	timer.one_shot = true
	add_child(timer)

	interact_icon.visible = false

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
	# Check if this dialog was for this NPC
	if finished_npc_id == npc_id:
		if in_cutscene:
			last_exited_body.disable_player_input = false
			in_cutscene = false
		is_in_dialog = false
		if player_nearby:
			interact_icon.visible = true
		else:
			interact_icon.visible = false


func start_dialog():
	print("Grasshopper: Starting dialog")
	is_in_dialog = true
	interact_icon.visible = false
	# Call the global dialog system
	if not has_node("/root/DialogSystem"):
		push_error("Cannot start dialog: DialogSystem not found!")
		return
	
	DialogSystem.start_dialog({
			"name": npc_name,
			"lines": ["Hi I'm the queen", "Here is where i would say a bunch of story stuff regarding my romance with the spider."],
			"name_color": name_color,
			"voice_sound_path": voice_sound_path
		}, npc_id)
	story_manager.met_queen = true


func _on_interaction_area_body_entered(body):
	if body is Player:
		player = body
		player_nearby = true
		interact_icon.visible = true

func _on_interaction_area_body_exited(body):
	if body is Player:
		player_nearby = false
		interact_icon.visible = false

func _process(delta):
	if player_nearby:
		# Get player node
		if player:
			if Input.is_action_just_pressed("interact") and !is_in_dialog:
				start_dialog()

func _on_body_entered(body):
	if body is Player:
		in_cutscene = true
		interact_icon.visible = false
		body.disable_player_input = true
		print("disabling player input")
		timer.start(1)
		await timer.timeout
		body.input_virtual_dir(Vector2.LEFT)

func _on_body_exited(body):
	if body is Player and in_cutscene:
		last_exited_body = body
		timer.start(.1)
		await timer.timeout
		body.input_virtual_dir_pulse(Vector2.RIGHT)
		timer.start(1.0)
		await timer.timeout
		start_dialog()
