extends Node
# =====================================================================
# SAVE MANAGER — reescrito do zero
# =====================================================================
#
# COMO INTEGRAR SEUS OBJETOS (leia isso antes de tudo)
#
# 1) OBJETOS QUE MUDAM DE ESTADO MAS CONTINUAM NO MAPA
#    (portas, interruptores, lanterna no chão, etc)
#    -> Coloque o nó no grupo "Persist"
#    -> Dê a ele um id único: node.set_meta("id_unico", "porta_quarto_01")
#       (se não setar, o script usa node.name, mas isso quebra se você
#       duplicar o nó em runtime — prefira sempre setar id_unico manual)
#    -> O nó precisa ter os métodos:
#         func save() -> Dictionary       # retorna o estado atual
#         func load_data(dados: Dictionary) -> void  # aplica o estado
#
# 2) ITENS QUE SOMEM PRA SEMPRE QUANDO COLETADOS
#    (fitas, itens de inventário largados no mapa, colecionáveis)
#    -> Coloque o nó no grupo "Persist_coletavel"
#    -> Dê um id_unico único (obrigatório aqui, não use node.name)
#    -> Quando o jogador pegar o item, dentro do script do item chame:
#         SaveManager.marcar_item_coletado(id_unico)
#         queue_free() # ou deixe o marcar_item_coletado remover, ver abaixo
#
#    No load, qualquer nó desse grupo cujo id_unico já esteja na lista
#    de coletados é destruído ANTES de qualquer outra coisa rodar —
#    ou seja, ele nunca chega a aparecer pro jogador.
#
# 3) PLAYER
#    -> Grupo "player", precisa dos métodos save()/load_data() também
#    -> Posição/rotação são tratadas à parte (ver player_data abaixo)
#
# 4) LANTERNA/ITEM NA MÃO
#    -> Continua guardado dentro dos dados do player (ver save_game),
#       igual ao seu sistema original — funcionava, não mexi nisso.
#
# =====================================================================

signal jogo_salvo
signal jogo_carregado

const SLOT_COUNT = 4
const AUTO_SAVE_INTERVAL = 80.0
const SAVE_FOLDER = "user://O Limbo das Memorias"
const CENA_JOGO = "res://scenes/casa_ofc.tscn"
const CENA_LOADING = "res://scenes/TelaCarregamento.tscn"
const CONFIG_PATH = "user://configuracoes.cfg"

var slot_ativo : bool = false
var current_slot : int = -1
var auto_save_timer : Timer

# Flags globais simples
var cutscene_inicial_vista : bool = false

# Lista de id_unico de tudo que já foi coletado PRA SEMPRE (grupo Persist_coletavel)
var itens_coletados : Array = []

# dentro do SaveManager.gd
var fitas_reproduzidas = {}
# nome_fita -> {fita_audio_path, fita_texto, fita_cor_*, fita_e_calmante}
# Persiste o áudio de cada fita coletada pra nunca voltar "em branco" no load.
var fitas_dados = {}

# ----- Integração com o site (API Railway) -----
const WEB_API_URL := "https://limbo-of-memories-production.up.railway.app/api"
const WEB_TOKEN_PATH := "user://limbo_web_token.txt"
const WEB_SYNC_INTERVAL := 30.0
var _http_web: HTTPRequest = null
var _web_token: String = ""
var _web_sync_timer: Timer = null
var _web_sessao_ativa: bool = false
var _web_playtime_base: int = 0
var _web_sessao_inicio_msec: int = 0
var _web_sync_em_andamento: bool = false
var _web_sync_pendente: bool = false
var _web_sync_pendente_reset: bool = false

var volume_musica: float = 1.0
var volume_sfx: float = 1.0
var legendas_ativadas: bool = true

var resolucao_index: int = 0
var tela_cheia: bool = true
var resolucoes_disponiveis: Array = []       # cada item: {"label": String, "shrink": int}
var _viewport_container_atual: ViewportContainer = null

var sensibilidade_mouse: float = 1.0
var inverter_mouse_y: bool = false

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	var dir = Directory.new()
	if not dir.dir_exists(SAVE_FOLDER):
		dir.make_dir_recursive(SAVE_FOLDER)

	auto_save_timer = Timer.new()
	auto_save_timer.wait_time = AUTO_SAVE_INTERVAL
	auto_save_timer.one_shot = false
	auto_save_timer.connect("timeout", self, "_on_auto_save")
	add_child(auto_save_timer)
	auto_save_timer.start()

	_http_web = HTTPRequest.new()
	_http_web.name = "HTTPWebAPI"
	_http_web.timeout = 15.0
	_http_web.use_threads = true  # não trava a thread principal
	add_child(_http_web)
	_http_web.connect("request_completed", self, "_on_web_request_completed")

	_web_sync_timer = Timer.new()
	_web_sync_timer.wait_time = WEB_SYNC_INTERVAL
	_web_sync_timer.one_shot = false
	_web_sync_timer.connect("timeout", self, "_on_web_sync_timer")
	add_child(_web_sync_timer)

	_carregar_web_token()
	carregar_configuracoes()
	_aplicar_refresh_rate_monitor()

## Trava o jogo no Hz do monitor (VSync + target_fps). Sem impacto visual.
func _aplicar_refresh_rate_monitor() -> void:
	OS.vsync_enabled = true
	var hz = 60
	if OS.has_method("get_screen_refresh_rate"):
		hz = int(OS.get_screen_refresh_rate())
	if hz < 30:
		hz = 60
	Engine.target_fps = hz
	print("[SaveManager] Refresh rate do monitor: %d Hz (VSync on)" % hz)


func _get_save_path(slot: int) -> String:
	return "%s/save_slot_%d.save" % [SAVE_FOLDER, slot]


# Chame isso de dentro do item quando ele for coletado.
# Ex: SaveManager.marcar_item_coletado(id_unico); queue_free()
func marcar_item_coletado(id_unico: String) -> void:
	if id_unico == "":
		push_warning("[SaveManager] tentou marcar item coletado sem id_unico!")
		return
	if not itens_coletados.has(id_unico):
		itens_coletados.append(id_unico)

func marcar_fita_reproduzida(nome: String):
	fitas_reproduzidas[nome] = true


## Guarda path/texto/cor da fita pelo nome (coleta ou início da reprodução).
func registrar_fita_audio(nome: String, path: String, texto: String = "", cor = null, calmante: bool = false) -> void:
	if nome == null or str(nome) == "":
		return
	nome = str(nome)
	if not fitas_dados.has(nome):
		fitas_dados[nome] = {}
	var d = fitas_dados[nome]
	if path != null and str(path) != "":
		d["fita_audio_path"] = str(path)
	if texto != null and str(texto) != "":
		d["fita_texto"] = str(texto)
	if cor != null and cor is Color:
		d["fita_cor_r"] = cor.r
		d["fita_cor_g"] = cor.g
		d["fita_cor_b"] = cor.b
		d["fita_cor_a"] = cor.a
	d["fita_e_calmante"] = calmante
	fitas_dados[nome] = d
	print("[SaveManager] registrar_fita_audio '%s' path=%s" % [nome, d.get("fita_audio_path", "")])
	sincronizar_progresso_web()

