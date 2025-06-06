extends RigidBody2D

@export var max_speed: float = 200.0
@export var bounce: float = 0.2

func _ready():
	# Critical physics settings
	gravity_scale = 1.0
	contact_monitor = true
	max_contacts_reported = 4
	mass = 2.0  # Not too heavy, not too light
	
	# Apply physics material with some bounce and low friction
	var physics_material = PhysicsMaterial.new()
	physics_material.friction = 0.2
	physics_material.bounce = bounce
	physics_material_override = physics_material
	
	# Make sure these are NOT set
	freeze = false
	
	# Important: Use continuous collision detection for better interactions
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY

func _physics_process(delta):
	# Make the ball visually roll based on its velocity
	var ball_radius = $CollisionShape2D.shape.radius
	if ball_radius > 0:
		angular_velocity = -linear_velocity.x / ball_radius
	
	# Cap maximum speed
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed
