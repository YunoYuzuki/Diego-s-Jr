extends CanvasLayer
# =====================================================================
# LEGENDAS — estilo Alien: Isolation / Destiny
# =====================================================================
#
# Regra é simples: você manda tocar um áudio com um texto junto.
# A legenda aparece na hora que o áudio começa e some sozinha quando
# o áudio termina. Não tem timestamp em arquivo separado, não tem JSON.
#
# COMO USAR
#
# 1) Esse script é anexado na RAIZ da cena Legendas.tscn (um CanvasLayer
#    com um Label filho chamado "Label"). Registre essa CENA (não o
#    .gd solto) como Autoload (nome sugerido: "Legendas") em
#    Project > Project Settings > AutoLoad.
#
# 2) Onde você já toca a fala, troque por:
#       Legendas.falar(meu_audio_stream_player, meu_audio_stream, "Texto da fala aqui", Color.white)
#
#    A cor é opcional — se não passar nada, usa branco.
#
#    ÁUDIOS LONGOS COM VÁRIAS FALAS/PESSOAS: separe as falas com "|".
#    Como o tamanho do texto NÃO corresponde ao tempo real de fala
#    (uma frase curta pode ser falada devagar, uma longa pode ser
#    falada rápido), você pode escrever a duração exata de cada fala
#    (em segundos) direto no texto, com "@":
#
#       Legendas.falar(player, audio, "Laura: Isso não devia estar aqui...@4.2|Jeff: Cuidado, Laura!@2.5|Laura: O que foi isso?!@3.0")
#
#    Ouça o áudio uma vez, anota quando cada fala termina, e escreve
#    esse tempo depois do "@". A ÚLTIMA fala não precisa de duração
#    certinha — ela sempre espera o áudio acabar de verdade (sinal
#    "finished"), então nunca fica sumindo antes ou depois da hora.
#
#    Se você não escrever "@duração" em nenhuma fala, ele volta a
#    dividir o tempo proporcional ao tamanho do texto (menos preciso,
#    mas funciona sem esforço nenhum pra falas simples).
#
# 3) Se precisar cancelar no meio (jogador saiu da área, cutscene foi
#    interrompida, etc):
#       Legendas.parar()
# =====================================================================

onready var _label: Label = $Label/Label

# Aceita AudioStreamPlayer e AudioStreamPlayer3D (ambos têm play/finished/stream)
var _player_atual = null

# Id de geração: evita que uma fala antiga (ainda "esperando o finished")
# esconda o texto de uma fala nova que começou por cima dela.
var _fala_id: int = 0

# true enquanto o jogo está pausado e há áudio de legenda em andamento
var _audio_pausado_pelo_jogo: bool = false

# Guarda texto/cor atuais pra poder recolocar se sumir (afastar do gravador, zona de luz, etc.)
var _texto_atual: String = ""
var _cor_atual: Color = Color(1, 1, 1, 1)
# true se a legenda atual é de fita do gravador (protegida: não some por distância/zona)
var _e_fita_protegida: bool = false

func _ready():
	# Continua recebendo notificações mesmo com a árvore pausada
	pause_mode = Node.PAUSE_MODE_PROCESS
	if _label:
		_label.visible = false
	set_process(true)


func _process(_delta: float) -> void:
	# Safety net: legenda de fita NÃO some por se afastar do gravador nem por
	# entrar em zona de luz / ponto tranquilo / troca de emoção.
	# Também mantém o texto VISÍVEL (travado) enquanto o jogo está pausado.
	if not SaveManager.legendas_ativadas:
		return
	if _label == null:
		return
	# Durante pause: se temos texto de fita, mantém visível e congelado
	if get_tree().paused:
		if _e_fita_protegida and _texto_atual != "":
			if _label.text != _texto_atual:
				_label.text = _texto_atual
				_label.add_color_override("font_color", _cor_atual)
			_label.visible = true
		return
	if _player_atual == null or not is_instance_valid(_player_atual):
		return
	# Ainda "ativa" se tocando OU stream_paused (pause manual do áudio)
	var ativo = _player_atual.playing or (("stream_paused" in _player_atual) and _player_atual.stream_paused) or _audio_pausado_pelo_jogo
	if not ativo and not _e_fita_protegida:
		return
	# Fita protegida: enquanto o áudio existir e a fala não foi cancelada, recoloca
	if _e_fita_protegida and _texto_atual != "":
		if _label.text != _texto_atual or not _label.visible:
			_label.add_color_override("font_color", _cor_atual)
			_label.text = _texto_atual
			_label.visible = true
		return
	if _label.text != "" and not _label.visible and ativo:
		_label.visible = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		pausar()
	elif what == NOTIFICATION_UNPAUSED:
		despausar()

