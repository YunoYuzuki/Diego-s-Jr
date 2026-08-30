extends Spatial
const CENA_CASA = preload("res://scenes/casa_ofc.tscn")

# Mesmos valores "calmos" do shader da câmera do jogador (SHADER_POR_EMOCAO[CALMA])
const SHADER_MENU_CALMA = {
	"static_intensity": 0.012,
	"brilho": 0.97,
	"vignette_size": 0.28,
	"grain": 0.012,
	"tint_emocional": 0.0,
}

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
	# Mantém o mesmo post-process da câmera do jogador no fundo 3D do menu
	_ativar_postprocess_menu(casa)
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

	# Nó hud (extends Node) — esconde filhos desenháveis,
	# EXCETO PostProcess (mesmo shader da câmera do jogador no fundo do menu)
	if nome == "hud":
		for filho in node.get_children():
			if filho.name == "PostProcess":
				continue
			if filho is CanvasLayer:
				filho.visible = false
			elif filho is CanvasItem:
				filho.visible = false
		return

	# CanvasLayers típicos de gameplay dentro do player
	# PostProcess fica visível de propósito (look & feel igual ao gameplay)
	if node is CanvasLayer:
		if nome in ["CanvasLayer", "PauseCanvas", "Emocao", "Cassette"]:
			node.visible = false

func _ativar_postprocess_menu(casa: Node) -> void:
	# Procura o ColorRect do post-process (hud/PostProcess/ColorRect) na casa instanciada
	var post = _encontrar_postprocess(casa)
	if post == null:
		# Fallback: qualquer nó chamado PostProcess na árvore
		post = find_node("PostProcess", true, false)
	if post == null:
		push_warning("QuartoMenu: PostProcess não encontrado — shader do menu não aplicado")
		return

	post.visible = true
	# Garante layer alto o bastante pra cobrir o 3D, mas abaixo do UI do MainMenu
	if post is CanvasLayer:
		# MainMenu UI costuma ficar em layers altos; 10 cobre o 3D sem cobrir botões
		if post.layer < 1:
			post.layer = 1

	var color_rect = null
	if post.has_node("ColorRect"):
		color_rect = post.get_node("ColorRect")
	else:
		for c in post.get_children():
			if c is ColorRect:
				color_rect = c
				break

	if color_rect == null:
		push_warning("QuartoMenu: ColorRect do PostProcess não encontrado")
		return

	color_rect.visible = true
	# Full-screen
	if color_rect is Control:
		color_rect.set_anchors_and_margins_preset(Control.PRESET_WIDE)
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Força o shader CRT (overlay_crt) — é o visual pedido pro menu
	var caminho_crt := "res://scripts/shaders/overlay_crt.gdshader"
	var shader_crt = null
	if ResourceLoader.exists(caminho_crt):
		shader_crt = load(caminho_crt)
	else:
		# fallback se a pasta shaders estiver em outro lugar
		for alt in ["res://shaders/overlay_crt.gdshader", "res://assets/shaders/overlay_crt.gdshader"]:
			if ResourceLoader.exists(alt):
				shader_crt = load(alt)
				break

	var mat = color_rect.material
	if shader_crt != null:
		if not (mat is ShaderMaterial):
			mat = ShaderMaterial.new()
			color_rect.material = mat
		mat.shader = shader_crt
	elif not (mat is ShaderMaterial):
		push_warning("QuartoMenu: sem ShaderMaterial e CRT não encontrado")
		return

	# Look calmo + defaults CRT agradáveis pro menu
	for chave in SHADER_MENU_CALMA.keys():
		mat.set_shader_param(chave, SHADER_MENU_CALMA[chave])
	# Params específicos do CRT (se existirem no shader)
	mat.set_shader_param("curvatura", 0.004)
	mat.set_shader_param("aberracao_cromatica", 0.0012)
	mat.set_shader_param("scanline_force", 0.16)
	mat.set_shader_param("mascara_forca", 0.08)
	mat.set_shader_param("glow_scanline", 0.10)
	mat.set_shader_param("flicker", 0.008)
	mat.set_shader_param("saturacao", 1.05)
	mat.set_shader_param("contraste", 1.05)
	mat.set_shader_param("tom_quente", 0.02)

	print("QuartoMenu: CRT ativo no fundo do menu (PostProcess)")

func _encontrar_postprocess(node: Node) -> Node:
	if node == null:
		return null
	if node.name == "PostProcess":
		return node
	for filho in node.get_children():
		var r = _encontrar_postprocess(filho)
		if r != null:
			return r
	return null

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
	# PostProcess precisa continuar processando o shader (TIME etc.)
	if node.name == "PostProcess" or (node.get_parent() and node.get_parent().name == "PostProcess"):
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
