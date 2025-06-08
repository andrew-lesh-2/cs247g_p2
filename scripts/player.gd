# Player.gd
extends CharacterBody2D

class_name Player

@export var god_mode: bool = false

@onready var particles = $GPUParticles2D

@export var disable_player_input: bool = false

@export var virtual_dir: Vector2 = Vector2.ZERO
var reset_virtual_dir: bool = false
@export var virtual_jump_pressed: bool = false
var prev_virtual_jump_pressed: bool = false

# — ACTION NAMES —
@export var jump_action     : String = "jump"
@export var interact_action : String = "interact"

# — MOVEMENT TUNING —
@export var SPEED               = 150.0
@export var JUMP_VELOCITY       = -350.0
@export var WALL_SLIDE_SPEED    = 30.0
@export var WALL_JUMP_H_SPEED   = 300.0
@export var WALL_JUMP_Y_DEBUFF  = 0.85
@export var WALL_JUMP_LOCK_TIME = 0.15   # seconds to ignore input after wall‐jump

# — WALL‐SLIDE DURATION —
@export var wall_slide_duration : float = 1   # how long to slide before normal gravity
var wall_slide_timer : float = 0.0
var was_on_wall      : bool  = false
var was_on_floor     : bool  = false
const ROTATE_TIME = 0.1
var rotate_timer = 0.0
var last_position = Vector2.ZERO

# — GRAVITY —
var gravity           = ProjectSettings.get_setting("physics/2d/default_gravity")
var default_gravity   = gravity
var slow_fall_gravity = default_gravity * 0.2

# — DOUBLE JUMP & COYOTE TIME —
var has_double_jumped = false
var is_wall_jumping   = false
var coyote_time       = 0.1
var coyote_timer      = 0.0

# — WALL‐JUMP INPUT LOCK —
var wall_jump_lock_timer = 0.0
var last_wall_jump_dir   = 0.0  # Track last wall jump direction

# — SPRITE OFFSET —
var sprite_offset_right    = Vector2(4,  0)   # Adjust these values to fine‐tune the offset
var sprite_offset_left     = Vector2(-2, 0)   # Adjust these values to fine‐tune the offset

var particles_offset_right = Vector2(4,  0)
var particles_offset_left  = Vector2(-12, 0)

# — DIALOG PAUSE —
var can_move = true
var target_angle = 0.0

# — JUMP SOUND —
@onready var jump_sound_player = AudioStreamPlayer.new()
@export var jump_sound_path               : String  = "res://audio/effects/bounce.wav"
@export_range(0.0, 1.0)  var jump_sound_volume : float   = 0.5
@export_range(0.5, 2.0)  var jump_sound_pitch  : float   = 1.0
@export var play_sound_for_double_jump    : bool    = true

# — RIGIDBODY PUSH SETTINGS — (Added from old script)
@export var PUSH_FACTOR: float = 2.0  # Increased from 0.5 for better pushing
@export var MIN_PUSH_SPEED: float = 50.0  # Minimum push force even when standing still
@export var SNAP_LOCK_TIME: float = 0.3

@export var normals_enabled = true

# Toggle for velocity arrow
@export var show_velocity_arrow: bool = false
# Toggle for collider shape rendering
@export var show_collider_shape: bool = false

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

var impulse_vector = Vector2.ZERO
var jump_timer = 0.0
var jumping = false

