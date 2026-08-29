extends StaticBody
# =====================================================================
# CARTA NO MAPA — coleta e envia pro CartasInventory + abre CartasUI
# =====================================================================
# Anexe este script no StaticBody da carta no mundo.
# Preencha os exports no Inspector:
#   id_unico   → chave estável pro save (ex: "carta_cozinha_01")
#   nome_carta → título no inventário / UI
#   conteudo   → texto completo da carta
#
# Grupos:
#   interagivel       → Camera consegue focar/interagir
#   Persist_coletavel → some no load se já coletada
# =====================================================================

export var id_unico: String = "carta_01"
export var nome_carta: String = "Carta"
export(String, MULTILINE) var conteudo: String = ""

onready var outline = _achar_outline()

var coletada: bool = false


func _ready() -> void:
	add_to_group("interagivel")
	add_to_group("Persist_coletavel")
	if id_unico.strip_edges() != "":
		set_meta("id_unico", id_unico.strip_edges())
	# Se já foi coletada neste save, some antes de aparecer
	if typeof(SaveManager) != TYPE_NIL and SaveManager.itens_coletados.has(_id()):
		queue_free()
		return
	if typeof(CartasInventory) != TYPE_NIL and CartasInventory.has_carta(_id()):
		queue_free()
		return


func _id() -> String:
	var id = id_unico.strip_edges()
	if id == "":
		id = str(get_meta("id_unico")) if has_meta("id_unico") else name
	return id


func _achar_outline() -> Node:
	# Tenta nomes comuns de outline / silhueta
	for n in get_children():
		var low = n.name.to_lower()
		if "outline" in low or "silhueta" in low:
			return n
		for c in n.get_children():
			var low2 = c.name.to_lower()
			if "outline" in low2 or "silhueta" in low2:
				return c
	return null


func set_foco(ativo: bool) -> void:
	if outline and is_instance_valid(outline):
		outline.visible = ativo and not coletada


func pode_interagir(_player) -> bool:
	return not coletada


func interagir(_player) -> void:
	if coletada:
		return
	coletada = true

	var id = _id()
	var nome = nome_carta if nome_carta.strip_edges() != "" else id
	var texto = conteudo

	if typeof(CartasInventory) != TYPE_NIL:
		CartasInventory.add_carta(id, nome, texto)

	if typeof(SaveManager) != TYPE_NIL and SaveManager.has_method("marcar_item_coletado"):
		SaveManager.marcar_item_coletado(id)

	# Abre a leitura (SEM pausar o jogo — CartasUI cuida disso)
	if typeof(CartasUI) != TYPE_NIL and CartasUI.has_method("mostrar"):
		CartasUI.mostrar(nome, texto)
	elif typeof(CartasInventory) != TYPE_NIL and CartasInventory.has_method("abrir_carta"):
		CartasInventory.abrir_carta(id)

	# Some do mapa
	remove_from_group("interagivel")
	visible = false
	for child in get_children():
		if child is CollisionShape or child is CollisionPolygon:
			child.disabled = true
	# Remove de verdade no próximo frame (evita race com raycast)
	call_deferred("queue_free")


func save() -> Dictionary:
	return {
		"id_unico": _id(),
		"coletada": coletada
	}


func load_data(data: Dictionary) -> void:
	coletada = data.get("coletada", false)
	if coletada or (typeof(SaveManager) != TYPE_NIL and SaveManager.itens_coletados.has(_id())):
		queue_free()
