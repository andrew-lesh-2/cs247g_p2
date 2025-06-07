extends Node2D

# Button press animation settings
@export var button_press_depth: float = 15.0  # How far down the button moves
@export var button_press_duration: float = 0.3  # How long the button animation takes
@export var sound_delay: float = 0.05  # Short delay before playing sound after button press

# Button textures
@export var xylophone_base_texture: Texture2D = preload("res://assets/sprites/environment/xylophone1.png")
@export var xylophone_button2_texture: Texture2D = preload("res://assets/sprites/environment/xylophone2.png")
@export var xylophone_button3_texture: Texture2D = preload("res://assets/sprites/environment/xylophone3.png")
@export var xylophone_button4_texture: Texture2D = preload("res://assets/sprites/environment/xylophone4.png")
@export var xylophone_button5_texture: Texture2D = preload("res://assets/sprites/environment/xylophone5.png")
@export var xylophone_button6_texture: Texture2D = preload("res://assets/sprites/environment/xylophone6.png")

# Button sounds
@export var button2_sound: AudioStream = preload("res://audio/effects/c.mp3")
@export var button3_sound: AudioStream = preload("res://audio/effects/d.mp3")
@export var button4_sound: AudioStream = preload("res://audio/effects/e.mp3")
@export var button5_sound: AudioStream = preload("res://audio/effects/g.mp3")
@export var button6_sound: AudioStream = preload("res://audio/effects/a.mp3")

# Button nodes
@onready var sprite = $Sprite2D
@onready var button2 = $ButtonAreas/Button2
@onready var button3 = $ButtonAreas/Button3
@onready var button4 = $ButtonAreas/Button4
@onready var button5 = $ButtonAreas/Button5
@onready var button6 = $ButtonAreas/Button6

# Detection areas
@onready var area2 = $DetectionAreas/area2
@onready var area3 = $DetectionAreas/area3
@onready var area4 = $DetectionAreas/area4
@onready var area5 = $DetectionAreas/area5
@onready var area6 = $DetectionAreas/area6

# Store original positions of buttons
var _button_original_positions = {}

# Track which buttons are currently being pressed
var _active_buttons = {}

# Track cooldowns for each button to prevent rapid retriggers
var _button_cooldowns = {}
const BUTTON_COOLDOWN_DURATION: float = 0.5

# Sound player for notes
var _sound_player: AudioStreamPlayer

func _ready():
	# Store original positions
	_button_original_positions[2] = button2.position
	_button_original_positions[3] = button3.position
	_button_original_positions[4] = button4.position
	_button_original_positions[5] = button5.position
	_button_original_positions[6] = button6.position
	
	# Initialize cooldowns
	_button_cooldowns[2] = 0.0
	_button_cooldowns[3] = 0.0
	_button_cooldowns[4] = 0.0
	_button_cooldowns[5] = 0.0
	_button_cooldowns[6] = 0.0
	
	# Connect area signals
	area2.body_entered.connect(_on_area2_body_entered)
	area3.body_entered.connect(_on_area3_body_entered)
	area4.body_entered.connect(_on_area4_body_entered)
	area5.body_entered.connect(_on_area5_body_entered)
	area6.body_entered.connect(_on_area6_body_entered)
	
	# Create sound player
	_sound_player = AudioStreamPlayer.new()
	_sound_player.bus = "SFX"  # Use SFX audio bus if you have one
	add_child(_sound_player)
	
	# Set initial texture
	sprite.texture = xylophone_base_texture


func _physics_process(delta):
	# Update cooldowns
	for button_num in _button_cooldowns.keys():
		if _button_cooldowns[button_num] > 0:
			_button_cooldowns[button_num] -= delta
	
	# Check for fast-falling players in each area
	if player_in_area_with_velocity(area2, 50) and _button_cooldowns[2] <= 0:
		_trigger_button(2)
		_button_cooldowns[2] = BUTTON_COOLDOWN_DURATION
	
	if player_in_area_with_velocity(area3, 50) and _button_cooldowns[3] <= 0:
		_trigger_button(3)
		_button_cooldowns[3] = BUTTON_COOLDOWN_DURATION
		
	if player_in_area_with_velocity(area4, 50) and _button_cooldowns[4] <= 0:
		_trigger_button(4)
		_button_cooldowns[4] = BUTTON_COOLDOWN_DURATION
		
	if player_in_area_with_velocity(area5, 50) and _button_cooldowns[5] <= 0:
		_trigger_button(5)
		_button_cooldowns[5] = BUTTON_COOLDOWN_DURATION
		
	if player_in_area_with_velocity(area6, 50) and _button_cooldowns[6] <= 0:
		_trigger_button(6)
		_button_cooldowns[6] = BUTTON_COOLDOWN_DURATION