func _pegar_id(node: Node) -> String:
	if node.has_meta("id_unico"):
		return str(node.get_meta("id_unico"))
	# Caminho completo do nó na árvore. Mais seguro que node.name sozinho,
	# porque dois objetos em pastas diferentes podem ter o mesmo nome
	# (ex: "Porta" dentro de "Quarto1" e "Porta" dentro de "Quarto2").
	return str(node.get_path())


# =====================================================================
# SALVAR
# =====================================================================

func save_game(slot: int) -> bool:
	if slot < 0 or slot >= SLOT_COUNT:
		push_error("[SaveManager] Slot inválido: %d" % slot)
		return false

	current_slot = slot
	slot_ativo = true

	# NÃO interrompe áudio da fita no save/auto-save — o jogador continua ouvindo.
	# Se o gravador estiver tocando, a fita já saiu do inventário em runtime;
	# no arquivo de save a gente inclui de volta só nos dados gravados, pra
	# um load a meio não perder a fita (sem mexer no inventário ao vivo).

	# Consolida o tempo da sessão no base (evita perder minutos se o sync falhar)
	# em save_game(), dentro de dados_do_save:
	var dados_do_save = {
		"versao": 2,
		"flags_globais": {
			"cutscene_inicial_vista": cutscene_inicial_vista
		},
		"itens_coletados": itens_coletados.duplicate(),
		"fitas_reproduzidas": fitas_reproduzidas.duplicate(),
		"fitas_dados": fitas_dados.duplicate(true),
		"playtime_seconds": get_playtime_seconds(),
		"capitulo": _capitulo_por_progresso(fitas_reproduzidas, itens_coletados),

		"quarto_laura": {},
		"inventario": [],
		"cartas": [],
		"tutorial_manager": {},
		"player": {},
		"objetos": {},
	}
	if typeof(QuartoLaura) != TYPE_NIL and QuartoLaura.has_method("get_save_data"):
		dados_do_save["quarto_laura"] = QuartoLaura.get_save_data()

	if typeof(Inventory) != TYPE_NIL and Inventory.has_method("get_save_data"):
		dados_do_save["inventario"] = Inventory.get_save_data()
		# Fita tocando no gravador: inventário vivo não tem ela, mas o save deve ter
		var fita_tocando_agora := false
		for g in get_tree().get_nodes_in_group("gravador"):
			if is_instance_valid(g) and "fita_tocando" in g and g.fita_tocando:
				fita_tocando_agora = true
				break
		var inv = dados_do_save["inventario"]
		if fita_tocando_agora:
			if typeof(inv) == TYPE_DICTIONARY:
				var lista = inv.get("items", [])
				if not lista.has("fita_cassete"):
					lista.append("fita_cassete")
					inv["items"] = lista
			elif typeof(inv) == TYPE_ARRAY and not inv.has("fita_cassete"):
				inv.append("fita_cassete")

	if typeof(CartasInventory) != TYPE_NIL and CartasInventory.has_method("get_save_data"):
		dados_do_save["cartas"] = CartasInventory.get_save_data()
		print("[SaveManager] Salvando cartas: %s" % str(dados_do_save["cartas"]))

	# Snapshot da fita no inventário (nunca perde áudio).
	dados_do_save["fita_inventario"] = {}
	var nome_f := ""
	var path_f := ""
	var texto_f := ""
	var cor_r := 1.0
	var cor_g := 1.0
	var cor_b := 1.0
	var cor_a := 1.0
	var calmante_f := false

	# 1) Câmera do player (fita ainda no inventário)
	for node in get_tree().get_nodes_in_group("player"):
		var cam = node.get_node_or_null("Camera")
		if cam == null:
			continue
		nome_f = str(cam.get("fita_nome") if cam.get("fita_nome") != null else "")
		if "fita_audio_path" in cam and str(cam.fita_audio_path) != "":
			path_f = str(cam.fita_audio_path)
		elif cam.get("fita_audio") and cam.fita_audio:
			path_f = str(cam.fita_audio.resource_path)
		texto_f = str(cam.get("fita_texto") if cam.get("fita_texto") != null else "")
		if "fita_cor" in cam and cam.fita_cor is Color:
			cor_r = float(cam.fita_cor.r)
			cor_g = float(cam.fita_cor.g)
			cor_b = float(cam.fita_cor.b)
			cor_a = float(cam.fita_cor.a)
		if "fita_e_calmante" in cam:
			calmante_f = bool(cam.fita_e_calmante)
		break

	# 2) Gravador tocando → API pública (fonte da verdade no meio da reprodução)
	for g in get_tree().get_nodes_in_group("gravador"):
		if not is_instance_valid(g):
			continue
		if not ("fita_tocando" in g and g.fita_tocando):
			continue
		var snap = {}
		if g.has_method("get_fita_em_reproducao"):
			snap = g.get_fita_em_reproducao()
		if typeof(snap) == TYPE_DICTIONARY and not snap.empty():
			if str(snap.get("fita_nome", "")) != "":
				nome_f = str(snap["fita_nome"])
			if str(snap.get("fita_audio_path", "")) != "":
				path_f = str(snap["fita_audio_path"])
			if str(snap.get("fita_texto", "")) != "":
				texto_f = str(snap["fita_texto"])
			cor_r = float(snap.get("fita_cor_r", cor_r))
			cor_g = float(snap.get("fita_cor_g", cor_g))
			cor_b = float(snap.get("fita_cor_b", cor_b))
			cor_a = float(snap.get("fita_cor_a", cor_a))
			calmante_f = bool(snap.get("fita_e_calmante", calmante_f))
			print("[SaveManager] Snapshot gravador: '%s' path=%s" % [nome_f, path_f])
		break

	# 3) Completa path/texto pelo registro persistente fitas_dados
	if nome_f != "" and fitas_dados.has(nome_f):
		var reg = fitas_dados[nome_f]
		if path_f == "" and str(reg.get("fita_audio_path", "")) != "":
			path_f = str(reg["fita_audio_path"])
		if texto_f == "" and str(reg.get("fita_texto", "")) != "":
			texto_f = str(reg["fita_texto"])
		if not calmante_f and reg.get("fita_e_calmante", false):
			calmante_f = true

	# 4) Se só temos path no registry e inventário tem fita (ou tocando), usa último registro
	if (nome_f == "" or path_f == "") and typeof(Inventory) != TYPE_NIL and Inventory.has_item("fita_cassete"):
		# pega qualquer entrada recente do registry se câmera vazia
		pass

	if nome_f != "" or path_f != "":
		dados_do_save["fita_inventario"] = {
			"fita_nome": nome_f,
			"fita_audio_path": path_f,
			"fita_texto": texto_f,
			"fita_cor_r": cor_r,
			"fita_cor_g": cor_g,
			"fita_cor_b": cor_b,
			"fita_cor_a": cor_a,
			"fita_e_calmante": calmante_f,
		}
		# Atualiza registry também
		if nome_f != "":
			registrar_fita_audio(nome_f, path_f, texto_f, Color(cor_r, cor_g, cor_b, cor_a), calmante_f)
		print("[SaveManager] fita_inventario salvo: %s" % str(dados_do_save["fita_inventario"]))
	else:
		print("[SaveManager] AVISO: nenhuma fita pra gravar em fita_inventario")

	if typeof(TutorialManager) != TYPE_NIL and TutorialManager.has_method("save_data"):
		dados_do_save["tutorial_manager"] = TutorialManager.save_data()

	# --- Player ---
	for node in get_tree().get_nodes_in_group("player"):
		if not node.has_method("save"):
			continue
		var data = node.save()
		data["pos_x"] = node.translation.x
		data["pos_y"] = node.translation.y
		data["pos_z"] = node.translation.z
		if node.has_node("Camera"):
			data["rot_x"] = node.get_node("Camera").rotation_degrees.x
		dados_do_save["player"] = data
		break # só um player

	# --- Objetos com estado (portas, interruptores, lanterna no chão, etc) ---
	for node in get_tree().get_nodes_in_group("Persist"):
		if node.is_in_group("player"):
			continue
		if not node.has_method("save"):
			continue
		var data = node.save()
		if data == null or (data is Dictionary and data.empty()):
			continue
		var id_unico = _pegar_id(node)
		dados_do_save["objetos"][id_unico] = data

	var save_file = File.new()
	if save_file.open(_get_save_path(slot), File.WRITE) != OK:
		push_error("[SaveManager] Não consegui abrir o arquivo de save pra escrita!")
		return false

	save_file.store_string(to_json(dados_do_save))
	save_file.close()
	print("💾 [SAVE] Slot %d salvo. %d objetos, %d itens coletados." % [
		slot, dados_do_save["objetos"].size(), itens_coletados.size()
	])
	emit_signal("jogo_salvo")
	sincronizar_progresso_web()
	enviar_save_nuvem(slot)
	return true


# =====================================================================
# CARREGAR
# =====================================================================

# Dispara a tela de loading, igual seu fluxo original
var _pending_load_after_cloud: bool = false

func load_game(slot: int) -> void:
	_limpar_uis_do_jogo()
	Global.rodando_como_menu_bg = false
	Global.slot_para_carregar = slot
	Global.cena_destino = CENA_JOGO
	# Se logado, tenta baixar o save da nuvem antes de abrir
	if get_web_token() != "":
		_pending_load_after_cloud = true
		_cloud_slot_pendente = slot
		baixar_save_nuvem(slot)
		# fallback: se o request nem iniciar, segue local
		return
	get_tree().change_scene(CENA_LOADING)


# Chame isso (em vez de ir direto pro change_scene) quando for um
# Novo Jogo de verdade — sem isso, itens_coletados/Inventory ficam com
# o estado da partida anterior (eles são autoload, então sobrevivem
# à troca de cena e até a voltar pro menu).
func iniciar_novo_jogo() -> void:
	# Zera TODO o estado de gameplay local
	current_slot = -1
	slot_ativo = false
	itens_coletados.clear()
	fitas_reproduzidas.clear()
	fitas_dados.clear()
	cutscene_inicial_vista = false
	if typeof(Inventory) != TYPE_NIL and Inventory.has_method("clear"):
		Inventory.clear()
	if typeof(CartasInventory) != TYPE_NIL and CartasInventory.has_method("clear"):
		CartasInventory.clear()
	if typeof(TutorialManager) != TYPE_NIL:
		if TutorialManager.has_method("load_data"):
			TutorialManager.load_data({})
		if TutorialManager.has_method("limpar_ui_ao_sair"):
			TutorialManager.limpar_ui_ao_sair()
	if typeof(QuartoLaura) != TYPE_NIL and QuartoLaura.has_method("limpar"):
		QuartoLaura.limpar()
	if typeof(Legendas) != TYPE_NIL and Legendas.has_method("parar"):
		Legendas.parar()
	_limpar_uis_do_jogo()
	# Zera tempo local e, se logado, zera no site (POST /progress/reset)
	_web_playtime_base = 0
	_web_sessao_inicio_msec = OS.get_ticks_msec()
	_web_sessao_ativa = true
	if _web_sync_timer:
		_web_sync_timer.start()
	resetar_progresso_web()
	print("[SaveManager] Novo jogo: estado local zerado (+ site se logado).")



