extends StaticBody
export(String) var nome_lampada = ""
export(AudioStream) var som_switch
var ligada  = false
var lampada = null
onready var lightswitch  = $Lightswitch
onready var lightswitch2 = $Lightswitch2
onready var outline1     = $Lightswitch/OutlineMesh
onready var outline2     = $Lightswitch2/OutlineMesh
var audio_player : AudioStreamPlayer3D

func _ready():
	add_to_group("Persist_estatico")
	add_to_group("Persist")
	add_to_group("interagivel")
	add_to_group("lightswitch")
	lampada = get_tree().get_root().find_node(nome_lampada, true, false)
	lightswitch.visible  = true
	lightswitch2.visible = false
	outline1.visible     = false
	outline2.visible     = false
	if lampada:
		lampada.visible = false

	audio_player = AudioStreamPlayer3D.new()
	audio_player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	audio_player.unit_db = 10.0
	audio_player.unit_size = 10.0
	audio_player.max_distance = 40.0
	audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
	add_child(audio_player)
	if som_switch:
		audio_player.stream = som_switch

func set_foco(ativo):
	if ligada:
		outline2.visible = ativo
	else:
		outline1.visible = ativo

func interagir(player):
	if not lampada:
		return
	# Blackout da Sombra: não deixa religar
	if typeof(Global) != TYPE_NIL and "luzes_bloqueadas" in Global and Global.luzes_bloqueadas:
		if audio_player and audio_player.stream:
			audio_player.play()
		return
	ligada = not ligada
	_atualizar_estado_visual()
	if audio_player and audio_player.stream:
		audio_player.play()

## Força estado (usado pela Sombra em blackout etc.) — altera switch + lâmpada
func forcar_estado(nova_ligada: bool, tocar_som: bool = false) -> void:
	ligada = nova_ligada
	_atualizar_estado_visual()
	if tocar_som and audio_player and audio_player.stream:
		audio_player.play()

## Só aplica o estado ATUAL do switch na lâmpada (não muda `ligada`).
## Usado após o flicker da Sombra: a luz volta pro que o interruptor indica.
func aplicar_estado_na_lampada() -> void:
	if not lampada:
		lampada = get_tree().get_root().find_node(nome_lampada, true, false)
	_atualizar_estado_visual()

## Sincroniza o switch com o estado atual da lâmpada (visible)
## Cuidado: NÃO usar depois do flicker — o flicker só mexe no visible da luz.
func sincronizar_com_lampada(tocar_som: bool = false) -> void:
	if not lampada:
		lampada = get_tree().get_root().find_node(nome_lampada, true, false)
	if not lampada:
		return
	forcar_estado(lampada.visible, tocar_som)

func _atualizar_estado_visual():
	if ligada:
		lightswitch.visible  = false
		lightswitch2.visible = true
		if lampada:
			lampada.visible  = true
	else:
		lightswitch2.visible = false
		lightswitch.visible  = true
		if lampada:
			lampada.visible  = false

# ENVIANDO DADOS DIRETOS AO DICIONÁRIO COMPACTO
func save() -> Dictionary:
	return {
		"ligada": ligada
	}

func load_data(data: Dictionary) -> void:
	ligada = data.get("ligada", false)
	
	# Força a busca pela lâmpada na árvore se ela sumiu na troca de cena
	if not lampada:
		lampada = get_tree().get_root().find_node(nome_lampada, true, false)
		
	# Força as malhas visuais e a luz a ligarem ou desligarem fisicamente
	if not lightswitch:
		lightswitch  = $Lightswitch
		lightswitch2 = $Lightswitch2
		
	if ligada:
		lightswitch.visible  = false
		lightswitch2.visible = true
		if lampada:
			lampada.visible = true
	else:
		lightswitch.visible  = true
		lightswitch2.visible = false
		if lampada:
			lampada.visible = false
