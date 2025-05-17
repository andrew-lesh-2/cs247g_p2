extends CharacterBody2D

# — ACTION NAMES —  
@export var jump_action     : String = "jump"
@export var interact_action : String = "interact"

# — MOVEMENT TUNING —  
const SPEED               = 50.0
const JUMP_VELOCITY       = -250.0
const WALL_SLIDE_SPEED    = 30.0
const WALL_JUMP_H_SPEED   = 200.0
const WALL_JUMP_LOCK_TIME = 0.15   # seconds to ignore input after wall‐jump

# — GRAVITY —  
var gravity           = ProjectSettings.get_setting("physics/2d/default_gravity")
var default_gravity   = gravity
var slow_fall_gravity = default_gravity * 0.2

# — DOUBLE JUMP & COYOTE TIME —  
var has_double_jumped = false
var coyote_time       = 0.1
var coyote_timer      = 0.0

# — WALL‐JUMP INPUT LOCK —  
var wall_jump_lock_timer = 0.0

# — DIALOG PAUSE —  
var can_move = true

# — JUMP SOUND —  
@onready var jump_sound_player = AudioStreamPlayer.new()
@export var jump_sound_path              : String = "res://audio/effects/bounce.wav"
@export_range(0.0, 1.0) var jump_sound_volume  : float  = 0.5
@export_range(0.5, 2.0) var jump_sound_pitch   : float  = 1.0
@export var play_sound_for_double_jump : bool   = true

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

func _physics_process(delta):
	# — tick down the wall‐jump input lock —
	wall_jump_lock_timer = max(0.0, wall_jump_lock_timer - delta)

	# — pause during dialog —
	if not can_move:
		$AnimatedSprite2D.play("idle")
		return

	# — floor vs air & coyote‐time —
	var on_floor = is_on_floor()
	if on_floor:
		has_double_jumped = false
		coyote_timer = 0.0
	else:
		coyote_timer += delta

	# — detect wall by slide collisions —
	var on_wall  = false
	var wall_dir = 0.0
	if not on_floor:
		for i in range(get_slide_collision_count()):
			var col = get_slide_collision(i)
			var nx = col.get_normal().x
			if abs(nx) > 0.7:
				on_wall  = true
				wall_dir = nx
				break

	# — apply gravity or wall‐slide —
	if not on_floor:
		if on_wall and velocity.y > 0:
			velocity.y = min(velocity.y + gravity * delta, WALL_SLIDE_SPEED)
			# reset jump so you can wall‐jump again
			has_double_jumped = false
			coyote_timer = coyote_time
		elif velocity.y > 0 and _is_jump_pressed():
			velocity.y += slow_fall_gravity * delta
		else:
			velocity.y += default_gravity * delta

	# — handle jumping / wall‐jump / double‐jump —
	if _is_jump_just_pressed():
		if on_floor or coyote_timer < coyote_time:
			# normal jump
			velocity.y = JUMP_VELOCITY
			coyote_timer = coyote_time
			play_jump_sound(false)
		elif on_wall:
			# wall‐jump: blast off the wall
			velocity.y = JUMP_VELOCITY
			velocity.x = wall_dir * WALL_JUMP_H_SPEED
			wall_jump_lock_timer = WALL_JUMP_LOCK_TIME
			play_jump_sound(false)
		elif not has_double_jumped:
			# double jump
			velocity.y = JUMP_VELOCITY * 0.8
			has_double_jumped = true
			play_jump_sound(true)

	# — horizontal movement & animations —
	if wall_jump_lock_timer <= 0.0:
		var dir = Input.get_axis("ui_left", "ui_right")
		if dir != 0:
			velocity.x = dir * SPEED
			$AnimatedSprite2D.flip_h = dir < 0
			if on_floor:
				$AnimatedSprite2D.play("walk")
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			if on_floor:
				$AnimatedSprite2D.play("idle")
	else:
		# during the lock, preserve your wall‐jump burst
		if on_floor and abs(velocity.x) < 1.0:
			$AnimatedSprite2D.play("idle")

	if not on_floor:
		$AnimatedSprite2D.play("jump")

	move_and_slide()

# — helpers to keep ui_accept free for dialogue —
func _is_jump_pressed() -> bool:
	return Input.is_action_pressed(jump_action) or (can_move and Input.is_action_pressed("ui_accept"))

func _is_jump_just_pressed() -> bool:
	return	Input.is_action_just_pressed(jump_action) \
		or (can_move and Input.is_action_just_pressed("ui_accept"))

func _on_dialog_started(_npc_id):
	can_move = false
	velocity = Vector2.ZERO

func _on_dialog_finished(_npc_id):
	can_move = true