func carregar_dados(slot: int) -> bool:
	var path = _get_save_path(slot)
	var save_file = File.new()
	if not save_file.file_exists(path):
		push_warning("[SaveManager] Save do slot %d não existe." % slot)
		return false

	if save_file.open(path, File.READ) != OK:
		push_error("[SaveManager] Não consegui abrir o save pra leitura!")
		return false
	var texto = save_file.get_as_text()
	save_file.close()

	var dados_do_save = parse_json(texto)
	if typeof(dados_do_save) != TYPE_DICTIONARY:
		push_error("[SaveManager] Save corrompido ou em formato inválido.")
		return false

	current_slot = slot
	slot_ativo = true

	# --- Dados globais simples (defensivo: .get() com default pra tudo) ---
	var flags = dados_do_save.get("flags_globais", {})
	cutscene_inicial_vista = flags.get("cutscene_inicial_vista", false)
	itens_coletados = dados_do_save.get("itens_coletados", [])
	fitas_reproduzidas = dados_do_save.get("fitas_reproduzidas", {})
	fitas_dados = dados_do_save.get("fitas_dados", {})
	if typeof(fitas_dados) != TYPE_DICTIONARY:
		fitas_dados = {}
	var _pt_salvo = int(dados_do_save.get("playtime_seconds", 0))
	if typeof(QuartoLaura) != TYPE_NIL and QuartoLaura.has_method("load_save_data"):
		QuartoLaura.load_save_data(dados_do_save.get("quarto_laura", {}))

	if dados_do_save.has("inventario") and typeof(Inventory) != TYPE_NIL:
		Inventory.apply_save_data(dados_do_save["inventario"])

	if typeof(CartasInventory) != TYPE_NIL and CartasInventory.has_method("apply_save_data"):
		var _cartas_data = dados_do_save.get("cartas", [])
		CartasInventory.apply_save_data(_cartas_data)
		print("[SaveManager] Cartas restauradas: %d" % CartasInventory.quantidade())

	if dados_do_save.has("tutorial_manager") and typeof(TutorialManager) != TYPE_NIL:
		TutorialManager.load_data(dados_do_save["tutorial_manager"])

	# --- Troca de cena ---
	get_tree().change_scene(CENA_JOGO)
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")

	# --- PASSO 1 (opcional): remove pra sempre quem já foi coletado ---
	# Sua fita (fita_global.gd) já resolve isso sozinha: ela mesma checa
	# SaveManager.itens_coletados no _ready() dela e se queue_free() se
	# já foi coletada — e isso já funciona, porque itens_coletados é
	# restaurado ANTES do change_scene() logo acima. Esse passo aqui é
	# só uma rede de segurança genérica pra futuros itens que você queira
	# plugar no grupo "Persist_coletavel" seguindo o mesmo padrão.
	for node in get_tree().get_nodes_in_group("Persist_coletavel"):
		var id_unico = _pegar_id(node)
		if itens_coletados.has(id_unico):
			node.queue_free()

	# Quarto da Laura: cama / fita 2 / ursinho conforme fitas já tocadas
	if typeof(QuartoLaura) != TYPE_NIL and QuartoLaura.has_method("forcar_atualizacao"):
		QuartoLaura.forcar_atualizacao()
	else:
		get_tree().call_group("quarto_laura", "atualizar_visibilidade")

	yield(get_tree(), "idle_frame")

	# --- PASSO 2: aplica estado no player ---
	var dados_player = dados_do_save.get("player", {})
	var player_node = null
	for node in get_tree().get_nodes_in_group("player"):
		player_node = node
		if not dados_player.empty():
			if dados_player.has("pos_x"):
				node.translation = Vector3(
					dados_player["pos_x"], dados_player["pos_y"], dados_player["pos_z"]
				)
			# Rotação (pitch + yaw), stamina e escala ficam por conta do
			# load_data() do próprio player — ele sabe alinhar a câmera
			# corretamente (ver KinematicBody.gd).
			if node.has_method("load_data"):
				node.load_data(dados_player)
		break

	# --- PASSO 3: aplica estado nos objetos persistentes (portas, etc) ---
	var objetos_salvos = dados_do_save.get("objetos", {})
	for node in get_tree().get_nodes_in_group("Persist"):
		if node.is_in_group("player"):
			continue
		if not node.has_method("load_data"):
			continue
		var id_unico = _pegar_id(node)
		if objetos_salvos.has(id_unico):
			node.load_data(objetos_salvos[id_unico])

	# --- PASSO 4: reconecta item na mão (lanterna/fita), igual ao original ---
	if dados_player.get("lanterna_equipada", false) and player_node:
		yield(get_tree(), "idle_frame")
		var cam = player_node.get_node_or_null("Camera")
		if cam and cam.has_method("pegar_lanterna"):
			for item in get_tree().get_nodes_in_group("lanterna"):
				cam.pegar_lanterna(item)
				if dados_player.get("lanterna_ligada", false) and item.has_method("ligar"):
					item.ligar()
				break

	# Dados da fita: prioriza bloco dedicado, depois registry, depois player
	var fita_blob = dados_do_save.get("fita_inventario", {})
	if typeof(fita_blob) != TYPE_DICTIONARY:
		fita_blob = {}
	if fita_blob.empty() and typeof(dados_player) == TYPE_DICTIONARY:
		fita_blob = dados_player

	var fita_nome_salva = str(fita_blob.get("fita_nome", ""))
	var fita_audio_path_salva = str(fita_blob.get("fita_audio_path", ""))
	var fita_texto_salva = str(fita_blob.get("fita_texto", ""))
	var fita_calmante_salva = bool(fita_blob.get("fita_e_calmante", false))
	var fita_cor_salva = Color(
		float(fita_blob.get("fita_cor_r", 1.0)),
		float(fita_blob.get("fita_cor_g", 1.0)),
		float(fita_blob.get("fita_cor_b", 1.0)),
		float(fita_blob.get("fita_cor_a", 1.0))
	)

	# Completa pelo registry persistente (fitas_dados)
	if fita_nome_salva != "" and fitas_dados.has(fita_nome_salva):
		var reg = fitas_dados[fita_nome_salva]
		if fita_audio_path_salva == "" and str(reg.get("fita_audio_path", "")) != "":
			fita_audio_path_salva = str(reg["fita_audio_path"])
		if fita_texto_salva == "" and str(reg.get("fita_texto", "")) != "":
			fita_texto_salva = str(reg["fita_texto"])
		if reg.has("fita_cor_r"):
			fita_cor_salva = Color(
				float(reg.get("fita_cor_r", 1.0)),
				float(reg.get("fita_cor_g", 1.0)),
				float(reg.get("fita_cor_b", 1.0)),
				float(reg.get("fita_cor_a", 1.0))
			)
		fita_calmante_salva = bool(reg.get("fita_e_calmante", fita_calmante_salva))

	# Se inventário tem fita mas blob vazio, tenta última entrada do registry
	if (fita_nome_salva == "" or fita_audio_path_salva == "") and typeof(Inventory) != TYPE_NIL and Inventory.has_item("fita_cassete"):
		for k in fitas_dados.keys():
			# se a fita ainda NÃO foi marcada como reproduzida, é candidata
			var ja_tocou = fitas_reproduzidas.has(k) and fitas_reproduzidas[k]
			if ja_tocou:
				continue
			var reg2 = fitas_dados[k]
			fita_nome_salva = str(k)
			fita_audio_path_salva = str(reg2.get("fita_audio_path", ""))
			fita_texto_salva = str(reg2.get("fita_texto", ""))
			fita_calmante_salva = bool(reg2.get("fita_e_calmante", false))
			if reg2.has("fita_cor_r"):
				fita_cor_salva = Color(
					float(reg2.get("fita_cor_r", 1.0)),
					float(reg2.get("fita_cor_g", 1.0)),
					float(reg2.get("fita_cor_b", 1.0)),
					float(reg2.get("fita_cor_a", 1.0))
				)
			print("[SaveManager] Fita recuperada do registry: '%s'" % fita_nome_salva)
			break

	# Aplica na câmera
	if player_node and (fita_nome_salva != "" or fita_audio_path_salva != ""):
		var cam = player_node.get_node_or_null("Camera")
		if cam:
			cam.fita_nome = fita_nome_salva
			if "fita_audio_path" in cam:
				cam.fita_audio_path = fita_audio_path_salva
			cam.fita_texto = fita_texto_salva
			if "fita_cor" in cam:
				cam.fita_cor = fita_cor_salva
			if "fita_e_calmante" in cam:
				cam.fita_e_calmante = fita_calmante_salva
			# Carrega o stream — tenta path direto e depois ResourceLoader
			var stream = null
			if fita_audio_path_salva != "":
				if ResourceLoader.exists(fita_audio_path_salva):
					stream = load(fita_audio_path_salva)
				else:
					stream = ResourceLoader.load(fita_audio_path_salva, "", true)
			if stream:
				cam.fita_audio = stream
				print("[SaveManager] Fita restaurada completa: '%s' path=%s stream=%s" % [fita_nome_salva, fita_audio_path_salva, stream])
			else:
				push_warning("[SaveManager] Não carregou áudio da fita: nome=%s path=%s" % [fita_nome_salva, fita_audio_path_salva])
			# Garante registry
			registrar_fita_audio(fita_nome_salva, fita_audio_path_salva, fita_texto_salva, fita_cor_salva, fita_calmante_salva)

	# Inventário DEVE ter a fita se temos dados (save no meio da reprodução)
	if typeof(Inventory) != TYPE_NIL and (fita_nome_salva != "" or fita_audio_path_salva != ""):
		if not Inventory.has_item("fita_cassete"):
			Inventory.add_item("fita_cassete")
			print("[SaveManager] Fita recolocada no inventário após load.")

	# Sanity: inventário tem fita mas câmera sem áudio
	if typeof(Inventory) != TYPE_NIL and Inventory.has_item("fita_cassete"):
		if player_node:
			var cam2 = player_node.get_node_or_null("Camera")
			if cam2 and (cam2.fita_audio == null or str(cam2.fita_nome) == ""):
				# Última tentativa: qualquer registry
				for k3 in fitas_dados.keys():
					var reg3 = fitas_dados[k3]
					var p3 = str(reg3.get("fita_audio_path", ""))
					if p3 == "":
						continue
					cam2.fita_nome = str(k3)
					cam2.fita_audio_path = p3
					cam2.fita_texto = str(reg3.get("fita_texto", ""))
					if ResourceLoader.exists(p3):
						cam2.fita_audio = load(p3)
					print("[SaveManager] Fallback final fita: '%s' path=%s" % [k3, p3])
					break
				if cam2.fita_audio == null:
					push_warning("[SaveManager] Inventário tem fita_cassete mas NÃO foi possível restaurar o áudio.")

	auto_save_timer.start()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("🎯 [LOAD] Slot %d restaurado. %d itens coletados aplicados." % [
		slot, itens_coletados.size()
	])
	emit_signal("jogo_carregado")
	# Continua o tempo de jogo a partir do valor salvo
	iniciar_sessao_web(int(dados_do_save.get("playtime_seconds", 0)))
	return true


