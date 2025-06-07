extends Node2D

# — NPC IDENTIFIERS & DIALOG TUNING — 
var timer: Timer

var npc_id       = "controller"
var npc_name     = ""
var name_color   = Color(1, 0.8, 0.1)
var voice_sound_path: String = "res://audio/voices/voice_Papyrus.wav"

var last_exited_body: Player = null

# Button area paths
@export var left_button_area_path  : NodePath = "ButtonAreas/LeftButtonArea"
@export var right_button_area_path : NodePath = "ButtonAreas/RightButtonArea"

# Button collider paths
@export var left_button_collider_path: NodePath = "Buttons/LeftButton"
@export var right_button_collider_path: NodePath = "Buttons/RightButton"

# Button press animation settings
@export var button_press_depth: float = 30.0  # How far down the button moves
@export var button_press_duration: float = 0.6  # How long the button animation takes

# Camera pan settings
@export var camera_pan_duration: float = 1.5  # How long to pan the camera
@export var pause_on_truck_duration: float = 2.0  # How long to watch the truck move
var _first_button_press: bool = true  # Track if this is the first time a button is pressed
var _camera_tween: Tween  # Store the camera tween for management
var _original_camera_offset: Vector2  # Store the camera's original offset from player

@onready var story_manager       = StoryManager                                                # assume StoryManager is the parent
@onready var interact_icon       = $interact_icon
@onready var controller_node     = $Controller
@onready var controller_sprite   = $Controller/"Controller Sprite"  as Sprite2D
@onready var interaction_area    = $InteractionArea                                             # unchanged
@onready var left_button_area    = get_node(left_button_area_path)  as Area2D
@onready var right_button_area   = get_node(right_button_area_path) as Area2D
var _buttons_enabled: bool = false

# Physical button state tracking
var _left_button_node: StaticBody2D
var _right_button_node: StaticBody2D
var _left_button_original_position: Vector2
var _right_button_original_position: Vector2
var _left_button_pressing: bool = false
var _right_button_pressing: bool = false
var _left_button_press_timer: float = 0.0
var _right_button_press_timer: float = 0.0

# Left button improved detection
var _left_button_cooldown: float = 0.0
const LEFT_BUTTON_COOLDOWN_DURATION: float = 0.8

# Track player position and velocity
var _player_positions: Array = []
const POSITION_HISTORY_LENGTH: int = 3

# Player movement control - to disable during button press
var _player_movement_disabled: bool = false
var _need_to_restore_player_movement: bool = false

# — FIRETRUCK REFERENCE & POSITION CLAMPING — 
@export var firetruck_path : NodePath = "../../firetruck"
@onready var firetruck_node  = get_node(firetruck_path) as Node2D

var _firetruck_start_x: float = 0.0

const SHIFT_AMOUNT     := 20.0
const MAX_RIGHT_OFFSET :=  1 * SHIFT_AMOUNT    # +20 px from start
const MAX_LEFT_OFFSET  := -15 * SHIFT_AMOUNT   # –300 px from start

# — SMOOTH MOVEMENT SETTINGS —
@export var movement_duration: float = 2.0  # Seconds for firetruck to complete movement
var _is_moving: bool = false
var _move_start_position: Vector2
var _move_target_position: Vector2
var _move_time: float = 0.0
var _move_direction: int = 0  # -1 for left, 1 for right

# — WHEEL ROTATION SETTINGS —
@export var wheel_rotation_speed: float = 0.5  # Rotations per second
@export var wheel_radius: float = 8.0  # Estimated radius of your wheel sprites in pixels
@onready var wheel_nodes = []  # Will store references to wheel sprites

# — PRELOADED TEXTURES — 
@export var clean_texture       : Texture2D = preload("res://assets/sprites/environment/controller.png")
@export var dusty_texture       : Texture2D = preload("res://assets/sprites/environment/controller_dirty.png")
@export var press_left_texture  : Texture2D = preload("res://assets/sprites/environment/controller_up.png")
@export var press_right_texture : Texture2D = preload("res://assets/sprites/environment/controller_down.png")

