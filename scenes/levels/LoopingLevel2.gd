extends Node2D

# — assign this in the Inspector —
@export var level_layout_scene : PackedScene = preload("res://scenes/levels/box_andrew.tscn")
@export var player_path         : NodePath    = "Player"
@export var num_segments        : int         = 3   # must be odd

# Music settings
@export_file("*.mp3") var intro_music_path: String = "res://audio/music/Lvl0Music.mp3"
@export_file("*.mp3") var main_music_path: String = "res://audio/music/Lvl1Music.mp3"
@export_range(0.0, 1.0) var music_volume: float = 0.4
@export var music_loop: bool = true

# Enhanced fade settings
@export_group("Fade Settings")
@export var fade_color: Color = Color(0, 0, 0, 1)  # Black
@export var initial_hold_time: float = 0.5  # Time to stay black before starting fade
@export var fade_in_duration: float = 1.5   # How long the actual fade takes

# Intro effect settings
@export_group("Intro Effect Settings")
@export var initial_zoom: float = 6.0  # Starting zoom level
@export var final_zoom: float = 3.0  # Final zoom level after intro
@export var intro_effect_duration: float = 2.0  # How long the intro effect takes

# internal
var cell_size     : Vector2
var origin_offset : float
var segment_width : float
var wrap_dist     : float
var segments      : Array[Node2D] = []
var intro_music_player: AudioStreamPlayer
var main_music_player: AudioStreamPlayer
var player: Player = null
var intro_completed: bool = false

# Fade overlay
var fade_overlay: ColorRect
var fade_tween: Tween

# Intro effect variables
var intro_tween: Tween

# For leaf detection
var area_to_segment = {}
var trigger_setup_complete = false

func _ready():
	# Create fade overlay (covers the whole screen)
	_setup_fade_overlay()
	
	# 0) remove the editor-placed template so you don't get a double in the center
	var template = $Box
	remove_child(template)
	template.queue_free()

	# 1) measure one segment by spawning a "probe"
	var probe = level_layout_scene.instantiate() as Node2D
	add_child(probe)

	# grab the TileMapLayer inside it
	var tm = probe.get_node("TileMapLayer") as TileMapLayer

	# in cells
	var used = tm.get_used_rect()                # Rect2i: what cells you actually painted
	# size of one cell in pixels
	cell_size = tm.tile_set.tile_size            # Vector2
	# how far in pixels the used-rect is offset from the tilemap origin
	origin_offset = used.position.x * cell_size.x

	# total pixel-width of one segment
	segment_width = used.size.x * cell_size.x
	# how far to wrap by
	wrap_dist = segment_width * num_segments

	remove_child(probe)
	probe.queue_free()

	# 2) spawn N fresh segments, centered around x=0
	var mid = int(num_segments / 2)
	for i in range(num_segments):
		var seg = level_layout_scene.instantiate() as Node2D
		seg.position.x = (i - mid) * segment_width
		add_child(seg)
		segments.append(seg)
	
	# Set initial camera zoom
	_set_camera_zoom(initial_zoom)
	
	# Get reference to player
	if not player_path.is_empty():
		player = get_node(player_path)
	
	# Start the fade-in effect after everything is set up
	_start_fade_in()
	
	# Set up the leaf3 trigger
	_setup_leaf3_triggers()
	
	# Start intro music with fade-in
	setup_intro_music()
	
	# Preload main music (but don't play yet)
	preload_main_music()

# Set up intro music with fade-in
func setup_intro_music():
	# Create player for intro music
	intro_music_player = AudioStreamPlayer.new()
	add_child(intro_music_player)
	
	# Load the music file
	if intro_music_path.is_empty():
		push_warning("No intro music file specified")
		return
		
	var music_resource = load(intro_music_path)
	if music_resource is AudioStream:
		intro_music_player.stream = music_resource
		intro_music_player.volume_db = -80  # Start silent
		
		# Set loop property if it's an MP3
		if music_resource is AudioStreamMP3:
			music_resource.loop = music_loop
		
		# Play the music
		intro_music_player.play()
		
		# Fade in
		var tween = create_tween()
		tween.tween_property(intro_music_player, "volume_db", linear_to_db(music_volume), fade_in_duration)
	else:
		push_error("Could not load intro music file: " + intro_music_path)

# Preload main music but don't play it yet
func preload_main_music():
	# Create player for main music
	main_music_player = AudioStreamPlayer.new()
	add_child(main_music_player)
	
	# Load the music file
	if main_music_path.is_empty():
		push_warning("No main music file specified")
		return
		
	var music_resource = load(main_music_path)
	if music_resource is AudioStream:
		main_music_player.stream = music_resource
		main_music_player.volume_db = -80  # Start silent
		
		# Set loop property if it's an MP3
		if music_resource is AudioStreamMP3:
			music_resource.loop = music_loop
	else:
		push_error("Could not load main music file: " + main_music_path)

