# story_manager_indoor.gd

extends Node2D

@export var spoke_grasshopper: bool = false
@export var spoke_bedmite: bool = false
@export var found_controller: bool = true
@export var fed_bedmite: bool = false
@export var insulted_bedmite: bool = false

@export var mite_mission_active: bool = false:
	set(value):
		mite_mission_active = value
		for callback in callbacks["mite_mission_active"].values():
			callback.call(value)


var callbacks: Dictionary = {}

func register_callback(
			property: String,
			callback: Callable,
			callback_id: String):
	if property in callbacks:
		callbacks[property][callback_id] = callback
	else:
		callbacks[property] = {callback_id: callback}
