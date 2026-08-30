extends Node

# Flags de tutoriais já exibidos
var lanterna_mostrado   : bool = false
var interagir_mostrado  : bool = false
var tab_mostrado        : bool = false
var ctrl_mostrado       : bool = false
var emocao_mostrado     : bool = false
var sair_quarto_mostrado: bool = false
var correr_mostrado    : bool = false
var cartas_mostrado    : bool = false

var exibindo           : bool = false
var fila               : Array = []

# UI de dicas rápidas (baixo da tela)
var label : Label = null
var canvas : CanvasLayer = null
var fonte: DynamicFont = null
const MINIPIXEL_PATH = "res://assets/fonts/MiniPixel/Minipixel-Regular.ttf"

# UI de tutorial "tela cheia" (emoção)
var painel_emocao : Control = null
var label_titulo  : Label = null
var label_corpo   : Label = null
var label_continuar : Label = null
var _esperando_input_emocao : bool = false

# UI de legenda narrativa (sair do quarto)
var label_legenda : Label = null
var canvas_legenda : CanvasLayer = null

func _ready():
	add_to_group("tutorial_manager")
	pause_mode = Node.PAUSE_MODE_PROCESS

	fonte = DynamicFont.new()
	fonte.font_data = load(MINIPIXEL_PATH)
	fonte.size = 26

	# --- Dicas rápidas (já existiam) ---
	canvas = CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	label = Label.new()
	label.set("custom_fonts/font", fonte)
	label.align = Label.ALIGN_CENTER
	label.anchor_left   = 0.0
	label.anchor_right  = 1.0
	label.anchor_top    = 1.0
	label.anchor_bottom = 1.0
	label.margin_top    = -60.0
	label.margin_bottom = -20.0
	label.modulate.a    = 0.0
	label.add_color_override("font_color", Color(1, 1, 1, 1))
	canvas.add_child(label)

	# --- Legenda narrativa (estilo subtítulo) ---
	canvas_legenda = CanvasLayer.new()
	canvas_legenda.layer = 12
	add_child(canvas_legenda)

	label_legenda = Label.new()
	label_legenda.set("custom_fonts/font", fonte)
	label_legenda.align = Label.ALIGN_CENTER
	label_legenda.autowrap = true
	label_legenda.anchor_left   = 0.1
	label_legenda.anchor_right  = 0.9
	label_legenda.anchor_top    = 0.78
	label_legenda.anchor_bottom = 0.92
	label_legenda.margin_left   = 0
	label_legenda.margin_right  = 0
	label_legenda.margin_top    = 0
	label_legenda.margin_bottom = 0
	label_legenda.modulate.a    = 0.0
	label_legenda.add_color_override("font_color", Color(0.92, 0.92, 0.95, 1.0))
	label_legenda.visible = false
	canvas_legenda.add_child(label_legenda)

	# --- Painel de tutorial de emoção ---
	_criar_painel_emocao()

func _criar_painel_emocao() -> void:
	painel_emocao = Control.new()
	painel_emocao.anchor_left = 0
	painel_emocao.anchor_top = 0
	painel_emocao.anchor_right = 1
	painel_emocao.anchor_bottom = 1
	painel_emocao.mouse_filter = Control.MOUSE_FILTER_STOP
	painel_emocao.visible = false
	painel_emocao.pause_mode = Node.PAUSE_MODE_PROCESS
	canvas.add_child(painel_emocao)

	# Fundo escurecido
	var fundo = ColorRect.new()
	fundo.anchor_left = 0
	fundo.anchor_top = 0
	fundo.anchor_right = 1
	fundo.anchor_bottom = 1
	fundo.color = Color(0, 0, 0, 0.72)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	painel_emocao.add_child(fundo)

	# Caixa central
	var caixa = Panel.new()
	caixa.anchor_left = 0.5
	caixa.anchor_top = 0.5
	caixa.anchor_right = 0.5
	caixa.anchor_bottom = 0.5
	caixa.margin_left = -280
	caixa.margin_right = 280
	caixa.margin_top = -160
	caixa.margin_bottom = 160
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel_emocao.add_child(caixa)

	label_titulo = Label.new()
	label_titulo.set("custom_fonts/font", fonte)
	label_titulo.align = Label.ALIGN_CENTER
	label_titulo.anchor_left = 0
	label_titulo.anchor_right = 1
	label_titulo.anchor_top = 0
	label_titulo.margin_top = 24
	label_titulo.margin_bottom = 56
	label_titulo.text = "Estado Emocional"
	label_titulo.add_color_override("font_color", Color(1, 0.85, 0.75, 1))
	caixa.add_child(label_titulo)

	label_corpo = Label.new()
	label_corpo.set("custom_fonts/font", fonte)
	label_corpo.align = Label.ALIGN_CENTER
	label_corpo.valign = Label.VALIGN_CENTER
	label_corpo.autowrap = true
	label_corpo.anchor_left = 0
	label_corpo.anchor_right = 1
	label_corpo.anchor_top = 0
	label_corpo.anchor_bottom = 1
	label_corpo.margin_left = 28
	label_corpo.margin_right = -28
	label_corpo.margin_top = 64
	label_corpo.margin_bottom = -48
	label_corpo.add_color_override("font_color", Color(0.95, 0.95, 0.95, 1))
	label_corpo.text = (
		"O aviso no canto da tela mostra como Laura está se sentindo.\n\n"
		+ "Calma → Com Medo → Assustada → Em Crise\n\n"
		+ "A tensão sobe no escuro e perto da Sombra.\n"
		+ "Luz e fitas calmantes ajudam a acalmar.\n\n"
		+ "Quanto pior o estado, mais a visão e o movimento sofrem."
	)
	caixa.add_child(label_corpo)

	label_continuar = Label.new()
	label_continuar.set("custom_fonts/font", fonte)
	label_continuar.align = Label.ALIGN_CENTER
	label_continuar.anchor_left = 0
	label_continuar.anchor_right = 1
	label_continuar.anchor_top = 1
	label_continuar.anchor_bottom = 1
	label_continuar.margin_top = -36
	label_continuar.margin_bottom = -12
	label_continuar.text = "Pressione E ou ESC para continuar"
	label_continuar.add_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	caixa.add_child(label_continuar)

