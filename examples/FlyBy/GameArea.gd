extends Area3D

func _on_GameArea_body_exited(body):
	if body.is_in_group('AGENT'):
		body.exited_game_area()