func _on_auto_save():
	auto_save_timer.start()
	var cena = get_tree().current_scene
	if cena and cena.filename == CENA_JOGO:
		var slot_alvo = current_slot if slot_ativo and current_slot >= 0 else 0
		save_game(slot_alvo)


func slot_has_save(slot: int) -> bool:
	return File.new().file_exists(_get_save_path(slot))


func delete_save(slot: int) -> bool:
	var path = _get_save_path(slot)
	var dir = Directory.new()
	if dir.file_exists(path):
		dir.remove(path)
	if current_slot == slot:
		current_slot = -1
		slot_ativo = false
	return true


func get_slot_info(slot: int) -> Dictionary:
	var path = _get_save_path(slot)
	var file = File.new()
	if not file.file_exists(path):
		return {
			"empty": true,
			"date": "",
			"time": "",
			"capitulo": "",
			"playtime": "",
			"fitas": 0,
		}
	var modified_time = file.get_modified_time(path)
	var datetime = OS.get_datetime_from_unix_time(
		modified_time + (OS.get_time_zone_info()["bias"] * 60)
	)
	var info = {
		"empty": false,
		"date": "%02d/%02d/%d" % [datetime.day, datetime.month, datetime.year],
		"time": "%02d:%02d" % [datetime.hour, datetime.minute],
		"capitulo": "O Limbo",
		"playtime": "",
		"fitas": 0,
	}
	# Lê metadados do JSON do save
	if file.open(path, File.READ) == OK:
		var texto = file.get_as_text()
		file.close()
		var dados = parse_json(texto)
		if typeof(dados) == TYPE_DICTIONARY:
			var pt = int(dados.get("playtime_seconds", 0))
			info["playtime"] = _format_playtime(pt)
			var fr = dados.get("fitas_reproduzidas", {})
			var ic = dados.get("itens_coletados", [])
			info["fitas"] = _contar_fitas_progresso(fr, ic)
			info["capitulo"] = _capitulo_por_progresso(fr, ic)
			if dados.has("capitulo") and str(dados["capitulo"]) != "":
				info["capitulo"] = str(dados["capitulo"])
	return info


func _format_playtime(secs: int) -> String:
	secs = max(secs, 0)
	var h = int(secs / 3600)
	var m = int((secs % 3600) / 60)
	if h > 0:
		return "%dh %02dm" % [h, m]
	return "%d min" % m


func _contar_fitas_progresso(fr, ic) -> int:
	var n = 0
	if typeof(fr) == TYPE_DICTIONARY:
		for k in fr.keys():
			if fr[k]:
				n += 1
	elif typeof(fr) == TYPE_ARRAY:
		n = fr.size()
	# fallback: itens coletados com "fita" no nome
	if n == 0 and typeof(ic) == TYPE_ARRAY:
		for item in ic:
			var s = str(item).to_lower()
			if "fita" in s:
				n += 1
	return n


## Títulos de capítulo alinhados à progressão das fitas (história da Laura).
func _capitulo_por_progresso(fr, ic) -> String:
	var nomes_ordem = [
		"Fita 01 - Primeiro Contato",
		"Fita 02",
		"Fita 03",
		"Fita 04",
		"Fita 05",
		"Fita 06",
		"Fita 07",
	]
	# Detecta quantas fitas normais já foram ouvidas / coletadas
	var nivel = 0
	var fontes = []
	if typeof(fr) == TYPE_DICTIONARY:
		for k in fr.keys():
			if fr[k]:
				fontes.append(str(k))
	if typeof(ic) == TYPE_ARRAY:
		for item in ic:
			fontes.append(str(item))

	for s in fontes:
		var low = s.to_lower()
		# douradas não avançam o arco principal do mesmo jeito
		if "dourad" in low or "golden" in low:
			continue
		for i in range(1, 8):
			if ("fita 0%d" % i) in low or ("fita0%d" % i) in low or ("fita %d" % i) in low or ("fita%d" % i) in low:
				nivel = max(nivel, i)
			# nomes parciais
			if i == 1 and ("primeiro contato" in low or "pais" in low):
				nivel = max(nivel, 1)

	var titulos = {
		0: "Chegada ao Limbo",
		1: "Laços de Família",
		2: "Diário Escondido",
		3: "Ethan",
		4: "A Escola",
		5: "A Biblioteca",
		6: "Paredes Finas",
		7: "Karen",
	}
	# Se ouviu douradas, sufixo especial
	var tem_dourada = false
	for s in fontes:
		var low = s.to_lower()
		if "dourad" in low or "sem certo" in low or "amizade" in low:
			tem_dourada = true
			break
	var base = titulos.get(nivel, "O Limbo")
	if tem_dourada and nivel >= 6:
		return base + " — Ecos"
	return base


# =====================================================================
# CONFIGURAÇÕES (áudio / legendas) — independente dos slots de save
# =====================================================================

func salvar_configuracoes() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "musica", volume_musica)
	config.set_value("audio", "sfx", volume_sfx)
	config.set_value("acessibilidade", "legendas", legendas_ativadas)
	config.set_value("video", "resolucao_index", resolucao_index)
	config.set_value("video", "tela_cheia", tela_cheia)
	config.set_value("controles", "sensibilidade_mouse", sensibilidade_mouse)
	config.set_value("controles", "inverter_mouse_y", inverter_mouse_y)
	config.save(CONFIG_PATH)


func carregar_configuracoes() -> void:
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	if err == OK:
		volume_musica = config.get_value("audio", "musica", 1.0)
		volume_sfx = config.get_value("audio", "sfx", 1.0)
		legendas_ativadas = config.get_value("acessibilidade", "legendas", true)
		resolucao_index = config.get_value("video", "resolucao_index", 0)
		tela_cheia = config.get_value("video", "tela_cheia", true)
		sensibilidade_mouse = config.get_value("controles", "sensibilidade_mouse", 1.0)
		inverter_mouse_y = config.get_value("controles", "inverter_mouse_y", false)
	_aplicar_volumes()
	aplicar_resolucao()
	# Aplica na câmera se ela já existir (ex.: config aberto no meio do jogo)
	aplicar_sensibilidade()

