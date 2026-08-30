extends CanvasLayer
# =====================================================================
# INVENTORY VIEWER UI — inventário estilo PS1 (item 3D girando no centro)
# =====================================================================
# Sem cena — tudo montado por código (igual RankingUI.gd). Registre este
# .gd DIRETO como Autoload (nome sugerido: "InventoryViewerUI").
#
# Abre com [TAB] (ação "inventory_toggle" — a mesma tecla que a lista de
# texto antiga usava; InventoryUI.gd foi desativada, essa tela toma o
# lugar dela por completo).
#
# [A] / [D] (ou setas esquerda/direita) trocam de item.
# [ESC] ou [TAB] de novo fecha.
# Sem descrição — só o item, igual PS1 (Resident Evil e companhia).
#
# Reaproveita a mesma lógica de enquadramento de câmera/luz do
# TelaPickup.gd (AABB combinada dos meshes, câmera posicionada pelo FOV).
# =====================================================================

const VEL_ROTACAO := 25.0  # graus/seg — giro lento e constante

# item_id (de Inventory.ITEMS_DB) -> cena do modelo 3D em res://assets/scenes_pickup
# Adicione aqui se novos itens físicos entrarem no jogo.
const CENA_POR_ITEM := {
	"lanterna":     "res://assets/scenes_pickup/flashlight_pickup.tscn",
	"chave_quarto": "res://assets/scenes_pickup/chave_pickup.tscn",
	"fita_cassete": "res://assets/scenes_pickup/Cassette.obj.tscn",
}

var esta_aberta := false
var _indice_atual := 0
var _ids_disponiveis: Array = []  # subconjunto de Inventory.items que tem modelo 3D

var _fundo: ColorRect
var _label_titulo: Label
var _label_a: Control
var _label_d: Control
var _viewport_container: ViewportContainer
var _viewport: Viewport
var _item_holder: Spatial
var _camera: Camera
var _luz_principal: OmniLight
var _luz_preenchimento: OmniLight
var _item_atual_no: Spatial

var _painel_nome: Panel
var _label_nome_item: Label

var _painel_emocao: Panel
var _grafico_emocao: Line2D
var _label_estado: Label
var _tempo_onda := 0.0

# Estado emocional da Laura (mesma ordem do enum Emocao em Camera.gd):
# CALMA, COM_MEDO, ASSUSTADA, EM_CRISE — cor e "batimento" do gráfico por estado.
const VISUAL_POR_EMOCAO = {
	0: {"cor": Color(0.35, 1.0, 0.45), "amp": 0.22, "freq": 1.0},  # Calma
	1: {"cor": Color(0.85, 0.95, 0.30), "amp": 0.42, "freq": 1.4},  # Com Medo
	2: {"cor": Color(1.0, 0.6, 0.15), "amp": 0.62, "freq": 1.9},  # Assustada
	3: {"cor": Color(1.0, 0.25, 0.25), "amp": 0.90, "freq": 2.6},  # Em Crise
}

var _mouse_antes: int = Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	layer = 105
	add_to_group("ui_bloqueia_pause")
	_construir_ui()
	visible = false
	set_process_input(true)
	set_process(true)

	if typeof(Inventory) != TYPE_NIL:
		Inventory.connect("item_added", self, "_on_itens_mudaram")
		Inventory.connect("item_removed", self, "_on_itens_mudaram")