# Helper function to check if player is in area with specified downward velocity
func player_in_area_with_velocity(area: Area2D, min_velocity: float) -> bool:
	var bodies = area.get_overlapping_bodies()
	for body in bodies:
		if body is Player and body.velocity.y > min_velocity:
			return true
	return false


# Signal handlers for area entry
func _on_area2_body_entered(body):
	if body is Player and _button_cooldowns[2] <= 0:
		var player_body = body as Player
		if player_body.velocity.y > 0:
			_trigger_button(2)
			_button_cooldowns[2] = BUTTON_COOLDOWN_DURATION


func _on_area3_body_entered(body):
	if body is Player and _button_cooldowns[3] <= 0:
		var player_body = body as Player
		if player_body.velocity.y > 0:
			_trigger_button(3)
			_button_cooldowns[3] = BUTTON_COOLDOWN_DURATION


func _on_area4_body_entered(body):
	if body is Player and _button_cooldowns[4] <= 0:
		var player_body = body as Player
		if player_body.velocity.y > 0:
			_trigger_button(4)
			_button_cooldowns[4] = BUTTON_COOLDOWN_DURATION


func _on_area5_body_entered(body):
	if body is Player and _button_cooldowns[5] <= 0:
		var player_body = body as Player
		if player_body.velocity.y > 0:
			_trigger_button(5)
			_button_cooldowns[5] = BUTTON_COOLDOWN_DURATION


func _on_area6_body_entered(body):
	if body is Player and _button_cooldowns[6] <= 0:
		var player_body = body as Player
		if player_body.velocity.y > 0:
			_trigger_button(6)
			_button_cooldowns[6] = BUTTON_COOLDOWN_DURATION


# Press the specified button
func _trigger_button(button_num: int) -> void:
	# Get the appropriate button node
	var button_node
	var texture
	var sound
	
	match button_num:
		2:
			button_node = button2
			texture = xylophone_button2_texture
			sound = button2_sound
		3:
			button_node = button3
			texture = xylophone_button3_texture
			sound = button3_sound
		4:
			button_node = button4
			texture = xylophone_button4_texture
			sound = button4_sound
		5:
			button_node = button5
			texture = xylophone_button5_texture
			sound = button5_sound
		6:
			button_node = button6
			texture = xylophone_button6_texture
			sound = button6_sound
	
	if button_node and not _active_buttons.get(button_num, false):
		# Mark button as active
		_active_buttons[button_num] = true
		
		# Change texture
		sprite.texture = texture
		
		# Press button down
		_press_button(button_node, button_num)
		
		# Play sound after a small delay
		get_tree().create_timer(sound_delay).timeout.connect(func(): _play_note(sound))


# Press a button down
func _press_button(button_node: Node2D, button_num: int) -> void:
	# Create a tween for button press
	var press_tween = create_tween()
	press_tween.set_ease(Tween.EASE_OUT)
	press_tween.set_trans(Tween.TRANS_SINE)
	
	# Move the button down
	var target_pos = _button_original_positions[button_num] + Vector2(0, button_press_depth)
	press_tween.tween_property(button_node, "position", target_pos, button_press_duration * 0.4)
	
	# Set up the release after a delay
	press_tween.tween_callback(func(): _release_button(button_node, button_num))


# Release a button
func _release_button(button_node: Node2D, button_num: int) -> void:
	# Create a tween for button release
	var release_tween = create_tween()
	release_tween.set_ease(Tween.EASE_OUT)
	release_tween.set_trans(Tween.TRANS_SINE)
	
	# Move the button back up
	release_tween.tween_property(button_node, "position", 
		_button_original_positions[button_num], button_press_duration * 0.6)
	
	# Reset texture and mark button as inactive when done
	release_tween.tween_callback(func():
		sprite.texture = xylophone_base_texture
		_active_buttons[button_num] = false
	)


# Play a sound
func _play_note(sound: AudioStream) -> void:
	if sound:
		_sound_player.stream = sound
		_sound_player.play()
