extends Node2D

var timer: Timer

var npc_id = "caterpillar"
var npc_name = "Caterpillar"
var name_color = Color(1, 0.8, 0.1)
var voice_sound_path: String = "res://audio/voices/voice_Papyrus.wav"


@onready var story_manager = StoryManager
@onready var interact_icon  = get_node("interact_icon")
@onready var mission_icon  = get_node("mission_icon")
@onready var caterpillar_node  = get_node("caterpillar")
@onready var interaction_area = $InteractionArea

var in_cutscene: bool = false
var player_nearby: bool = false
var player: Player = null

var is_in_dialog: bool = false

func _ready():
	interaction_area.body_entered.connect(_on_interaction_area_body_entered)
	interaction_area.body_exited.connect(_on_interaction_area_body_exited)

	interact_icon.visible = false
	
	# set true if you add a mission, 
	# and its currently available given story_manager state
	mission_icon.visible = false 
	
	_ensure_dialog_connection()

func start_dialog():
	is_in_dialog = true
	interact_icon.visible = false
	mission_icon.visible = false
	# Call the global dialog system
	if not has_node("/root/DialogSystem"):
		push_error("Cannot start dialog: DialogSystem not found!")
		return

	if story_manager.met_caterpillar:
		DialogSystem.start_dialog({
			"name": npc_name,
			"lines": ["You can get to the anthill by traveling down the tree.", "Please deliver my love letter to the queen! I'll be eating away these leaves while I await your return. Hehe."],
			"name_color": name_color,
			"voice_sound_path": voice_sound_path
		}, npc_id)
		
	if story_manager.met_caterpillar and story_manager.met_queen:
		DialogSystem.start_dialog({
			"name": npc_name,
			"lines": ["SO?! What did she think?!", "...", "YOU DID IT LITTLE LADYBUG! YOU ARE A HERO!", "...",
			 "She wants to meet me? Well... I guess I better start forming my chrysalis. Good thing I ate all these leaves!",
			"Well little ladybug... I must get big and strong for the lady so that she doesn't realize you totally lied to her!",
			"Now, just crawl up on top of the tree, and you should be able to find your path back home.",
			"Best of luck on your journey. I hope we run into each other again very soon -- maybe you won't recognize me at first,
			but I promise I'll never forget you!"],
			"name_color": name_color,
			"voice_sound_path": voice_sound_path
		}, npc_id)
		
	else:
		DialogSystem.start_dialog({
			"name": npc_name,
			"lines": ["A LADYBUG?!", "My my you must be very far away from home, how did you get all the way up here?", "...",
			"Ah. It sounds like the child abducted you. It happens to all of us -- that's how I ended up here. Glad you could escape from the box!",
			"So, are you on your way back home?", "...", "I see. You don't know how to get back home.",
			 "How about this! I'll make you a deal.", "You see, I'm in love... but this woman.. she's such a... woman.",
			"And look at me! I'm just a little caterpillar!", "I wrote this love letter... but every time I try to enter the anthill I get lost.",
			"If you deliver this love letter to the Queen Ant, I'll eat the leaves above us to clear a path, and then you'll be able to see a route back home!", 
			"How about it little ladybug, you up for the challenge?", "...", "GREAT! Come back once you've delivered it, and tell me what she thinks!", 
			"Maybe... don't mention my size. Just tell her the letter is from someone BIG and STRONG and SMART. Soon enough I'll be a butterfly, so it'll be true!"],
			"name_color": name_color,
			"voice_sound_path": voice_sound_path
		}, npc_id)
		story_manager.met_caterpillar = true
	

func _on_interaction_area_body_entered(body):
	if body is Player:
		player = body
		player_nearby = true
		interact_icon.visible = true
		mission_icon.visible = false

func _on_interaction_area_body_exited(body):
	if body is Player:
		player_nearby = false
		interact_icon.visible = false

		 # set this to true if the this character has a mission available
		mission_icon.visible = false

func _process(delta):
	if player_nearby:
		# Get player node
		if player:
			# Compare x positions to determine direction
			var direction_to_player = player.global_position.x - caterpillar_node.global_position.x
			# Flip sprite based on player position
			caterpillar_node.scale.x = -1 if direction_to_player < 0 else 1

		if Input.is_action_just_pressed("interact") and !is_in_dialog:
			start_dialog()
	else:
		# Return to default orientation
		caterpillar_node.scale.x = 1







# !! Boilerplate code below, feel free to ignore !!


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
		is_in_dialog = false
		mission_icon.visible = false
		if player_nearby:
			interact_icon.visible = true
		else:
			interact_icon.visible = false
		in_cutscene = false
