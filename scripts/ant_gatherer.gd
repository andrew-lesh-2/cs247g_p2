extends Node2D

var timer: Timer

var last_exited_body: Player = null

@onready var story_manager = StoryManager
@onready var interact_icon  = get_node("interact_icon")
@onready var mission_icon  = get_node("mission_icon")
@onready var ant_node  = get_node("Ant")
@onready var interaction_area = $InteractionArea

var in_cutscene: bool = false
var player_nearby: bool = false
var player: Player = null

var is_in_dialog: bool = false

@onready var dialog = get_parent().get_parent().get_node("Dialog")

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
	return (story_manager.food_mission_active or
		story_manager.food_mission_completed)

func start_dialog():
	is_in_dialog = true
	interact_icon.visible = false
	mission_icon.visible = false
	# Call the global dialog system
	if (not have_spoken() and story_manager.stick_mission_active):
		dialog.display_dialog(
			'Ant Forager',
			'ant_forager',
			["Come talk to me when you're done helping the artist, if you're looking for a way to be useful to the colony."]
		)
	elif (not have_spoken() and story_manager.doctor_mission_active):
		dialog.display_dialog(
			'Ant Forager',
			'ant_forager',
			["Come talk to me when you're done helping the doctor, if you're looking for a way to be useful to the colony."]
		)
	elif not have_spoken():
		dialog.display_dialog(
			'Ant Forager',
			'ant_forager',
			["Hey there sweetie.",
				"Hey there sweetie.",
				"Rumor has it that you're a good jumper and climber.",
				"Some people are even saying that you can fly...",
				"Anyways, we went foraging for berries earlier, but there were a few berries left on the bush that we weren't able to reach!",
				"Think you could grab those berries?",
				"I'm sure someone like you could reach the top of the bush easily."],
		)
		story_manager.food_mission_active = true
	elif story_manager.food_mission_active and story_manager.holding_berries == 0:
		dialog.display_dialog(
			'Ant Forager',
			["Still haven't found the berries?",
				"Still haven't found the berries?",
				"No worries, you're still new around here.",
				"The bush is to the right of the anthill on the surface!"]
		)
	elif story_manager.food_mission_active and story_manager.holding_berries < 4:
		var count_str = "one"
		if story_manager.holding_berries == 2:
			count_str = "two"
		elif story_manager.holding_berries == 3:
			count_str = "three"
		dialog.display_dialog(
			'Ant Forager',
			["Nice job dear, you found the berries",
				"Nice job dear, you found the berries",
				"Weren't there four berries though? You only brought " + count_str + ".",
				"Go check if you can find some more."]
		)
	elif story_manager.food_mission_active and story_manager.holding_berries:
		story_manager.food_mission_completed = true
		story_manager.food_mission_active = false
		dialog.display_dialog(
			'Ant Forager',
			["I knew you could reach those berries!",
				"I knew you could reach those berries!",
				"Thank you so much, this will really help the colony.",
				"You know, its not too bad having someone thats a little different around."]
		)
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
		mission_icon.visible = (not story_manager.food_mission_active
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

		if Input.is_action_just_pressed("interact") and !is_in_dialog:
			start_dialog()
	else:
		# Return to default orientation
		ant_node.scale.x = 1
