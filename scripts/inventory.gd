extends Node

signal item_added(item_id)
signal item_removed(item_id)
signal stack_changed(item_id, quantidade)

const ITEMS_DB = {
	"chave_quarto":  { "nome": "Chave", "stackable": false },
	"lanterna":      { "nome": "Lanterna", "stackable": false },
	"fita_cassete":  { "nome": "Fita Cassete", "stackable": false },
}

var items: Array = []
var stacks: Dictionary = {}

func add_item(item_id: String, quantidade: int = 1) -> void:
	if not item_id in ITEMS_DB:
		if not items.has(item_id):
			items.append(item_id)
			emit_signal("item_added", item_id)
		return

	var info = ITEMS_DB[item_id]
	if info.get("stackable", false):
		var q = max(quantidade, 1)
		var atual = int(stacks.get(item_id, 0))
		stacks[item_id] = atual + q
		if not items.has(item_id):
			items.append(item_id)
			emit_signal("item_added", item_id)
		emit_signal("stack_changed", item_id, stacks[item_id])
	else:
		if not has_item(item_id):
			items.append(item_id)
			emit_signal("item_added", item_id)

func remove_item(item_id: String, quantidade: int = 1) -> void:
	if item_id in ITEMS_DB and ITEMS_DB[item_id].get("stackable", false):
		if not stacks.has(item_id):
			return
		stacks[item_id] = int(stacks[item_id]) - max(quantidade, 1)
		if stacks[item_id] <= 0:
			stacks.erase(item_id)
			if items.has(item_id):
				items.erase(item_id)
				emit_signal("item_removed", item_id)
		else:
			emit_signal("stack_changed", item_id, stacks[item_id])
		return
	if has_item(item_id):
		items.erase(item_id)
		emit_signal("item_removed", item_id)

func has_item(item_id: String) -> bool:
	if item_id in ITEMS_DB and ITEMS_DB[item_id].get("stackable", false):
		return int(stacks.get(item_id, 0)) > 0
	return items.has(item_id)

func get_quantidade(item_id: String) -> int:
	if item_id in ITEMS_DB and ITEMS_DB[item_id].get("stackable", false):
		return int(stacks.get(item_id, 0))
	return 1 if has_item(item_id) else 0

func clear() -> void:
	for item_id in items.duplicate():
		emit_signal("item_removed", item_id)
	items.clear()
	stacks.clear()

func get_item_name(item_id: String) -> String:
	if not item_id in ITEMS_DB:
		return item_id
	var nome = ITEMS_DB[item_id]["nome"]
	if ITEMS_DB[item_id].get("stackable", false):
		var q = get_quantidade(item_id)
		if q > 1:
			return "%s  x%d" % [nome, q]
	return nome

func esta_vazio() -> bool:
	return items.empty()

func get_save_data():
	return {
		"items": items.duplicate(),
		"stacks": stacks.duplicate()
	}

func apply_save_data(data) -> void:
	for item_id in items.duplicate():
		emit_signal("item_removed", item_id)
	items.clear()
	stacks.clear()

	if typeof(data) == TYPE_ARRAY:
		for item_id in data:
			add_item(str(item_id))
		return

	if typeof(data) == TYPE_DICTIONARY:
		var st = data.get("stacks", {})
		if typeof(st) == TYPE_DICTIONARY:
			for k in st.keys():
				stacks[str(k)] = int(st[k])
		var lista = data.get("items", [])
		for item_id in lista:
			var id = str(item_id)
			if not items.has(id):
				items.append(id)
			emit_signal("item_added", id)
			if stacks.has(id):
				emit_signal("stack_changed", id, stacks[id])
