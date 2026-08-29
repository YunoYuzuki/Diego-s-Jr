extends Node
# =====================================================================
# CARTAS INVENTORY — colecionáveis de texto (cartas / notas / documentos)
# =====================================================================
# Autoload sugerido: CartasInventory (Node, este script).
#
# Cada carta:
#   { "id": String, "nome": String, "conteudo": String }
#
# Uso no mapa (script cartas.gd):
#   CartasInventory.add_carta(id_unico, nome_carta, conteudo_carta)
#   CartasUI.mostrar(nome_carta, conteudo_carta)
# =====================================================================

signal carta_adicionada(carta_id)
signal cartas_mudaram()

# Lista na ordem de coleta: Array de Dictionary
var cartas: Array = []

func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS


func add_carta(id: String, nome: String, conteudo: String) -> bool:
	id = String(id).strip_edges()
	if id == "":
		push_warning("[CartasInventory] id vazio — carta ignorada")
		return false
	if has_carta(id):
		return false
	var entry := {
		"id": id,
		"nome": String(nome).strip_edges() if nome != null else id,
		"conteudo": String(conteudo) if conteudo != null else ""
	}
	cartas.append(entry)
	emit_signal("carta_adicionada", id)
	emit_signal("cartas_mudaram")
	if typeof(SaveManager) != TYPE_NIL and SaveManager.has_method("sincronizar_progresso_web"):
		SaveManager.sincronizar_progresso_web()
	return true


func has_carta(id: String) -> bool:
	for c in cartas:
		if str(c.get("id", "")) == id:
			return true
	return false


func get_carta(id: String) -> Dictionary:
	for c in cartas:
		if str(c.get("id", "")) == id:
			return c
	return {}


func get_cartas() -> Array:
	return cartas.duplicate(true)


func quantidade() -> int:
	return cartas.size()


func esta_vazio() -> bool:
	return cartas.empty()


func clear() -> void:
	cartas.clear()
	emit_signal("cartas_mudaram")


func get_save_data() -> Array:
	var out: Array = []
	for c in cartas:
		out.append({
			"id": str(c.get("id", "")),
			"nome": str(c.get("nome", "")),
			"conteudo": str(c.get("conteudo", ""))
		})
	return out


func apply_save_data(data) -> void:
	cartas.clear()
	if typeof(data) != TYPE_ARRAY:
		emit_signal("cartas_mudaram")
		return
	for item in data:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var id = str(item.get("id", "")).strip_edges()
		if id == "" or has_carta(id):
			continue
		cartas.append({
			"id": id,
			"nome": str(item.get("nome", id)),
			"conteudo": str(item.get("conteudo", ""))
		})
	emit_signal("cartas_mudaram")


## Reordena uma carta de `from` para `to` (índices da lista atual).
## Persistido no próximo save (get_save_data usa a ordem do array).
func mover_carta(from: int, to: int) -> bool:
	if from < 0 or from >= cartas.size():
		return false
	if to < 0 or to >= cartas.size():
		return false
	if from == to:
		return true
	var item = cartas[from]
	cartas.remove(from)
	cartas.insert(to, item)
	emit_signal("cartas_mudaram")
	if typeof(SaveManager) != TYPE_NIL and SaveManager.has_method("sincronizar_progresso_web"):
		SaveManager.sincronizar_progresso_web()
	return true


## Abre a UI da carta (se CartasUI existir como Autoload ou no grupo).
func abrir_carta(id: String) -> void:
	var c = get_carta(id)
	if c.empty():
		return
	_mostrar_ui(str(c.get("nome", "")), str(c.get("conteudo", "")))


func abrir_ultima() -> void:
	if cartas.empty():
		return
	var c = cartas[cartas.size() - 1]
	_mostrar_ui(str(c.get("nome", "")), str(c.get("conteudo", "")))


func _mostrar_ui(nome: String, conteudo: String) -> void:
	if typeof(CartasUI) != TYPE_NIL and CartasUI.has_method("mostrar"):
		CartasUI.mostrar(nome, conteudo)
		return
	for n in get_tree().get_nodes_in_group("cartas_ui"):
		if is_instance_valid(n) and n.has_method("mostrar"):
			n.mostrar(nome, conteudo)
			return
	push_warning("[CartasInventory] CartasUI não encontrado (Autoload ou grupo 'cartas_ui')")