# A Timer we'll use to revert the sprite back after 0.6 s
var _press_timer: Timer

# — OTHER FLAGS — 
var in_cutscene: bool    = false
var player_nearby: bool = false
var player: Player      = null

var is_in_dialog: bool  = false

# — INTERNAL FLAG TO ENSURE "DUSTY→CLEAN" ONLY RUNS ONCE — 
var _has_unlocked_buttons: bool = false

# Active button tracking
var _active_button: String = ""  # "left" or "right"


func _ready():
	# 1) Record the starting X of the firetruck so we can clamp its movement later
	if firetruck_node:
		_firetruck_start_x = firetruck_node.position.x
		
		# Get references to the wheel sprites
		if firetruck_node.has_node("Wheels"):
			var wheels_node = firetruck_node.get_node("Wheels")
			for i in range(wheels_node.get_child_count()):
				var child = wheels_node.get_child(i)
				if child is Sprite2D:
					wheel_nodes.append(child)
	else:
		push_error("⚠️ controller_npc.gd: firetruck_node is null (check firetruck_path).")
	
	# Get references to the physical button nodes
	_left_button_node = get_node(left_button_collider_path)
	_right_button_node = get_node(right_button_collider_path)
	
	if _left_button_node:
		_left_button_original_position = _left_button_node.position
	else:
		push_error("Left button collider not found at path: " + str(left_button_collider_path))
		
	if _right_button_node:
		_right_button_original_position = _right_button_node.position
	else:
		push_error("Right button collider not found at path: " + str(right_button_collider_path))

	# 2) Immediately show the "dusty" texture (since it hasn't been fed yet)
	if controller_sprite:
		print("DEBUG: _ready() → setting dusty_texture")
		controller_sprite.texture = dusty_texture
	else:
		push_error("⚠️ controller_sprite is null in _ready().")

	# 3) Disable both button areas until we explicitly unlock them
	_buttons_enabled = false
	left_button_area.monitoring = false
	right_button_area.monitoring = false

	# 4) Connect interaction‐area signals (so we can show/hide the "Press E" icon)
	interaction_area.body_entered.connect(_on_interaction_area_body_entered)
	interaction_area.body_exited.connect(_on_interaction_area_body_exited)

	interact_icon.visible = false

	# 5) Hook up DialogSystem
	_ensure_dialog_connection()

	# 6) Connect the button‐area "body_entered" callbacks
	left_button_area.body_entered.connect(_on_left_button_area_body_entered)
	right_button_area.body_entered.connect(_on_right_button_pressed)

	# 7) Create a one-shot Timer to revert the press texture after 0.6 s
	_press_timer = Timer.new()
	_press_timer.one_shot = true
	_press_timer.wait_time = 0.6
	_press_timer.autostart = false
	add_child(_press_timer)
	_press_timer.connect("timeout", Callable(self, "_on_press_timer_timeout"))
	
	


func _ensure_dialog_connection():
	if not has_node("/root/DialogSystem"):
		push_error("DialogSystem autoload not found! Make sure it's added in Project Settings.")
		return

	if not DialogSystem.has_signal("dialog_finished"):
		push_error("DialogSystem doesn't have a 'dialog_finished' signal!")
		return

	# Avoid double‐connecting
	var already_connected = false
	for conn in DialogSystem.get_signal_connection_list("dialog_finished"):
		if conn.callable.get_object() == self and conn.callable.get_method() == "_on_dialog_finished":
			already_connected = true
			break

	if not already_connected:
		print("Connecting firetruck controller to dialog system...")
		DialogSystem.connect("dialog_finished", Callable(self, "_on_dialog_finished"))
	else:
		print("Firetruck controller already connected to dialog system")


func _on_dialog_finished(finished_npc_id):
	# Called whenever ANY NPC finishes dialog.
	# We no longer do "dusty→clean" here; that happens in _process().
	if finished_npc_id != npc_id:
		return

	print("Firetruck controller received dialog_finished signal for npc_id:", finished_npc_id)
	is_in_dialog = false

	if player_nearby:
		interact_icon.visible = true
	else:
		interact_icon.visible = false

	in_cutscene = false

	# No direct dusty→clean swap here any more.
	# The swap will be triggered in _process() once fed_bedmite==true.


