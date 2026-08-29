extends Area

# Aceita OmniLight ou SpotLight como pai (antes só OmniLight → várias zonas
# simplesmente nunca ligavam esta_na_luz).
var luz: Light = null
var _jogador_dentro: Node = null
var _estado_luz_anterior: bool = false

func _ready() -> void:
	add_to_group("zona_luz")
	set_process(true)

	luz = get_parent() as Light
	if luz == null:
		# fallback: procura qualquer Light entre os irmãos / filhos do pai
		var pai = get_parent()
		if pai:
			for c in pai.get_children():
				if c is Light:
					luz = c
					break

	if not is_connected("body_entered", self, "_on_body_entered"):
		connect("body_entered", self, "_on_body_entered")
	if not is_connected("body_exited", self, "_on_body_exited"):
		connect("body_exited", self, "_on_body_exited")

func _process(_delta: float) -> void:
	if not _jogador_dentro or not is_instance_valid(_jogador_dentro):
		_jogador_dentro = null
		return

	var luz_ativa = _light_is_active()
	if luz_ativa != _estado_luz_anterior:
		_estado_luz_anterior = luz_ativa
		if luz_ativa and _jogador_dentro.has_method("entrar_zona_luz"):
			_jogador_dentro.entrar_zona_luz()
		elif not luz_ativa and _jogador_dentro.has_method("sair_zona_luz"):
			_jogador_dentro.sair_zona_luz()

func _on_body_entered(body: Node) -> void:
	# Só o player de verdade — evita KinematicBody aleatório (sombra, etc)
	if not body.is_in_group("player"):
		return
	_jogador_dentro = body
	_estado_luz_anterior = _light_is_active()
	if _estado_luz_anterior and body.has_method("entrar_zona_luz"):
		body.entrar_zona_luz()

func _on_body_exited(body: Node) -> void:
	if body != _jogador_dentro:
		return
	if _estado_luz_anterior and body.has_method("sair_zona_luz"):
		body.sair_zona_luz()
	_jogador_dentro = null
	_estado_luz_anterior = false

func _light_is_active() -> bool:
	if luz == null or not is_instance_valid(luz):
		return false
	# visible=false (sombra apagando luzes) OU energy ~0 → zona inativa
	if not luz.is_visible_in_tree():
		return false
	if luz.light_energy <= 0.01:
		return false
	return true