# Set up area triggers on all Leaf3 StaticBody2Ds
func _setup_leaf3_triggers() -> void:
	# Clear any existing connections
	area_to_segment.clear()
	
	# Create a signal connection for each Leaf3
	for segment in segments:
		# Find Leaf3 in this segment
		if segment.has_node("Box/Leaf3/StaticBody2D"):
			var static_body = segment.get_node("Box/Leaf3/StaticBody2D")
			
			# Create an Area2D if it doesn't exist
			var area_name = "Leaf3Trigger"
			var area = null
			
			if static_body.has_node(area_name):
				area = static_body.get_node(area_name)
			else:
				# Create a new Area2D on the StaticBody2D
				area = Area2D.new()
				area.name = area_name
				static_body.add_child(area)
				
				# Create a CollisionShape2D that matches the StaticBody2D's shape
				var collision_shape = null
				for child in static_body.get_children():
					if child is CollisionShape2D:
						collision_shape = CollisionShape2D.new()
						collision_shape.shape = child.shape.duplicate()
						area.add_child(collision_shape)
						break
			
			# Make sure monitoring is enabled
			area.monitoring = true
			area.monitorable = true
			
			# Connect the body_entered signal
			if area.is_connected("body_entered", Callable(self, "_on_leaf3_area_entered")):
				area.disconnect("body_entered", Callable(self, "_on_leaf3_area_entered"))
			
			area.connect("body_entered", Callable(self, "_on_leaf3_area_entered"))
			
			# Store the mapping from area to segment
			area_to_segment[area] = segment
	
	# Disable all the intro Area2Ds
	for segment in segments:
		if segment.has_node("Box/Intro/Area2D"):
			var intro_area = segment.get_node("Box/Intro/Area2D")
			intro_area.monitoring = false
			intro_area.monitorable = false
	
	trigger_setup_complete = true

# Signal handler for when a body enters the Leaf3 area
func _on_leaf3_area_entered(body: Node) -> void:
	if body is Player and not intro_completed:
		# Get the segment for this area
		var segment = null
		for area in area_to_segment:
			if area.is_connected("body_entered", Callable(self, "_on_leaf3_area_entered")):
				segment = area_to_segment[area]
				break
		
		if segment:
			# Find the ColorRect in the Intro node
			var color_rect = null
			if segment.has_node("Box/Intro/ColorRect"):
				color_rect = segment.get_node("Box/Intro/ColorRect")
			
			intro_completed = true
			_start_intro_effect(color_rect)

# Start the intro effect (zoom out and fade overlay)
func _start_intro_effect(color_rect: ColorRect) -> void:
	print("Starting intro effect...")
	
	# Disable player input
	if player:
		player.disable_player_input = true
		print("Disabled player input")
	
	# Cancel any existing tween
	if intro_tween and intro_tween.is_valid():
		intro_tween.kill()
	
	# Create a new tween for the effect
	intro_tween = create_tween()
	intro_tween.set_parallel(true)  # Make all tweens run simultaneously
	intro_tween.set_ease(Tween.EASE_IN_OUT)
	intro_tween.set_trans(Tween.TRANS_SINE)
	
	# 1. Tween the camera zoom
	var camera = get_viewport().get_camera_2d()
	if camera:
		print("Tweening camera zoom from", initial_zoom, "to", final_zoom)
		intro_tween.tween_method(
			_set_camera_zoom,
			initial_zoom,
			final_zoom,
			intro_effect_duration
		)
	
	# 2. Tween the ColorRect's modulate to fade it out
	if color_rect:
		print("Tweening ColorRect modulate to transparent")
		# Make sure it's fully visible at the start
		color_rect.modulate = Color(1, 1, 1, 1)
		
		# Ensure the color rect is visible during the tween
		color_rect.visible = true
		
		# Tween the alpha value over the same duration as the zoom
		intro_tween.tween_property(
			color_rect,
			"modulate",
			Color(1, 1, 1, 0),  # Fully transparent
			intro_effect_duration
		)
	else:
		print("Warning: ColorRect not found in intro node")
	
	# 3. Handle music crossfade
	_crossfade_music(intro_effect_duration)
	
	# After the effect completes
	intro_tween.chain().tween_callback(func():
		print("Intro effect completed, re-enabling player input")
		# Re-enable player input
		if player:
			player.disable_player_input = false
		
		# Only now remove all intro nodes from all segments
		for seg in segments:
			if seg.has_node("Box/Intro"):
				print("Removing Intro node from segment")
				seg.get_node("Box/Intro").queue_free()
	)

# Crossfade between intro music and main music
func _crossfade_music(duration: float) -> void:
	print("Starting music crossfade...")
	
	# Create a tween for the crossfade
	var music_tween = create_tween()
	music_tween.set_parallel(true)
	
	# Fade out intro music
	if intro_music_player and intro_music_player.playing:
		print("Fading out intro music from volume:", intro_music_player.volume_db)
		
		# Important: Tween the volume WITHOUT stopping the music
		music_tween.tween_property(intro_music_player, "volume_db", -80, duration)
		
		# After the fade completes, then stop the music
		var stop_tween = create_tween()
		stop_tween.tween_interval(duration)  # Wait for fade to complete
		stop_tween.tween_callback(func(): 
			print("Stopping intro music after fade")
			intro_music_player.stop()
		)
	else:
		print("Intro music not playing, skipping fade out")
	
	# Wait a moment before starting main music
	if main_music_player:
		# Set initial volume to silent
		main_music_player.volume_db = -80
		
		# Start with a slight delay
		var delay = duration * 0.3  # 30% of the fade duration
		
		var main_music_tween = create_tween()
		main_music_tween.tween_interval(delay)
		main_music_tween.tween_callback(func():
			print("Starting main music (delayed)")
			main_music_player.play()
			
			# Create a separate tween for fading in
			var fade_in_tween = create_tween()
			fade_in_tween.tween_property(main_music_player, "volume_db", 
				linear_to_db(music_volume), duration - delay)
			print("Fading in main music to volume:", linear_to_db(music_volume))
		)
	else:
		print("Main music player not initialized")