func _aplicar_volumes() -> void:
	var idx_music = AudioServer.get_bus_index("Music")
	if idx_music != -1:
		AudioServer.set_bus_volume_db(idx_music, linear2db(volume_musica))
	var idx_sfx = AudioServer.get_bus_index("SFX")
	if idx_sfx != -1:
		AudioServer.set_bus_volume_db(idx_sfx, linear2db(volume_sfx))

# Calcula, a partir do monitor real do jogador, quais resoluções fazem
# sentido oferecer — sempre mantendo a proporção (aspect ratio) da tela
# dele, pra não esticar/distorcer a imagem.
#
# Observação: no Windows com DPI scaling, OS.get_screen_size() às vezes
# devolve a resolução *lógica* (ex.: 1440x900) em vez da física (1080p/1440p).
# Por isso:
#  1) tentamos recuperar a resolução física
#  2) sempre oferecemos presets comuns até 4K, mesmo se o SO sub-reportar

func _resolucoes_fisicas_conhecidas() -> Array:
	return [
		Vector2(1280, 720), Vector2(1280, 800),
		Vector2(1366, 768), Vector2(1440, 900),
		Vector2(1600, 900), Vector2(1680, 1050),
		Vector2(1920, 1080), Vector2(1920, 1200),
		Vector2(2048, 1280), Vector2(2560, 1440), Vector2(2560, 1600),
		Vector2(2880, 1800), Vector2(3200, 2000),
		Vector2(3840, 2160), Vector2(3840, 2400)
	]

func _detectar_resolucao_tela() -> Vector2:
	# Tela atual (multi-monitor)
	var tela_atual = OS.get_current_screen()
	var reportada = OS.get_screen_size(tela_atual)
	if reportada.x < 640 or reportada.y < 360:
		reportada = OS.get_screen_size()

	# Windows costuma devolver resolução LÓGICA (DPI scale), não a física.
	# Ex.: monitor 1920x1200 @ 125% → OS reporta 1536x960.
	# get_screen_dpi() muitas vezes volta 96 mesmo com scaling → não confiar só nisso.
	var nativa = _recuperar_resolucao_fisica(reportada, tela_atual)

	if nativa.x < 640 or nativa.y < 360:
		nativa = Vector2(1920, 1080)

	print("[SaveManager] Tela reportada: %dx%d → física: %dx%d (%s)" % [
		int(reportada.x), int(reportada.y),
		int(nativa.x), int(nativa.y),
		_nome_aspecto(nativa.x / float(nativa.y))
	])
	return nativa

## Tenta achar a resolução física real a partir da lógica reportada pelo SO.
func _recuperar_resolucao_fisica(reportada: Vector2, tela_atual: int) -> Vector2:
	var conhecidas = _resolucoes_fisicas_conhecidas()

	# 1) Já é uma resolução física conhecida?
	for c in conhecidas:
		if abs(c.x - reportada.x) <= 2 and abs(c.y - reportada.y) <= 2:
			return c

	# 2) Escalas DPI comuns do Windows (100% … 300%)
	var escalas = [1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 3.0]

	# 2a) Via DPI se o SO reportar algo útil (> 100)
	if OS.has_method("get_screen_dpi"):
		var dpi = float(OS.get_screen_dpi(tela_atual))
		if dpi > 100.0:
			escalas.push_front(dpi / 96.0)

	var melhor = reportada
	var melhor_erro = 1e12
	var achou = false

	for escala in escalas:
		if escala < 1.01:
			continue
		var candidata = Vector2(
			round(reportada.x * escala),
			round(reportada.y * escala)
		)
		# Casa com resolução conhecida (tolerância a arredondamento)
		for c in conhecidas:
			var err = abs(c.x - candidata.x) + abs(c.y - candidata.y)
			if err < melhor_erro and err <= 8.0:
				melhor_erro = err
				melhor = c
				achou = true

	if achou:
		return melhor

	# 3) Inverso: alguma conhecida / escala ≈ reportada?
	melhor_erro = 1e12
	for c in conhecidas:
		if c.x < reportada.x - 2 or c.y < reportada.y - 2:
			continue
		for escala in escalas:
			if escala < 1.01:
				continue
			var logica = Vector2(round(c.x / escala), round(c.y / escala))
			var err = abs(logica.x - reportada.x) + abs(logica.y - reportada.y)
			if err < melhor_erro and err <= 6.0:
				melhor_erro = err
				melhor = c
				achou = true

	if achou:
		return melhor

	# 4) Não conseguiu mapear — devolve a reportada
	return reportada

func _nome_aspecto(aspecto: float) -> String:
	if abs(aspecto - 16.0 / 10.0) < 0.04:
		return "16:10"
	if abs(aspecto - 16.0 / 9.0) < 0.04:
		return "16:9"
	if abs(aspecto - 21.0 / 9.0) < 0.06:
		return "21:9"
	if abs(aspecto - 4.0 / 3.0) < 0.04:
		return "4:3"
	return "%.2f:1" % aspecto

func calcular_resolucoes_disponiveis() -> Array:
	var nativa = _detectar_resolucao_tela()
	var aspecto = nativa.x / float(nativa.y)
	var nome_asp = _nome_aspecto(aspecto)

	# Alturas típicas; 16:10 inclui 800/900/1050/1200/1600
	var alturas_candidatas = [360, 480, 720, 800, 900, 1050, 1080, 1200, 1440, 1600, 1800, 2160, 2400]
	var altura_nativa = int(nativa.y)
	if not alturas_candidatas.has(altura_nativa):
		alturas_candidatas.append(altura_nativa)
	alturas_candidatas.sort()

	var teto = altura_nativa
	var lista = []
	var vistos = {}
	for altura in alturas_candidatas:
		if altura > teto:
			continue
		var largura = int(round(altura * aspecto))
		# largura par (evita subpixel)
		if largura % 2 != 0:
			largura += 1
		if largura > int(nativa.x) + 2:
			continue
		var chave = "%dx%d" % [largura, altura]
		if vistos.has(chave):
			continue
		vistos[chave] = true

		var shrink = 1
		if altura < nativa.y:
			shrink = max(1, int(round(nativa.y / float(altura))))

		var label = "%d x %d" % [largura, altura]
		if altura == altura_nativa and abs(largura - int(nativa.x)) <= 2:
			label += " (nativa %s)" % nome_asp
		else:
			label += " (%s)" % nome_asp
		lista.append({"label": label, "shrink": shrink, "altura": altura, "largura": largura})

	if lista.empty():
		lista.append({
			"label": "%d x %d (nativa %s)" % [int(nativa.x), int(nativa.y), nome_asp],
			"shrink": 1,
			"altura": int(nativa.y),
			"largura": int(nativa.x)
		})

	return lista

# Chame isso no _ready() da cena principal (casa_ofc.tscn), passando
# o ViewportContainer que envolve o Player/sombra/fitas/urso etc.
func registrar_viewport_3d(container: ViewportContainer) -> void:
	_viewport_container_atual = container
	container.stretch = true
	# Crítico no Godot 3.6: sub-Viewport não escuta áudio 3D a menos que
	# audio_listener_enable_3d esteja true. Sem isso AudioStreamPlayer3D fica mudo.
	if container.has_node("Viewport"):
		var vp = container.get_node("Viewport")
		if vp is Viewport:
			vp.audio_listener_enable_3d = true
			vp.audio_listener_enable_2d = true
	_aplicar_resolucao_3d()

