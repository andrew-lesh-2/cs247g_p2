extends Node2D


@onready var glow_effect  = get_node("Sprite2D/Glow")
@onready var story_manager = StoryManager

@onready var interact_icon  = get_node("interact_icon")
@onready var interaction_area = $InteractionArea

var player_nearby = false

func _ready() -> void:
	story_manager.register_callback(
		"stick_mission_active",
		Callable(self, "_on_stick_mission_active"),
		"perfect_stick")
		
	interaction_area.body_entered.connect(_on_interaction_area_body_entered)
	interaction_area.body_exited.connect(_on_interaction_area_body_exited)
	
	interact_icon.visible = false
	move_to_final_placement()
	if story_manager.stick_mission_active:
		glow_effect.enabled = true
	if story_manager.stick_mission_completed:
		move_to_final_placement()
	elif (story_manager.stick_mission_active and 
		story_manager.is_carrying_stick):
		move_to_final_placement()
		self.visible = false 

func _process(delta):
	if story_manager.is_carrying_stick or not story_manager.stick_mission_active:
		return
	if player_nearby:
		if Input.is_action_just_pressed("interact"):
			self.visible = false
			move_to_final_placement()
			story_manager.is_carrying_stick = true

func move_to_final_placement():
	self.position = Vector2(-1302.0, 621.0)
	self.rotation_degrees = -59

func _on_stick_mission_active(active: bool):
	if active:
		glow_effect.enabled = true
	else:
		glow_effect.enabled = false
		self.visible = true
		
		
		

func _on_interaction_area_body_entered(body):
	if body is Player and story_manager.stick_mission_active:
		interact_icon.visible = true
		player_nearby = true
		
		

func _on_interaction_area_body_exited(body):
	if body is Player:
		interact_icon.visible = false
		player_nearby = true
