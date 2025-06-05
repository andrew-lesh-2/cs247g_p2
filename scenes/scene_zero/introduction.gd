extends Node2D

@onready var rich_text_label = $Control/RichTextLabel

var typing_speed := 0.06  # Normal typing speed
var fast_typing_speed := 0.01  # Faster when spacebar is held
var is_speeding_up := false  # Whether the spacebar is held

func _ready() -> void:
	type_text("This is where the introduction will go.")

func _process(_delta: float) -> void:
	is_speeding_up = Input.is_action_pressed("ui_accept")  # Spacebar or Enter by default

func type_text(text: String) -> void:
	rich_text_label.clear()
	rich_text_label.bbcode_enabled = true
	call_deferred("_type_text", text)

func _type_text(text: String) -> void:
	for char in text:
		rich_text_label.append_text(char)
		var delay = fast_typing_speed if is_speeding_up else typing_speed
		await get_tree().create_timer(delay).timeout
