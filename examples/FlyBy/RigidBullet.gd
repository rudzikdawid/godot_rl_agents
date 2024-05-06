extends RigidBody3D


# Called when the node enters the scene tree for the first time.
func _ready():
	print('readyyyyyy')
	var velocity = -transform.basis.z.normalized() * 300
	#set_velocity(velocity)
	#set_up_direction(Vector3.UP)
	#move_and_slide()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
