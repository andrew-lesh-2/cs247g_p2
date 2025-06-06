# scene_transition.gd
extends CanvasLayer

# This will be used as an Autoload singleton
# Go to Project > Project Settings > Autoload and add this script as "SceneTransition"

var transition_color: Color = Color.BLACK
var transition_duration: float = 0.75

func _ready():
	# Make the layer high to be on top of everything
	layer = 128
	
	# Create the transition ColorRect but keep it hidden
	var rect = ColorRect.new()
	rect.name = "TransitionRect"
	rect.color = transition_color
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.visible = false
	add_child(rect)

func transition_to_scene(target_scene: String, duration: float = 0.75, color: Color = Color.BLACK):
	# Update settings
	transition_duration = duration
	transition_color = color
	
	var rect = $TransitionRect
	rect.color = transition_color
	
	# Add shader material
	var material = ShaderMaterial.new()
	var shader = load("res://circle_wipe.gdshader")
	if not shader:
		print("ERROR: Could not load circle_wipe.gdshader")
		return
		
	material.shader = shader
	rect.material = material
	
	# Start with no circle
	material.set_shader_parameter("circle_size", 0.0)
	material.set_shader_parameter("circle_center", Vector2(0.5, 0.5))
	material.set_shader_parameter("invert_mask", false)
	
	# Show the transition rect
	rect.visible = true
	
	# Grow the circle to cover the screen
	var tween = create_tween()
	tween.tween_method(
		Callable(material, "set_shader_parameter").bind("circle_size"),
		0.0, # Start with no circle
		2.0, # Grow beyond screen bounds
		transition_duration / 2.0
	)
	
	# Change scene when the screen is black
	tween.tween_callback(func():
		get_tree().change_scene_to_file(target_scene)
		
		# Add a small delay for scene loading
		var timer = Timer.new()
		timer.wait_time = 0.1
		timer.one_shot = true
		add_child(timer)
		timer.timeout.connect(func():
			# Invert the shader for second phase
			material.set_shader_parameter("invert_mask", true)
			
			# Shrink the circle to reveal the new scene
			var reveal_tween = create_tween()
			reveal_tween.tween_method(
				Callable(material, "set_shader_parameter").bind("circle_size"),
				0.0, # Start fully covered (with invert_mask=true)
				2.0, # Shrink beyond screen bounds
				transition_duration / 2.0
			)
			
			# Hide the rect when done
			reveal_tween.tween_callback(func():
				rect.visible = false
				timer.queue_free()
			)
		)
		timer.start()
	)