func limpar_ui_ao_sair() -> void:
	fila.clear()
	exibindo = false
	_esperando_input_emocao = false
	if label:
		label.modulate.a = 0.0
	if canvas:
		canvas.visible = false
	if painel_emocao:
		painel_emocao.visible = false
	if label_legenda:
		label_legenda.visible = false
		label_legenda.modulate.a = 0.0

func esconder_para_pause() -> void:
	# Não fecha o tutorial de emoção a meio se estiver esperando input —
	# só esconde UI de dicas pra não ficar por cima do pause.
	if label:
		label.modulate.a = 0.0
	if canvas:
		canvas.visible = false
	if painel_emocao and painel_emocao.visible:
		painel_emocao.visible = false
		_esperando_input_emocao = false
		if get_tree().paused:
			pass  # pause_game já pausou; não mexe em get_tree().paused aqui
	if label_legenda:
		label_legenda.visible = false
		label_legenda.modulate.a = 0.0

# ==================== SAVE / LOAD ====================

func save_data() -> Dictionary:
	return {
		"lanterna_mostrado"    : lanterna_mostrado,
		"interagir_mostrado"   : interagir_mostrado,
		"tab_mostrado"         : tab_mostrado,
		"ctrl_mostrado"        : ctrl_mostrado,
		"emocao_mostrado"      : emocao_mostrado,
		"sair_quarto_mostrado" : sair_quarto_mostrado,
		"correr_mostrado"      : correr_mostrado,
		"cartas_mostrado"      : cartas_mostrado,
	}

func load_data(data: Dictionary) -> void:
	lanterna_mostrado    = data.get("lanterna_mostrado", false)
	interagir_mostrado   = data.get("interagir_mostrado", false)
	tab_mostrado         = data.get("tab_mostrado", false)
	ctrl_mostrado        = data.get("ctrl_mostrado", false)
	emocao_mostrado      = data.get("emocao_mostrado", false)
	sair_quarto_mostrado = data.get("sair_quarto_mostrado", false)
	correr_mostrado      = data.get("correr_mostrado", false)
	cartas_mostrado      = data.get("cartas_mostrado", false)
	fila.clear()
	exibindo = false
	_esperando_input_emocao = false
	print("TutorialManager restaurado via Autoload")

# ==================== TUTORIAIS RÁPIDOS ====================

func tutorial_lanterna():
	if lanterna_mostrado:
		return
	lanterna_mostrado = true
	fila.append("Pressione \"F\" para ligar ou desligar a lanterna")
	_processar_fila()

func tutorial_interagir():
	if interagir_mostrado:
		return
	interagir_mostrado = true
	fila.append("Pressione \"E\" ou o botão esquerdo do mouse para interagir")
	_processar_fila()

func tutorial_inventario():
	if tab_mostrado:
		return
	tab_mostrado = true
	fila.append("*delay*")
	fila.append("Pressione \"TAB\" para ver o inventário")
	_processar_fila()

func tutorial_agachar():
	if ctrl_mostrado:
		return
	ctrl_mostrado = true
	fila.append("*delay*")
	fila.append("Segure \"CTRL\" para se agachar")
	_processar_fila()

func tutorial_correr():
	if correr_mostrado:
		return
	correr_mostrado = true
	fila.append("*delay*")
	fila.append("Pressione \"Shift\" para correr")
	_processar_fila()

