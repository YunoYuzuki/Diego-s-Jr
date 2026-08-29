extends StaticBody
#  Portinha 
const PORTINHA_ABERTA_TRANS  = Vector3(-0.042, -0.017, 1.086)
const PORTINHA_FECHADA_TRANS = Vector3(-0.042, -0.007, 1.086)
const PORTINHA_FECHADA_ROT   = Vector3(0.0, 0.0, -25.0)
export(float) var tween_speed    = 0.3
export(float) var audio_max_distance : float = 55.0
export(float) var audio_unit_db : float = 8.0

# Cor padrão usada caso a fita não defina uma cor própria (fita_cor vazia/nula).
export(Color) var cor_legenda_padrao = Color(1, 1, 1, 1)

onready var portinha     = $portinha
onready var outline_mesh = $gravador/OutlineMesh
# Pode ser o nó da cena (2D) ou o 3D que criamos em _ready
var audio_player = null
var fita_tocando : bool = false
var jogador      : Node = null
# Incrementado ao cancelar (save) — o yield do _tocar_fita checa isso
# pra NÃO consumir a fita / marcar como reproduzida se foi interrompida.
var _reproducao_id : int = 0
# Snapshot da fita em reprodução (pra devolver pro inventário/câmera se o save cancelar)
var _audio_em_reproducao : AudioStream = null
var _nome_em_reproducao : String = ""
var _texto_em_reproducao : String = ""
var _cor_em_reproducao : Color = Color(1, 1, 1, 1)
var _fita_finished_flag : bool = false

func _on_fita_finished_sinal() -> void:
	_fita_finished_flag = true

func _ready():
	add_to_group("interagivel")
	add_to_group("Persist_estatico")
	add_to_group("Persist")
	add_to_group("gravador")
	add_to_group("cassette_player")  # Camera procura esse grupo pro cassete calmante
	if outline_mesh:
		outline_mesh.visible = false
	_set_portinha_aberta(true)
	_garantir_audio_3d()

func _garantir_audio_3d() -> void:
	# Troca o AudioStreamPlayer 2D da cena por um 3D posicional
	var antigo = get_node_or_null("AudioStreamPlayer")
	if antigo and not (antigo is AudioStreamPlayer3D):
		antigo.stop()
		antigo.queue_free()
	audio_player = get_node_or_null("AudioStreamPlayer3D")
	if audio_player == null:
		audio_player = AudioStreamPlayer3D.new()
		audio_player.name = "AudioStreamPlayer3D"
		add_child(audio_player)
	audio_player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	audio_player.unit_db = audio_unit_db
	audio_player.unit_size = 10.0
	audio_player.max_distance = audio_max_distance
	audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
	# Com o jogo pausado a fita PARA (PAUSE_MODE_STOP = padrão do engine)
	audio_player.pause_mode = Node.PAUSE_MODE_STOP
func set_foco(ativo: bool):
	if outline_mesh:
		outline_mesh.visible = ativo
# 
func interagir(camera):
	if fita_tocando:
		return
	if not Inventory.has_item("fita_cassete"):
		camera._mostrar_mensagem("Voce nao possui nenhuma fita.")
		return
	jogador = camera.get_parent()
	var audio = camera.fita_audio
	var nome  = camera.fita_nome
	# Texto e cor da legenda dessa fita específica (defina fita_texto e
	# fita_cor junto de fita_audio/fita_nome, no script que guarda esses dados).
	var texto = camera.fita_texto if "fita_texto" in camera else ""
	var cor   = camera.fita_cor if "fita_cor" in camera else cor_legenda_padrao

	# Sem áudio/nome válidos = inventário tem item “fantasma” (ex.: pegou fita 2
	# enquanto a 1 tocava e o fim da 1 apagou os dados da câmera).
	if audio == null or nome == "":
		camera._mostrar_mensagem("Essa fita parece estar em branco...")
		# Remove o item inválido pra não travar o inventário
		if Inventory.has_item("fita_cassete"):
			Inventory.remove_item("fita_cassete")
		return

	# Tira a fita do inventário na hora em que é colocada no gravador
	if Inventory.has_item("fita_cassete"):
		Inventory.remove_item("fita_cassete")

	# Preserva flag calmante durante a reprodução (Camera alivia tensão com isso)
	var era_calmante = false
	if camera and "fita_e_calmante" in camera:
		era_calmante = bool(camera.fita_e_calmante)

	# Limpa áudio/nome da câmera; mantém fita_e_calmante enquanto toca
	if camera:
		camera.fita_audio = null
		camera.fita_nome = ""
		camera.fita_texto = ""
		camera.fita_e_calmante = era_calmante

	_tocar_fita(camera, audio, nome, texto, cor, era_calmante)