func have_spoken() -> bool:
	return story_manager.found_controller


func start_dialog():
	is_in_dialog = true
	interact_icon.visible = false

	if not has_node("/root/DialogSystem"):
		push_error("Cannot start dialog: DialogSystem not found!")
		return

	# Choose which set of lines based on story flags:
	if not have_spoken() and not story_manager.spoke_bedmite:
		DialogSystem.start_dialog({
			"name": npc_name,
			"lines": [
				"Something about this object calls to you.",
				"Unfortunately, it is absolutely caked with dust.",
				"It's a shame you don't like eating dust."
			],
			"name_color": name_color,
			"voice_sound_path": voice_sound_path
		}, npc_id)
		story_manager.found_controller = true

	elif not have_spoken() and story_manager.spoke_bedmite:
		DialogSystem.start_dialog({
			"name": npc_name,
			"lines": [
				"Something about this object calls to you.",
				"Unfortunately, it is absolutely caked with dust.",
				"Perhaps the dust mite would enjoy eating this."
			],
			"name_color": name_color,
			"voice_sound_path": voice_sound_path
		}, npc_id)
		story_manager.found_controller = true

	elif have_spoken() and not story_manager.spoke_bedmite:
		DialogSystem.start_dialog({
			"name": npc_name,
			"lines": [
				"Yup, it's still covered in dust.  Nasty."
			],
			"name_color": name_color,
			"voice_sound_path": voice_sound_path
		}, npc_id)
		story_manager.found_controller = true

	elif have_spoken() and story_manager.spoke_bedmite and not story_manager.fed_bedmite:
		DialogSystem.start_dialog({
			"name": npc_name,
			"lines": [
				"It's still covered in dust.",
				"Maybe the dust mite would like to clean it off?"
			],
			"name_color": name_color,
			"voice_sound_path": voice_sound_path
		}, npc_id)
		story_manager.found_controller = true

	elif have_spoken() and story_manager.fed_bedmite:
		DialogSystem.start_dialog({
			"name": npc_name,
			"lines": [
				"Squeaky clean!",
				"You feel a strange compulsion to jump on it now."
			],
			"name_color": name_color,
			"voice_sound_path": voice_sound_path
		}, npc_id)
		story_manager.found_controller = true


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


func _on_interaction_area_body_exited(body):
	if body is Player:
		player_nearby = false
		interact_icon.visible = false


# This function now tracks player position history instead of immediately triggering
func _on_left_button_area_body_entered(body: Node) -> void:
	if not _buttons_enabled or _is_moving:
		return
		
	if body is Player and _left_button_cooldown <= 0:
		var player_body = body as Player
		
		# Store velocity.y to make this consistent with right button
		if player_body.velocity.y > 0:
			_trigger_left_button(player_body)
			_left_button_cooldown = LEFT_BUTTON_COOLDOWN_DURATION
		elif player_body.velocity.y >= 0 and player_body.slow_falling:
			# Special case for slow-falling (holding jump button)
			_trigger_left_button(player_body)
			_left_button_cooldown = LEFT_BUTTON_COOLDOWN_DURATION


func _physics_process(delta):
	# Update the left button cooldown
	if _left_button_cooldown > 0:
		_left_button_cooldown -= delta
	
	# Track player position history for fast falls
	if player and _buttons_enabled and not _is_moving:
		# Check if player is in left button area but moving too fast
		var bodies = left_button_area.get_overlapping_bodies()
		if bodies.has(player) and _left_button_cooldown <= 0:
			var current_vel_y = player.velocity.y
			
			# If player is falling (even fast) through the button
			if current_vel_y > 50:  # Minimum downward speed threshold
				# Record that we triggered the button
				_trigger_left_button(player)
				_left_button_cooldown = LEFT_BUTTON_COOLDOWN_DURATION
	
	# Check if we need to restore player movement when firetruck stops
	if _player_movement_disabled and not _is_moving:
		_restore_player_movement()