func _physics_process(delta):
	# — tick down the wall‐jump input lock —
	var input_result = _handle_input()
	var dir = input_result[0]
	var is_jump_pressed = input_result[1]
	var is_jump_just_pressed = input_result[2]
	var player_has_input = (dir != 0) or is_jump_pressed

	rotate_timer = max(0.0, rotate_timer - delta)
	jump_timer = max(0.0, jump_timer - delta)
	wall_jump_lock_timer = max(0.0, wall_jump_lock_timer - delta)

	# — pause during dialog —
	if not can_move:
		$AnimatedSprite2D.play("idle")
		return

	# — floor vs air & coyote‐time —
	var on_floor = is_on_floor()

	if on_floor:
		has_double_jumped  = false
		is_wall_jumping    = false
		coyote_timer       = 0.0
		last_wall_jump_dir = 0.0  # Reset last wall jump direction when on ground
		if jump_timer == 0:
			jumping = false
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

	# — reset or advance wall‐slide timer —
	if on_wall:
		# just began touching?
		if not was_on_wall:
			wall_slide_timer = 0.0
		was_on_wall = true
	else:
		was_on_wall       = false
		wall_slide_timer  = 0.0

	# — apply gravity, wall‐slide (limited time), or slow‐fall —
	if not on_floor:
		# if we still have remaining slide‐time and are sliding down
		if on_wall and velocity.y > 0 and wall_slide_timer < wall_slide_duration:
			velocity.y = min(velocity.y + gravity * delta, WALL_SLIDE_SPEED)
			wall_slide_timer += delta
			# reset jump so you can wall‐jump again
			coyote_timer      = coyote_time
			slow_falling      = false
		elif ((velocity.y > 0 or slow_falling)
			and is_jump_pressed
			and not is_jump_just_pressed):
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
			jump_timer = SNAP_LOCK_TIME
			jumping = true
			velocity = -Vector2.UP * JUMP_VELOCITY  # Unchanged from original
			coyote_timer = coyote_time
			play_jump_sound(false)
		elif on_wall and wall_dir != last_wall_jump_dir:
			jump_timer = SNAP_LOCK_TIME
			jumping = true
			is_wall_jumping    = true
			velocity.y         = WALL_JUMP_Y_DEBUFF * JUMP_VELOCITY
			velocity.x         = wall_dir * WALL_JUMP_H_SPEED
			wall_jump_lock_timer = WALL_JUMP_LOCK_TIME
			last_wall_jump_dir   = wall_dir  # Store direction of this wall jump
			play_jump_sound(false)
		elif not has_double_jumped:
			jump_timer = SNAP_LOCK_TIME
			jumping = true
			velocity.y        = JUMP_VELOCITY * 0.8
			has_double_jumped = true
			play_jump_sound(true)

	# — horizontal movement & animations —
	if wall_jump_lock_timer <= 0.0:
		if dir != 0:
			velocity.x = dir * SPEED
			$AnimatedSprite2D.flip_h  = dir < 0
			if on_floor:
				$AnimatedSprite2D.play("walk")
		else:
			impulse_vector = Vector2.ZERO
			velocity.x = move_toward(velocity.x, 0, SPEED)
			if on_floor:
				$AnimatedSprite2D.play("idle")
	else:
		# during the lock, preserve your wall‐jump burst
		if on_floor and abs(velocity.x) < 1.0:
			$AnimatedSprite2D.play("idle")

	# Handle wall rotation and sprite position
	if on_wall and velocity.y > 0:
		$AnimatedSprite2D.rotation_degrees = (90 - (180 * rotation / PI)) * wall_dir
		particles.emitting = true
		# Offset sprite in the direction of the wall
		if wall_dir == -1:
			$AnimatedSprite2D.position = sprite_offset_right
			particles.position        = particles_offset_right
			particles.rotation        = 180
		else:
			$AnimatedSprite2D.position = sprite_offset_left
			particles.position        = particles_offset_left
			particles.rotation        = 0
	elif not on_floor:
		particles.emitting = false
		$AnimatedSprite2D.rotation_degrees = 0
	else:
		particles.emitting        = false
		$AnimatedSprite2D.rotation_degrees = 0
		# Reset sprite position
		$AnimatedSprite2D.position = Vector2.ZERO

	if not on_floor:
		if normals_enabled:
			if not jumping and not on_wall and not is_on_ceiling():
				apply_floor_snap()
		if slow_falling and not is_jump_just_pressed:
			$AnimatedSprite2D.play("fly")
		else:
			$AnimatedSprite2D.play("jump")

	if normals_enabled:
		if is_on_floor() and (player_has_input or not was_on_floor):
			var angle = get_floor_angle()
			var normal = get_floor_normal()

			# For a flat floor, normal is usually (0, -1)
			# You can use this to rotate your sprite:
			if angle < PI / 5:
				target_angle = 0


			if normal.x > 0:
				angle = angle
			else:
				angle = -angle

			target_angle = angle

		else:
			target_angle = 0

		rotation = move_toward(rotation, target_angle, .2)

	was_on_floor = is_on_floor()

	# ------------------------------------------------------
	#  This actually moves the CharacterBody2D with physics
	# ------------------------------------------------------
	move_and_slide()

	# ------------------------------------------------------
	#  IMMEDIATELY AFTER move_and_slide(), look for any RigidBody2D collisions
	#  and give them a push so they will actually roll.
	# ------------------------------------------------------
	for i in range(get_slide_collision_count()):
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider is RigidBody2D:
			var rb = collider as RigidBody2D

			# Calculate direction from player to rigidbody
			var push_direction = (rb.global_position - global_position).normalized()

			# Get player's speed, with a minimum value to ensure pushing works even when stationary
			var speed = max(abs(velocity.x), MIN_PUSH_SPEED)

			# Create push vector with primarily horizontal force but some vertical component
			# This makes the pushing more natural and helps objects move up slopes
			var push_vector = Vector2(
				push_direction.x * speed * PUSH_FACTOR * rb.mass,
				push_direction.y * speed * 0.5 * rb.mass
			)

			# Apply impulse at contact point for more natural physics
			var contact_point = col.get_position() - rb.global_position
			rb.apply_impulse(push_vector, contact_point)

			# For very lightweight objects, add a central impulse as well
			if rb.mass < 1.0:
				rb.apply_central_impulse(push_vector * 0.5)

	queue_redraw() # Ensure _draw is called every frame

