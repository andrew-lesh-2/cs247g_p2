extends Node2D

var timer: Timer

var last_exited_body: Player = null

@onready var story_manager = StoryManager
@onready var interact_icon  = get_node("interact_icon")
@onready var mission_icon  = get_node("mission_icon")
@onready var ant_node  = get_node("Ant")
@onready var interaction_area = $InteractionArea
@onready var dialog = get_parent().get_parent().get_node("Dialog")

var in_cutscene: bool = false
var player_nearby: bool = false
var player: Player = null

var is_in_dialog: bool = false

func _ready():
	interaction_area.body_entered.connect(_on_interaction_area_body_entered)
	interaction_area.body_exited.connect(_on_interaction_area_body_exited)

	interact_icon.visible = false
	mission_icon.visible = not have_spoken()


func _on_dialog_finished():
	is_in_dialog = false
	mission_icon.visible = false
	if player_nearby:
		interact_icon.visible = true
	else:
		interact_icon.visible = false
	in_cutscene = false

func have_spoken():
	return (story_manager.doctor_mission_active or
		story_manager.doctor_mission_completed)

func start_dialog():
	interact_icon.visible = false
	mission_icon.visible = false

	if not have_spoken() and story_manager.food_mission_active:
		dialog.display_dialog(
			'Ant Doctor',
			'ant_doctor',
			["Hey there, I could really use your help!",
				"Come talk to me when you're done helping the forager!"]
		)
	elif not have_spoken() and story_manager.stick_mission_active:
		dialog.display_dialog(
			'Ant Doctor',
			'ant_doctor',
			["Hey there, I could really use your help!",
				"Come talk to me when you're done helping the artist!"]
		)
	elif (not have_spoken()):
		dialog.display_dialog(
			'Ant Doctor',
			'ant_doctor',
			["Howdy strange bug!",
				"How are you today?",
				"Probably doing better than my patient over here!",
				"Speaking of, I need some daisy petals to make the treatment for these wounds, but we just ran out.",
				"Could you run to the surface for me and see if you can find any daisys? It'd be a huge help."]
		)
		story_manager.doctor_mission_active = true
	elif (story_manager.doctor_mission_active and
		story_manager.holding_daisies == 0):
		dialog.display_dialog(
			'Ant Doctor',
			'ant_doctor',
			["Well, what are you waiting for?",
				"Daisies grow on the surface!",
				"I'd get them myself but I have to stay with my patients"]
		)
	elif (story_manager.doctor_mission_active and
		story_manager.holding_daisies == 1):
		dialog.display_dialog(
			'Ant Doctor',
			'ant_doctor',
			["Great! You found a daisy.",
				"I'll need two more to produce the treatment I'm working on.",
				"Thanks!"]
		)
	elif (story_manager.doctor_mission_active and
		story_manager.holding_daisies == 2):
		dialog.display_dialog(
			'Ant Doctor',
			'ant_doctor',
			["Two Daisies, that's wonderful!",
				"One more and I'll be able to cure our hurt friend."]
		)
	elif (story_manager.doctor_mission_active and
		story_manager.holding_daisies >= 3):
		dialog.display_dialog(
			'Ant Doctor',
			'ant_doctor',
			["You found three daisies!",
			"That's just enough for me to make my medicine.",
			"*hits patient on the back a little too hard* You'll be walking in no time buddy!",
			"Thanks again for your work!"]
		)
		story_manager.doctor_mission_completed = true
		story_manager.doctor_mission_active = false

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
		dialog.display_dialog(
			'Ant Doctor',
			'ant_doctor',
			lines
		)
	_on_dialog_finished()

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
		mission_icon.visible = false

func _on_interaction_area_body_exited(body):
	if body is Player:
		player_nearby = false
		interact_icon.visible = false
		mission_icon.visible = (not story_manager.doctor_mission_active
								and
								not have_spoken())

func _process(delta):
	if player_nearby:
		# Get player node
		if player:
			# Compare x positions to determine direction
			var direction_to_player = player.global_position.x - ant_node.global_position.x
			# Flip sprite based on player position
			ant_node.scale.x = -1 if direction_to_player < 0 else 1

		if Input.is_action_just_pressed("interact"):
			start_dialog()
	else:
		# Return to default orientation
		ant_node.scale.x = 1
