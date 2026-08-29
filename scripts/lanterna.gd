extends RigidBody
onready var luz = $Flashlight/SpotLight
onready var mesh_principal = $Flashlight
onready var outline_mesh = $Flashlight/OutlineMesh
onready var area_colisao = $Area
var ligada = false
var pode_tocar = true
var recuando = false

# --- Equipada na mão ---
var equipada : bool = false

# Animação de "sumir pra baixo" (sai da tela)
export var sumir_baixo_amount : float = 0.55
export var sumir_rot_amount   : float = 35.0
export var velocidade_anim    : float = 9.0

var _offset_y_alvo   : float = 0.0
var _offset_y_atual  : float = 0.0
var _rot_x_alvo      : float = 0.0
var _rot_x_atual     : float = 0.0

# Guarda se a lanterna estava ligada antes de sumir
var _estava_ligada_antes : bool = false
var _sumiu_por_colisao   : bool = false
# Esconde sozinha quando desligada (mesma animação de colisão)
var _sumiu_por_desligada : bool = false
var _timer_esconder_desligada : float = -1.0
const TEMPO_ESCONDER_APOS_DESLIGAR : float = 2.0

# Contador de colisões sólidas (sem o player)
var _colisao_count : int = 0
# Só volta a subir depois de ficar livre por um tempinho (evita oscilar)
var _cooldown_voltar : float = 0.0
const TEMPO_LIVRE_PARA_VOLTAR : float = 0.3

var _energia_base : float = 1.0

func _ready():
	add_to_group("interagivel")
	add_to_group("lanterna")
	add_to_group("Persist")
	luz.visible = false
	_energia_base = luz.light_energy if luz else 1.0
	if outline_mesh:
		outline_mesh.visible = false
	
	area_colisao.add_to_group("interagivel")
	area_colisao.set_meta("door_parent", self)
	area_colisao.connect("body_entered", self, "_on_body_entered")
	area_colisao.connect("body_exited", self, "_on_body_exited")

func marcar_equipada(valor: bool) -> void:
	equipada = valor
	recuando = false
	_sumiu_por_colisao = false
	_sumiu_por_desligada = false
	_timer_esconder_desligada = -1.0
	_colisao_count = 0
	_cooldown_voltar = 0.0
	if valor:
		# Equipada: mesh some pra baixo até o jogador LIGAR a lanterna
		visible = true
		if mesh_principal:
			mesh_principal.visible = true
		_offset_y_alvo = -sumir_baixo_amount
		_rot_x_alvo = sumir_rot_amount
		_offset_y_atual = -sumir_baixo_amount
		_rot_x_atual = sumir_rot_amount
		_sumiu_por_desligada = true
		if mesh_principal:
			mesh_principal.translation.y = _offset_y_atual
			mesh_principal.rotation_degrees.x = _rot_x_atual
	else:
		_offset_y_atual = 0.0
		_offset_y_alvo  = 0.0
		_rot_x_atual    = 0.0
		_rot_x_alvo     = 0.0
		translation.y   = 0.0
		rotation_degrees.x = 0.0
		if mesh_principal:
			mesh_principal.translation.y = 0.0
			mesh_principal.rotation_degrees.x = 0.0

func save() -> Dictionary:
	# Se está na mão, a posição do mundo não importa (SaveManager recoloca na câmera)
	var na_mao = equipada or Inventory.has_item("lanterna")
	return {
		"node_path": str(get_path()),
		"pos_x": translation.x,
		"pos_y": translation.y,
		"pos_z": translation.z,
		"ligada": ligada,
		"equipada": na_mao
	}

func load_data(data: Dictionary) -> void:
	ligada = data.get("ligada", false)
	var estava_equipada = data.get("equipada", false) or Inventory.has_item("lanterna")
	if estava_equipada:
		visible = false
		luz.visible = false
		return
	visible = true
	luz.visible = ligada
	if luz and ligada:
		luz.light_energy = _energia_base
	translation = Vector3(
		data.get("pos_x", translation.x),
		data.get("pos_y", translation.y),
		data.get("pos_z", translation.z)
	)

func _on_body_entered(body):
	if body.is_in_group("player"):
		return

	if equipada:
		_colisao_count += 1
		_cooldown_voltar = 0.0
		if _colisao_count == 1:
			_iniciar_sumir()
	else:
		recuando = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		return

	if equipada:
		_colisao_count = max(_colisao_count - 1, 0)
		# NÃO chama _iniciar_voltar aqui — o _physics_process decide
		# com hysteresis, senão oscila sobe/desce na parede
	else:
		if area_colisao.get_overlapping_bodies().size() <= 1:
			recuando = false

