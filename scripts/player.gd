extends CharacterBody2D

class_name Player

@export var god_mode: bool = false

@onready var particles = $GPUParticles2D

@export var disable_player_input: bool = false

@export var virtual_dir: Vector2 = Vector2.ZERO
var reset_virtual_dir: bool = false
@export var virtual_jump_pressed: bool = false
@export var prev_virtual_jump_pressed: bool = false

# — ACTION NAMES —
@export var jump_action     : String = "jump"
@export var interact_action : String = "interact"

# — MOVEMENT TUNING —
@export var SPEED               = 50.0
@export var JUMP_VELOCITY       = -250.0
@export var WALL_SLIDE_SPEED    = 30.0
@export var WALL_JUMP_H_SPEED   = 300.0
@export var WALL_JUMP_Y_DEBUFF = 0.85
@export var WALL_JUMP_LOCK_TIME = 0.15   # seconds to ignore input after wall‐jump

# — WALL‐SLIDE DURATION —
@export var wall_slide_duration : float = 1  # how long to slide before normal gravity
var wall_slide_timer : float = 0.0
var was_on_wall      : bool  = false

# — GRAVITY —
var gravity           = ProjectSettings.get_setting("physics/2d/default_gravity")
var default_gravity   = gravity
var slow_fall_gravity = default_gravity * 0.2

# — DOUBLE JUMP & COYOTE TIME —
var has_double_jumped = false
var is_wall_jumping = false
var coyote_time       = 0.1
var coyote_timer      = 0.0

# — WALL‐JUMP INPUT LOCK —
var wall_jump_lock_timer = 0.0
var last_wall_jump_dir = 0.0  # Track last wall jump direction

# — SPRITE OFFSET —
var sprite_offset_right = Vector2(4, 0)  # Adjust these values to fine-tune the offset
var sprite_offset_left = Vector2(-2, 0)  # Adjust these values to fine-tune the offset

var particles_offset_right = Vector2(4, 0)
var particles_offset_left = Vector2(-12, 0)
var was_on_floor = false
# — DIALOG PAUSE —
var can_move = true
# — JUMP SOUND —
@onready var jump_sound_player = AudioStreamPlayer.new()
@export var jump_sound_path              : String = "res://audio/effects/bounce.wav"
@export_range(0.0, 1.0) var jump_sound_volume  : float  = 0.5
@export_range(0.5, 2.0) var jump_sound_pitch   : float  = 1.0
@export var play_sound_for_double_jump : bool   = true

const ROTATE_TIME = 0.1

func _ready():
	add_to_group("player")
	if has_node("/root/DialogSystem"):
		DialogSystem.connect("dialog_started",  Callable(self, "_on_dialog_started"))
		DialogSystem.connect("dialog_finished", Callable(self, "_on_dialog_finished"))
	setup_jump_sound()

func setup_jump_sound():
	add_child(jump_sound_player)
	jump_sound_player.volume_db   = linear_to_db(jump_sound_volume)
	jump_sound_player.pitch_scale = jump_sound_pitch
	if ResourceLoader.exists(jump_sound_path):
		jump_sound_player.stream = load(jump_sound_path)
	else:
		push_error("Failed to load jump sound at: " + jump_sound_path)

func play_jump_sound(is_double_jump: bool = false):
	if not jump_sound_player.stream:
		return
	jump_sound_player.stop()
	if is_double_jump and play_sound_for_double_jump:
		jump_sound_player.pitch_scale = jump_sound_pitch * 1.2
	else:
		jump_sound_player.pitch_scale = jump_sound_pitch
	jump_sound_player.play()

var slow_falling = false
var rotate_timer = 0.0

