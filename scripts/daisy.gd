extends Node2D

@export var amplitude: float = 0.35
@export var period: float = 10.0
@export var sample_offset: float = 0.1

@onready var enabler: VisibleOnScreenNotifier2D = $Enabler

@export var show_bounds: bool = false
@export var animated: bool = true

@export var stem_range: Vector2 = Vector2(6,12)

var segment = preload("res://scenes/environment/daisy_stem.tscn")

var segments = []
var time = 0.0
var phase_offset = 0.0

var sample_rate: int = 0
var iteration: int = 0
var SAMPLE_RATE_DIVISOR: float = 3000.0

@export var num_segments: int = 10

func _ready():
	phase_offset = randf_range(0, 2 * PI)
	place_stem_segments()
	update_notifier_bounds()
	sample_rate = int(max(1, period**3 / SAMPLE_RATE_DIVISOR) / (amplitude**1.5))
	print("sample_rate: ", sample_rate)

	if not animated:
		time = randf_range(0, period)  # Random time within one period
		update_segment_positions()

func update_notifier_bounds():
	var total_height = num_segments * 4
	var max_sway = num_segments * amplitude

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

func place_stem_segments():
	var current_y = -2
	for i in range(num_segments):
		var segment_inst = segment.instantiate()
		add_child(segment_inst)
		segment_inst.position.y = current_y

		# 70% chance for index 0, 30% chance for random index 0-3
		if i == num_segments - 1:
			segment_inst.STEM_SEGMENT_INDEX = 4
		elif i < 2 or i > num_segments - 8:
			segment_inst.STEM_SEGMENT_INDEX = 0
		elif i % 8 == 0:
			segment_inst.STEM_SEGMENT_INDEX = 3
		else:
			segment_inst.STEM_SEGMENT_INDEX = 0

		segments.append(segment_inst)
		current_y -= 4

func update_segment_positions():
	for i in range(segments.size()):
		if i == 0:  # Base segment doesn't move
			continue

		var max_amplitude = i  # Each segment can move i pixels from the one below
		var offset = sin(time * (2 * PI / period) + sample_offset * i + phase_offset) * max_amplitude * amplitude
		segments[i].position.x = offset
		#segments[i].position.x = snapped(offset, 1)
