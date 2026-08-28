extends Spatial

export(NodePath) var caminho_superficie
export(NodePath) var caminho_viewport
export(NodePath) var caminho_camera_espelho
export var ativar_apenas_perto := true
export var distancia_ativacao := 6.0

onready var superficie   : MeshInstance = get_node(caminho_superficie)
onready var viewport      : Viewport     = get_node(caminho_viewport)
onready var camera_espelho: Camera       = get_node(caminho_camera_espelho)

var camera_player : Camera = null
var material_espelho : SpatialMaterial

func _ready() -> void:
	# Pega a câmera do player pelo grupo, sem depender de path fixo
	var jogadores = get_tree().get_nodes_in_group("camera_player")
	if jogadores.size() > 0:
		camera_player = jogadores[0]

	# A câmera do espelho precisa ver a layer da cabeça que a câmera
	# principal esconde — libera todas as layers no espelho
	camera_espelho.cull_mask = 0xFFFFF  # todas as 20 layers

	# Aplica a textura do viewport como reflexo no material do vidro
	material_espelho = superficie.get_surface_material(0)
	if material_espelho == null:
		material_espelho = SpatialMaterial.new()
	material_espelho.albedo_texture = viewport.get_texture()
	material_espelho.flags_unshaded = true  # reflexo não recebe luz da cena, só mostra a imagem
	superficie.set_surface_material(0, material_espelho)


func _process(_delta: float) -> void:
	if camera_player == null:
		return

	# Otimização: só renderiza o espelho se o jogador estiver perto
	if ativar_apenas_perto:
		var perto = global_transform.origin.distance_to(camera_player.global_transform.origin) < distancia_ativacao
		viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS if perto else Viewport.UPDATE_DISABLED
		if not perto:
			return

	_atualizar_camera_espelho()


func _atualizar_camera_espelho() -> void:
	var normal_espelho = -global_transform.basis.z.normalized()
	var ponto_espelho  = global_transform.origin

	var pos_relativa  = camera_player.global_transform.origin - ponto_espelho
	var dist_ao_plano = pos_relativa.dot(normal_espelho)
	var pos_refletida = camera_player.global_transform.origin - 2.0 * dist_ao_plano * normal_espelho

	camera_espelho.global_transform.origin = pos_refletida

	var forward           = -camera_player.global_transform.basis.z
	var forward_refletido = forward - 2.0 * forward.dot(normal_espelho) * normal_espelho
	var up_refletido       = camera_player.global_transform.basis.y

	camera_espelho.global_transform = camera_espelho.global_transform.looking_at(
		pos_refletida + forward_refletido, up_refletido)

	camera_espelho.fov = camera_player.fov

	# NOVO — corta tudo que está entre a câmera-espelho e o plano do
	# espelho (ex: o cômodo do outro lado da parede), senão isso
	# aparece renderizado por cima do reflexo do quarto certo.
	var dist_cam_ao_plano = abs(dist_ao_plano)
	camera_espelho.near = max(0.05, dist_cam_ao_plano - 0.05)
