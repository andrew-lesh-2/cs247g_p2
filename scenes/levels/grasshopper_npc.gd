extends Node2D

var timer: Timer

var last_exited_body: Player = null

@onready var story_manager = StoryManager
@onready var interact_icon  = get_node("interact_icon")
#@onready var mission_icon  = get_node("mission_icon")
@onready var grasshopper_node  = get_node("Grasshopper")
@onready var interaction_area = $InteractionArea

@onready var dialog = get_parent().get_parent().get_parent().get_node('Dialog')

var in_cutscene: bool = false
var player_nearby: bool = false
var player: Player = null

var is_in_dialog: bool = false

var just_dialoged: bool = false

func _ready():
	interaction_area.body_entered.connect(_on_interaction_area_body_entered)
	interaction_area.body_exited.connect(_on_interaction_area_body_exited)

	interact_icon.visible = false
	# mission_icon.visible = not have_spoken()

	print("grasshopper parent", get_parent().get_parent())


func _on_dialog_finished():
	# mission_icon.visible = false
	if player_nearby:
		interact_icon.visible = true
	else:
		interact_icon.visible = false
	in_cutscene = false
	is_in_dialog = false

func have_spoken():
	return (story_manager.spoke_grasshopper)

func start_dialog():
	is_in_dialog = true
	interact_icon.visible = false
	# mission_icon.visible = false
	if not have_spoken():
		dialog.display_dialog(
			'Grasshopper',
			'grasshopper',
			[
				"Hello there, subject. You were unconscious for quite some time.",
				"Welcome to my castle.  The giant one brought you here to entertain me, I presume.",
				"I've earned the giant one's favor, you see.  It bestowed me with this miraculous fortress.",
				"It also provides me with the finest of leaves, truly fit for a nobleman like myself.",
				"Oh, you want to leave?  Why?  This is a paradise!"],
		)
		story_manager.spoke_grasshopper = true
	elif (have_spoken() and story_manager.spoke_bedmite and not story_manager.insulted_bedmite):
		dialog.display_dialog(
			'Grasshopper',
			'grasshopper',
			[
				"Oh, so you've met that notorious dust mite, have you?",
				"Well I don't mean to be rude, but are you not aware that dust mites eat dust?",
				"Absolutely uncivilized!  I mean can you imagine?!  Dust instead of leaves?!",
				"You really ought to think more carefully about the company you keep."],
		)
		story_manager.insulted_bedmite = true
	elif (have_spoken()):
		dialog.display_dialog(
			'Grasshopper',
			'grasshopper',
			["Have you come to your senses?  Stay, stay!"]
		)

	_on_dialog_finished()

func _on_body_entered(body):
	if body is Player and not story_manager.can_enter_anthill:
		pass
		#start_dialog()

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
		print("just_dialoged", just_dialoged)
		if Input.is_action_just_pressed("interact") and not just_dialoged:
			print("INTERACT CALLED")
			start_dialog()
			just_dialoged = true
			print("just_dialoged set", just_dialoged)
			return

		just_dialoged = false
	#else:
		# Return to default orientation
	#	grasshopper_node.scale.x = 1
