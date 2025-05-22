extends Area2D

# This script goes on the GroundPoundAbility node

func _ready():
	# Connect the body_entered signal
	connect("body_entered", Callable(self, "_on_body_entered"))
	# Start with monitoring disabled
	monitoring = false
	print("GroundPoundAbility ready")

func _on_body_entered(body):
	#print("GroundPoundAbility detected: ", body.name, " (Groups: ", body.get_groups(), ")")
	if body.is_in_group("enemies"):
		#print("Body is in enemies group!")
		if body.has_method("take_damage"):
			#print("Body has take_damage method - calling it now")
			body.take_damage()
		#else:
			#print("ERROR: Body does not have take_damage method!")
	#else:
		#print("Body is NOT in enemies group")

# Function to activate ground pound detection
func activate_ground_pound():
	#print("Activating ground pound detection")
	monitoring = true
	#print("Monitoring set to: ", monitoring)
	
	# Turn off after a brief moment
	await get_tree().create_timer(0.2).timeout
	monitoring = false
	#print("Ground pound detection disabled")
