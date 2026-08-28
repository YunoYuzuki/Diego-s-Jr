extends "res://scripts/porta.gd"

const ITEM_CHAVE = "chave_quarto"

var objetivo_mostrado : bool = false

func _ready() -> void:
	._ready()
	# Mantém trancada por padrão apenas se for um jogo novo
	if not SaveManager.slot_ativo:
		trancada = true

func interagir(player) -> void:
	if animando:
		return

	if trancada:
		if Inventory.has_item(ITEM_CHAVE):
			# Consome a chave e destranca
			Inventory.remove_item(ITEM_CHAVE)
			trancada = false
			print("🔑 Quarto dos pais destrancado!")
			# Abre imediatamente após destrancar
			aberta     = true
			alvo_porta = angulo_aberta
			animando   = true
			_anim_tempo = 0.0
			_atualizar_colisoes()
			_tocar_som(audio_porta) 
		else:
			# Sem chave: toca som de trancada sempre, mas objetivo só aparece 1 vez
			_tocar_som(audio_porta_trancada)
			if not objetivo_mostrado:
				_ativar_objetivo()
				objetivo_mostrado = true
		return

	# Porta destrancada: comportamento normal
	aberta     = !aberta
	alvo_porta = angulo_aberta if aberta else 0.0
	animando   = true
	_anim_tempo = 0.0
	_atualizar_colisoes()
	_tocar_som(audio_porta)

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
			ui.mostrar_objetivo("Está trancado...")

# SALVAMENTO TOTALMENTE ALINHADO COM O NOVO GERENCIADOR
func save() -> Dictionary:
	return {
		"node_path": str(get_path()),
		"aberta": aberta,
		"trancada": trancada,
		"objetivo_mostrado": objetivo_mostrado
	}

func load_data(data: Dictionary) -> void:
	# Executa o carregamento básico da porta comum (aberta, trancada, etc)
	.load_data(data)
	
	# Agora carrega a variável que é exclusiva do quarto
	objetivo_mostrado = data.get("objetivo_mostrado", false)


