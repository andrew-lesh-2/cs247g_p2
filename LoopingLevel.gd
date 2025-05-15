extends Node2D

# — assign this in the Inspector, or preload it directly below —
@export var level_layout_scene : PackedScene = preload("res://test_scroll_level_layout.tscn")
@export var player_path         : NodePath    = "Player"
@export var num_segments        : int         = 3  # must be odd

# internal
var segment_width : float
var wrap_dist     : float
var segments      : Array[Node2D] = []


func _ready():
	# 1) measure one segment by spawning a “probe”
	var probe = level_layout_scene.instantiate() as Node2D
	add_child(probe)

	var tm   = probe.get_node("TileMap") as TileMap
	var used = tm.get_used_rect()            # in cells
	var tsz  = tm.tile_set.tile_size         # pixels per cell
	segment_width = used.size.x * tsz.x
	wrap_dist     = segment_width * num_segments

	remove_child(probe)
	probe.queue_free()

	# 2) spawn N fresh segments, centered around x=0
	var mid = int(num_segments / 2)          # e.g. 1 for 3 segments
	for i in range(num_segments):
		var seg = level_layout_scene.instantiate() as Node2D
		seg.position.x = (i - mid) * segment_width
		add_child(seg)
		segments.append(seg)


func _physics_process(delta):
	# 1) world-space X of the player
	var ply = get_node_or_null(player_path)
	if ply == null:
		return
	var px = ply.global_position.x

	# 2) compute screen-bounds in world units
	var cam   = ply.get_node_or_null("Camera2D") as Camera2D
	var vw    = get_viewport_rect().size.x
	var half_w = vw * 0.5
	if cam:
		half_w *= cam.zoom.x
	var left_b  = px - half_w
	var right_b = px + half_w

	# 3) recycle any segment fully off-screen
	for seg in segments:
		var sx = seg.global_position.x
		if sx + segment_width < left_b:
			seg.global_position.x += wrap_dist
		elif sx > right_b:
			seg.global_position.x -= wrap_dist
