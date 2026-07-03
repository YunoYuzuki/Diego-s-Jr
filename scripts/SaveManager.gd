extends Node

signal jogo_salvo

var token : String = ""
var player_name : String = ""

const SLOT_COUNT = 4
const AUTO_SAVE_INTERVAL = 70.0
const SAVE_FOLDER = "user://O Limbo das Memorias"

var current_slot = 0
var auto_save_timer : Timer
var itens_coletados = []

func _ready():
	var dir = Directory.new()
	if not dir.dir_exists(SAVE_FOLDER):
		dir.make_dir(SAVE_FOLDER)

	auto_save_timer = Timer.new()
	auto_save_timer.wait_time = AUTO_SAVE_INTERVAL
	auto_save_timer.one_shot = false
	auto_save_timer.connect("timeout", self, "_on_auto_save")
	add_child(auto_save_timer)
	auto_save_timer.start()

func _get_save_path(slot: int) -> String:
	return "%s/save_slot_%d.save" % [SAVE_FOLDER, slot]

func save_game(slot: int):
	if slot < 0 or slot >= SLOT_COUNT:
		print("Slot inválido!")
		return
	current_slot = slot

	var save_file = File.new()
	save_file.open(_get_save_path(slot), File.WRITE)

	# Salva itens_coletados PRIMEIRO
	save_file.store_line(to_json({
		"tipo": "itens_coletados",
		"lista": itens_coletados
	}))

	for node in get_tree().get_nodes_in_group("Persist"):
		if not node.has_method("save"):
			continue
		var data = node.call("save")
		if data.empty():
			continue
		save_file.store_line(to_json(data))

	# FIX: TutorialManager salvo ANTES de fechar o arquivo
	save_file.store_line(to_json({
		"tipo": "tutorial_manager",
		"data": TutorialManager.save_data()
	}))

	save_file.close()
	print("Jogo salvo no slot ", slot)
	emit_signal("jogo_salvo")

func load_game(slot: int):
	var path = _get_save_path(slot)
	var save_file = File.new()
	if not save_file.file_exists(path):
		print("Save não encontrado no slot ", slot)
		return false

	current_slot = slot
	itens_coletados = []

	# Passo 1: carrega itens_coletados ANTES de mudar de cena
	save_file.open(path, File.READ)
	while save_file.get_position() < save_file.get_len():
		var node_data = parse_json(save_file.get_line())
		if node_data.has("tipo") and node_data["tipo"] == "itens_coletados":
			itens_coletados = node_data["lista"]
			print("itens_coletados restaurados antes da cena: ", itens_coletados)
			break
	save_file.close()

	get_tree().change_scene("res://scenes/casa_ofc.tscn")
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")

	for node in get_tree().get_nodes_in_group("Persist"):
		if not node.is_in_group("Persist_estatico"):
			node.queue_free()
	yield(get_tree(), "idle_frame")

	# Passo 3: carrega o resto dos nodes
	save_file.open(path, File.READ)
	var player_node = null
	var lanterna_equipada = false
	var lanterna_ligada = false

	while save_file.get_position() < save_file.get_len():
		var node_data = parse_json(save_file.get_line())

		if node_data.has("tipo") and node_data["tipo"] == "itens_coletados":
			continue

		if node_data.has("tipo") and node_data["tipo"] == "tutorial_manager":
			TutorialManager.load_data(node_data["data"])
			continue

		if node_data.has("tipo_estatico"):
			var parent_node = get_node_or_null(node_data["parent"])
			if parent_node:
				var static_node = parent_node.get_node_or_null(node_data["name"])
				if static_node and static_node.has_method("load_data"):
					static_node.load_data(node_data)
			continue

		if not node_data.has("filename") or node_data["filename"] == "":
			continue

		var new_object = load(node_data["filename"]).instance()
		var parent = get_node_or_null(node_data["parent"])
		if not parent:
			new_object.free()
			continue

		parent.add_child(new_object)
		new_object.translation = Vector3(
			node_data["pos_x"],
			node_data["pos_y"],
			node_data["pos_z"]
		)

		if node_data.has("scale_x"):
			new_object.scale = Vector3(
				node_data["scale_x"],
				node_data["scale_y"],
				node_data["scale_z"]
			)

		for key in node_data.keys():
			if key in ["filename", "parent", "pos_x", "pos_y", "pos_z",
					   "hide_pos_x", "hide_pos_y", "hide_pos_z",
					   "scale_x", "scale_y", "scale_z"]:
				continue
			if key == "inventory":
				Inventory.apply_save_data(node_data["inventory"])
				continue
			if key == "lanterna_equipada":
				lanterna_equipada = node_data["lanterna_equipada"]
				player_node = new_object
				continue
			if key == "lanterna_ligada":
				lanterna_ligada = node_data["lanterna_ligada"]
				continue
			new_object.set(key, node_data[key])

		if "rot_x" in node_data and new_object.has_node("Camera"):
			new_object.rot_x = node_data["rot_x"]
			new_object.get_node("Camera").rotation_degrees.x = new_object.rot_x

		if new_object.has_method("load_data"):
			new_object.load_data(node_data)

	save_file.close()
	yield(get_tree(), "idle_frame")

	if lanterna_equipada and player_node:
		yield(get_tree(), "idle_frame")
		var cam = player_node.get_node_or_null("Camera")
		if cam and cam.has_method("pegar_lanterna"):
			for item in get_tree().get_nodes_in_group("lanterna"):
				cam.pegar_lanterna(item)
				if lanterna_ligada and item.has_method("ligar"):
					item.ligar()
				break

	auto_save_timer.start()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("Jogo carregado do slot ", slot)
	return true

func _on_auto_save():
	if current_slot >= 0:
		save_game(current_slot)

func slot_has_save(slot: int) -> bool:
	return File.new().file_exists(_get_save_path(slot))

func get_slot_info(slot: int) -> Dictionary:
	var path = _get_save_path(slot)
	var file = File.new()
	if not file.file_exists(path):
		return {"empty": true, "date": "", "time": ""}

	var modified_time = file.get_modified_time(path)
	var timezone_info = OS.get_time_zone_info()
	var bias = timezone_info["bias"]
	var unix_local = modified_time + (bias * 60)
	var datetime = OS.get_datetime_from_unix_time(unix_local)

	var date_str = "%02d/%02d/%d" % [datetime.day, datetime.month, datetime.year]
	var time_str = "%02d:%02d" % [datetime.hour, datetime.minute]

	return {"empty": false, "date": date_str, "time": time_str}
