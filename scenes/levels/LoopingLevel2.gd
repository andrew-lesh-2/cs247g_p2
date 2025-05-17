extends Node2D

# — assign this in the Inspector —
@export var level_layout_scene : PackedScene = preload("res://scenes/levels/box_andrew.tscn")
@export var player_path         : NodePath    = "Player"
@export var num_segments        : int         = 3   # must be odd

# internal
var cell_size     : Vector2
var origin_offset : float
var segment_width : float
var wrap_dist     : float
var segments      : Array[Node2D] = []

func _ready():
	# 0) remove the editor-placed template so you don't get a double in the center
	var template = $Box
	remove_child(template)
	template.queue_free()

	# 1) measure one segment by spawning a “probe”
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
		# compute this segment’s true left/right edges in world-pixels
		var seg_left  = seg.global_position.x + origin_offset
		var seg_right = seg_left + segment_width

		if seg_right < left_b:
			seg.global_position.x += wrap_dist
		elif seg_left > right_b:
			seg.global_position.x -= wrap_dist