func _player_eh_fita_protegida(p) -> bool:
	# Identifica áudio do gravador: Legendas.parar() não deve DAR STOP nele
	# (pause do jogo sim — isso é outro caminho)
	if p == null or not is_instance_valid(p):
		return false
	var n = p
	var guard = 0
	while n != null and guard < 12:
		if n.is_in_group("gravador") or n.is_in_group("cassette_player"):
			return true
		n = n.get_parent()
		guard += 1
	return false

func pausar() -> void:
	# Pause do jogo: pausa legenda + áudio (incluindo fita).
	# O texto FICA travado/visível — não some no pause.
	if _player_atual != null and is_instance_valid(_player_atual) and _player_atual.playing:
		_player_atual.stream_paused = true
		_audio_pausado_pelo_jogo = true
	if _texto_atual != "" and _label:
		_label.text = _texto_atual
		_label.add_color_override("font_color", _cor_atual)
		_label.visible = true

func despausar() -> void:
	# Saiu do pause: retoma de onde parou
	if _audio_pausado_pelo_jogo and _player_atual != null and is_instance_valid(_player_atual):
		_player_atual.stream_paused = false
	_audio_pausado_pelo_jogo = false
	
func falar(player, stream: AudioStream, texto: String, cor: Color = Color(1, 1, 1, 1)) -> void:
	# Texto vazio = só toca o áudio, NÃO mexe na legenda de outra fonte (ursinho etc.)
	var texto_limpo = ""
	if texto != null:
		texto_limpo = String(texto).strip_edges()
	if texto_limpo == "":
		_audio_pausado_pelo_jogo = false
		if stream != null and player != null:
			player.stream = stream
			player.stream_paused = false
			player.play()
		return

	# NÃO para o áudio anterior — só assume a legenda visual
	_fala_id += 1
	var meu_id = _fala_id
	_player_atual = player
	_e_fita_protegida = _player_eh_fita_protegida(player)
	_texto_atual = ""
	_cor_atual = cor
	
	_audio_pausado_pelo_jogo = false
	if stream != null:
		player.stream = stream
	player.stream_paused = false
	player.play()

	if not "|" in texto_limpo:
		_mostrar_texto(_remover_duracao(texto_limpo), cor)
		yield(player, "finished")
		if meu_id != _fala_id:
			return # já foi cancelada ou substituída por outra fala
		# Só esconde se ainda somos o dono da legenda
		if _player_atual == player:
			_esconder_texto(true)
			_player_atual = null
			_e_fita_protegida = false
			_texto_atual = ""
		return

	# Modo de múltiplas falas.
	var partes : Array = []
	for parte in texto.split("|"):
		var limpo = String(parte).strip_edges()
		if limpo != "":
			partes.append(limpo)

	if partes.size() <= 1:
		_mostrar_texto(_remover_duracao(texto), cor)
		yield(player, "finished")
		if meu_id != _fala_id:
			return
		_esconder_texto(true)
		_player_atual = null
		_e_fita_protegida = false
		_texto_atual = ""
		return

	# Separa texto e duração manual (se tiver "@") de cada trecho.
	var linhas : Array = []       # só o texto, sem o "@duracao"
	var duracoes : Array = []     # duração manual (-1.0 se não foi definida)
	for parte in partes:
		var arroba = parte.rfind("@")
		if arroba != -1:
			var possivel_numero = parte.substr(arroba + 1).strip_edges()
			if possivel_numero.is_valid_float():
				linhas.append(parte.substr(0, arroba).strip_edges())
				duracoes.append(float(possivel_numero))
				continue
		linhas.append(parte)
		duracoes.append(-1.0)

	# Duração total do áudio, usada só pra quem NÃO tiver "@duracao" manual.
	var duracao_total : float = 0.0
	if player.stream != null:
		duracao_total = player.stream.get_length()

	var duracao_manual_somada : float = 0.0
	var total_caracteres_sem_manual := 0
	for i in range(linhas.size()):
		if duracoes[i] >= 0.0:
			duracao_manual_somada += duracoes[i]
		else:
			total_caracteres_sem_manual += max(linhas[i].length(), 1)

	var duracao_restante = max(duracao_total - duracao_manual_somada, 0.0)

	for i in range(linhas.size()):
		if meu_id != _fala_id:
			return

		var eh_ultima = (i == linhas.size() - 1)
		_mostrar_texto(linhas[i], cor)

		if eh_ultima:
			# a última fala sempre espera o fim real do áudio, então
			# nunca sobra nem falta tempo por causa de arredondamento
			yield(player, "finished")
		elif duracoes[i] >= 0.0:
			# process_always=false: o timer PAUSA junto com o jogo, senão ele
			# continua contando escondido enquanto o áudio fica parado
			# (stream_paused), e a legenda dessincroniza ao despausar.
			yield(get_tree().create_timer(duracoes[i], false), "timeout")
		else:
			var peso = max(linhas[i].length(), 1) / float(max(total_caracteres_sem_manual, 1))
			yield(get_tree().create_timer(duracao_restante * peso, false), "timeout")

		if meu_id != _fala_id:
			return

	_esconder_texto(true)
	_player_atual = null
	_e_fita_protegida = false
	_texto_atual = ""


