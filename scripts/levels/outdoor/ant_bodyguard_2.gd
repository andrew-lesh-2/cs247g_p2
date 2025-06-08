extends Node2D

var timer: Timer

var last_exited_body: Player = null

@onready var story_manager = StoryManager
@onready var interact_icon  = get_node("interact_icon")
@onready var ant_node  = get_node("Ant")
@onready var area = $Area2D
@onready var interaction_area = $InteractionArea

@onready var dialog = get_parent().get_parent().get_node("Dialog")

var in_cutscene: bool = false
var player_nearby: bool = false
var player: Player = null


func _ready():
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	interaction_area.body_entered.connect(_on_interaction_area_body_entered)
	interaction_area.body_exited.connect(_on_interaction_area_body_exited)

	interact_icon.visible = false


	# Create and setup timer
	timer = Timer.new()
	timer.one_shot = true
	add_child(timer)



func _on_dialog_finished():
	if player_nearby:
		interact_icon.visible = true
	else:
		interact_icon.visible = false
	in_cutscene = false


func start_dialog():
	interact_icon.visible = false
	if not story_manager.can_enter_anthill:
		dialog.display_dialog(
			'Ant Bodyguard',
			'ant_bodyguard_2',
			["What?!?!?", "You really made it through the collapsed tunnels?!?!?", "-- I mean the visitors center", "You must be one tough bug", "You're cool enough to hang with the Ants!"]
		)
		story_manager.can_enter_anthill = true
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
			'Ant Bodyguard',
			'ant_bodyguard_2',
			lines
		)
	_on_dialog_finished()

func _on_body_entered(body):
	if body is Player and not story_manager.can_enter_anthill:
		start_dialog()

func _on_body_exited(body):
	pass

func _on_interaction_area_body_entered(body):
	if body is Player and story_manager.can_enter_anthill:
		player = body
		player_nearby = true
		interact_icon.visible = true

func _on_interaction_area_body_exited(body):
	if body is Player and story_manager.can_enter_anthill:
		player_nearby = false
		interact_icon.visible = false

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