func _process(delta):
	# 1) If player is nearby and presses "interact" (E or Space), start dialog
	if player_nearby and Input.is_action_just_pressed("interact") and not is_in_dialog:
		start_dialog()

	# 2) Once bedmite is fed, swap "dusty → clean" exactly once, then enable buttons.
	if story_manager.fed_bedmite and not _has_unlocked_buttons:
		_has_unlocked_buttons = true

		print("DEBUG: swapping dusty → clean (inside _process)")
		if controller_sprite:
			controller_sprite.texture = clean_texture
		else:
			push_error("⚠️ controller_sprite is null in _process() swap.")

		_enable_button_areas()
	
	# 3) Handle smooth firetruck movement if it's currently in motion
	if _is_moving and firetruck_node:
		# Store previous position before updating
		var previous_position = firetruck_node.position
		
		# Update time and calculate progress
		_move_time += delta
		var progress = min(_move_time / movement_duration, 1.0)
		
		# Use ease_in_out for smooth acceleration and deceleration
		var ease_progress = smoothstep(0.0, 1.0, progress)
		
		# Update firetruck position
		firetruck_node.position = _move_start_position.lerp(_move_target_position, ease_progress)
		
		# Calculate actual distance moved this frame
		var distance_moved = firetruck_node.position.x - previous_position.x
		
		# Only rotate wheels if the truck actually moved this frame
		if abs(distance_moved) > 0.001:  # Small threshold to avoid tiny movements
			# Calculate wheel rotation based on distance moved
			var rotation_amount = distance_moved / wheel_radius
			for wheel in wheel_nodes:
				wheel.rotation += rotation_amount
		
		# Check if movement is complete
		if progress >= 1.0:
			_is_moving = false
			
			# When truck stops moving, release the buttons
			if _active_button == "left":
				_release_left_button()
			elif _active_button == "right":
				_release_right_button()
				
			_active_button = ""
			
			# If camera is still focused on the truck after movement completes
			# and this was a first-time press demonstration, pan back to player
			if _first_button_press == false and in_cutscene:
				_pan_camera_to_player()
	
	# 4) Handle left button animation - only if manually animating release
	if _left_button_pressing and _left_button_node and _active_button != "left":
		_left_button_press_timer += delta
		var progress = min(_left_button_press_timer / button_press_duration, 1.0)
		
		if progress < 0.4:  # Press down phase (40% of total time)
			var press_progress = progress / 0.4
			_left_button_node.position = _left_button_original_position + Vector2(0, button_press_depth * press_progress)
		else:  # Release phase (60% of total time)
			var release_progress = (progress - 0.4) / 0.6
			_left_button_node.position = _left_button_original_position + Vector2(0, button_press_depth * (1.0 - release_progress))
		
		if progress >= 1.0:
			_left_button_pressing = false
			_left_button_node.position = _left_button_original_position
	
	# 5) Handle right button animation - only if manually animating release
	if _right_button_pressing and _right_button_node and _active_button != "right":
		_right_button_press_timer += delta
		var progress = min(_right_button_press_timer / button_press_duration, 1.0)
		
		if progress < 0.4:  # Press down phase
			var press_progress = progress / 0.4
			_right_button_node.position = _right_button_original_position + Vector2(0, button_press_depth * press_progress)
		else:  # Release phase
			var release_progress = (progress - 0.4) / 0.6
			_right_button_node.position = _right_button_original_position + Vector2(0, button_press_depth * (1.0 - release_progress))
		
		if progress >= 1.0:
			_right_button_pressing = false
			_right_button_node.position = _right_button_original_position


#
# ────────────────────────────────────────────────────────────────────────────────
#    BUTTON / FIRETRUCK LOGIC WITH CLAMP + PRESS ANIMATION
# ────────────────────────────────────────────────────────────────────────────────
#

func _enable_button_areas() -> void:
	if _buttons_enabled:
		return
	_buttons_enabled = true
	left_button_area.monitoring = true
	right_button_area.monitoring = true
	print("✅ ButtonAreas unlocked: player can now push the firetruck.")


