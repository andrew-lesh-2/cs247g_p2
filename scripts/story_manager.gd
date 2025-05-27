extends Node2D



@export var can_enter_anthill: bool = false

@export var spoke_after_tunnels: bool = false
@export var met_first_bodyguard: bool = false

@export var stick_mission_active: bool = false
@export var is_carrying_stick: bool = false
@export var stick_mission_completed: bool = false

var callbacks: Dictionary = {}

func register_callback(
			property: String,
			callback: Callable, 
			callback_id: String):
	if property in callbacks:
		callbacks[property][callback_id] = callback
	else:
		callbacks[property] = {callback_id: callback}
		
func set_stick_mission_active(active: bool):
	stick_mission_active = active
	for callback in callbacks["stick_mission_active"].values():
		callback.call(active)