func _iniciar_sumir() -> void:
	if _sumiu_por_colisao:
		return
	_sumiu_por_colisao = true
	_cooldown_voltar = 0.0
	_estava_ligada_antes = ligada
	# Só esconde o MESH — a luz CONTINUA acesa se estava ligada
	_offset_y_alvo = -sumir_baixo_amount
	_rot_x_alvo    = sumir_rot_amount

func _iniciar_voltar() -> void:
	if not _sumiu_por_colisao:
		return
	if _colisao_count > 0:
		return  # ainda tem parede na Area — não sobe
	_sumiu_por_colisao = false
	_cooldown_voltar = 0.0
	# Volta o mesh se a luz ainda está acesa; se desligou na parede, fica escondida
	if ligada:
		_offset_y_alvo = 0.0
		_rot_x_alvo    = 0.0
		_sumiu_por_desligada = false
	else:
		_sumiu_por_desligada = true
		_offset_y_alvo = -sumir_baixo_amount
		_rot_x_alvo    = sumir_rot_amount

func _physics_process(delta):
	if equipada:
		# Timer: desligada → esconde após 2s
		if _timer_esconder_desligada >= 0.0 and not ligada and not _sumiu_por_colisao:
			_timer_esconder_desligada += delta
			if _timer_esconder_desligada >= TEMPO_ESCONDER_APOS_DESLIGAR:
				_timer_esconder_desligada = -1.0
				_iniciar_sumir_desligada()

		# Anima só o MESH — a Area fica no lugar.
		var t = 1.0 - exp(-velocidade_anim * delta)
		_offset_y_atual = lerp(_offset_y_atual, _offset_y_alvo, t)
		_rot_x_atual    = lerp(_rot_x_atual,    _rot_x_alvo,    t)
		if mesh_principal:
			mesh_principal.translation.y = _offset_y_atual
			mesh_principal.rotation_degrees.x = _rot_x_atual
		translation.y = 0.0
		rotation_degrees.x = 0.0

		if _sumiu_por_colisao:
			if _colisao_count <= 0:
				_cooldown_voltar += delta
				if _cooldown_voltar >= TEMPO_LIVRE_PARA_VOLTAR:
					_iniciar_voltar()
			else:
				_cooldown_voltar = 0.0
	else:
		if recuando:
			translation.z = lerp(translation.z, -5.0, 12.0 * delta)
		else:
			translation.z = lerp(translation.z, 0.0, 12.0 * delta)

func ligar():
	ligada = true
	luz.visible = true
	if luz:
		luz.light_energy = _energia_base
	_timer_esconder_desligada = -1.0
	# Mostra a lanterna (sobe) ao ligar
	if equipada:
		_sumiu_por_desligada = false
		_offset_y_alvo = 0.0
		_rot_x_alvo = 0.0
		if _sumiu_por_colisao and _colisao_count <= 0:
			_sumiu_por_colisao = false

func desligar():
	ligada = false
	luz.visible = false
	if luz:
		luz.light_energy = _energia_base
	# Após 2s esconde com a animação de “descer”
	if equipada and not _sumiu_por_colisao:
		_timer_esconder_desligada = 0.0

func alternar():
	# Pode ligar mesmo “escondida”; não pode se estiver em colisão com parede
	if _sumiu_por_colisao and _colisao_count > 0:
		return
	if ligada:
		desligar()
	else:
		ligar()

func _iniciar_sumir_desligada() -> void:
	if _sumiu_por_colisao:
		return
	_sumiu_por_desligada = true
	_offset_y_alvo = -sumir_baixo_amount
	_rot_x_alvo = sumir_rot_amount

func set_foco(ativo):
	if outline_mesh:
		outline_mesh.visible = ativo
	pode_tocar = not ativo

func interagir(player):
	if Inventory.has_item("lanterna"):
		return
	Inventory.add_item("lanterna")
	player.pegar_lanterna(self)
	TelaPickup.mostrar_item("Lanterna", "Uma lanterna normal. O nome 'Karen' está escrito nela...", preload("res://assets/scenes_pickup/flashlight_pickup.tscn"))

func pode_interagir(player):
	return player.lanterna_atual == null

func get_spot() -> SpotLight:
	return luz

# True quando a mesh da lanterna está "na mão" visível na tela
# (não sumida pra baixo por colisão/desligada).
func esta_visivel_na_mao() -> bool:
	if not equipada:
		return false
	# offset perto de 0 = levantada / visível
	return _offset_y_atual > -sumir_baixo_amount * 0.5