func _tocar_fita(camera, audio: AudioStream, nome: String, texto: String = "", cor: Color = Color(1, 1, 1, 1), era_calmante: bool = false):
	fita_tocando = true
	var id_desta = _reproducao_id
	# Snapshot local + no gravador (pro cancelar_save devolver a fita certa)
	var nome_desta_reproducao = nome
	_audio_em_reproducao = audio
	_nome_em_reproducao = nome
	_texto_em_reproducao = texto
	_cor_em_reproducao = cor
	_animar_portinha(false)
	yield(get_tree().create_timer(tween_speed + 0.1), "timeout")
	# Cancelada durante a animação da portinha (ex.: auto-save)
	if id_desta != _reproducao_id or not fita_tocando:
		return
	if camera and camera.has_method("mostrar_cassete_ui"):
		camera.mostrar_cassete_ui(nome_desta_reproducao)
	if audio_player is AudioStreamPlayer3D:
		audio_player.unit_db = audio_unit_db
	else:
		audio_player.volume_db = 0.0
	# Fala legenda só se tiver texto; áudio sempre toca
	if texto != null and String(texto).strip_edges() != "":
		Legendas.falar(audio_player, audio, texto, cor)
	else:
		if audio_player is AudioStreamPlayer3D:
			audio_player.unit_db = audio_unit_db
		audio_player.stream = audio
		audio_player.play()

	# pause_mode padrão: com o jogo pausado a fita e a legenda PAUSAM
	# (não PROCESS — senão o pause não para o áudio)
	if audio_player:
		audio_player.pause_mode = Node.PAUSE_MODE_STOP

	# Espera o fim natural. Não retoma à força — só não deixa a legenda/outros
	# darem stop() no meio (Legendas.parar não para mais o áudio da fita).
	_fita_finished_flag = false
	if audio_player.is_connected("finished", self, "_on_fita_finished_sinal"):
		audio_player.disconnect("finished", self, "_on_fita_finished_sinal")
	audio_player.connect("finished", self, "_on_fita_finished_sinal", [], CONNECT_ONESHOT)

	while id_desta == _reproducao_id and fita_tocando:
		if _fita_finished_flag:
			break
		# Durante pause do jogo, só espera (áudio/legenda ficam pausados pelo engine)
		if get_tree().paused:
			yield(get_tree().create_timer(0.15), "timeout")
			continue
		if audio_player == null or not is_instance_valid(audio_player):
			break
		# Fim real: não está tocando e não está stream_paused (pause manual)
		var pausado = ("stream_paused" in audio_player) and audio_player.stream_paused
		if not audio_player.playing and not pausado:
			break
		yield(get_tree().create_timer(0.15), "timeout")

	_fita_finished_flag = false

	# Se o save interrompeu a fita, o cancelar_reproducao_para_save já tratou
	if id_desta != _reproducao_id or not fita_tocando:
		return

	_finalizar_reproducao(camera, nome_desta_reproducao, era_calmante)

