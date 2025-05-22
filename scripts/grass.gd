extends Node2D

@export var base_segment: int = 0
@export var segment_count: int = 1

@export var amplitude: float = 0.35
@export var period: float = 10.0
@export var sample_offset: float = 0.1

@onready var enabler: VisibleOnScreenNotifier2D = $Enabler

@export var show_bounds: bool = false
@export var animated: bool = true

var segment = preload("res://scenes/environment/segment.tscn")

var segments = []
var time = 0.0
var phase_offset = 0.0


var sample_rate: int = 0
var iteration: int = 0
var SAMPLE_RATE_DIVISOR: float = 3000.0
func _ready():
	phase_offset = randf_range(0, 2 * PI)
	place_grass_segments()
	update_notifier_bounds()
	sample_rate = int(max(1, period**3 / SAMPLE_RATE_DIVISOR) / (amplitude**1.5))
	print("sample_rate: ", sample_rate)

	if not animated:
		time = randf_range(0, period)  # Random time within one period
		update_segment_positions()

func update_notifier_bounds():
	var total_height = segment_count * (26 - base_segment + 1) * 8
	var max_sway = segment_count * (26 - base_segment + 1) * amplitude

	# Offset upwards from the base
	enabler.rect = Rect2(
		Vector2(-max_sway, -total_height),
		Vector2(2 * max_sway, total_height)
	)

func _draw():
	if show_bounds:
		var rect = enabler.rect
		draw_rect(rect, Color(0, 1, 1, 0.3), false, 2)

func _process(delta):
	time += delta
	if animated:
		if sample_rate == 0:
			update_segment_positions()
		else:
			if iteration == 0:
				update_segment_positions()
			iteration = (iteration + 1) % 2 # sample_rate

func place_grass_segments():
	var current_y = 0
	for i in range(base_segment, 27):
		for j in range(segment_count):
			var segment_inst = segment.instantiate()
			segment_inst.GRASS_SEGMENT_INDEX = i
			add_child(segment_inst)
			#segment.position.y = snapped(current_y, 1)
			segment_inst.position.y = current_y
			segments.append(segment_inst)
			current_y -= 8
			if i == 26:
				break

func update_segment_positions():
	for i in range(segments.size()):
		if i == 0:  # Base segment doesn't move
			continue

		var max_amplitude = i  # Each segment can move i pixels from the one below
		var offset = sin(time * (2 * PI / period) + sample_offset * i + phase_offset) * max_amplitude * amplitude
		segments[i].position.x = offset
		#segments[i].position.x = snapped(offset, 1)
