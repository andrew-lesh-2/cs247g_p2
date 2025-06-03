extends Node2D


@onready var glow_effect  = get_node("Daisy/Glow")
@onready var story_manager = StoryManager

@onready var interact_icon  = get_node("interact_icon")
@onready var interaction_area = $InteractionArea

@export var final_position = Vector2.ZERO
@export var final_degrees = 0

var player_nearby = false

func _ready() -> void:
	var unique = str(randi() % 1000000)

	story_manager.register_callback(
		"doctor_mission_active",
		Callable(self, "_on_doctor_mission_active"),
		"daisy" + unique)

	interaction_area.body_entered.connect(_on_interaction_area_body_entered)
	interaction_area.body_exited.connect(_on_interaction_area_body_exited)

	interact_icon.visible = false
	if story_manager.doctor_mission_active:
		glow_effect.enabled = true

	if story_manager.doctor_mission_completed:
		queue_free()

func _process(delta):
	if not story_manager.doctor_mission_active:
		return
	if player_nearby:
		if Input.is_action_just_pressed("interact"):
			story_manager.holding_daisies += 1
			queue_free()

func _on_doctor_mission_active(active: bool):
	print("doctor mission active", active)
	if active:
		glow_effect.enabled = true
	else:
		glow_effect.enabled = false


func _on_interaction_area_body_entered(body):
	if body is Player and story_manager.doctor_mission_active:
		interact_icon.visible = true
		player_nearby = true

func _on_interaction_area_body_exited(body):
	if body is Player:
		interact_icon.visible = false
		player_nearby = false
