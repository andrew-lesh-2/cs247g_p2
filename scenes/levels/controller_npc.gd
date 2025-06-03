# controller_npc.gd

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
@onready var controller_node  = get_node("Controller")
@onready var controller_sprite: Sprite2D = $Controller.get_node("Controller Sprite") as Sprite2D
@onready var interaction_area = $InteractionArea

var in_cutscene: bool = false
var player_nearby: bool = false
var player: Player = null

var is_in_dialog: bool = false


# Preload both textures so you’re not doing a “load()” every frame:
@export var clean_texture   : Texture2D = preload("res://assets/sprites/environment/test_controller.png")
@export var dusty_texture      : Texture2D = preload("res://assets/sprites/environment/test_controller_dusty.png")


func _ready():
	controller_sprite.texture = dusty_texture
	
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
	elif (have_spoken() and not story_manager.spoke_bedmite):
		DialogSystem.start_dialog({
			"name": npc_name,
			"lines": [
				"Yup, it's still covered in dust.  Nasty."],
			"name_color": name_color,
			"voice_sound_path": voice_sound_path
		}, npc_id)
		story_manager.found_controller = true
	elif (have_spoken() and story_manager.spoke_bedmite and not story_manager.fed_bedmite):
		DialogSystem.start_dialog({
			"name": npc_name,
			"lines": [
				"It's still covered in dust.",
				"Maybe the dust mite would like to clean it off?"],
			"name_color": name_color,
			"voice_sound_path": voice_sound_path
		}, npc_id)
		story_manager.found_controller = true
	elif (have_spoken() and story_manager.fed_bedmite):
		DialogSystem.start_dialog({
			"name": npc_name,
			"lines": [
				"Squeaky clean!",
				"You feel a strange compulsion to jump on it now."],
			"name_color": name_color,
			"voice_sound_path": voice_sound_path
		}, npc_id)
		story_manager.found_controller = true
	

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

		if Input.is_action_just_pressed("interact") and !is_in_dialog:
			start_dialog()
			
	# As soon as story_manager.fed_bedmite becomes true, swap in the “fed” texture.
	# You can guard so that you only assign it once:
	if story_manager.fed_bedmite and controller_sprite.texture != clean_texture:
		controller_sprite.texture = clean_texture
	