func _aplicar_resolucao_3d() -> void:
	if _viewport_container_atual == null or not is_instance_valid(_viewport_container_atual):
		_viewport_container_atual = null
		return
	var opcoes = calcular_resolucoes_disponiveis()
	if resolucao_index >= opcoes.size():
		resolucao_index = 0
	_viewport_container_atual.stretch_shrink = opcoes[resolucao_index]["shrink"]
	_aplicar_antialiasing(opcoes[resolucao_index]["altura"])

# FXAA + MSAA 4x ligados automaticamente a partir de 720p (abaixo disso,
# o custo não compensa e some com a nitidez, então fica desligado).
func _aplicar_antialiasing(altura: int) -> void:
	if _viewport_container_atual == null or not _viewport_container_atual.has_node("Viewport"):
		return
	var viewport_3d = _viewport_container_atual.get_node("Viewport")
	if altura >= 720:
		viewport_3d.msaa = Viewport.MSAA_4X
		viewport_3d.fxaa = true
	else:
		viewport_3d.msaa = Viewport.MSAA_DISABLED
		viewport_3d.fxaa = false

func aplicar_resolucao() -> void:
	OS.window_fullscreen = tela_cheia
	var opcoes = calcular_resolucoes_disponiveis()
	if resolucao_index >= opcoes.size():
		resolucao_index = 0
	var escolha = opcoes[resolucao_index]
	var w = int(escolha.get("largura", 0))
	var h = int(escolha.get("altura", 0))
	if w <= 0 or h <= 0:
		var nativa = _detectar_resolucao_tela()
		w = int(nativa.x)
		h = int(nativa.y)
	if not tela_cheia:
		OS.window_size = Vector2(w, h)
	_aplicar_resolucao_3d()

func aplicar_sensibilidade() -> void:
	var cams = Engine.get_main_loop().get_nodes_in_group("camera_player")
	for cam in cams:
		if cam.has_method("set_sensibilidade_mult"):
			cam.set_sensibilidade_mult(sensibilidade_mouse)
			
func _limpar_uis_do_jogo() -> void:
	Legendas.parar()
	get_tree().call_group("ui_persistente", "queue_free")
	for nodo in get_tree().get_nodes_in_group("reparentar_hud"):
		if is_instance_valid(nodo):
			nodo.queue_free()
	# Segurança extra: qualquer CrosshairUI órfã na raiz
	for nodo in get_tree().root.get_children():
		if not is_instance_valid(nodo):
			continue
		if nodo.name == "CrosshairUI" or nodo.name == "hud":
			nodo.queue_free()
	if typeof(TutorialManager) != TYPE_NIL:
		TutorialManager.limpar_ui_ao_sair()

# =====================================================================
# SITE / API — progresso (fitas, cartas, tempo de jogo)
# =====================================================================
# Token: salve o JWT do site em user://limbo_web_token.txt
# (localStorage "lm_token" depois do login) OU:
#   SaveManager.set_web_token("seu_token_aqui")

func set_web_token(token: String) -> void:
	_web_token = str(token).strip_edges()
	var f = File.new()
	if f.open(WEB_TOKEN_PATH, File.WRITE) == OK:
		f.store_string(_web_token)
		f.close()
	print("[SaveManager] Token web salvo.")


func get_web_token() -> String:
	if _web_token != "":
		return _web_token
	_carregar_web_token()
	return _web_token


func _carregar_web_token() -> void:
	var f = File.new()
	if not f.file_exists(WEB_TOKEN_PATH):
		_web_token = ""
		return
	if f.open(WEB_TOKEN_PATH, File.READ) != OK:
		_web_token = ""
		return
	_web_token = f.get_as_text().strip_edges()
	f.close()


func iniciar_sessao_web(playtime_base_seconds: int = 0) -> void:
	_web_playtime_base = int(max(0, int(playtime_base_seconds)))
	_web_sessao_inicio_msec = OS.get_ticks_msec()
	_web_sessao_ativa = true
	if _web_sync_timer:
		_web_sync_timer.start()
	print("[SaveManager] Sessão web iniciada (playtime base=%ds)." % _web_playtime_base)
	sincronizar_progresso_web()
	enviar_presenca_web()


func encerrar_sessao_web() -> void:
	if _web_sessao_ativa:
		sincronizar_progresso_web()
	_web_sessao_ativa = false
	if _web_sync_timer:
		_web_sync_timer.stop()


func get_playtime_seconds() -> int:
	if not _web_sessao_ativa:
		return int(max(0, _web_playtime_base))
	var extra = int((OS.get_ticks_msec() - _web_sessao_inicio_msec) / 1000.0)
	return int(max(0, _web_playtime_base + extra))



func _contar_fitas_web() -> Dictionary:
	var normais := 0
	var douradas := 0
	for k in fitas_reproduzidas.keys():
		if not fitas_reproduzidas[k]:
			continue
		var n := str(k).to_lower()
		if "dourad" in n or "gold" in n or "golden" in n:
			douradas += 1
		else:
			normais += 1
	return {
		"normais": int(clamp(normais, 0, 7)),
		"douradas": int(clamp(douradas, 0, 2))
	}


func _contar_cartas_web() -> int:
	if typeof(CartasInventory) != TYPE_NIL and CartasInventory.has_method("quantidade"):
		return int(clamp(CartasInventory.quantidade(), 0, 20))
	return 0


func _on_web_sync_timer() -> void:
	if _web_sessao_ativa:
		sincronizar_progresso_web()


## Zera playtime/fitas/cartas no site (Novo Jogo). Requer token.
## A API normal (PUT /progress) só sobe valores (GREATEST) — por isso existe
## o endpoint dedicado POST /progress/reset.
func resetar_progresso_web() -> void:
	var token := get_web_token()
	if token == "":
		print("[SaveManager] Novo jogo offline — progresso do site não alterado.")
		iniciar_sessao_web(0)
		return
	if _http_web == null:
		iniciar_sessao_web(0)
		return
	# Garante contadores locais zerados antes de qualquer sync futuro
	_web_playtime_base = 0
	_web_sessao_inicio_msec = OS.get_ticks_msec()
	_web_sessao_ativa = true
	fitas_reproduzidas.clear()
	fitas_dados.clear()
	if typeof(CartasInventory) != TYPE_NIL and CartasInventory.has_method("clear"):
		CartasInventory.clear()

	if _web_sync_em_andamento:
		# Espera a request atual e tenta de novo
		_web_sync_pendente_reset = true
		print("[SaveManager] Reset web adiado (HTTP ocupada).")
		return

	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token
	]
	_web_callback = "_on_progress_reset_done"
	_web_sync_em_andamento = true
	_web_sync_pendente = false
	var err := _http_web.request(WEB_API_URL + "/progress/reset", headers, true, HTTPClient.METHOD_POST, "{}")
	if err != OK:
		_web_sync_em_andamento = false
		_web_callback = ""
		push_warning("[SaveManager] Falha ao iniciar reset web: %s" % str(err))
		iniciar_sessao_web(0)
	else:
		print("[SaveManager] Reset de progresso enviado ao site...")



