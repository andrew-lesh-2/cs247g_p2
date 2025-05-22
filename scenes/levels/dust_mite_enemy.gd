extends CharacterBody2D

# This script goes on the DustMiteEnemy node

@onready var area = $Area2D
@onready var sprite = $AnimatedSprite2D
var speed = 100
var direction = 1
var move_distance = 200
var traveled_distance = 0
var is_dying = false
signal collided_with_player

func _ready():
	if area:
		area.connect("body_entered", Callable(self, "_on_body_entered"))
	else:
		print("ERROR: No Area2D found on ", name)
	
	add_to_group("enemies")
	print(name, " dust mite ready - Groups: ", get_groups())

# Use _physics_process instead of _process to prevent flying
func _physics_process(delta):
	if is_dying:
		return
		
	velocity.x = speed * direction
	velocity.y = 0  # Force y velocity to zero to prevent flying
	move_and_slide()
	traveled_distance += abs(velocity.x) * delta
	
	# Check if the DustMiteEnemy should turn around
	if traveled_distance >= move_distance:
		direction *= -1
		traveled_distance = 0
		# Flip the sprite horizontally
		sprite.flip_h = direction == -1

func _on_body_entered(body):
	if is_dying:
		return
		
	if body.is_in_group("player"):
		print("Player collided with dust mite!")
		emit_signal("collided_with_player")
		
		# Call player's damage function - now it supports amount parameter
		if body.has_method("take_damage"):
			body.take_damage(1)  # Deal 1 damage to player

func take_damage():
	print("=== TAKE_DAMAGE CALLED ON ", name, " ===")
	
	if is_dying:
		print("Already dying, ignoring damage")
		return
	
	is_dying = true
	print("Setting is_dying to true, stopping movement")
	
	# Visual feedback
	modulate = Color(1, 0, 0)  # Turn red
	print("Changed color to red")
	
	# Disable collision to prevent further interactions
	if area:
		area.monitoring = false
		area.monitorable = false
	
	# Simple fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 0, 0, 0), 0.3)
	print("Started fade tween")
	
	# Remove after animation
	await tween.finished
	print("Tween finished, calling queue_free")
	queue_free()
