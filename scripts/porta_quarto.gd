extends "res://scripts/porta.gd"

const ITEM_CHAVE = "chave_quarto"

func _ready() -> void:
	._ready()
	trancada = true

func interagir(player) -> void:
	if animando:
		return

	if trancada:
		if Inventory.has_item(ITEM_CHAVE):
			# Consome a chave e destranque
			Inventory.remove_item(ITEM_CHAVE)
			trancada = false
			print("🔑 Quarto dos pais destrancado!")
			# Abre imediatamente após destrancar
			aberta     = true
			alvo_porta = angulo_aberta
			animando   = true
			_atualizar_colisoes()
			_tocar_som_porta()
		else:
			# Sem chave: ativa objetivo e revela chave no mapa
			_ativar_objetivo()
		return

	# Porta destrancada: comportamento normal
	aberta     = !aberta
	alvo_porta = angulo_aberta if aberta else 0.0
	animando   = true
	_atualizar_colisoes()
	_tocar_som_porta()

func _ativar_objetivo() -> void:
	# Revela a chave no mapa (se ainda não foi revelada)
	var chaves = get_tree().get_nodes_in_group("chave_quarto")
	for chave in chaves:
		if chave.has_method("revelar"):
			chave.revelar()

	# Dispara o UI de objetivo
	var obj_ui = get_tree().get_nodes_in_group("objetivo_ui")
	for ui in obj_ui:
		if ui.has_method("mostrar_objetivo"):
			ui.mostrar_objetivo("Encontre a chave do quarto")

func save() -> Dictionary:
	return {
		"tipo_estatico": "porta_quarto",
		"name": name,
		"parent": get_parent().get_path(),
		"pos_x": translation.x,
		"pos_y": translation.y,
		"pos_z": translation.z,
		"aberta": aberta,
		"trancada": trancada
	}

func load_data(data: Dictionary) -> void:
	aberta = data.get("aberta", false)
	trancada = data.get("trancada", true)
	alvo_porta = angulo_aberta if aberta else 0.0
	pivot.rotation_degrees.z = alvo_porta
	_atualizar_colisoes()
