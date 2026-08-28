extends StaticBody

export(NodePath) var caminho_outline
onready var outline = get_node(caminho_outline) if caminho_outline else null

export(AudioStream) var audio_sala
export(AudioStream) var audio_quarto_pais
export(AudioStream) var audio_lavanderia
export(AudioStream) var audio_quarto_laura

export(String, MULTILINE) var texto_sala = ""
export(String, MULTILINE) var texto_quarto_pais = ""
export(String, MULTILINE) var texto_lavanderia = ""
export(String, MULTILINE) var texto_quarto_laura = ""

export(Color) var cor_legenda = Color(1, 1, 1, 1)

export(float, -80, 24) var volume_das_vozes = 10.0
export(float) var audio_max_distance = 45.0

onready var audio_player = AudioStreamPlayer3D.new()

var area_atual_nome: String = ""
var tempo_na_area: float = 0.0
var destino_pendente_pos: Vector3 = Vector3.ZERO
var destino_pendente_yaw: float = 0.0  # rotação Y do Position3D de destino
var precisa_teletransportar: bool = false
var jogador_node: Spatial = null

var audios_tocados = {
	"area_sala": false,
	"area_quarto": false,
	"area_lavanderia": false,
	"area_quartinho": false
}

export(String) var fita_necessaria = "Fita 02 - Diario"

var _area_pendente_apos_audio := ""
var _tem_reposicionamento_pendente := false

var ursinho_liberado: bool = false
var teleporte_liberado: bool = false

var _estado_restaurado_do_save: bool = false
var jogador_na_area_atual: bool = false

# Tempo máximo esperando FOV livre pra teleportar — evita travar pra sempre
export var teleporte_timeout: float = 6.0
var _tempo_esperando_tp: float = 0.0
var _falando: bool = false

func _set(property: String, value) -> bool:
	if property == "rotation_degrees" and value is Vector3:
		var rot_atual = rotation_degrees
		if value.z != rot_atual.z:
			value.y += (value.z - rot_atual.z)
		if value.x != rot_atual.x:
			value.y += (value.x - rot_atual.x)
		value.x = 0.0
		value.z = 0.0
		rotation_degrees = value
		return true
	elif property == "rotation" and value is Vector3:
		var rot_atual = rotation
		if value.z != rot_atual.z:
			value.y += (value.z - rot_atual.z)
		if value.x != rot_atual.x:
			value.y += (value.x - rot_atual.x)
		value.x = 0.0
		value.z = 0.0
		rotation = value
		return true
	return false

func _ready():
	add_to_group("interagivel")
	add_to_group("Persist")
	add_to_group("ursinho")
	if outline:
		outline.visible = false

	audio_player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	audio_player.unit_db = volume_das_vozes
	audio_player.unit_size = 10.0
	audio_player.max_distance = audio_max_distance
	audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
	add_child(audio_player)

	ursinho_liberado = _fita_ja_reproduzida()
	_aplicar_visibilidade(ursinho_liberado)
	set_process(true)

	if not ursinho_liberado:
		return

	yield(get_tree(), "idle_frame")
	_conectar_areas_casa()
	if not _estado_restaurado_do_save:
		_forcar_spawn_no_quartinho()

func _process(delta):
	if not ursinho_liberado:
		if _fita_ja_reproduzida():
			_liberar_ursinho()
		return

	_checar_tempo_audio(delta)
	_sincronizar_area_pelo_player()
	if teleporte_liberado:
		_tentar_teletransporte_pendente(delta)

func _fita_ja_reproduzida() -> bool:
	if typeof(SaveManager) == TYPE_NIL:
		return false
	if SaveManager.fitas_reproduzidas.has(fita_necessaria):
		return true
	# Match flexível (nome ligeiramente diferente no export da fita)
	for k in SaveManager.fitas_reproduzidas.keys():
		var ks = str(k).to_lower()
		var alvo = fita_necessaria.to_lower()
		if ks == alvo:
			return true
		if "fita 02" in ks or "diario" in ks:
			if "02" in alvo or "diario" in alvo:
				return true
	return false

func _liberar_ursinho() -> void:
	if ursinho_liberado:
		return
	ursinho_liberado = true
	_aplicar_visibilidade(true)
	_conectar_areas_casa()
	if not _estado_restaurado_do_save:
		# Tenta spawn agora e de novo no próximo frame (cena pode ainda estar montando)
		_forcar_spawn_no_quartinho()
		call_deferred("_forcar_spawn_no_quartinho")
	print("🧸 Ursinho liberado (fita ok)")

func _aplicar_visibilidade(ativo: bool) -> void:
	visible = ativo
	set_collision_layer_bit(0, ativo)
	# Garante que não fica “fantasma” sem colisão de interação
	if ativo:
		set_collision_mask_bit(0, true)

# --- força o ursinho a nascer no quartinho na primeira liberação ---
func _forcar_spawn_no_quartinho() -> void:
	var ponto = _obter_ponto_tp("position_quartinho")
	if ponto == null:
		push_warning("🧸 PontosTPUrsinho/position_quartinho não encontrado — ursinho fica onde está")
		area_atual_nome = "area_quartinho"
		tempo_na_area = 0.0
		jogador_na_area_atual = false
		_checar_jogador_ja_no_quartinho()
		return

	_aplicar_transform_do_ponto(ponto)
	# Garante visível na posição certa
	_aplicar_visibilidade(true)
	area_atual_nome = "area_quartinho"
	tempo_na_area = 0.0
	jogador_na_area_atual = false
	precisa_teletransportar = false
	print("🧸 Ursinho spawnou no quartinho: ", global_transform.origin, " yaw=", rad2deg(rotation.y))
	_checar_jogador_ja_no_quartinho()

func _checar_jogador_ja_no_quartinho() -> void:
	var area_quartinho = _find_area("area_quartinho")
	if area_quartinho == null:
		return
	for body in area_quartinho.get_overlapping_bodies():
		if body.is_in_group("player") or body is KinematicBody:
			jogador_node = body
			jogador_na_area_atual = true
			return

func _checar_tempo_audio(delta):
	if not area_atual_nome in audios_tocados:
		return
	if audios_tocados[area_atual_nome] == true:
		return
	if not jogador_na_area_atual:
		return
	if _falando:
		return
	tempo_na_area += delta
	if tempo_na_area >= 5.0:
		_tocar_audio_ambiente()

func _tocar_audio_ambiente():
	var som_para_tocar : AudioStream = _obter_audio(area_atual_nome)
	var texto_da_fala : String = _obter_texto(area_atual_nome)
	var area_desta_fala := area_atual_nome

	if not som_para_tocar:
		if area_desta_fala == "area_quartinho" and not teleporte_liberado:
			teleporte_liberado = true
		audios_tocados[area_desta_fala] = true
		push_warning("🧸 Sem áudio configurado para: " + area_desta_fala)
		return

	# Garante que está visível e no ponto da área antes da fala
	_garantir_posicao_da_area(area_desta_fala)

	audios_tocados[area_desta_fala] = true
	_falando = true
	audio_player.unit_db = volume_das_vozes
	audio_player.max_distance = audio_max_distance
	Legendas.falar(audio_player, som_para_tocar, texto_da_fala, cor_legenda)

	if area_desta_fala == "area_quartinho" and not teleporte_liberado:
		yield(audio_player, "finished")
		_falando = false
		teleporte_liberado = true
		print("🧸 1ª fala ok — teleporte liberado")
		return

	yield(audio_player, "finished")
	_falando = false

	if _tem_reposicionamento_pendente:
		_tem_reposicionamento_pendente = false
		area_atual_nome = _area_pendente_apos_audio
		_atualizar_posicao_ursinho()

func _garantir_posicao_da_area(nome_area: String) -> void:
	var nome_ponto = _nome_ponto_para_area(nome_area)
	var ponto = _obter_ponto_tp(nome_ponto)
	if ponto:
		_aplicar_transform_do_ponto(ponto)
		_aplicar_visibilidade(true)

func _obter_audio(nome_area: String) -> AudioStream:
	match nome_area:
		"area_sala": return audio_sala
		"area_quarto": return audio_quarto_pais
		"area_lavanderia": return audio_lavanderia
		"area_quartinho": return audio_quarto_laura
	return null

func _obter_texto(nome_area: String) -> String:
	match nome_area:
		"area_sala": return texto_sala
		"area_quarto": return texto_quarto_pais
		"area_lavanderia": return texto_lavanderia
		"area_quartinho": return texto_quarto_laura
	return ""

# Volume agora é 3D nativo (unit_db + max_distance) — sem atenuação manual.

func _conectar_areas_casa():
	var areas_casa = _find_node_por_nome("areas_casa")
	if areas_casa == null:
		push_warning("🧸 areas_casa não encontrada")
		return
	for area in areas_casa.get_children():
		if area is Area:
			if area.is_connected("body_entered", self, "_on_jogador_entrou_na_area"):
				area.disconnect("body_entered", self, "_on_jogador_entrou_na_area")
			if area.is_connected("body_exited", self, "_on_jogador_saiu_da_area"):
				area.disconnect("body_exited", self, "_on_jogador_saiu_da_area")
			area.connect("body_entered", self, "_on_jogador_entrou_na_area", [area.name])
			area.connect("body_exited", self, "_on_jogador_saiu_da_area", [area.name])

func _on_jogador_entrou_na_area(body, nome_da_area: String):
	if not body.is_in_group("player"):
		return
	jogador_node = body

	if not teleporte_liberado:
		# Ainda na 1ª fala: só conta se for o quartinho (ou a área atual)
		if nome_da_area == "area_quartinho" or nome_da_area == area_atual_nome:
			jogador_na_area_atual = true
			if area_atual_nome == "":
				area_atual_nome = nome_da_area
			if not audios_tocados.get(area_atual_nome, true):
				tempo_na_area = 0.0
		return

	if area_atual_nome != nome_da_area:
		area_atual_nome = nome_da_area
		tempo_na_area = 0.0
		jogador_na_area_atual = true

		if audio_player.playing or _falando:
			_area_pendente_apos_audio = nome_da_area
			_tem_reposicionamento_pendente = true
		else:
			_atualizar_posicao_ursinho()
	else:
		jogador_na_area_atual = true

	if not audio_player.playing and not _falando:
		Legendas.parar()

func _on_jogador_saiu_da_area(body, nome_da_area: String):
	if not body.is_in_group("player"):
		return
	if nome_da_area == area_atual_nome:
		jogador_na_area_atual = false
		if not audios_tocados.get(area_atual_nome, true):
			tempo_na_area = 0.0

func _nome_ponto_para_area(nome_area: String) -> String:
	match nome_area:
		"area_sala": return "position_sala"
		"area_quarto": return "position_quarto"
		"area_lavanderia": return "position_lavanderia"
		"area_quartinho": return "position_quartinho"
		"area_banheiro": return "position_sala"
	return "position_sala"

func _atualizar_posicao_ursinho():
	var nome_ponto_destino = _nome_ponto_para_area(area_atual_nome)
	var ponto_nodo = _obter_ponto_tp(nome_ponto_destino)
	if ponto_nodo == null:
		ponto_nodo = _obter_ponto_tp("position_sala")
	if ponto_nodo == null:
		push_warning("🧸 Nenhum ponto de TP encontrado para: " + nome_ponto_destino)
		return

	# NUNCA usa posição do player — só pontos fixos da cena
	destino_pendente_pos = ponto_nodo.global_transform.origin
	destino_pendente_yaw = _yaw_do_ponto(ponto_nodo)
	precisa_teletransportar = true
	_tempo_esperando_tp = 0.0
	print("🧸 TP pendente → ", nome_ponto_destino, " ", destino_pendente_pos, " yaw=", rad2deg(destino_pendente_yaw))

