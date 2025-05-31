extends Node2D



@export var can_enter_anthill: bool = false

@export var spoke_after_tunnels: bool = false
@export var met_first_bodyguard: bool = false

@export var stick_mission_active: bool = false:
	set(value):
		stick_mission_active = value
		for callback in callbacks["stick_mission_active"].values():
			callback.call(value)

@export var is_carrying_stick: bool = false
@export var stick_mission_completed: bool = false

@export var food_mission_active: bool = false:
	set(value):
		food_mission_active = value
		if "food_mission_active" not in callbacks:
			return
		for callback in callbacks["food_mission_active"].values():
			callback.call(value)
@export var food_mission_completed: bool = false
@export var holding_berries: int = 0

var callbacks: Dictionary = {}

func register_callback(
			property: String,
			callback: Callable,
			callback_id: String):
	if property in callbacks:
		callbacks[property][callback_id] = callback
	else:
		callbacks[property] = {callback_id: callback}