func _on_right_button_pressed(body: Node) -> void:
	if not _buttons_enabled or _is_moving:
		return
	if body is Player:
		# Only if the Player is moving downward
		var pvel = (body as CharacterBody2D).velocity
		if pvel.y > 0:
			# If Player is also in the LEFT area simultaneously, cancel
			var left_bodies = left_button_area.get_overlapping_bodies()
			if left_bodies.has(body):
				return

			# Compute new candidate X and clamp it
			var desired_x = firetruck_node.position.x + (SHIFT_AMOUNT)
			var min_x = _firetruck_start_x + MAX_LEFT_OFFSET
			var max_x = _firetruck_start_x + MAX_RIGHT_OFFSET
			desired_x = clamp(desired_x, min_x, max_x)

			# Only apply if it actually changed
			if !is_equal_approx(desired_x, firetruck_node.position.x):
				# Disable player movement during button press
				_disable_player_movement()
				
				# Remember which button is active
				_active_button = "right"
				
				# Set up smooth movement
				_move_start_position = firetruck_node.position
				_move_target_position = Vector2(desired_x, firetruck_node.position.y)
				_move_time = 0.0
				_is_moving = true
				_move_direction = 1  # Moving right
				
				# Press the button down immediately
				_press_right_button()
				
				# For the first button press, pan the camera to show the firetruck
				if _first_button_press:
					_first_button_press = false
					_pan_camera_to_firetruck()
				
				print("Player fell into RIGHT button → Firetruck shifting right to X=", desired_x)

				# Change sprite to the right-press image:
				print("DEBUG: swapping clean → press_right")
				if controller_sprite:
					controller_sprite.texture = press_right_texture
				else:
					push_error("⚠️ controller_sprite is null in _on_right_button_pressed()")

				# Stop the press timer if it's running
				if not _press_timer.is_stopped():
					_press_timer.stop()
			else:
				# Already at the rightmost limit; do nothing
				pass


# Helper function to trigger the left button
func _trigger_left_button(body: Player) -> void:
	if not _buttons_enabled or _is_moving:
		return
		
	# Only apply if it actually changed
	var desired_x = firetruck_node.position.x + (-SHIFT_AMOUNT)
	var min_x = _firetruck_start_x + MAX_LEFT_OFFSET
	var max_x = _firetruck_start_x + MAX_RIGHT_OFFSET
	desired_x = clamp(desired_x, min_x, max_x)
	
	if !is_equal_approx(desired_x, firetruck_node.position.x):
		# Disable player movement during button press
		_disable_player_movement()
		
		# Remember which button is active
		_active_button = "left"
		
		# Set up smooth movement
		_move_start_position = firetruck_node.position
		_move_target_position = Vector2(desired_x, firetruck_node.position.y)
		_move_time = 0.0
		_is_moving = true
		_move_direction = -1  # Moving left
		
		# Press the button down immediately
		_press_left_button()
		
		# For the first button press, pan the camera to show the firetruck
		if _first_button_press:
			_first_button_press = false
			_pan_camera_to_firetruck()
		
		print("Player triggered LEFT button → Firetruck shifting left to X=", desired_x)

		# Change sprite to the left-press image:
		if controller_sprite:
			controller_sprite.texture = press_left_texture
		else:
			push_error("⚠️ controller_sprite is null in _trigger_left_button()")

		# Stop the press timer if it's running
		if not _press_timer.is_stopped():
			_press_timer.stop()


# Press the left button down immediately
func _press_left_button() -> void:
	if _left_button_node:
		_left_button_pressing = true
		_left_button_node.position = _left_button_original_position + Vector2(0, button_press_depth)


# Press the right button down immediately
func _press_right_button() -> void:
	if _right_button_node:
		_right_button_pressing = true
		_right_button_node.position = _right_button_original_position + Vector2(0, button_press_depth)