func _finalizar_reproducao(camera, nome_desta_reproducao: String, era_calmante: bool = false) -> void:
	SaveManager.marcar_fita_reproduzida(nome_desta_reproducao)

	var sombras = get_tree().get_nodes_in_group("sombra")
	if sombras.size() > 0 and sombras[0].has_method("ao_ouvir_fita"):
		sombras[0].ao_ouvir_fita()

	# Quarto da Laura: libera cama / fita seguinte / ursinho etc.
	if typeof(QuartoLaura) != TYPE_NIL and QuartoLaura.has_method("ao_fita_reproduzida"):
		QuartoLaura.ao_fita_reproduzida(nome_desta_reproducao)
	else:
		get_tree().call_group("quarto_laura", "atualizar_visibilidade")

	_audio_em_reproducao = null
	_nome_em_reproducao = ""
	_texto_em_reproducao = ""

	if camera:
		if camera.has_method("esconder_cassete_ui"):
			camera.esconder_cassete_ui()
		# Fim da fita — desliga flag calmante
		if "fita_e_calmante" in camera:
			camera.fita_e_calmante = false
	_animar_portinha(true)
	fita_tocando = false
	jogador = null
# 
func _animar_portinha(abrir: bool):
	var tween = Tween.new()
	add_child(tween)
	var trans_alvo = PORTINHA_ABERTA_TRANS  if abrir else PORTINHA_FECHADA_TRANS
	var rot_alvo   = Vector3.ZERO           if abrir else PORTINHA_FECHADA_ROT
	tween.interpolate_property(portinha, "translation",
		portinha.translation, trans_alvo,
		tween_speed, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	tween.interpolate_property(portinha, "rotation_degrees",
		portinha.rotation_degrees, rot_alvo,
		tween_speed, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_all_completed")
	tween.queue_free()
func _set_portinha_aberta(abrir: bool):
	portinha.translation      = PORTINHA_ABERTA_TRANS  if abrir else PORTINHA_FECHADA_TRANS
	portinha.rotation_degrees = Vector3.ZERO           if abrir else PORTINHA_FECHADA_ROT

# Chamado pelo SaveManager ANTES de gravar o save.
# Se a fita estiver tocando, interrompe limpo: fita continua no inventário,
# NÃO marca como reproduzida, portinha volta a abrir, UI some.
func cancelar_reproducao_para_save() -> void:
	if not fita_tocando:
		return
	_reproducao_id += 1  # invalida o yield ativo do _tocar_fita
	if audio_player and audio_player.playing:
		audio_player.stop()
	if typeof(Legendas) != TYPE_NIL and Legendas.has_method("parar"):
		Legendas.parar()
	# Devolve a fita ao inventário (foi removida ao colocar, mas o áudio não terminou)
	if not Inventory.has_item("fita_cassete"):
		Inventory.add_item("fita_cassete")
	# Restaura os dados da fita na câmera (foram limpos ao colocar no gravador)
	var cams = get_tree().get_nodes_in_group("camera_player")
	for cam in cams:
		# Só restaura se a câmera NÃO tiver outra fita mais nova (pegada no meio)
		var tem_outra = ("fita_nome" in cam) and str(cam.fita_nome) != "" and str(cam.fita_nome) != _nome_em_reproducao
		if not tem_outra:
			cam.fita_audio = _audio_em_reproducao
			cam.fita_nome = _nome_em_reproducao
			cam.fita_texto = _texto_em_reproducao
			if "fita_cor" in cam:
				cam.fita_cor = _cor_em_reproducao
		if cam.has_method("esconder_cassete_ui"):
			cam.esconder_cassete_ui()
		break
	_audio_em_reproducao = null
	_nome_em_reproducao = ""
	_texto_em_reproducao = ""
	_set_portinha_aberta(true)
	fita_tocando = false
	jogador = null

func save() -> Dictionary:
	return {
		"fita_tocando": false  # nunca persiste reprodução a meio — sempre estado idle
	}

func load_data(_data: Dictionary) -> void:
	# Garante estado limpo após load (portinha aberta, sem áudio residual)
	if audio_player and audio_player.playing:
		audio_player.stop()
	fita_tocando = false
	jogador = null
	_set_portinha_aberta(true)
