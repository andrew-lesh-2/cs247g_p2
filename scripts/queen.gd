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

	dialog.display_dialog(
		'Queen',
		'ant_queen',
		["Is that... it couldn't be... a ladybug?", "My my... how unexpected. You are far from your home, young traveler.
			It must have taken no small measure of wit and strength to have reached my chambers.", "...", "What have we here? A letter?
			How curious... Let's see...", "To Her Majesty, Queen of the Endless Tunnels, From beyond your earthen halls, a humble creature sends their heart.
			I have seen many wonders beneath leaf and sky, but none so radiant as you. Your voice commands armies, yet it silences mine with awe.
			Your grace turns soil to silk and duty into art.", "I am no king, no soldier, only a wanderer with growing wings, which I hope will carry me to you.
			If your heart holds space for one who is not of your kind, then let me wait at your gates and dream until you call.",
			"— Yours, if you'll have me A Devoted Stranger", "...", "Little ladybug... will you please convey to this stranger that I would like to meet them
			in seven days time. I shall be awaiting their presence at the top of the anthill.",  "Thank you for traveling all the way
			here little ladybug. Now, make haste. I wish you luck on your journey."],
	)
	story_manager.met_queen = true
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
			if Input.is_action_just_pressed("interact"):
				start_dialog()

func _on_body_entered(body):
	if body is Player:
		in_cutscene = true
		interact_icon.visible = false
		body.disable_player_input = true
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