func _handle_input():
	if disable_player_input:
		var out = [
			virtual_dir.x,
			virtual_jump_pressed,
			virtual_jump_pressed and not prev_virtual_jump_pressed
		]
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
	return Input.is_action_just_pressed(jump_action) \
		or (can_move and Input.is_action_just_pressed("ui_accept"))

func _on_dialog_started(_npc_id):
	can_move = false
	velocity  = Vector2.ZERO

func _on_dialog_finished(_npc_id):
	can_move = true

func _draw():
	if show_velocity_arrow and impulse_vector.length() > 1.0:
		var arrow_color = Color(0.2, 0.4, 1.0, 0.8)
		var start = Vector2.ZERO
		var scale = 0.4 # Adjust for visual size
		var end = (impulse_vector.rotated(-rotation)) * scale
		# Draw main line
		draw_line(start, end, arrow_color, 3.0)
		# Draw arrowhead
		var arrow_len = 18.0
		var arrow_angle = 0.5
		var dir = (end - start).normalized()
		var left = end - dir.rotated(arrow_angle) * arrow_len
		var right = end - dir.rotated(-arrow_angle) * arrow_len
		draw_polygon([end, left, right], [arrow_color])

	if show_collider_shape:
		var collider = $CollisionShape2D if has_node("CollisionShape2D") else null
		if collider and collider.shape:
			var shape = collider.shape
			var col_pos = collider.position
			var col_rot = collider.rotation
			var col_color = Color(0.2, 1.0, 0.2, 0.4)

			# Approximate with two circles and a rect
			var r = shape.radius
			var h = shape.height - (2 * r)
			var up = Vector2.UP.rotated(col_rot)
			var down = Vector2.DOWN.rotated(col_rot)
			var center = col_pos
			var top = center + up * h/2
			var bottom = center + down * h/2
			draw_circle(top, r, col_color)
			draw_circle(bottom, r, col_color)
			# Draw the body as a rect
			var rect_center = center
			var rect_size = Vector2(h, r*2)
			draw_rect(Rect2(rect_center - Vector2(r, h/2), rect_size), col_color, true, col_rot)