func tutorial_cartas():
	if cartas_mostrado:
		return
	cartas_mostrado = true
	fila.append("*delay*")
	fila.append("Pressione \"C\" para abrir o inventário de coletáveis")
	_processar_fila()

# ==================== TUTORIAL DE EMOÇÃO (tela) ====================

func tutorial_emocao():
	if emocao_mostrado:
		return
	emocao_mostrado = true
	_mostrar_painel_emocao()

func _mostrar_painel_emocao() -> void:
	if painel_emocao == null:
		return
	# Pausa o jogo pra o jogador ler com calma
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	painel_emocao.visible = true
	painel_emocao.modulate.a = 0.0
	_esperando_input_emocao = true

	var tween = Tween.new()
	tween.pause_mode = Node.PAUSE_MODE_PROCESS
	add_child(tween)
	tween.interpolate_property(painel_emocao, "modulate:a", 0.0, 1.0, 0.35,
		Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.start()
	yield(tween, "tween_all_completed")
	tween.queue_free()

func _fechar_painel_emocao() -> void:
	if not _esperando_input_emocao:
		return
	_esperando_input_emocao = false

	var tween = Tween.new()
	tween.pause_mode = Node.PAUSE_MODE_PROCESS
	add_child(tween)
	tween.interpolate_property(painel_emocao, "modulate:a", painel_emocao.modulate.a, 0.0, 0.25,
		Tween.TRANS_SINE, Tween.EASE_IN)
	tween.start()
	yield(tween, "tween_all_completed")
	tween.queue_free()

	painel_emocao.visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Continua a fila de dicas, se houver algo esperando
	_processar_fila()

func _input(event) -> void:
	if not event.is_action_pressed("esc") or event.echo:
		return
	var emotion_tuts = get_tree().get_nodes_in_group("emotion_tutorial")
	if emotion_tuts.size() > 0:
		return
		
	if not _esperando_input_emocao:
		return
	if event.is_action_pressed("e") or event.is_action_pressed("ui_cancel") \
			or (event is InputEventKey and event.pressed and event.scancode == KEY_ESCAPE):
		_fechar_painel_emocao()
		get_tree().set_input_as_handled()

# ==================== LEGENDA AO SAIR DO QUARTO ====================

func tutorial_sair_quarto():
	if sair_quarto_mostrado:
		return
	# Bloqueia se a casa estiver rodando só como fundo do menu
	if typeof(Global) != TYPE_NIL and Global.rodando_como_menu_bg:
		return
	sair_quarto_mostrado = true
	_mostrar_legenda(
		"Essa casa... eu me lembro dela. Talvez eu devesse procurar algo que me ajude a saber o porquê eu estou aqui.",
		6.5
	)

func _mostrar_legenda(texto: String, duracao: float = 5.0) -> void:
	if label_legenda == null:
		return
	label_legenda.text = texto
	label_legenda.visible = true
	label_legenda.modulate.a = 0.0

	var tween = Tween.new()
	add_child(tween)
	tween.interpolate_property(label_legenda, "modulate:a", 0.0, 1.0, 0.6,
		Tween.TRANS_SINE, Tween.EASE_OUT)
	tween.start()
	yield(tween, "tween_all_completed")

	yield(get_tree().create_timer(duracao, false), "timeout")

	tween.interpolate_property(label_legenda, "modulate:a", label_legenda.modulate.a, 0.0, 0.8,
		Tween.TRANS_SINE, Tween.EASE_IN)
	tween.start()
	yield(tween, "tween_all_completed")
	label_legenda.visible = false
	tween.queue_free()

# ==================== FILA DE DICAS RÁPIDAS ====================

func _processar_fila():
	if exibindo or fila.empty():
		return
	if get_tree().paused:
		return
	if _esperando_input_emocao:
		return
	exibindo = true
	_exibir_proximo()

func _exibir_proximo():
	if fila.empty():
		exibindo = false
		return
	if get_tree().paused or _esperando_input_emocao:
		exibindo = false
		return
	if canvas:
		canvas.visible = true

	var msg = fila.pop_front()
	if msg == "*delay*":
		yield(get_tree().create_timer(3.0, false), "timeout")
		_exibir_proximo()
		return
	label.text = msg
	_fade(1.0, 0.5)
	yield(get_tree().create_timer(3.0, false), "timeout")
	_fade(0.0, 0.5)
	yield(get_tree().create_timer(0.5, false), "timeout")
	_exibir_proximo()

func _fade(alvo: float, duracao: float):
	var tween = Tween.new()
	add_child(tween)
	tween.interpolate_property(label, "modulate:a", label.modulate.a, alvo, duracao, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_completed")
	tween.queue_free()