# Remove um eventual "@duracao" no final de um texto sem "|" (fala única).
func _remover_duracao(texto: String) -> String:
	var arroba = texto.rfind("@")
	if arroba != -1:
		var possivel_numero = texto.substr(arroba + 1).strip_edges()
		if possivel_numero.is_valid_float():
			return texto.substr(0, arroba).strip_edges()
	return texto


# Cancela só a LEGENDA visual. NÃO para o áudio de outras fontes
# (gravador / ursinho). Use parar_audio() se quiser matar o player atual.
func parar() -> void:
	_fala_id += 1
	_player_atual = null
	_audio_pausado_pelo_jogo = false
	_e_fita_protegida = false
	_texto_atual = ""
	_esconder_texto(true)

## Para legenda + áudio do player atual — EXCETO fita do gravador (nunca para).
func parar_audio() -> void:
	_fala_id += 1
	if _player_atual != null and is_instance_valid(_player_atual):
		if not _player_eh_fita_protegida(_player_atual):
			_player_atual.stream_paused = false
			if _player_atual.playing:
				_player_atual.stop()
	_player_atual = null
	_audio_pausado_pelo_jogo = false
	_e_fita_protegida = false
	_texto_atual = ""
	_esconder_texto(true)


func _mostrar_texto(texto: String, cor: Color = Color(1, 1, 1, 1)) -> void:
	_texto_atual = texto
	_cor_atual = cor
	if not SaveManager.legendas_ativadas:
		_label.visible = false
		return
	_label.add_color_override("font_color", cor)
	_label.text = texto
	_label.visible = true


func _esconder_texto(forcar: bool = false) -> void:
	# forcar=true: parar() / parar_audio() / fim legítimo.
	# forcar=false: fim natural via yield — se o áudio ainda está tocando
	# (yield acordou cedo por se afastar / zona de luz / emoção), NÃO esconde.
	if not forcar:
		if _e_fita_protegida and _texto_atual != "":
			# Fita: só esconde de verdade quando o áudio acabou de fato
			if _player_atual != null and is_instance_valid(_player_atual):
				var ainda = _player_atual.playing or (("stream_paused" in _player_atual) and _player_atual.stream_paused) or _audio_pausado_pelo_jogo
				if ainda:
					# recoloca se sumiu
					if _label and not _label.visible:
						_label.text = _texto_atual
						_label.add_color_override("font_color", _cor_atual)
						_label.visible = true
					return
		elif _player_atual != null and is_instance_valid(_player_atual):
			if _player_atual.playing and not _player_atual.stream_paused and not _audio_pausado_pelo_jogo:
				return
	if _label:
		_label.visible = false
	if forcar:
		_texto_atual = ""
		_e_fita_protegida = false


func atualizar_visibilidade() -> void:
	if not SaveManager.legendas_ativadas:
		if _label:
			_label.visible = false
	elif _player_atual != null and is_instance_valid(_player_atual) and _player_atual.playing:
		if _label and _label.text != "" and not _label.visible:
			_label.visible = true
