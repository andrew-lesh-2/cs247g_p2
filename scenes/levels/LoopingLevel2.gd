extends Node2D

# — assign this in the Inspector, or preload it directly below —
@export var level_layout_scene : PackedScene = preload("res://scenes/levels/box.tscn")
@export var player_path         : NodePath    = "Player"
@export var num_segments        : int         = 3  # must be odd

# internal
var segment_width : float
var wrap_dist     : float
var segments      : Array[Node2D] = []


func _ready():
	# remove the editor-placed template so you don't get a double-NPC in the middle
	var template = $Box
	remove_child(template)
	template.queue_free()
	
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

func _physics_process(_delta):
	# 1) get the active Camera2D
	var cam = get_viewport().get_camera_2d()
	if cam == null:
		return

	# 2) compute world-space left/right edges
	var cx      = cam.global_position.x
	var vw      = get_viewport_rect().size.x
	var half_w  = (vw * 0.5) / cam.zoom.x
	var left_b  = cx - half_w
	var right_b = cx + half_w

	# 3) now wrap segments that fully leave view
	for seg in segments:
		var seg_left  = seg.global_position.x
		var seg_right = seg_left + segment_width

		if seg_right < left_b:
			seg.global_position.x += wrap_dist
		elif seg_left > right_b:
			seg.global_position.x -= wrap_dist
