extends Node2D


@onready var glow_effect  = get_node("Sprite2D/Glow")
@onready var story_manager = get_parent()

@onready var interact_icon  = get_node("interact_icon")
@onready var interaction_area = $InteractionArea

@export var final_position = Vector2.ZERO
@export var final_degrees = 0

var player_nearby = false

func _ready() -> void:
	var unique = str(randi() % 1000000)

	story_manager.register_callback(
		"food_mission_active",
		Callable(self, "_on_food_mission_active"),
		"berry" + unique)

	interaction_area.body_entered.connect(_on_interaction_area_body_entered)
	interaction_area.body_exited.connect(_on_interaction_area_body_exited)

	interact_icon.visible = false
	if story_manager.food_mission_active:
		glow_effect.enabled = true

	if story_manager.food_mission_completed:
		move_to_final_placement()
	elif story_manager.holding_berries >= 4:
		move_to_final_placement()
		self.visible = false

func _process(delta):
	if not story_manager.food_mission_active:
		return
	if player_nearby:
		if Input.is_action_just_pressed("interact"):
			self.visible = false
			move_to_final_placement()
			story_manager.holding_berries += 1

func move_to_final_placement():
	print("move to final placement")
	self.position = final_position
	self.rotation_degrees = final_degrees

func _on_food_mission_active(active: bool):
	print("food mission active", active)
	if active:
		glow_effect.enabled = true
	else:
		glow_effect.enabled = false
		self.visible = true


func _on_interaction_area_body_entered(body):
	if body is Player and story_manager.food_mission_active:
		interact_icon.visible = true
		player_nearby = true



func _on_interaction_area_body_exited(body):
	if body is Player:
		interact_icon.visible = false
		player_nearby = true