func _on_progress_reset_done(result: int, response_code: int, body_text: String) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		push_warning("[SaveManager] Reset web falhou (HTTP %d): %s" % [response_code, body_text])
	else:
		print("[SaveManager] Progresso do site zerado (Novo Jogo).")
	# Sessão começa do zero localmente de qualquer forma
	_web_playtime_base = 0
	_web_sessao_inicio_msec = OS.get_ticks_msec()
	_web_sessao_ativa = true
	if _web_sync_timer:
		_web_sync_timer.start()
	if _web_sync_pendente:
		call_deferred("sincronizar_progresso_web")



## Heartbeat de "online" no site
func enviar_presenca_web() -> void:
	var token := get_web_token()
	if token == "" or _http_web == null:
		return
	if _web_sync_em_andamento:
		return
	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token
	]
	_web_callback = "_on_presence_done"
	_web_sync_em_andamento = true
	var err := _http_web.request(WEB_API_URL + "/presence", headers, true, HTTPClient.METHOD_POST, "{}")
	if err != OK:
		_web_sync_em_andamento = false
		_web_callback = ""


func _on_presence_done(_result: int, _response_code: int, _body_text: String) -> void:
	pass


func sincronizar_progresso_web() -> void:

	var token := get_web_token()
	if token == "":
		return
	if _http_web == null:
		return
	# Se HTTP ocupada (upload de save etc.), marca pendente e tenta de novo depois
	if _web_sync_em_andamento:
		_web_sync_pendente = true
		return

	var fitas := _contar_fitas_web()
	var pt := get_playtime_seconds()
	var body := {
		"playtime_seconds": pt,
		"fitas_normais": fitas["normais"],
		"fitas_douradas": fitas["douradas"],
		"cartas": _contar_cartas_web()
	}
	var json_body := to_json(body)
	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token
	]
	var url := WEB_API_URL + "/progress"
	_web_callback = ""
	_web_sync_em_andamento = true
	_web_sync_pendente = false
	var err := _http_web.request(url, headers, true, HTTPClient.METHOD_PUT, json_body)
	if err != OK:
		_web_sync_em_andamento = false
		_web_sync_pendente = true
		push_warning("[SaveManager] Falha ao iniciar request web: %s" % str(err))
	else:
		print("[SaveManager] Sync progresso enviado (playtime=%ds, cartas=%d)." % [pt, body["cartas"]])


func _on_web_request_completed(result: int, response_code: int, headers: PoolStringArray, body: PoolByteArray) -> void:
	_web_sync_em_andamento = false
	var body_text := body.get_string_from_utf8()
	var cb := _web_callback
	_web_callback = ""
	if cb == "_on_cloud_upload_done":
		_on_cloud_upload_done(result, response_code, body_text)
		if _web_sync_pendente_reset:
			_web_sync_pendente_reset = false
			call_deferred("resetar_progresso_web")
		elif _web_sync_pendente:
			call_deferred("sincronizar_progresso_web")
		return
	if cb == "_on_cloud_download_done":
		_on_cloud_download_done(result, response_code, body_text)
		if _web_sync_pendente_reset:
			_web_sync_pendente_reset = false
			call_deferred("resetar_progresso_web")
		return
	if cb == "_on_presence_done":
		_on_presence_done(result, response_code, body_text)
		return
	if cb == "_on_progress_reset_done":
		_on_progress_reset_done(result, response_code, body_text)
		return
	# callback padrão = sync de progresso
	if result != HTTPRequest.RESULT_SUCCESS:
		push_warning("[SaveManager] Sync web falhou (result=%d)." % result)
		if _web_sync_pendente:
			call_deferred("sincronizar_progresso_web")
		return
	if response_code == 401 or response_code == 403:
		push_warning("[SaveManager] Token web inválido/expirado (HTTP %d)." % response_code)
		return
	if response_code < 200 or response_code >= 300:
		push_warning("[SaveManager] Sync web HTTP %d: %s" % [response_code, body_text])
		return
	print("[SaveManager] Progresso sincronizado com o site.")
	call_deferred("enviar_presenca_web")
	if _web_sync_pendente:
		call_deferred("sincronizar_progresso_web")


# =====================================================================
# SAVE EM NUVEM (conta logada)
# =====================================================================

func enviar_save_nuvem(slot: int) -> void:
	var token := get_web_token()
	if token == "":
		return
	if slot < 0:
		return
	var path := _get_save_path(slot)
	var f := File.new()
	if not f.file_exists(path):
		return
	if f.open(path, File.READ) != OK:
		return
	var texto := f.get_as_text()
	f.close()
	var dados = parse_json(texto)
	if typeof(dados) != TYPE_DICTIONARY:
		return
	_web_request_json(
		HTTPClient.METHOD_PUT,
		"/saves/%d" % slot,
		{"data": dados},
		"_on_cloud_upload_done"
	)


func baixar_save_nuvem(slot: int) -> void:
	var token := get_web_token()
	if token == "":
		return
	_cloud_slot_pendente = slot
	_web_request_json(HTTPClient.METHOD_GET, "/saves/%d" % slot, null, "_on_cloud_download_done")


var _cloud_slot_pendente: int = -1
var _web_callback: String = ""


func _web_request_json(method: int, path: String, body, callback_method: String) -> void:
	var token := get_web_token()
	if token == "" or _http_web == null:
		return
	if _web_sync_em_andamento:
		# evita colidir com outro request; tenta de novo em breve
		if callback_method == "_on_cloud_upload_done":
			call_deferred("enviar_save_nuvem", _cloud_slot_pendente if _cloud_slot_pendente >= 0 else current_slot)
		return
	_web_callback = callback_method
	_web_sync_em_andamento = true
	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token
	]
	var payload := ""
	if body != null:
		payload = to_json(body)
	var err := _http_web.request(WEB_API_URL + path, headers, true, method, payload)
	if err != OK:
		_web_sync_em_andamento = false
		_web_callback = ""
		push_warning("[SaveManager] Request nuvem falhou ao iniciar: %s" % str(err))


func _on_cloud_upload_done(result: int, response_code: int, body_text: String) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		push_warning("[SaveManager] Upload nuvem falhou (HTTP %d)." % response_code)
		return
	print("[SaveManager] Save enviado para a nuvem.")


func _on_cloud_download_done(result: int, response_code: int, body_text: String) -> void:
	var slot := _cloud_slot_pendente
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		push_warning("[SaveManager] Download nuvem falhou (HTTP %d) — usando save local se houver." % response_code)
	else:
		var data = parse_json(body_text)
		if typeof(data) == TYPE_DICTIONARY:
			var save_data = data.get("data", null)
			if typeof(save_data) == TYPE_DICTIONARY and slot >= 0:
				var f := File.new()
				if f.open(_get_save_path(slot), File.WRITE) == OK:
					f.store_string(to_json(save_data))
					f.close()
					print("[SaveManager] Save da nuvem gravado no slot %d local." % slot)
	if _pending_load_after_cloud:
		_pending_load_after_cloud = false
		get_tree().change_scene(CENA_LOADING)
