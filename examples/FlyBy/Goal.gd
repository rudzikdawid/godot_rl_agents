extends CSGTorus3D

func _on_Area_body_entered(body):
	if body.has_method('goaal_reached'):
		body.goaal_reached(self)