func _construir_ui() -> void:
	_fundo = ColorRect.new()
	_fundo.color = Color(0, 0, 0, 0.88)
	_fundo.anchor_right = 1.0
	_fundo.anchor_bottom = 1.0
	_fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_fundo)

	_viewport_container = ViewportContainer.new()
	_viewport_container.anchor_left = 0.5
	_viewport_container.anchor_right = 0.5
	_viewport_container.anchor_top = 0.5
	_viewport_container.anchor_bottom = 0.5
	_viewport_container.margin_left = -260
	_viewport_container.margin_right = 260
	_viewport_container.margin_top = -220
	_viewport_container.margin_bottom = 220
	_viewport_container.stretch = true
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_viewport_container)

	_viewport = Viewport.new()
	_viewport.size = Vector2(520, 440)
	_viewport.transparent_bg = true
	_viewport.own_world = true
	_viewport_container.add_child(_viewport)

	_item_holder = Spatial.new()
	_viewport.add_child(_item_holder)

	_camera = Camera.new()
	_camera.fov = 45.0
	_viewport.add_child(_camera)

	_luz_principal = OmniLight.new()
	_luz_principal.light_energy = 1.6
	_luz_principal.light_color = Color(1.0, 0.98, 0.92)
	_luz_principal.omni_range = 12.0
	_luz_principal.translation = Vector3(1.2, 1.5, 2.5)
	_viewport.add_child(_luz_principal)

	_luz_preenchimento = OmniLight.new()
	_luz_preenchimento.light_energy = 0.55
	_luz_preenchimento.light_color = Color(0.75, 0.82, 1.0)
	_luz_preenchimento.omni_range = 10.0
	_luz_preenchimento.translation = Vector3(-1.5, 0.8, 1.0)
	_viewport.add_child(_luz_preenchimento)

	# Título "INVENTÁRIO" no topo, igual telas de item estilo PS1
	_label_titulo = Label.new()
	_label_titulo.text = "INVENTÁRIO"
	_label_titulo.add_font_override("font", _fonte(42))
	_label_titulo.modulate = Color(1, 1, 1, 0.92)
	_label_titulo.align = Label.ALIGN_CENTER
	_label_titulo.anchor_left = 0.0
	_label_titulo.anchor_right = 1.0
	_label_titulo.anchor_top = 0.0
	_label_titulo.margin_top = 34
	_label_titulo.margin_bottom = 92
	add_child(_label_titulo)

	# "A" — caixinha ao lado esquerdo do item (igual à referência)
	_label_a = _criar_botao_letra("A")
	_label_a.anchor_left = 0.5
	_label_a.anchor_top = 0.5
	_label_a.margin_left = -330
	_label_a.margin_right = -282
	_label_a.margin_top = -24
	_label_a.margin_bottom = 24
	add_child(_label_a)

	# "D" — caixinha ao lado direito do item
	_label_d = _criar_botao_letra("D")
	_label_d.anchor_left = 0.5
	_label_d.anchor_top = 0.5
	_label_d.margin_left = 282
	_label_d.margin_right = 330
	_label_d.margin_top = -24
	_label_d.margin_bottom = 24
	add_child(_label_d)

	# Painel de nome do item — centralizado, um pouco acima da base da tela
	_painel_nome = Panel.new()
	_painel_nome.anchor_left = 0.5
	_painel_nome.anchor_right = 0.5
	_painel_nome.anchor_top = 1.0
	_painel_nome.anchor_bottom = 1.0
	_painel_nome.margin_left = -170
	_painel_nome.margin_right = 170
	_painel_nome.margin_top = -150
	_painel_nome.margin_bottom = -70
	_painel_nome.add_stylebox_override("panel", _criar_stylebox(Color(0.10, 0.10, 0.13, 0.85), Color(0.45, 0.45, 0.55, 0.85)))
	add_child(_painel_nome)

	_label_nome_item = Label.new()
	_label_nome_item.anchor_left = 0.0
	_label_nome_item.anchor_right = 1.0
	_label_nome_item.anchor_top = 0.0
	_label_nome_item.anchor_bottom = 1.0
	_label_nome_item.align = Label.ALIGN_CENTER
	_label_nome_item.valign = Label.VALIGN_CENTER
	_label_nome_item.autowrap = true
	_label_nome_item.add_font_override("font", _fonte(28))
	_painel_nome.add_child(_label_nome_item)

	# Painel de estado emocional — canto inferior esquerdo, menor que o de nome
	_painel_emocao = Panel.new()
	_painel_emocao.anchor_left = 0.0
	_painel_emocao.anchor_right = 0.0
	_painel_emocao.anchor_top = 1.0
	_painel_emocao.anchor_bottom = 1.0
	_painel_emocao.margin_left = 24
	_painel_emocao.margin_right = 254
	_painel_emocao.margin_top = -110
	_painel_emocao.margin_bottom = -30
	_painel_emocao.add_stylebox_override("panel", _criar_stylebox(Color(0.06, 0.10, 0.08, 0.85), Color(0.35, 0.55, 0.4, 0.85)))
	add_child(_painel_emocao)

	_grafico_emocao = Line2D.new()
	_grafico_emocao.width = 2.0
	_grafico_emocao.position = Vector2(16, 10)
	_grafico_emocao.default_color = Color(0.35, 1.0, 0.45)
	_painel_emocao.add_child(_grafico_emocao)

	_label_estado = Label.new()
	_label_estado.text = "ESTADO: Calma"
	_label_estado.anchor_left = 0.0
	_label_estado.anchor_right = 1.0
	_label_estado.anchor_top = 1.0
	_label_estado.anchor_bottom = 1.0
	_label_estado.margin_left = 16
	_label_estado.margin_top = -26
	_label_estado.margin_bottom = -6
	_label_estado.add_font_override("font", _fonte(15))
	_painel_emocao.add_child(_label_estado)


