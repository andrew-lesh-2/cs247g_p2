extends Node2D

var timer: Timer

@onready var story_manager = StoryManager
@onready var interact_icon  = get_node("interact_icon")
@onready var mission_icon  = get_node("mission_icon")
@onready var caterpillar_node  = get_node("caterpillar")
@onready var interaction_area = $InteractionArea

@onready var dialog = get_parent().get_parent().get_node("Dialog")

var in_cutscene: bool = false
var player_nearby: bool = false
var player: Player = null

var final_dialog_completed: bool = false  # Track if the final dialog completed

func _ready():
	interaction_area.body_entered.connect(_on_interaction_area_body_entered)
	interaction_area.body_exited.connect(_on_interaction_area_body_exited)

	interact_icon.visible = false

	# set true if you add a mission,
	# and its currently available given story_manager state
	mission_icon.visible = false

func start_dialog():
	interact_icon.visible = false
	mission_icon.visible = false
	# Call the global dialog system
	if not has_node("/root/DialogSystem"):
		push_error("Cannot start dialog: DialogSystem not found!")
		return

	if story_manager.met_caterpillar and story_manager.met_queen:
		dialog.display_dialog(
			'Caterpillar',
			["SO?! What did she think?!",
			"...",
			"YOU DID IT LITTLE LADYBUG! YOU ARE A HERO!",
			"...",
			"She wants to meet me? Well... I guess I better start forming my chrysalis. Good thing I ate all these leaves!",
			"Well little ladybug... I must get big and strong for the lady so that she doesn't realize you totally lied to her!",
			"Now, just crawl up on top of the tree, and you should be able to find your path back home.",
			"Best of luck on your journey. I hope we run into each other again very soon -- maybe you won't recognize me at first,
			but I promise I'll never forget you!"])

		# Mark that this is the final dialog
		final_dialog_completed = true

	elif story_manager.met_caterpillar:
		dialog.display_dialog(
			'Caterpillar',
			["You can get to the anthill by traveling down the tree.", "Please deliver my love letter to the queen! I'll be eating away these leaves while I await your return. Hehe."]
		)

	else:
		dialog.display_dialog(
			'Caterpillar',
			["A LADYBUG?!", "My my you must be very far away from home, how did you get all the way up here?",
			"...",
			"Ah. It sounds like the child abducted you. It happens to all of us -- that's how I ended up here. Glad you could escape from the box!",
			"So, are you on your way back home?",
			"...",
			"I see. You don't know how to get back home.",
			 "How about this! I'll make you a deal.",
			 "You see, I'm in love... but she.. wow... I mean she sure is something...",
			"And look at me! I'm just a little caterpillar!",
			"I wrote this love letter for her... but every time I try to enter the anthill I get lost.",
			"If you deliver this love letter to the Queen Ant, I'll eat the leaves above us to clear a path, and then you'll be able to see a route back home!",
			"How about it little ladybug, you up for the challenge?",
			"...",
			"GREAT! Come back once you've delivered it, and tell me what she thinks!",
			"Maybe... don't mention my size. Just tell her the letter is from someone BIG and STRONG and SMART. Soon enough I'll be a butterfly, so it'll be true!"],
		)
		story_manager.met_caterpillar = true

	_on_dialog_finished()


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

		if Input.is_action_just_pressed("interact"):
			start_dialog()
	else:
		# Return to default orientation
		caterpillar_node.scale.x = 1

# Start the transition to the Combat Scene with fade-out
func start_level_transition():
	# Get the parent level node (should be the outdoor level with fade capability)
	var level_node = get_tree().current_scene

	# Check if the parent level has the fade_out method
	if level_node.has_method("fade_out"):
		# Disable player input if possible
		if player:
			if player.has_method("disable_input"):
				player.disable_input(true)
			else:
				player.disable_player_input = true

		# Call the parent's fade_out method with a callback to change scenes
		level_node.fade_out(2.0, 0.5, func(): get_tree().change_scene_to_file("res://scenes/levels/CombatScene.tscn"))
	else:
		# Fallback if parent doesn't have fade capability
		get_tree().change_scene_to_file("res://scenes/levels/CombatScene.tscn")

func _on_dialog_finished():
	mission_icon.visible = false

	# Check if this was the final dialog that should trigger level transition
	if final_dialog_completed and story_manager.met_caterpillar and story_manager.met_queen:
		# Wait a brief moment before starting transition
		var timer = get_tree().create_timer(1.0)
		timer.timeout.connect(func(): start_level_transition())
	else:
		# Normal dialog end behavior
		if player_nearby:
			interact_icon.visible = true
		else:
			interact_icon.visible = false
		in_cutscene = false
