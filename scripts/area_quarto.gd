extends Area

export var nome_ambiente: String = ""

func _on_Area_body_entered(body):
	if body.is_in_group("player"):
		body.add_to_group(nome_ambiente)

func _on_Area_body_exited(body):
	if body.is_in_group("player"):
		body.remove_from_group(nome_ambiente)
