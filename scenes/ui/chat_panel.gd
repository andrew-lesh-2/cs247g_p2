extends Control

var parent = null


var offset = Vector2.ZERO
var player_position = Vector2.ZERO
var active = false

@export_category("Voice Settings")
@export_range(0.0, 1.0) var voice_volume: float = 0.5  # Voice sound volume
@export_range(0.5, 2.0) var voice_pitch: float = 1.0  # Voice sound pitch
@export var character_sound_cooldown: float = 0.03

@onready var name_label = $Panel/Name
@onready var dialog = $Panel/dialog
@onready var hint_label = $Panel/hint

@onready var caterpillar_portrait = $Caterpillar
@onready var ant_bodyguard_1_portrait = $ant_bodyguard_1
@onready var ant_bodyguard_2_portrait = $ant_bodyguard_2
@onready var ant_bodyguard_3_portrait = $ant_bodyguard_3
@onready var ant_forager_portrait = $ant_forager
@onready var ant_doctor_portrait = $ant_doctor
@onready var ant_artist_portrait = $ant_artist
@onready var ant_queen_portrait = $ant_queen
@onready var grasshopper_portrait = $grasshopper
@onready var ladybug_portrait = $ladybug
@onready var dust_mite_portrait = $dust_mite
@onready var controller_portrait = $controller

var current_portrait = null

@export var follow_player : bool = true

const PER_WORD_DELAY = 0.05
var word_timer = 0.0
var sound_timer = 0.0
var current_char = 0
var current_line = 0
var lines = []
var get_player_input : bool = false

var voice_sound_player = null
@onready var voice_sound = load('res://audio/voices/voice_Papyrus.wav')

func _ready():
	parent = get_parent()
	if parent:
		offset = position - parent.get_node("Player").position
	visible = false
	hint_label.visible = false
	setup_voice_player()


func reset():
	word_timer = 0
	current_char = 0
	current_line = 0
	get_player_input = false
	lines = []
	dialog.text = ""
	if current_portrait:
		current_portrait.visible = false
		current_portrait = null

func _process(delta):
	if parent and follow_player:
		position = parent.get_node("Player").position + offset

		# if space is pressed, display the next line
	if not active:
		return


	hint_label.visible = get_player_input


	var user_action = Input.is_action_just_pressed("interact")
	var speed_up = Input.is_action_pressed("interact")

	var time_multiplier = 1
	if speed_up:
		time_multiplier = 4
	word_timer += delta * time_multiplier
	sound_timer += delta * time_multiplier


	if get_player_input and user_action:
		get_player_input = false
		if current_line >= lines.size():
			active = false
			reset()
			visible = false
			get_tree().paused = false
			return
		user_action = false
	
	if user_action:
		dialog.text = lines[current_line]
		current_line += 1
		current_char = 0
		get_player_input = true
		return
		
		

	if word_timer > PER_WORD_DELAY and not get_player_input:
		word_timer = 0

		var line = lines[current_line]

		dialog.text = line.substr(0, current_char + 1)
		if sound_timer > character_sound_cooldown:
			if play_character_sound(line[current_char]):
				sound_timer = 0


		current_char += 1
		if current_char >= lines[current_line].length():
			current_line += 1
			current_char = 0
			get_player_input = true

func play_character_sound(character):
	if voice_sound_player and voice_sound and character not in [" ", "\n", ".", ",", "!", "?"]:
		print("Playing sound")
		# Stop any currently playing sound
		voice_sound_player.stop()

		# Play the sound with a small random pitch variation for natural feel
		voice_sound_player.pitch_scale = voice_pitch * randf_range(0.95, 1.05)
		voice_sound_player.play()
		return true
	else:
		return false

func display_dialog(character, id, input_lines):
	print("DISPLAY DIALOG CALLED")
	get_tree().paused = true
	visible = true
	name_label.text = character
	active = true
	lines = input_lines

	if id.to_lower() == "caterpillar":
		caterpillar_portrait.visible = true
		current_portrait = caterpillar_portrait
	if id.to_lower() == 'ant_bodyguard_1':
		ant_bodyguard_1_portrait.visible = true
		current_portrait = ant_bodyguard_1_portrait
	if id.to_lower() == 'ant_bodyguard_2':
		ant_bodyguard_2_portrait.visible = true
		current_portrait = ant_bodyguard_2_portrait
	if id.to_lower() == 'ant_bodyguard_3':
		ant_bodyguard_3_portrait.visible = true
		current_portrait = ant_bodyguard_3_portrait
	if id.to_lower() == 'ant_forager':
		ant_forager_portrait.visible = true
		current_portrait = ant_forager_portrait
	if id.to_lower() == 'ant_doctor':
		ant_doctor_portrait.visible = true
		current_portrait = ant_doctor_portrait
	if id.to_lower() == 'ant_artist':
		ant_artist_portrait.visible = true
		current_portrait = ant_artist_portrait
	if id.to_lower() == 'ant_queen':
		ant_queen_portrait.visible = true
		current_portrait = ant_queen_portrait
	if id.to_lower() == 'grasshopper':
		grasshopper_portrait.visible = true
		current_portrait = grasshopper_portrait
	if id.to_lower() == 'ladybug':
		ladybug_portrait.visible = true
		current_portrait = ladybug_portrait
	if id.to_lower() == 'dust_mite':
		dust_mite_portrait.visible = true
		current_portrait = dust_mite_portrait
	if id.to_lower() == 'controller':
		controller_portrait.visible = true
		current_portrait = controller_portrait

func setup_voice_player():
	# Create audio player for voice sounds
	voice_sound_player = AudioStreamPlayer.new()
	voice_sound_player.process_mode = Node.PROCESS_MODE_ALWAYS
	voice_sound_player.volume_db = linear_to_db(voice_volume)
	voice_sound_player.pitch_scale = voice_pitch
	voice_sound_player.stream = voice_sound
	add_child(voice_sound_player)