func _tentar_teletransporte_pendente(delta: float = 0.0):
	if not precisa_teletransportar:
		return

	_tempo_esperando_tp += delta

	var camera = get_viewport().get_camera()
	if camera == null:
		# Sem câmera válida: espera (não força aparecer na frente)
		return

	var origem_fora = _posicao_esta_fora_de_vista(camera, global_transform.origin)
	var destino_fora = _posicao_esta_fora_de_vista(camera, destino_pendente_pos)

	# Se o jogador está olhando pra origem, esconde o ursinho (sumiu "nos fundos")
	# mas SÓ completa o TP quando o destino também estiver fora da mira.
	if origem_fora and not destino_fora:
		if visible:
			_aplicar_visibilidade(false)
		return

	# Só teleporta quando NÃO está olhando nem a origem nem o destino
	if origem_fora and destino_fora:
		_executar_teleporte()
		return

	# Timeout longo: ainda assim NÃO aparece se o destino estiver na mira
	if _tempo_esperando_tp >= teleporte_timeout * 4.0:
		if destino_fora:
			print("🧸 TP por timeout longo (%.1fs) — destino fora de vista" % _tempo_esperando_tp)
			_executar_teleporte()
		else:
			# Continua escondido e esperando o jogador olhar pra outro lado
			if visible:
				_aplicar_visibilidade(false)

func _executar_teleporte() -> void:
	global_transform.origin = destino_pendente_pos
	_aplicar_yaw(destino_pendente_yaw)
	_aplicar_visibilidade(true)
	precisa_teletransportar = false
	_tempo_esperando_tp = 0.0
	print("🧸 Ursinho teleportou para ", destino_pendente_pos, " yaw=", rad2deg(destino_pendente_yaw))

## Copia posição + rotação Y do Position3D (pra mirar pro lado que o ponto aponta).
func _aplicar_transform_do_ponto(ponto: Spatial) -> void:
	if ponto == null:
		return
	global_transform.origin = ponto.global_transform.origin
	_aplicar_yaw(_yaw_do_ponto(ponto))

## Yaw global do Spatial (eixo Y), em radianos.
func _yaw_do_ponto(ponto: Spatial) -> float:
	if ponto == null:
		return rotation.y
	# Euler Y do transform global = mesma rotação que você gira no editor
	return ponto.global_transform.basis.get_euler().y

func _aplicar_yaw(yaw: float) -> void:
	# Mantém só Y (ursinho em pé) — o _set já força x/z=0 se alguém mexer
	rotation = Vector3(0.0, yaw, 0.0)

func _posicao_esta_fora_de_vista(camera: Camera, posicao: Vector3) -> bool:
	# true = seguro pra teleportar (jogador NÃO está olhando)
	if camera.is_position_behind(posicao):
		return true

	var direcao_ao_ponto = (posicao - camera.global_transform.origin)
	if direcao_ao_ponto.length() < 0.05:
		return false
	direcao_ao_ponto = direcao_ao_ponto.normalized()
	var direcao_camera = -camera.global_transform.basis.z.normalized()
	var produto_escalar = direcao_camera.dot(direcao_ao_ponto)
	# Qualquer coisa dentro de ~55° do centro do FOV = "está olhando"
	if produto_escalar < 0.55:
		return true

	# Mesmo no FOV: se tem parede no caminho, conta como fora de vista
	var espaco_fisico = get_world().direct_space_state
	var resultado_raio = espaco_fisico.intersect_ray(
		camera.global_transform.origin, posicao, [self, get_parent()]
	)
	if resultado_raio and resultado_raio.collider:
		if not (resultado_raio.collider.is_in_group("player") or resultado_raio.collider is KinematicBody):
			return true

	return false

