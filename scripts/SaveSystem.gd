extends Node

signal jogo_salvo

const SLOT_COUNT = 4
const AUTO_SAVE_INTERVAL = 60.0

var current_slot : int = -1
var itens_coletados : Array = []
var auto_save_timer : Timer

# ---------------------------------------------------------------------------
func _ready() -> void:
	add_to_group("save_system")
	auto_save_timer = Timer.new()
	auto_save_timer.wait_time = AUTO_SAVE_INTERVAL
	auto_save_timer.one_shot = false
	auto_save_timer.connect("timeout", self, "_on_auto_save")
	add_child(auto_save_timer)

# ---------------------------------------------------------------------------
func _get_save_path(slot: int) -> String:
	return "user://save_slot_%d.save" % slot

func _is_valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < SLOT_COUNT

# ---------------------------------------------------------------------------
# SAVE
# ---------------------------------------------------------------------------
func save_game(slot: int) -> void:
	if not _is_valid_slot(slot):
		push_error("SaveSystem: slot invlido (%d)" % slot)
		return

	current_slot = slot
	var save_file := File.new()
	var err := save_file.open(_get_save_path(slot), File.WRITE)
	if err != OK:
		push_error("SaveSystem: falha ao abrir arquivo de save")
		return

	# Despausa temporariamente pra pegar os ns
	var estava_pausado = get_tree().paused
	get_tree().paused = false

	for node in get_tree().get_nodes_in_group("Persist"):
		if not node.has_method("save"):
			continue
		var data = node.call("save")
		if data is Dictionary and not data.empty():
			save_file.store_line(to_json(data))

	get_tree().paused = estava_pausado

	var datetime := OS.get_datetime()
	save_file.store_line(to_json({
		"tipo": "save_meta",
		"date": "%02d/%02d/%04d" % [datetime.day, datetime.month, datetime.year],
		"time": "%02d:%02d" % [datetime.hour, datetime.minute]
	}))
	save_file.store_line(to_json({
		"tipo": "itens_coletados",
		"lista": itens_coletados
	}))

	save_file.close()
	emit_signal("jogo_salvo")
	print("[SaveSystem] Jogo salvo no slot %d" % slot)

# ---------------------------------------------------------------------------
# LOAD
# ---------------------------------------------------------------------------
func load_game(slot: int) -> bool:
	if not _is_valid_slot(slot):
		push_error("SaveSystem: slot invlido")
		return false

	var path := _get_save_path(slot)
	var save_file := File.new()
	if not save_file.file_exists(path):
		print("[SaveSystem] Save no encontrado no slot %d" % slot)
		return false

	for node in get_tree().get_nodes_in_group("Persist"):
		node.queue_free()
	yield(get_tree(), "idle_frame")

	save_file.open(path, File.READ)

	var player_node : Node = null
	var lanterna_equipada := false
	var lanterna_ligada := false

	while save_file.get_position() < save_file.get_len():
		var line := save_file.get_line().strip_edges()
		if line.empty():
			continue

		var node_data = parse_json(line)
		if not node_data is Dictionary:
			continue

		if node_data.get("tipo") == "itens_coletados":
			itens_coletados = node_data.get("lista", [])
			continue

		if node_data.get("tipo") == "save_meta":
			continue

		if not node_data.has("filename") or not node_data.has("parent"):
			continue

		var scene_resource : PackedScene = load(node_data["filename"]) as PackedScene
		if not scene_resource:
			continue

		var new_object : Node = scene_resource.instance()
		var parent_node = get_node_or_null(node_data["parent"])
		if not parent_node:
			new_object.free()
			continue

		parent_node.add_child(new_object)

		if new_object is Spatial:
			if node_data.has("global_position"):
				new_object.global_transform.origin = node_data["global_position"]
			else:
				new_object.global_transform.origin = Vector3(
					node_data.get("pos_x", 0.0),
					node_data.get("pos_y", 0.0),
					node_data.get("pos_z", 0.0)
				)
			if node_data.has("scale"):
				new_object.scale = node_data["scale"]
			if node_data.has("global_rotation"):
				new_object.global_transform.basis = node_data["global_rotation"]

		var skip_keys = ["filename", "parent", "global_position", "pos_x", "pos_y", "pos_z",
						"global_rotation", "scale", "lanterna_equipada", "lanterna_ligada",
						"tipo", "date", "time", "lista"]

		for key in node_data.keys():
			if key in skip_keys:
				continue
			if key == "inventory":
				if new_object.has_method("apply_save_data"):
					new_object.apply_save_data(node_data["inventory"])
				continue
			new_object.set(key, node_data[key])

		if node_data.has("lanterna_equipada"):
			lanterna_equipada = node_data["lanterna_equipada"]
			player_node = new_object
		if node_data.has("lanterna_ligada"):
			lanterna_ligada = node_data["lanterna_ligada"]

		if node_data.has("is_hidden") and new_object.has_method("hide_in_closet"):
			new_object.hide_in_closet(Vector3(
				node_data.get("hide_pos_x", 0),
				node_data.get("hide_pos_y", 0),
				node_data.get("hide_pos_z", 0)
			))

	save_file.close()
	yield(get_tree(), "idle_frame")

	for item in get_tree().get_nodes_in_group("cassette"):
		item.queue_free()

	if lanterna_equipada and is_instance_valid(player_node):
		var cam = player_node.get_node_or_null("Camera")
		if cam and cam.has_method("pegar_lanterna"):
			for lantern in get_tree().get_nodes_in_group("lanterna"):
				cam.pegar_lanterna(lantern)
				if lanterna_ligada and lantern.has_method("ligar"):
					lantern.ligar()
				break

	current_slot = slot
	auto_save_timer.start()

	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	print("[SaveSystem] Jogo carregado do slot %d" % slot)
	return true

# ---------------------------------------------------------------------------
func _on_auto_save() -> void:
	if _is_valid_slot(current_slot):
		print("[SaveSystem] Autosave no slot %d" % current_slot)
		save_game(current_slot)

func slot_has_save(slot: int) -> bool:
	return File.new().file_exists(_get_save_path(slot))

# ---------------------------------------------------------------------------
# MTODOS PARA A UI
# ---------------------------------------------------------------------------
func save_to_slot(slot: int) -> void:
	save_game(slot)

func load_from_slot(slot: int) -> bool:
	return load_game(slot)

func get_slot_info(slot: int) -> Dictionary:
	if not _is_valid_slot(slot):
		return {"empty": true}

	var path := _get_save_path(slot)
	if not File.new().file_exists(path):
		return {"empty": true}

	var save_file := File.new()
	save_file.open(path, File.READ)
	while save_file.get_position() < save_file.get_len():
		var line := save_file.get_line().strip_edges()
		if line.empty():
			continue
		var data = parse_json(line)
		if data is Dictionary and data.get("tipo") == "save_meta":
			save_file.close()
			return {
				"empty": false,
				"date": data.get("date", "??/??/????"),
				"time": data.get("time", "??:??")
			}
	save_file.close()

	return {"empty": false, "date": "Slot %d" % (slot + 1), "time": ""}