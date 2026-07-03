extends Node

signal item_added(item_id)
signal item_removed(item_id)

const ITEMS_DB = {
	"chave_velha":   { "nome": "Chave Velha" },
	"chave_quarto":  { "nome": "Chave do Quarto" },
	"lanterna":      { "nome": "Lanterna" },
	"diario":        { "nome": "Diário Rasgado" },
	"amuleto":       { "nome": "Amuleto" },
	"fita_cassete":  { "nome": "Fita Cassete" },
	"gravador":      { "nome": "Gravador" },
}

var items: Array = []

func add_item(item_id: String):
	if item_id in ITEMS_DB and not has_item(item_id):
		items.append(item_id)
		emit_signal("item_added", item_id)

func remove_item(item_id: String):
	if has_item(item_id):
		items.erase(item_id)
		emit_signal("item_removed", item_id)

func has_item(item_id: String) -> bool:
	return items.has(item_id)

func get_item_name(item_id: String) -> String:
	return ITEMS_DB[item_id]["nome"] if item_id in ITEMS_DB else item_id

func get_save_data() -> Array:
	return items.duplicate()

func apply_save_data(data: Array):
	items = data.duplicate()
	for item_id in items:
		emit_signal("item_added", item_id)
