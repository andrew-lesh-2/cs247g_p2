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
	is_in_dialog = true
	interact_icon.visible = false

	if (num_missions_completed() == 0 and
		not story_manager.spoken_to_queens_guard):
		dialog.display_dialog(
			'Ant Bodyguard',
			'ant_bodyguard_3',
			["HEY! STOP!",
					  "You better have a good reason you're coming down to the queen's chambers.",
					  "What about a spider?",
					"Listen, you have some real nerve waltzing into our anthill and immediately demanding an audience with the queen.",
					"Its always outsiders looking for favors from the queen, never offering to help her colony.",
					"Get out of my sight."],
		)
		story_manager.spoken_to_queens_guard = true
	elif num_missions_completed() == 0:
		dialog.display_dialog(
			'Ant Bodyguard',
			'ant_bodyguard_3',
			["What did I tell you already?",
					  "Get out of here.",
					  "You're not seeing the queen."],
		)
	elif (num_missions_completed() == 1 and
		not story_manager.spoken_to_queens_guard):
		dialog.display_dialog(
			'Ant Bodyguard',
			'ant_bodyguard_3',
			["Hey, stop!",
					  "The Queen's chambers are past this way, authorized guests only.",
					  "Say I thought I heard something about a Ladybug around the colony, wasn't sure if it was true.",
					  "You want to see the Queen?",
					  "HA! The Queen is incredibly busy, and has no idea who you are.",
					  "Maybe if there weren't so many problems to deal with in the anthill, she'd have time to meet with you!"],
		)
		story_manager.spoken_to_queens_guard = true
	elif num_missions_completed() == 1:
		dialog.display_dialog(
			'Ant Bodyguard',
			'ant_bodyguard_3',
			["Quit trying to see the Queen, it's not going to happen!", "She's way too busy"],
		)
	elif (num_missions_completed() == 2 and
		not story_manager.spoken_to_queens_guard):
		dialog.display_dialog(
			'Ant Bodyguard',
			'ant_bodyguard_3',
			["Woah woah woah, slow down there.",
					  "I'm sorry, but the Queen will only see authorized guests.",
					  "Say are you that ladybug they say has been helping out around the anthill?",
					  "Well it's nice to meet you, thanks for your service to the colony.",
					  "Look between you and me, I think if you keep making a name for yourself in the anthill, eventually the Queen will want to meet you",
					  "Good luck."],
		)
		story_manager.spoken_to_queens_guard = true
	elif num_missions_completed() == 2:
		dialog.display_dialog(
			'Ant Bodyguard',
			'ant_bodyguard_3',
			["Keep things up and I'm sure the Queen will eventually agree to meet with you."]
		)
	elif allowed_to_pass() and not story_manager.spoken_to_queens_guard:
		dialog.display_dialog(
			'Ant Bodyguard',
			'ant_bodyguard_3',
			["Stop right there, this is the way to the Queen's chambers.",
			"Wait a second, are you that ladybug thats been helping out around the colony?",
			"I must admit, you're quite popular around the anthill these days.",
			"You're looking for the Queen?",
			"Well, she did recently mention wanting to meet the helpful Ladybug.",
			"Good luck."],
		)
		story_manager.spoken_to_queens_guard = true
		story_manager.gotten_past_queens_guard = true
	elif allowed_to_pass() and not story_manager.gotten_past_queens_guard:
		dialog.display_dialog(
			'Ant Bodyguard',
			'ant_bodyguard_3',
			["I must say, all your good deeds have paid off",
			"You've been a huge help to the colony, and everybody is singing your praises.",
			"The Queen has agreed to grant you an audience.",
			"Good luck."],
		)
		story_manager.gotten_past_queens_guard = true
	elif (story_manager.met_first_bodyguard and not story_manager.spoke_after_tunnels):
		dialog.display_dialog(
			'Ant Bodyguard',
			'ant_bodyguard_3',
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
			'ant_bodyguard_3',
			lines
		)
	_on_dialog_finished()


func _on_interaction_area_body_entered(body):
	if body is Player:
		player = body
		player_nearby = true
		if allowed_to_pass() and story_manager.spoken_to_queens_guard:
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
		if (allowed_to_pass() and story_manager.spoken_to_queens_guard):
			if Input.is_action_just_pressed("interact"):
				start_dialog()
	else:
		# Return to default orientation
		ant_node.scale.x = -1

func allowed_to_pass():
	return (story_manager.stick_mission_completed and
			story_manager.food_mission_completed and
			story_manager.doctor_mission_completed)

func num_missions_completed():
	var completed = 0
	if story_manager.stick_mission_completed:
		completed += 1
	if story_manager.food_mission_completed:
		completed += 1
	if story_manager.doctor_mission_completed:
		completed += 1
	return completed

func _on_body_entered(body):
	if body is Player and (not allowed_to_pass() or
		not story_manager.gotten_past_queens_guard):
		in_cutscene = true
		body.disable_player_input = true
		print("disabling player input")
		timer.start(1)
		await timer.timeout
		body.input_virtual_dir(Vector2.LEFT)

func _on_body_exited(body):
	if body is Player and in_cutscene:
		last_exited_body = body
		timer.start(.2)
		await timer.timeout
		body.input_virtual_dir_pulse(Vector2.RIGHT)
		timer.start(1.0)
		await timer.timeout
		start_dialog()
