extends Node
# =============================================================
# QUARTO_LAURA — Autoload global
#
# Project → Autoload:
#   Path: res://scripts/quarto_laura.gd
#   Name: QuartoLaura
#
# Nos objetos do quarto (cama, fita 2, ursinho...):
#   anexe quarto_laura_item.gd e preencha o export "Fita Tocada".
# =============================================================

signal fita_tocada(nome_fita)
signal quarto_atualizado

# IDs dos props que já apareceram (persistido no save)
# chave = id_unico do item  |  valor = true
var itens_aparecidos : Dictionary = {}

func _ready() -> void:
	call_deferred("_atualizar_tudo")

## Chamado pelo Gravador quando uma fita termina de tocar de verdade.
func ao_fita_reproduzida(nome_fita: String) -> void:
	if nome_fita == "":
		return
	print("🛏️ QuartoLaura: fita tocada → ", nome_fita)
	emit_signal("fita_tocada", nome_fita)
	_atualizar_tudo()

## True se essa fita já foi ouvida até o fim.
func fita_foi_tocada(nome: String) -> bool:
	if nome == null or str(nome).strip_edges() == "":
		return false
	if typeof(SaveManager) == TYPE_NIL:
		return false
	var alvo = str(nome).strip_edges()
	if SaveManager.fitas_reproduzidas.has(alvo):
		return true
	var alvo_l = alvo.to_lower()
	for k in SaveManager.fitas_reproduzidas.keys():
		var ks = str(k).to_lower().strip_edges()
		if ks == alvo_l:
			return true
		if alvo_l in ks or ks in alvo_l:
			return true
	return false

## Marca um prop como "já apareceu" (vai pro save).
func marcar_item_aparecido(id_unico: String) -> void:
	if id_unico == null or str(id_unico).strip_edges() == "":
		return
	itens_aparecidos[str(id_unico)] = true

## True se esse prop já tinha aparecido num save anterior.
func item_ja_apareceu(id_unico: String) -> bool:
	if id_unico == null or str(id_unico).strip_edges() == "":
		return false
	return itens_aparecidos.has(str(id_unico)) and itens_aparecidos[str(id_unico)]

## Dados pro SaveManager.
func get_save_data() -> Dictionary:
	return {
		"itens_aparecidos": itens_aparecidos.duplicate()
	}

## Restaura do save (antes ou depois da cena carregar).
func load_save_data(data: Dictionary) -> void:
	itens_aparecidos.clear()
	if data == null or typeof(data) != TYPE_DICTIONARY:
		return
	var raw = data.get("itens_aparecidos", {})
	if typeof(raw) == TYPE_DICTIONARY:
		for k in raw.keys():
			itens_aparecidos[str(k)] = true
	print("🛏️ QuartoLaura load: ", itens_aparecidos.size(), " item(ns) já aparecido(s)")

func limpar() -> void:
	itens_aparecidos.clear()

func _atualizar_tudo() -> void:
	if not is_inside_tree():
		return
	var nos = get_tree().get_nodes_in_group("quarto_laura")
	for n in nos:
		if n != null and is_instance_valid(n) and n.has_method("atualizar_visibilidade"):
			n.atualizar_visibilidade()
	emit_signal("quarto_atualizado")

func forcar_atualizacao() -> void:
	_atualizar_tudo()
