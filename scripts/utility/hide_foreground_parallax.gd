extends Parallax2D

var player: Node2D

func _ready():
	# Get reference to Player node (parent's parent's child)
	player = get_parent().get_parent().get_node("Player")

func _process(_delta):
	if player and player.position.y > 150:
		visible = false
	else:
		visible = true
