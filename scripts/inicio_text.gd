extends CanvasLayer

export var velocidade_texto : float = 0.045
export var tempo_tela_preta : float = 2.0
export var tempo_apos_texto : float = 1.0

onready var text_label = $Text_Label
onready var continue_label = $Label
onready var color_rect = $ColorRect

var linhas = []
var linha_atual : int = 0
var texto_atual : String = ""
var indice_letra : float = 0.0
var escrevendo : bool = false
var esperando_tecla : bool = false
var aguardando_apos_texto : bool = false

func _ready():
	# Pega o texto que já está escrito no Label e divide em parágrafos
	var texto_completo = text_label.text.strip_edges()
	linhas = []
	for paragrafo in texto_completo.split("\n"):
		var limpo = paragrafo.strip_edges()
		if limpo != "":
			linhas.append(limpo)
	
	text_label.visible = false
	continue_label.visible = false
	text_label.text = ""
	continue_label.text = "Pressione qualquer tecla para continuar"
	
	# Tela preta inicial
	yield(get_tree().create_timer(tempo_tela_preta), "timeout")
	iniciar_proxima_linha()

func _process(delta):
	if not escrevendo:
		return
	
	indice_letra += delta / velocidade_texto
	
	if indice_letra >= texto_atual.length():
		_completar_texto()
	else:
		text_label.text = texto_atual.substr(0, int(indice_letra))
		text_label.visible = true

func _input(event):
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	
	# Durante a digitação: Enter ou Espaço completa a mensagem imediatamente
	if escrevendo:
		var tecla = event.scancode
		if tecla == KEY_ENTER or tecla == KEY_KP_ENTER or tecla == KEY_SPACE:
			_completar_texto()
		return
	
	# Depois que o "pressione qualquer tecla" apareceu
	if esperando_tecla:
		esperando_tecla = false
		continue_label.visible = false
		linha_atual += 1
		
		if linha_atual < linhas.size():
			iniciar_proxima_linha()
		else:
			text_label.visible = false
			continue_label.visible = false
			yield(get_tree().create_timer(tempo_tela_preta), "timeout")
			get_tree().change_scene("res://scenes/casa_ofc.tscn")

func _completar_texto():
	if not escrevendo:
		return
	escrevendo = false
	text_label.text = texto_atual
	text_label.visible = true
	_apos_texto_completo()

func _apos_texto_completo():
	if aguardando_apos_texto:
		return
	aguardando_apos_texto = true
	yield(get_tree().create_timer(tempo_apos_texto), "timeout")
	aguardando_apos_texto = false
	continue_label.visible = true
	esperando_tecla = true

func iniciar_proxima_linha():
	texto_atual = linhas[linha_atual]
	indice_letra = 0.0
	text_label.text = ""
	text_label.visible = false
	continue_label.visible = false
	escrevendo = true
	esperando_tecla = false
	aguardando_apos_texto = false
