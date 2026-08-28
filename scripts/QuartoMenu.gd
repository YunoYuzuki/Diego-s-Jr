extends Spatial
const CENA_CASA = preload("res://scenes/casa_ofc.tscn")

func _ready():
	Global.rodando_como_menu_bg = true
	
	var casa = CENA_CASA.instance()
	add_child(casa)
	# Desliga Areas imediatamente pra nenhum body_exited/entered
	# disparar tutorial / lógica de gameplay no fundo do menu
	_desativar_areas(casa)
	_esconder_hud_gameplay(casa)
	yield(get_tree(), "idle_frame")
	_congelar_arvore(casa)
	_esconder_hud_gameplay(casa)
	_desativar_outras_cameras(casa)
	_ativar_camera_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Limpa qualquer crosshair/HUD órfão que tenha ficado na raiz
	_limpar_ui_orfan()

func _esconder_hud_gameplay(node: Node) -> void:
	# Só esconde HUD de gameplay conhecido — NÃO esconde Camera nem Spatial genérico
	for filho in node.get_children():
		_esconder_hud_gameplay(filho)

	var nome = node.name
	# Crosshair e hotbar
	if nome == "CrosshairUI" or nome == "HotbarContainer" or nome == "StaminaBar":
		if node is CanvasItem:
			node.visible = false
		return

	# Nó hud (extends Node) — esconde filhos desenháveis
	if nome == "hud":
		for filho in node.get_children():
			if filho is CanvasLayer:
				filho.visible = false
			elif filho is CanvasItem:
				filho.visible = false
		return

	# CanvasLayers típicos de gameplay dentro do player
	if node is CanvasLayer:
		if nome in ["CanvasLayer", "PauseCanvas", "Emocao", "PostProcess", "Cassette"]:
			node.visible = false

func _limpar_ui_orfan() -> void:
	# Crosshairs / HUDs que foram reparentados pra raiz em sessões anteriores
	for n in get_tree().get_nodes_in_group("ui_persistente"):
		if not is_instance_valid(n):
			continue
		if n.get_parent() == get_tree().root:
			n.queue_free()
	for n in get_tree().get_nodes_in_group("reparentar_hud"):
		if is_instance_valid(n) and n.get_parent() == get_tree().root:
			n.queue_free()

func _desativar_areas(node: Node) -> void:
	for filho in node.get_children():
		_desativar_areas(filho)
	if node is Area:
		node.monitoring = false
		node.monitorable = false
		node.set_process(false)
		node.set_physics_process(false)

func _congelar_arvore(node: Node) -> void:
	for filho in node.get_children():
		_congelar_arvore(filho)

	# Nunca congela a câmera do menu — ela precisa continuar válida
	if node.is_in_group("camera_menu"):
		return
	if node is Camera and node.is_in_group("camera_menu"):
		return

	if node.has_method("set_process"):
		node.set_process(false)
	if node.has_method("set_physics_process"):
		node.set_physics_process(false)
	if node.has_method("set_process_input"):
		node.set_process_input(false)
	if node.has_method("set_process_unhandled_input"):
		node.set_process_unhandled_input(false)
	if "pause_mode" in node:
		node.pause_mode = Node.PAUSE_MODE_STOP
	if node is Timer:
		node.stop()
	if node is AnimationPlayer:
		node.stop()
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
		node.stop()
	if node.is_in_group("sombra"):
		node.queue_free()

func _desativar_outras_cameras(node: Node) -> void:
	for filho in node.get_children():
		_desativar_outras_cameras(filho)
	if node is Camera and not node.is_in_group("camera_menu"):
		node.current = false

func _ativar_camera_menu() -> void:
	var cameras = get_tree().get_nodes_in_group("camera_menu")
	print("Cameras no group: ", cameras.size())
	if cameras.size() == 0:
		# Fallback: procura por nome na árvore
		var found = find_node("camera_menu", true, false)
		if found == null:
			found = find_node("CameraMenu", true, false)
		if found is Camera:
			cameras = [found]
			print("Camera menu achada por nome: ", found.get_path())

	if cameras.size() > 0:
		var cam = cameras[0]
		if cam is Spatial:
			cam.visible = true
		# Garante que nenhuma outra câmera da casa continue current
		_desativar_outras_cameras(self)
		cam.current = true
		print("Camera ativada: ", cam.get_path(), " | current=", cam.current)
	else:
		push_warning("QuartoMenu: nenhuma camera_menu encontrada!")

func _desativar_gameplay(casa):
	if casa.has_node("Player"):
		casa.get_node("Player").set_physics_process(false)
		casa.get_node("Player").set_process(false)
	if casa.has_node("shadow"):
		casa.get_node("shadow").set_process(false)
