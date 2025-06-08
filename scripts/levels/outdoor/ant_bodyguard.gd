extends Node2D

var timer: Timer

var last_exited_body: Player = null

@onready var story_manager = StoryManager
@onready var ant_node  = get_node("Ant")
@onready var interact_icon  = get_node("interact_icon")
@onready var area = $Area2D
@onready var interaction_area = $InteractionArea

@onready var dialog = get_parent().get_parent().get_node("Dialog")

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


func _on_dialog_finished():
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

	if not story_manager.can_enter_anthill:
		dialog.display_dialog(
			'Ant Bodyguard',
			'ant_bodyguard_1',
			["Hey, this way's for ants and approved guests only!", "You're not allowed to go this way.", "Go the other way for our guest check ins"]
		)
		story_manager.met_first_bodyguard = true
	elif (not story_manager.met_first_bodyguard and not story_manager.spoke_after_tunnels):
		dialog.display_dialog(
			'Ant Bodyguard',
			'ant_bodyguard_1',
			["Hey, nice to meet you!", "I heard you made it through the collapsed tunnels?", "That makes you an honorary ant in my eyes!"]
		)
		story_manager.spoke_after_tunnels = true
	elif (story_manager.met_first_bodyguard and not story_manager.spoke_after_tunnels):
		dialog.display_dialog(
			'Ant Bodyguard',
			'ant_bodyguard_1',
			["I sent you into the abandoned tunnels, and you made it out in one piece!", "That makes you an honorary ant in my eyes!"]
		)
		story_manager.spoke_after_tunnels = true
	else:
		var line_options = [
			["How's the anthill treating you?"],
			["If it isn't my favorite ladybug."],
			["You’ve earned your place here, welcome back."],
			["Good to see you again, ladybug. Ready for another day of work?"],
			["Not every day we get someone as skilled as you around here."],
			["I’ve got to admit, I’m impressed with your efforts."],
			["Ah, the ladybug returns. What’s the latest news from the outside world?"],
			["It’s rare to see someone handle things so well around here."],
			["So, how’s the journey treating you? Found any trouble?"],
			["You’re more than just a guest now. You’re part of this place."],
			["I knew you had it in you. The anthill’s better for your presence."],
			["Not all ants are as welcoming, but I’m glad you’ve proven yourself."],
			["Welcome back to the heart of the anthill. It’s safe here."],
			["You’re always welcome here. Just don’t make me regret it!"],
			["I’ve seen your strength, ladybug. I hope you’re here to stay."],
			["Things go smoother with you around. You’ve earned respect."],
			["Every new face has a story, but yours was written in action."],
			["Another day, another ladybug earning their keep. You’ve done well."],
			["It’s not easy to be trusted here. You’ve done just that."]
		]
		var lines = line_options[randi() % line_options.size()]
		dialog.display_dialog(
			'Ant Bodyguard',
			'ant_bodyguard_1',
			lines
		)
	_on_dialog_finished()


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
			# Compare x positions to determine direction
			var direction_to_player = player.global_position.x - ant_node.global_position.x
			# Flip sprite based on player position
			ant_node.scale.x = -1 if direction_to_player < 0 else 1

		if Input.is_action_just_pressed("interact") and !is_in_dialog:
			start_dialog()
	else:
		# Return to default orientation
		ant_node.scale.x = 1

func _on_body_entered(body):
	if body is Player and not story_manager.can_enter_anthill:
		in_cutscene = true
		body.disable_player_input = true
		print("disabling player input")
		timer.start(1)
		await timer.timeout
		body.input_virtual_dir(Vector2.RIGHT)

func _on_body_exited(body):
	if body is Player and in_cutscene:
		last_exited_body = body
		timer.start(.2)
		await timer.timeout
		body.input_virtual_dir_pulse(Vector2.LEFT)
		timer.start(1.0)
		await timer.timeout
		start_dialog()