func _physics_process(delta):
	# — tick down the wall‐jump input lock —

	var input_result = _handle_input()
	var dir = input_result[0]
	var is_jump_pressed = input_result[1]
	var is_jump_just_pressed = input_result[2]

	rotate_timer = max(0.0, rotate_timer - delta)


	wall_jump_lock_timer = max(0.0, wall_jump_lock_timer - delta)

	# — pause during dialog —
	if not can_move:
		$AnimatedSprite2D.play("idle")
		return

	# — floor vs air & coyote‐time —
	var on_floor = is_on_floor()
	if on_floor:
		has_double_jumped  = false
		is_wall_jumping = false
		coyote_timer       = 0.0
		last_wall_jump_dir = 0.0  # Reset last wall jump direction when touching ground
	else:
		coyote_timer += delta

	# — detect wall by slide collisions —
	var on_wall  = false
	var wall_dir = 0.0
	if not on_floor:
		for i in range(get_slide_collision_count()):
			var col = get_slide_collision(i)
			var nx  = col.get_normal().x
			if abs(nx) > 0.7 and dir != 0:
				on_wall  = true
				wall_dir = 1 if nx > 0 else -1
			break

	# — reset or advance wall-slide timer —
	if on_wall:
		# just began touching?
		if not was_on_wall:
			wall_slide_timer = 0.0
		was_on_wall = true
	else:
		was_on_wall      = false
		wall_slide_timer = 0.0

	# — apply gravity, wall‐slide (limited time), or slow-fall —
	if not on_floor:
		# if we still have remaining slide‐time and are sliding down
		if on_wall and velocity.y > 0 and wall_slide_timer < wall_slide_duration:
			velocity.y = min(velocity.y + gravity * delta, WALL_SLIDE_SPEED)
			wall_slide_timer += delta
			# reset jump so you can wall‐jump again
			coyote_timer      = coyote_time
			slow_falling = false
		elif ((velocity.y > 0 or slow_falling) and
			is_jump_pressed and
			not is_jump_just_pressed):
			# slow‐fall if holding jump
			if god_mode:
				velocity.y += -100 * delta
			else:
				velocity.y += slow_fall_gravity * delta
			slow_falling = true
		else:
			# normal gravity
			velocity.y += default_gravity * delta
			slow_falling = false
	else:
		slow_falling = false

	# — handle jumping / wall‐jump / double‐jump —
	if is_jump_just_pressed:
		if on_floor or coyote_timer < coyote_time:
			velocity.y       = JUMP_VELOCITY
			coyote_timer     = coyote_time
			play_jump_sound(false)
			#(not has_double_jumped or is_wall_jumping)
		elif on_wall and wall_dir != last_wall_jump_dir:
			is_wall_jumping = true
			velocity.y          = WALL_JUMP_Y_DEBUFF * JUMP_VELOCITY
			velocity.x          = wall_dir * WALL_JUMP_H_SPEED
			wall_jump_lock_timer = WALL_JUMP_LOCK_TIME
			last_wall_jump_dir   = wall_dir  # Store the direction of this wall jump
			#has_double_jumped = true
			play_jump_sound(false)
		elif not has_double_jumped:
			velocity.y        = JUMP_VELOCITY * 0.8
			has_double_jumped = true
			play_jump_sound(true)

	# — horizontal movement & animations —
	if wall_jump_lock_timer <= 0.0:
		if dir != 0:
			if on_floor:
				var normal = get_floor_normal()
				var tangent = Vector2(normal.y, -normal.x)
				velocity = -1 * tangent * (dir * SPEED) + normal * velocity.dot(normal)
				$AnimatedSprite2D.play("walk")
			else:
				velocity.x = dir * SPEED

			$AnimatedSprite2D.flip_h = dir < 0
		else:
			if on_floor:
				# Project velocity onto normal to stop horizontal movement
				var normal = get_floor_normal()
				velocity = normal * velocity.dot(normal)
				$AnimatedSprite2D.play("idle")
	else:
		# during the lock, preserve your wall‐jump burst
		if on_floor and abs(velocity.x) < 1.0:
			$AnimatedSprite2D.play("idle")

	# Handle wall rotation and sprite position
	if on_wall and velocity.y > 0:
		$AnimatedSprite2D.rotation_degrees = 90 * wall_dir
		particles.emitting = true
		# Offset sprite in the direction of the wall
		if wall_dir == -1:
			$AnimatedSprite2D.position = sprite_offset_right

			particles.position = particles_offset_right
			particles.rotation = 180
		else:
			$AnimatedSprite2D.position = sprite_offset_left
			particles.position = particles_offset_left
			particles.rotation = 0
	elif not on_floor:
		particles.emitting = false
		$AnimatedSprite2D.rotation_degrees = 0

	else:
		particles.emitting = false
		$AnimatedSprite2D.rotation_degrees = 0
		# Reset sprite position
		$AnimatedSprite2D.position = Vector2.ZERO

	if not on_floor:
		if slow_falling and not is_jump_just_pressed:
			$AnimatedSprite2D.play("fly")
		else:
			$AnimatedSprite2D.play("jump")

	move_and_slide()

	if is_on_floor() and rotate_timer == 0.0 and (dir != 0 or not was_on_floor):
		var normal = get_floor_normal()
		rotate_timer = ROTATE_TIME
		# For a flat floor, normal is usually (0, -1)
		# You can use this to rotate your sprite:
		rotation = normal.angle() + PI/2
	elif rotate_timer == 0.0 and dir != 0:
		rotate_timer = ROTATE_TIME
		rotation = 0

	was_on_floor = is_on_floor()

func _handle_input():
	if disable_player_input:
		var out = [virtual_dir.x, virtual_jump_pressed, virtual_jump_pressed and not prev_virtual_jump_pressed]
		prev_virtual_jump_pressed = virtual_jump_pressed
		virtual_jump_pressed = false
		if reset_virtual_dir:
			virtual_dir = Vector2.ZERO
			reset_virtual_dir = false
		return out

	var dir = Input.get_axis("ui_left", "ui_right")
	var is_jump_pressed = _is_jump_pressed()
	var is_jump_just_pressed = _is_jump_just_pressed()

	return [dir, is_jump_pressed, is_jump_just_pressed]

func input_virtual_dir(dir: Vector2):
	virtual_dir = dir


func input_virtual_dir_pulse(dir: Vector2):
	virtual_dir = dir
	reset_virtual_dir = true

func input_virtual_jump():
	virtual_jump_pressed = true
# — helpers to keep ui_accept free for dialogue —
func _is_jump_pressed() -> bool:
	return Input.is_action_pressed(jump_action) or (can_move and Input.is_action_pressed("ui_accept"))

func _is_jump_just_pressed() -> bool:
	return	Input.is_action_just_pressed(jump_action) \
		or (can_move and Input.is_action_just_pressed("ui_accept"))

func _on_dialog_started(_npc_id):
	can_move = false
	velocity  = Vector2.ZERO

func _on_dialog_finished(_npc_id):
	can_move = true