func _criar_botao_letra(texto: String) -> Panel:
	var painel := Panel.new()
	painel.add_stylebox_override("panel", _criar_stylebox(Color(0.16, 0.15, 0.22, 0.88), Color(0.6, 0.56, 0.7, 0.9)))
	var lbl := Label.new()
	lbl.text = texto
	lbl.add_font_override("font", _fonte(24))
	lbl.align = Label.ALIGN_CENTER
	lbl.valign = Label.VALIGN_CENTER
	lbl.anchor_left = 0.0
	lbl.anchor_right = 1.0
	lbl.anchor_top = 0.0
	lbl.anchor_bottom = 1.0
	painel.add_child(lbl)
	return painel


func _criar_stylebox(cor_fundo: Color, cor_borda: Color, raio: int = 8, borda: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = cor_fundo
	sb.border_color = cor_borda
	sb.set_border_width_all(borda)
	sb.set_corner_radius_all(raio)
	return sb


func _fonte(tamanho: int) -> DynamicFont:
	var f := DynamicFont.new()
	if ResourceLoader.exists("res://assets/fonts/MiniPixel/Minipixel-Regular.ttf"):
		f.font_data = load("res://assets/fonts/MiniPixel/Minipixel-Regular.ttf")
	f.size = tamanho
	return f


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory_toggle"):
		if esta_aberta:
			fechar()
			get_tree().set_input_as_handled()
			return
		if _pode_abrir():
			abrir()
			get_tree().set_input_as_handled()
		return

	if not esta_aberta:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.scancode:
			KEY_ESCAPE:
				fechar()
				get_tree().set_input_as_handled()
			KEY_A, KEY_LEFT:
				_trocar_item(-1)
				get_tree().set_input_as_handled()
			KEY_D, KEY_RIGHT:
				_trocar_item(1)
				get_tree().set_input_as_handled()


func _pode_abrir() -> bool:
	if typeof(Inventory) == TYPE_NIL or Inventory.esta_vazio():
		return false
	# Não abre por cima da tela de "item adquirido" nem de outras UIs
	# que já bloqueiam o jogo (carta, salvar, config, etc.)
	if typeof(TelaPickup) != TYPE_NIL and is_instance_valid(TelaPickup) and TelaPickup.painel.visible:
		return false
	if typeof(CartasUI) != TYPE_NIL and CartasUI.get("esta_aberta") == true:
		return false
	for grupo in ["save_ui", "config_screen", "cartas_inventory_ui"]:
		for n in get_tree().get_nodes_in_group(grupo):
			if is_instance_valid(n) and n.get("esta_aberta") != false:
				return false
	# Só abre na cena de jogo de verdade
	if typeof(SaveManager) != TYPE_NIL and "CENA_JOGO" in SaveManager:
		var cena = get_tree().current_scene
		if cena == null:
			return false
		var path := ""
		if "filename" in cena and cena.filename != "":
			path = cena.filename
		if path != SaveManager.CENA_JOGO:
			return false
	return true


func abrir() -> void:
	_atualizar_lista_disponiveis()
	if _ids_disponiveis.empty():
		return
	_indice_atual = clamp(_indice_atual, 0, _ids_disponiveis.size() - 1)
	esta_aberta = true
	visible = true
	get_tree().paused = true
	_mouse_antes = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_mostrar_item_atual()


func fechar() -> void:
	esta_aberta = false
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(_mouse_antes)


func _on_itens_mudaram(_item_id = null) -> void:
	if not esta_aberta:
		return
	_atualizar_lista_disponiveis()
	if _ids_disponiveis.empty():
		fechar()
		return
	_indice_atual = clamp(_indice_atual, 0, _ids_disponiveis.size() - 1)
	_mostrar_item_atual()


func _atualizar_lista_disponiveis() -> void:
	_ids_disponiveis.clear()
	if typeof(Inventory) == TYPE_NIL:
		return
	for item_id in Inventory.items:
		if CENA_POR_ITEM.has(item_id):
			_ids_disponiveis.append(item_id)


func _trocar_item(direcao: int) -> void:
	if _ids_disponiveis.size() <= 1:
		return
	_indice_atual = (_indice_atual + direcao + _ids_disponiveis.size()) % _ids_disponiveis.size()
	_mostrar_item_atual()


func _mostrar_item_atual() -> void:
	if is_instance_valid(_item_atual_no):
		_item_atual_no.queue_free()
	_item_atual_no = null

	if _indice_atual < 0 or _indice_atual >= _ids_disponiveis.size():
		return

	var item_id: String = _ids_disponiveis[_indice_atual]

	if _label_nome_item and typeof(Inventory) != TYPE_NIL:
		_label_nome_item.text = Inventory.get_item_name(item_id)

	var caminho: String = CENA_POR_ITEM.get(item_id, "")
	if caminho == "" or not ResourceLoader.exists(caminho):
		push_warning("[InventoryViewerUI] Cena não encontrada pra '%s': %s" % [item_id, caminho])
		return

	var cena: PackedScene = load(caminho)
	_item_atual_no = cena.instance()
	_item_holder.add_child(_item_atual_no)
	_item_atual_no.translation = Vector3.ZERO
	_item_atual_no.force_update_transform()

	var aabb := _get_aabb_combinada(_item_atual_no)
	if aabb.size.length() < 0.001:
		aabb = AABB(Vector3(-0.1, -0.1, -0.1), Vector3(0.2, 0.2, 0.2))
	_item_atual_no.translation = -(aabb.position + aabb.size / 2.0)

	var raio = aabb.size.length() / 2.0
	if raio <= 0.0:
		raio = 0.5
	var fov_rad = deg2rad(_camera.fov)
	var distancia = (raio / sin(fov_rad / 2.0)) * 1.4
	_camera.translation = Vector3(0, 0, distancia)
	_camera.look_at(Vector3.ZERO, Vector3.UP)
	_camera.near = 0.05
	_camera.far = max(distancia * 3.0, 5.0)

	_luz_principal.translation = Vector3(distancia * 0.45, distancia * 0.55, distancia * 0.9)
	_luz_principal.omni_range = max(distancia * 4.0, 8.0)


func _process(delta: float) -> void:
	if esta_aberta and is_instance_valid(_item_atual_no):
		_item_atual_no.rotate_y(deg2rad(VEL_ROTACAO * delta))

	# Só mostra as setas [A]/[D] se tiver mais de 1 item pra trocar
	if _label_a and _label_d:
		var mostrar_setas: bool = _ids_disponiveis.size() > 1
		_label_a.visible = mostrar_setas
		_label_d.visible = mostrar_setas

	if esta_aberta:
		_atualizar_estado_emocional(delta)


# Pega a Camera do jogador (grupo "camera_player") pra ler o estado emocional atual da Laura.
func _pegar_camera_jogador() -> Node:
	if not is_inside_tree():
		return null
	var nos = get_tree().get_nodes_in_group("camera_player")
	if nos.size() > 0 and is_instance_valid(nos[0]):
		return nos[0]
	return null


# Desenha o "eletrocardiograma" no lugar da barra de condição, refletindo
# a emoção atual da Laura (Calma / Com Medo / Assustada / Em Crise).
func _atualizar_estado_emocional(delta: float) -> void:
	if _grafico_emocao == null or _label_estado == null:
		return

	var emocao := 0
	var nome := "Calma"
	var cam = _pegar_camera_jogador()
	if cam and cam.has_method("get_emocao"):
		emocao = cam.get_emocao()
		if cam.has_method("get_emocao_nome"):
			nome = cam.get_emocao_nome()

	var visual = VISUAL_POR_EMOCAO.get(emocao, VISUAL_POR_EMOCAO[0])
	var cor: Color = visual["cor"]
	var amp: float = visual["amp"]
	var freq: float = visual["freq"]

	_tempo_onda += delta * freq
	_label_estado.text = "ESTADO: %s" % nome
	_label_estado.add_color_override("font_color", cor)
	_grafico_emocao.default_color = cor

	var largura := 198.0
	var altura := 30.0
	var passos := 40
	var pontos := PoolVector2Array()
	for i in range(passos + 1):
		var t: float = float(i) / passos
		var x: float = t * largura
		var y: float = altura * 0.5 - sin(t * TAU * 3.0 + _tempo_onda * 5.0) * amp * (altura * 0.5 - 4.0)
		pontos.append(Vector2(x, y))
	_grafico_emocao.points = pontos


# Mesma lógica de TelaPickup.gd: soma as AABBs de todos os MeshInstance
# filhos pra saber o tamanho real do modelo, mesmo com vários meshes.
func _get_aabb_combinada(node: Node) -> AABB:
	var resultado = {"aabb": AABB(), "definida": false}
	_coletar_aabb(node, node, resultado)
	return resultado["aabb"]


func _coletar_aabb(raiz: Node, node: Node, resultado: Dictionary) -> void:
	if node is VisualInstance and node.visible:
		var transform_relativo = raiz.global_transform.affine_inverse() * node.global_transform
		var aabb_local = transform_relativo.xform(node.get_aabb())
		if not resultado["definida"]:
			resultado["aabb"] = aabb_local
			resultado["definida"] = true
		else:
			resultado["aabb"] = resultado["aabb"].merge(aabb_local)
	for filho in node.get_children():
		_coletar_aabb(raiz, filho, resultado)
