extends Area

export var nome_ambiente: String = ""
# Marque TRUE só na Area do quarto onde a Laura começa o jogo
export var dispara_tutorial_saida : bool = false

func _on_Area_body_entered(body):
	if body.is_in_group("player"):
		body.add_to_group(nome_ambiente)

func _on_Area_body_exited(body):
	if not body.is_in_group("player"):
		return
	body.remove_from_group(nome_ambiente)
	if not dispara_tutorial_saida:
		return
	# Não dispara no fundo 3D do MainMenu
	if typeof(Global) != TYPE_NIL and Global.rodando_como_menu_bg:
		return
	var managers = get_tree().get_nodes_in_group("tutorial_manager")
	for m in managers:
		if is_instance_valid(m) and m.has_method("tutorial_sair_quarto"):
			m.tutorial_sair_quarto()
			break
