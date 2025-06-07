extends Node2D

# — assign this in the Inspector —
@export var level_layout_scene : PackedScene = preload("res://scenes/levels/box_andrew.tscn")
@export var player_path         : NodePath    = "Player"
@export var num_segments        : int         = 3   # must be odd

# Music settings
@export_file("*.mp3") var music_path: String = "res://audio/music/Lvl1Music.mp3"
@export_range(0.0, 1.0) var music_volume: float = 0.4
@export var music_loop: bool = true

# Enhanced fade settings
@export_group("Fade Settings")
@export var fade_color: Color = Color(0, 0, 0, 1)  # Black
@export var initial_hold_time: float = 0.5  # Time to stay black before starting fade
@export var fade_in_duration: float = 1.5   # How long the actual fade takes

# internal
var cell_size     : Vector2
var origin_offset : float
var segment_width : float
var wrap_dist     : float
var segments      : Array[Node2D] = []
var music_player: AudioStreamPlayer

# Fade overlay
var fade_overlay: ColorRect
var fade_tween: Tween

func _ready():
	# Create fade overlay (covers the whole screen)
	_setup_fade_overlay()
	
	# Set up music player
	setup_music()
	
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
	
	# Start the fade-in effect after everything is set up
	_start_fade_in()

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

# Set up music player
func setup_music():
	# Create a new AudioStreamPlayer
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	
	# Load the music file
	if music_path.is_empty():
		push_warning("No music file specified in level script")
		return
		
	var music_resource = load(music_path)
	if music_resource is AudioStream:
		music_player.stream = music_resource
		music_player.volume_db = linear_to_db(music_volume)
		
		# Set loop property if it's an MP3
		if music_resource is AudioStreamMP3:
			music_resource.loop = music_loop
			
		# Start playing the music
		music_player.play()
	else:
		push_error("Could not load music file: " + music_path)

func _physics_process(_delta):
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
		elif seg_left > right_b:
			seg.global_position.x -= wrap_dist

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
	if music_player:
		music_player.stream_paused = true

func resume_music():
	if music_player:
		music_player.stream_paused = false

func stop_music():
	if music_player:
		music_player.stop()

func set_music_volume(volume: float):
	if music_player:
		music_player.volume_db = linear_to_db(clamp(volume, 0.0, 1.0))