# Release the left button with animation
func _release_left_button() -> void:
	if _left_button_node:
		# Create tween for smooth button release
		var button_tween = create_tween()
		button_tween.set_ease(Tween.EASE_OUT)
		button_tween.set_trans(Tween.TRANS_SINE)
		
		# Tween button back to original position
		button_tween.tween_property(_left_button_node, "position", 
			_left_button_original_position, 0.3)
		
		_left_button_pressing = false
		
		# Reset controller sprite
		if controller_sprite:
			controller_sprite.texture = clean_texture
		
		# Start the press timer to ensure controller resets
		_press_timer.start()


# Release the right button with animation
func _release_right_button() -> void:
	if _right_button_node:
		# Create tween for smooth button release
		var button_tween = create_tween()
		button_tween.set_ease(Tween.EASE_OUT)
		button_tween.set_trans(Tween.TRANS_SINE)
		
		# Tween button back to original position
		button_tween.tween_property(_right_button_node, "position", 
			_right_button_original_position, 0.3)
		
		_right_button_pressing = false
		
		# Reset controller sprite
		if controller_sprite:
			controller_sprite.texture = clean_texture
		
		# Start the press timer to ensure controller resets
		_press_timer.start()


# Disable player movement during button press
func _disable_player_movement() -> void:
	if player and not _player_movement_disabled:
		_player_movement_disabled = true
		_need_to_restore_player_movement = true
		player.disable_player_input = true
		player.velocity = Vector2.ZERO  # Stop all movement
		print("Player movement disabled during button press")


# Restore player movement when button press animation completes
func _restore_player_movement() -> void:
	if player and _player_movement_disabled:
		_player_movement_disabled = false
		_need_to_restore_player_movement = false
		player.disable_player_input = false
		print("Player movement restored after button press")


# Update the _pan_camera_to_firetruck function
func _pan_camera_to_firetruck() -> void:
	# Get the main camera
	var camera = get_viewport().get_camera_2d()
	if not camera or not player:
		return
		
	# Store the original camera offset from player for later restoration
	_original_camera_offset = camera.global_position - player.global_position
	
	# Set cutscene flag
	in_cutscene = true
	
	# Temporarily disable player input
	if player and player.has_method("disable_input"):
		player.disable_input(true)
	elif player:
		player.disable_player_input = true
	
	# Create a tween to move the camera
	_camera_tween = create_tween()
	_camera_tween.set_ease(Tween.EASE_IN_OUT)
	_camera_tween.set_trans(Tween.TRANS_SINE)
	
	# Pan to the firetruck
	_camera_tween.tween_property(camera, "global_position", 
		firetruck_node.global_position, camera_pan_duration)
	
	# Add a pause to watch the truck move
	_camera_tween.tween_interval(pause_on_truck_duration)
	
	# The camera will pan back to the player after the truck finishes moving
	# This happens in the _process function when _is_moving becomes false


# Update the _pan_camera_to_player function to use the stored offset
func _pan_camera_to_player() -> void:
	# Get the main camera
	var camera = get_viewport().get_camera_2d()
	if not camera or not player:
		in_cutscene = false
		return
	
	# Create a tween to move back to the player with the original offset
	_camera_tween = create_tween()
	_camera_tween.set_ease(Tween.EASE_IN_OUT)
	_camera_tween.set_trans(Tween.TRANS_SINE)
	
	# Pan back to the player's position plus the original offset
	_camera_tween.tween_property(camera, "global_position", 
		player.global_position + _original_camera_offset, camera_pan_duration)
	
	# Re-enable player input when done
	_camera_tween.tween_callback(func():
		in_cutscene = false
		if player and player.has_method("disable_input"):
			player.disable_input(false)
		elif player:
			player.disable_player_input = false
	)


func _on_press_timer_timeout() -> void:
	# After 0.6 s, revert from "press" texture back to the normal clean look.
	# This is now only used for controller sprite resets
	print("DEBUG: _on_press_timer_timeout() → swapping press_* → clean")
	if controller_sprite:
		controller_sprite.texture = clean_texture
	else:
		push_error("⚠️ controller_sprite is null in _on_press_timer_timeout()")
