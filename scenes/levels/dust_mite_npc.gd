# dust_mite_npc.gd
extends Node2D

var timer: Timer

var last_exited_body: Player = null

@onready var story_manager = StoryManager
@onready var interact_icon    = $interact_icon
@onready var dust_mite_sprite : AnimatedSprite2D = $"Dust Mite/Dust Mite Sprite"
@onready var interaction_area = $InteractionArea

@onready var dialog = get_parent().get_parent().get_parent().get_node('Dialog')

var in_cutscene: bool = false
var player_nearby: bool = false
var player: Player = null

var is_in_dialog: bool = false

# Make sure we only depart once
var _has_departed: bool = false

var just_dialoged: bool = false

func _ready():
	interaction_area.body_entered.connect(_on_interaction_area_body_entered)
	interaction_area.body_exited.connect(_on_interaction_area_body_exited)

	interact_icon.visible = false

func _on_dialog_finished():
	is_in_dialog = false
	# Restore the interact icon if the player is still nearby
	interact_icon.visible = player_nearby
	in_cutscene = false

	# *** NEW: If we have already fed the bedmite, depart now (once only) ***
	if story_manager.fed_bedmite and not _has_departed:
		_has_departed = true
		_depart_dust_mite()


func have_spoken() -> bool:
	return story_manager.spoke_bedmite


func start_dialog():
	is_in_dialog = true
	interact_icon.visible = false

	# Choose which dialog to run and (possibly) set fed_bedmite = true
	if (not have_spoken() and not story_manager.found_controller):
		dialog.display_dialog(
			'Dust Mite',
			'dust_mite',
			[
				"Wow!  I reckon you're the biggest dust mite I've ever seen!",
				"But I've already claimed this dust, I'm afraid you'll have to find your own.",
				"Although I should say that I'm open to a fair trade.",
				"If you find a dust supply of equal or greater value, I'd be happy to exchange.",
				"Now if you don't mind, I'm going to resume my very important business of eating this here dust."
			],
		)
		story_manager.spoke_bedmite = true

	elif (not have_spoken() and story_manager.found_controller):
		dialog.display_dialog(
			'Dust Mite',
			'dust_mite',
			[
				"Wow!  I reckon you're the biggest dust mite I've ever seen!",
				"But I've already claimed this dust, I'm afraid you'll have to find your own.",
				"Although I should say that I'm open to a fair trade.",
				"If you find a dust supply of equal or greater value, I'd be happy to exchange.",
				"What's that?  You found something super dusty in that big green thing?",
				"Well that's incredible news!  You can have this big soft dusty thing then.",
				"I'm gonna go chow down.  See ya around!"
			],
		)
		story_manager.spoke_bedmite = true
		story_manager.fed_bedmite = true   # Mark “fed” right now, but departure waits until dialog ends

	elif (have_spoken() and not story_manager.found_controller):
		dialog.display_dialog(
			'Dust Mite',
			'dust_mite',
			[
				"Haven't found a worthy trade, eh?  Then this dust is still mine!"
			],
		)

	elif (have_spoken() and story_manager.found_controller):
		dialog.display_dialog(
			'Dust Mite',
			'dust_mite',
			[
				"What's that?  You found something super dusty in that big green thing?",
				"Well that's incredible news!  You can have this big soft dusty thing then.",
				"I'm gonna go chow down.  See ya around!"
			],
		)
		story_manager.fed_bedmite = true   # Already fed, so next _on_dialog_finished will depart

	elif story_manager.stick_mission_active:
		dialog.display_dialog(
			'Dust Mite',
			'dust_mite',
			[
				"Wow! What a great stick you've brought me!",
				"Thank you so much.",
				"Now I can finally get back to my working on my masterpiece!"
			],
		)
		story_manager.stick_mission_active = false
		story_manager.is_carrying_stick = false
		story_manager.stick_mission_completed = true

	else:
		var line_options = [
			["Back again, I see. Everything going smoothly?"],
			["You’ve proven yourself to be quite the asset around here."],
			["I can see why they trust you. You’ve earned your place."],
			["Well, well, if it isn’t the ladybug of the hour. How’s the world treating you?"],
			["Looks like you're fitting right in with us ants."],
			["You’ve been a real help around here. We appreciate it."],
			["Ah, you’re back. The anthill’s a bit brighter with you around."],
			["I’ve seen a lot of newcomers, but you stand out."],
			["You know, it’s not often we get someone as reliable as you."],
			["What’s the latest news from the surface? I’m always curious."],
			["The work here gets easier with you around. Keep it up."],
			["I trust you’re not causing any trouble, right? You’re on our side now."],
			["You’ve adapted quickly. I have to respect that."],
			["Another day, another good deed. You’ve made yourself valuable."],
			["Good to see you again. Ready for whatever comes next?"],
			["I see the others have warmed up to you. Not an easy feat."],
			["You're more than capable, I can tell. Keep it up."],
			["Every time you show up, things get a little smoother around here."],
			["You're not just a guest anymore, you’re part of the team."],
			["Welcome back. The anthill’s always better with you in it."]
		]
		var lines = line_options[randi() % line_options.size()]
		dialog.display_dialog(
			'Dust Mite',
			'dust_mite',
			lines,
		)
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
	# We no longer check `fed_bedmite` here.
	# Instead, departure is triggered inside _on_dialog_finished when fed==true.
	if player_nearby and Input.is_action_just_pressed("interact") and not just_dialoged:
		start_dialog()
		just_dialoged = true
		return
	just_dialoged = false


# ───────────────────────────────────────────────────────────────────
#   Parabolic Leap + Downward Fall (called only after dialog)
# ───────────────────────────────────────────────────────────────────
func _depart_dust_mite():
	# Disable further interaction
	interact_icon.visible = false
	interaction_area.monitoring = false

	var start_global = dust_mite_sprite.global_position

	# Tweak these values to change arc shape/speed/distance:
	var jump_height   = 100.0    # pixels up from current Y
	var forward_dist  = 60.0     # pixels forward along +X
	var up_time       = 0.4      # seconds to rise
	var down_time     = 0.8      # seconds to descend
	var total_time    = up_time + down_time

	# 1) HORIZONTAL TWEEN: constant forward motion over total_time
	var tween_h = create_tween()
	tween_h.tween_property(
		dust_mite_sprite, "global_position:x",
		start_global.x + forward_dist,
		total_time
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

	# 2) VERTICAL TWEEN: two‐phase up→down
	var peak_y = start_global.y - jump_height
	var viewport_bottom = get_viewport_rect().size.y + 50.0

	var tween_v = create_tween()
	# Phase 1: rise to peak
	tween_v.tween_property(
		dust_mite_sprite, "global_position:y",
		peak_y,
		up_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Phase 2: fall from peak to just below bottom
	tween_v.tween_property(
		dust_mite_sprite, "global_position:y",
		viewport_bottom,
		down_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# Once done, hide or free
	tween_v.tween_callback( Callable(self, "_on_dust_mite_fully_gone") )


func _on_dust_mite_fully_gone():
	dust_mite_sprite.hide()
	# If you prefer removing the entire NPC node, uncomment:
	# queue_free()