# Helper to set camera zoom
func _set_camera_zoom(zoom_level: float) -> void:
	var camera = get_viewport().get_camera_2d()
	if camera:
		camera.zoom = Vector2(zoom_level, zoom_level)

# Set up the fade overlay
func _setup_fade_overlay():
	# Create a ColorRect that covers the entire viewport
	fade_overlay = ColorRect.new()
	fade_overlay.color = fade_color
	
	# Make sure it covers the entire viewport regardless of resolution
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't intercept mouse events
	
	# Create a CanvasLayer to ensure it's drawn on top
	var overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 128  # High layer number to be on top
	overlay_layer.add_child(fade_overlay)
	
	# Add to scene
	add_child(overlay_layer)

# Start the fade-in animation with initial hold time
func _start_fade_in():
	# Cancel any existing tween
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	
	# Create a new tween
	fade_tween = create_tween()
	fade_tween.set_ease(Tween.EASE_OUT)
	fade_tween.set_trans(Tween.TRANS_SINE)  # Smoother sine transition
	
	# First hold at full black for the specified time
	if initial_hold_time > 0:
		fade_tween.tween_interval(initial_hold_time)
	
	# Then animate the alpha from 1 to 0 over the fade duration
	fade_tween.tween_property(fade_overlay, "color", 
		Color(fade_color.r, fade_color.g, fade_color.b, 0), 
		fade_in_duration)
	
	# Optional: Add a callback when the fade completes to remove the overlay
	fade_tween.tween_callback(func():
		fade_overlay.visible = false
	)

func _physics_process(_delta):
	# Setup the leaf3 trigger if not already done (ensure it's set up after all segments are created)
	if not trigger_setup_complete:
		_setup_leaf3_triggers()
	
	# 1) find the active camera
	var cam = get_viewport().get_camera_2d()
	if cam == null:
		return

	# 2) compute world-space view-bounds
	var cx     = cam.global_position.x
	var vw     = get_viewport_rect().size.x
	# note: zoom is a scale, so divide
	var half_w = (vw * 0.5) / cam.zoom.x
	var left_b = cx - half_w
	var right_b = cx + half_w

	# 3) wrap any segment that fully leaves the viewport
	for seg in segments:
		# compute this segment's true left/right edges in world-pixels
		var seg_left  = seg.global_position.x + origin_offset
		var seg_right = seg_left + segment_width

		if seg_right < left_b:
			seg.global_position.x += wrap_dist
			# Reset triggers after wrapping
			trigger_setup_complete = false
		elif seg_left > right_b:
			seg.global_position.x -= wrap_dist
			# Reset triggers after wrapping
			trigger_setup_complete = false

# Customizable fade-out for transitions
func fade_out(duration: float = 1.0, hold_time: float = 0.0, callback: Callable = Callable()) -> void:
	# Make sure the overlay is visible
	fade_overlay.visible = true
	
	# Cancel any existing tween
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	
	# Create a new tween
	fade_tween = create_tween()
	fade_tween.set_ease(Tween.EASE_IN)
	fade_tween.set_trans(Tween.TRANS_SINE)
	
	# Animate the alpha from 0 to 1
	fade_tween.tween_property(fade_overlay, "color", 
		Color(fade_color.r, fade_color.g, fade_color.b, 1), 
		duration)
	
	# Hold at black if specified
	if hold_time > 0:
		fade_tween.tween_interval(hold_time)
	
	# Execute the callback when the fade completes
	if callback.is_valid():
		fade_tween.tween_callback(callback)

# Optional: Methods to control music during gameplay
func pause_music():
	if intro_music_player and intro_music_player.playing:
		intro_music_player.stream_paused = true
	if main_music_player and main_music_player.playing:
		main_music_player.stream_paused = true

func resume_music():
	if intro_music_player and intro_music_player.stream_paused:
		intro_music_player.stream_paused = false
	if main_music_player and main_music_player.stream_paused:
		main_music_player.stream_paused = false

func stop_music():
	if intro_music_player:
		intro_music_player.stop()
	if main_music_player:
		main_music_player.stop()

func set_music_volume(volume: float):
	var db_volume = linear_to_db(clamp(volume, 0.0, 1.0))
	if intro_music_player and intro_music_player.playing:
		intro_music_player.volume_db = db_volume
	if main_music_player and main_music_player.playing:
		main_music_player.volume_db = db_volume