# Detecta área do player por overlap (não depende só de body_entered — evita delay)
func _sincronizar_area_pelo_player() -> void:
	if not teleporte_liberado or not ursinho_liberado:
		return
	if not jogador_node or not is_instance_valid(jogador_node):
		var players = get_tree().get_nodes_in_group("player")
		if players.empty():
			return
		jogador_node = players[0]

	var areas_casa = _find_node_por_nome("areas_casa")
	if areas_casa == null:
		return

	var area_detectada := ""
	for area in areas_casa.get_children():
		if not (area is Area):
			continue
		for body in area.get_overlapping_bodies():
			if body == jogador_node or body.is_in_group("player"):
				area_detectada = area.name
				break
		if area_detectada != "":
			break

	if area_detectada == "":
		return

	if area_atual_nome != area_detectada:
		area_atual_nome = area_detectada
		tempo_na_area = 0.0
		jogador_na_area_atual = true
		if audio_player.playing or _falando:
			_area_pendente_apos_audio = area_detectada
			_tem_reposicionamento_pendente = true
		else:
			_atualizar_posicao_ursinho()
	else:
		jogador_na_area_atual = true

# --- helpers de busca na árvore (robusto com Viewport / cenas aninhadas) ---
func _obter_ponto_tp(nome: String) -> Spatial:
	var root_pontos = _find_node_por_nome("PontosTPUrsinho")
	if root_pontos == null:
		return null
	var p = root_pontos.find_node(nome, true, false)
	if p and p is Spatial:
		return p
	return null

func _find_area(nome: String) -> Area:
	var areas_casa = _find_node_por_nome("areas_casa")
	if areas_casa == null:
		return null
	var a = areas_casa.find_node(nome, true, false)
	if a is Area:
		return a
	return null

func _find_node_por_nome(nome: String) -> Node:
	# 1) current_scene
	var cena = get_tree().current_scene
	if cena:
		var n = cena.find_node(nome, true, false)
		if n:
			return n
	# 2) sobe a hierarquia a partir do ursinho
	var p = get_parent()
	while p:
		var n2 = p.find_node(nome, true, false)
		if n2:
			return n2
		p = p.get_parent()
	# 3) root inteiro
	var n3 = get_tree().root.find_node(nome, true, false)
	return n3

func set_foco(ativo: bool):
	if outline:
		outline.visible = ativo

func interagir(camera):
	camera.iniciar_inspecao(self)

# =====================================================================
# SAVE / LOAD
# =====================================================================
func save() -> Dictionary:
	return {
		"pos_x": global_transform.origin.x,
		"pos_y": global_transform.origin.y,
		"pos_z": global_transform.origin.z,
		"rot_y": rotation.y,
		"area_atual_nome": area_atual_nome,
		"ursinho_liberado": ursinho_liberado,
		"teleporte_liberado": teleporte_liberado,
		"audios_tocados": audios_tocados.duplicate()
	}

func load_data(data: Dictionary) -> void:
	if data.has("pos_x"):
		global_transform.origin = Vector3(
			data.get("pos_x", global_transform.origin.x),
			data.get("pos_y", global_transform.origin.y),
			data.get("pos_z", global_transform.origin.z)
		)
	if data.has("rot_y"):
		_aplicar_yaw(float(data.get("rot_y", rotation.y)))

	area_atual_nome    = data.get("area_atual_nome", area_atual_nome)
	ursinho_liberado   = data.get("ursinho_liberado", ursinho_liberado)
	teleporte_liberado = data.get("teleporte_liberado", teleporte_liberado)

	var audios_salvos = data.get("audios_tocados", null)
	if typeof(audios_salvos) == TYPE_DICTIONARY:
		for chave in audios_tocados.keys():
			if audios_salvos.has(chave):
				audios_tocados[chave] = audios_salvos[chave]

	if ursinho_liberado:
		_aplicar_visibilidade(true)
		call_deferred("_conectar_areas_casa")

	_estado_restaurado_do_save = true
	jogador_na_area_atual = false
	tempo_na_area = 0.0
	precisa_teletransportar = false
	_falando = false
