# controller_npc.gd
extends Node2D

# — NPC IDENTIFIERS & DIALOG TUNING — 
var timer: Timer

var npc_id       = "controller"
var npc_name     = ""
var name_color   = Color(1, 0.8, 0.1)
var voice_sound_path: String = "res://audio/voices/voice_Papyrus.wav"

var last_exited_body: Player = null

# You already have these exported NodePaths for your button areas:
@export var left_button_area_path  : NodePath = "ButtonAreas/LeftButtonArea"
@export var right_button_area_path : NodePath = "ButtonAreas/RightButtonArea"

@onready var story_manager       = StoryManager                                                # assume StoryManager is the parent
@onready var interact_icon       = $interact_icon
@onready var controller_node     = $Controller
@onready var controller_sprite   = $Controller/"Controller Sprite"  as Sprite2D
@onready var interaction_area    = $InteractionArea                                             # unchanged
@onready var left_button_area    = get_node(left_button_area_path)  as Area2D
@onready var right_button_area   = get_node(right_button_area_path) as Area2D
var _buttons_enabled: bool = false

# — FIRETRUCK REFERENCE & POSITION CLAMPING — 
@export var firetruck_path : NodePath = "../../firetruck"
@onready var firetruck_node  = get_node(firetruck_path) as Node2D

var _firetruck_start_x: float = 0.0

const SHIFT_AMOUNT     := 20.0
const MAX_RIGHT_OFFSET :=  1 * SHIFT_AMOUNT    # +20 px from start
const MAX_LEFT_OFFSET  := -15 * SHIFT_AMOUNT   # –300 px from start

# — PRELOADED TEXTURES — 
@export var clean_texture       : Texture2D = preload("res://assets/sprites/environment/controller.png")
@export var dusty_texture       : Texture2D = preload("res://assets/sprites/environment/controller_dirty.png")
@export var press_left_texture  : Texture2D = preload("res://assets/sprites/environment/controller_up.png")
@export var press_right_texture : Texture2D = preload("res://assets/sprites/environment/controller_down.png")

# A Timer we’ll use to revert the sprite back after 0.6 s
var _press_timer: Timer

# — OTHER FLAGS — 
var in_cutscene: bool    = false
var player_nearby: bool = false
var player: Player      = null

var is_in_dialog: bool  = false

# — INTERNAL FLAG TO ENSURE “DUSTY→CLEAN” ONLY RUNS ONCE — 
var _has_unlocked_buttons: bool = false


func _ready():
	# 1) Record the starting X of the firetruck so we can clamp its movement later
	if firetruck_node:
		_firetruck_start_x = firetruck_node.position.x
	else:
		push_error("⚠️ controller_npc.gd: firetruck_node is null (check firetruck_path).")

	# 2) Immediately show the “dusty” texture (since it hasn’t been fed yet)
	if controller_sprite:
		print("DEBUG: _ready() → setting dusty_texture")
		controller_sprite.texture = dusty_texture
	else:
		push_error("⚠️ controller_sprite is null in _ready().")

	# 3) Disable both button areas until we explicitly unlock them
	_buttons_enabled = false
	left_button_area.monitoring  = false
	right_button_area.monitoring = false

	# 4) Connect interaction‐area signals (so we can show/hide the “Press E” icon)
	interaction_area.body_entered.connect(_on_interaction_area_body_entered)
	interaction_area.body_exited.connect(_on_interaction_area_body_exited)

	interact_icon.visible = false

	# 5) Hook up DialogSystem
	_ensure_dialog_connection()

	# 6) Connect the button‐area “body_entered” callbacks
	left_button_area.body_entered.connect(_on_left_button_pressed)
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
	# We no longer do “dusty→clean” here; that happens in _process().
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


func _process(delta):
	# 1) If player is nearby and presses “interact” (E or Space), start dialog
	if player_nearby and Input.is_action_just_pressed("interact") and not is_in_dialog:
		start_dialog()

	# 2) Once bedmite is fed, swap “dusty → clean” exactly once, then enable buttons.
	if story_manager.fed_bedmite and not _has_unlocked_buttons:
		_has_unlocked_buttons = true

		print("DEBUG: swapping dusty → clean (inside _process)")
		if controller_sprite:
			controller_sprite.texture = clean_texture
		else:
			push_error("⚠️ controller_sprite is null in _process() swap.")

		_enable_button_areas()


#
# ────────────────────────────────────────────────────────────────────────────────
#    BUTTON / FIRETRUCK LOGIC WITH CLAMP + PRESS ANIMATION
# ────────────────────────────────────────────────────────────────────────────────
#

func _enable_button_areas() -> void:
	if _buttons_enabled:
		return
	_buttons_enabled = true
	left_button_area.monitoring  = true
	right_button_area.monitoring = true
	print("✅ ButtonAreas unlocked: player can now push the firetruck.")


func _on_left_button_pressed(body: Node) -> void:
	if not _buttons_enabled:
		return
	if body is Player:
		# Only if the Player is moving downward
		var pvel = (body as CharacterBody2D).velocity
		if pvel.y > 0:
			# If Player is also in the RIGHT area simultaneously, cancel
			var right_bodies = right_button_area.get_overlapping_bodies()
			if right_bodies.has(body):
				return

			# Compute new candidate X and clamp it
			var desired_x = firetruck_node.position.x + (-SHIFT_AMOUNT)
			var min_x = _firetruck_start_x + MAX_LEFT_OFFSET
			var max_x = _firetruck_start_x + MAX_RIGHT_OFFSET
			desired_x = clamp(desired_x, min_x, max_x)

			# Only apply if it actually changed
			if !is_equal_approx(desired_x, firetruck_node.position.x):
				firetruck_node.position.x = desired_x
				print("Player fell into LEFT button → Firetruck shifted left to X=", desired_x)

				# Change sprite to the left-press image:
				print("DEBUG: swapping clean → press_left")
				if controller_sprite:
					controller_sprite.texture = press_left_texture
				else:
					push_error("⚠️ controller_sprite is null in _on_left_button_pressed()")

				# Restart the 0.6 s timer that will revert to “clean” texture:
				if not _press_timer.is_stopped():
					_press_timer.stop()
				_press_timer.start()
			else:
				# Already at the leftmost limit; do nothing
				pass


func _on_right_button_pressed(body: Node) -> void:
	if not _buttons_enabled:
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
				firetruck_node.position.x = desired_x
				print("Player fell into RIGHT button → Firetruck shifted right to X=", desired_x)

				# Change sprite to the right-press image:
				print("DEBUG: swapping clean → press_right")
				if controller_sprite:
					controller_sprite.texture = press_right_texture
				else:
					push_error("⚠️ controller_sprite is null in _on_right_button_pressed()")

				# Restart the 0.6 s timer that will revert to “clean” texture:
				if not _press_timer.is_stopped():
					_press_timer.stop()
				_press_timer.start()
			else:
				# Already at the rightmost limit; do nothing
				pass


func _on_press_timer_timeout() -> void:
	# After 0.6 s, revert from “press” texture back to the normal clean look.
	# (By this point, story_manager.fed_bedmite must be true, so “clean_texture” is correct.)
	print("DEBUG: _on_press_timer_timeout() → swapping press_* → clean")
	if controller_sprite:
		controller_sprite.texture = clean_texture
	else:
		push_error("⚠️ controller_sprite is null in _on_press_timer_timeout()")
