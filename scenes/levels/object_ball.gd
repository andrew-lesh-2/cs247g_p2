# object_ball.gd
# ----------------------------
# Attach this to a Sprite2D whose only child is a RigidBody2D (with a CollisionShape2D under it).

extends Sprite2D

@onready var body: RigidBody2D = $RigidBody2D


func _ready() -> void:
	# 1) Ensure the child exists:
	if body == null:
		push_error("object_ball.gd: Could not find a child RigidBody2D!")
		return

	# 2) Gravity (already working by default):
	body.gravity_scale = 1.0

	# 3) Create a small PhysicsMaterial2D so the ball has friction + minimal bounce:
	var mat := PhysicsMaterial.new()
	mat.friction = 0.8        # ← makes the ball “stick”/slow as it rolls
	mat.bounce   = 0.05       # ← very little spring; set to 0.0 for no bounce at all
	body.physics_material_override = mat

	# 4) (Optional) Add a bit of damp so it eventually comes to rest instead of sliding forever:
	body.linear_damp  = 0.2   # slows down linear sliding over time
	body.angular_damp = 0.2   # slows down spinning over time

	# 5) By default, new RigidBody2D’s “Mode” is already Rigid in the editor,
	#    so we don’t need to call body.body_mode = ... here.  If you ever accidentally
	#    switched it to Static or Kinematic in the editor, you can uncomment:
	#    body.body_mode = PhysicsBody2D.BODY_MODE_RIGID

	# 6) By default in Godot 4, rotation is allowed on a new RigidBody2D, so you do NOT need
	#    to clear any “freeze” flags unless you previously froze it in the editor:
	#    body.freeze = 0    # ← only if you had frozen rotation by mistake


func _physics_process(delta: float) -> void:
	# 7) Each physics frame, copy the RigidBody2D’s position+rotation onto the Sprite2D:
	#    so that the PNG “rides” the physics body exactly and spins as it rolls.
	if body:
		global_position = body.global_position
		rotation        = body.rotation
