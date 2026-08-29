extends CanvasLayer
# =====================================================================
# CARTAS UI — leitura de uma carta (sem pausar o jogo)
# =====================================================================
# Anexe na raiz da cena CartasUI.tscn (CanvasLayer).
# Autoload sugerido: CartasUI (a CENA, não o .gd solto).
#
# Hierarquia esperada (ajuste os caminhos se os seus nós tiverem outros nomes):
#   CartasUI (CanvasLayer)  ← este script
#   └── Control / Painel
#       ├── Titulo   (Label)  — nome da carta
#       └── Texto    (Label ou RichTextLabel) — conteúdo
#
# Comportamento:
#   - Começa TOTALMENTE escondida (só aparece em mostrar())
#   - Qualquer tecla (ou clique) fecha a UI
#   - NÃO chama get_tree().paused — o mundo continua "vivo", mas o input
#     do player é bloqueado via flag esta_aberta
#   - ESC NÃO abre o pause (InputManager checa esta_aberta)
#   - Layer alto pra ficar acima de tutoriais / HUD
# =====================================================================

signal fechou()

export var layer_ui: int = 110

# Caminhos opcionais — se vazios, procura por nomes comuns
export(NodePath) var caminho_painel
export(NodePath) var caminho_titulo
export(NodePath) var caminho_texto

var esta_aberta: bool = false
var _painel: Control = null
var _titulo: Label = null
var _texto = null  # Label ou RichTextLabel
var _mouse_antes: int = Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	layer = layer_ui
	add_to_group("cartas_ui")
	add_to_group("ui_bloqueia_pause")
	_resolver_nos()
	# CRÍTICO: começa invisível — só aparece quando pegar uma carta
	_esconder_tudo()
	set_process_input(true)


func _esconder_tudo() -> void:
	esta_aberta = false
	visible = false
	if _painel and is_instance_valid(_painel):
		_painel.visible = false
	# Garante que nenhum filho Control fique desenhando por cima do jogo
	for c in get_children():
		if c is CanvasItem:
			c.visible = false


func _resolver_nos() -> void:
	if caminho_painel:
		_painel = get_node_or_null(caminho_painel) as Control
	if caminho_titulo:
		_titulo = get_node_or_null(caminho_titulo) as Label
	if caminho_texto:
		_texto = get_node_or_null(caminho_texto)

	if _painel == null:
		_painel = _achar_controle(["Painel", "Control", "Panel", "PanelContainer"])
	if _titulo == null:
		_titulo = _achar_label(["Titulo", "Título", "Title", "Nome", "LabelTitulo"])
	if _texto == null:
		_texto = _achar_texto(["Texto", "Conteudo", "Conteúdo", "Descricao", "Descrição", "Body", "RichTextLabel"])


func _achar_controle(nomes: Array) -> Control:
	for n in nomes:
		var node = find_node(n, true, false)
		if node is Control:
			return node
	# fallback: primeiro Control filho
	for c in get_children():
		if c is Control:
			return c
	return null


func _achar_label(nomes: Array) -> Label:
	for n in nomes:
		var node = find_node(n, true, false)
		if node is Label:
			return node
	return null


func _achar_texto(nomes: Array):
	for n in nomes:
		var node = find_node(n, true, false)
		if node is Label or node is RichTextLabel:
			return node
	return null


## API pública — mostra a carta com nome + conteúdo
func mostrar(nome: String, conteudo: String) -> void:
	_resolver_nos()
	if _titulo:
		_titulo.text = nome
	if _texto:
		if _texto is RichTextLabel:
			_texto.bbcode_enabled = false
			_texto.text = conteudo
		else:
			_texto.text = conteudo

	esta_aberta = true
	# Revela CanvasLayer + filhos
	visible = true
	for c in get_children():
		if c is CanvasItem:
			c.visible = true
	if _painel:
		_painel.visible = true

	# Mouse livre pra ler, mas SEM pausar a árvore
	_mouse_antes = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Avisa tutoriais pra não sobrepor
	_notificar_tutoriais(true)


func fechar() -> void:
	if not esta_aberta:
		# Mesmo se a flag estiver inconsistente, garante que some da tela
		_esconder_tudo()
		return
	esta_aberta = false
	_esconder_tudo()
	Input.set_mouse_mode(_mouse_antes)
	_notificar_tutoriais(false)
	emit_signal("fechou")

	# Libera fila de tutoriais (mesmo padrão do TelaPickup)
	if is_inside_tree():
		for manager in get_tree().get_nodes_in_group("tutorial_manager"):
			if manager.has_method("_processar_fila"):
				manager._processar_fila()


func _notificar_tutoriais(bloqueando: bool) -> void:
	if not is_inside_tree():
		return
	for tm in get_tree().get_nodes_in_group("tutorial_manager"):
		if not is_instance_valid(tm):
			continue
		if bloqueando and tm.has_method("esconder_para_pause"):
			tm.esconder_para_pause()
		elif not bloqueando and tm.has_method("mostrar_apos_pause"):
			tm.mostrar_apos_pause()


func _input(event) -> void:
	if not esta_aberta:
		return

	# Qualquer tecla ou clique fecha
	var fechar_agora := false
	if event is InputEventKey and event.pressed and not event.echo:
		fechar_agora = true
	elif event is InputEventMouseButton and event.pressed:
		fechar_agora = true
	elif event is InputEventJoypadButton and event.pressed:
		fechar_agora = true

	if fechar_agora:
		fechar()
		get_tree().set_input_as_handled()


## Compat: alguns sistemas checam .painel.visible (igual TelaPickup)
func get_painel_visivel() -> bool:
	return esta_aberta
