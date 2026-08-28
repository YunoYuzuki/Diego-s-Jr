extends Spatial
# =============================================================
# Cole este script no objeto (cama, fita, ursinho, Spatial, etc.)
# No Inspector aparece a caixinha "Fita Tocada"
# =============================================================

# >>> ESCREVE O NOME DA FITA AQUI (Inspector) <<<
export(String) var fita_tocada = ""

export(String) var id_unico = ""
export(bool) var comecar_escondido = true
export(bool) var desabilitar_colisao = true
export(bool) var bloquear_interacao = true

var _visivel_agora = false
var _colisores = []

func _ready():
	add_to_group("quarto_laura")
	add_to_group("Persist")
	if str(id_unico).strip_edges() == "":
		id_unico = name
	_cache_colisores()
	if comecar_escondido:
		_aplicar(false, false)
	call_deferred("atualizar_visibilidade")
	set_process(true)

func _process(_delta):
	atualizar_visibilidade()
	if _visivel_agora:
		set_process(false)

func atualizar_visibilidade():
	var deve = _deve_aparecer()
	if deve == _visivel_agora:
		if deve:
			set_process(false)
		return
	_aplicar(deve, true)
	if deve:
		set_process(false)

func _deve_aparecer():
	if typeof(QuartoLaura) != TYPE_NIL and QuartoLaura.has_method("item_ja_apareceu"):
		if QuartoLaura.item_ja_apareceu(_meu_id()):
			return true

	var nome_fita = str(fita_tocada).strip_edges()
	if nome_fita == "":
		return true

	if typeof(QuartoLaura) != TYPE_NIL and QuartoLaura.has_method("fita_foi_tocada"):
		return QuartoLaura.fita_foi_tocada(nome_fita)

	if typeof(SaveManager) == TYPE_NIL:
		return false
	if SaveManager.fitas_reproduzidas.has(nome_fita):
		return true
	var alvo = nome_fita.to_lower()
	for k in SaveManager.fitas_reproduzidas.keys():
		var ks = str(k).to_lower().strip_edges()
		if ks == alvo or alvo in ks or ks in alvo:
			return true
	return false

func _meu_id():
	if str(id_unico).strip_edges() != "":
		return str(id_unico).strip_edges()
	return str(name)

func _aplicar(mostrar, registrar_save):
	_visivel_agora = mostrar
	visible = mostrar

	if desabilitar_colisao:
		for info in _colisores:
			var cs = info.node
			if cs == null or not is_instance_valid(cs):
				continue
			if cs is CollisionShape:
				cs.disabled = not mostrar

	if bloquear_interacao:
		if mostrar:
			if not is_in_group("interagivel"):
				add_to_group("interagivel")
		else:
			if is_in_group("interagivel"):
				remove_from_group("interagivel")

	if mostrar and registrar_save:
		if typeof(QuartoLaura) != TYPE_NIL and QuartoLaura.has_method("marcar_item_aparecido"):
			QuartoLaura.marcar_item_aparecido(_meu_id())

	if mostrar:
		print("Apareceu: ", name, " | Fita Tocada='", fita_tocada, "'")
	else:
		print("Escondido: ", name, " | espera Fita Tocada='", fita_tocada, "'")

func _cache_colisores():
	_colisores = []
	_coletar_colisores(self)

func _coletar_colisores(n):
	for c in n.get_children():
		if c is CollisionShape:
			_colisores.append({"node": c})
		_coletar_colisores(c)

func save():
	return {
		"node_path": str(get_path()),
		"id_unico": _meu_id(),
		"apareceu": _visivel_agora,
		"fita_tocada": fita_tocada
	}

func load_data(data):
	if data.get("apareceu", false):
		if typeof(QuartoLaura) != TYPE_NIL and QuartoLaura.has_method("marcar_item_aparecido"):
			QuartoLaura.marcar_item_aparecido(data.get("id_unico", _meu_id()))
		_aplicar(true, false)
		set_process(false)
