extends CanvasLayer
onready var titulo = $Control/Titulo
onready var descricao = $Control/Descricao
onready var item_holder = $Control/ViewportContainer/Viewport/ItemHolder
onready var item_camera = $Control/ViewportContainer/Viewport/Camera
onready var item_viewport = $Control/ViewportContainer/Viewport
onready var painel = $Control
var item_atual = null
var itens_ja_mostrados = {}  # guarda os nomes dos itens que já apareceram
var _luz_item: OmniLight = null

func _ready():
	layer = 100
	painel.visible = false
	item_viewport.own_world = true
	item_viewport.transparent_bg = true
	_garantir_luz()


func _garantir_luz() -> void:
	# Viewport com own_world não tem luzes do mundo → mesh fica preto/invisível
	if is_instance_valid(_luz_item):
		return
	_luz_item = OmniLight.new()
	_luz_item.name = "PickupLight"
	_luz_item.light_energy = 1.6
	_luz_item.light_color = Color(1.0, 0.98, 0.92)
	_luz_item.omni_range = 12.0
	_luz_item.translation = Vector3(1.2, 1.5, 2.5)
	item_viewport.add_child(_luz_item)
	# Segunda luz de preenchimento (mais fraca, do outro lado)
	var fill = OmniLight.new()
	fill.name = "PickupFill"
	fill.light_energy = 0.55
	fill.light_color = Color(0.75, 0.82, 1.0)
	fill.omni_range = 10.0
	fill.translation = Vector3(-1.5, 0.8, 1.0)
	item_viewport.add_child(fill)


## Mostra o pickup clonando meshes visuais de um node do mundo (ex.: bateria no chão).
func mostrar_item_de_node(nome_item, texto_descricao, node_origem: Node, forcar: bool = true) -> void:
	if not forcar and itens_ja_mostrados.has(nome_item):
		return
	itens_ja_mostrados[nome_item] = true

	titulo.text = "Item Adquirido"
	descricao.text = texto_descricao

	if item_atual:
		item_atual.queue_free()
		item_atual = null

	_garantir_luz()

	var clone = _clonar_visuais(node_origem)
	if clone:
		item_atual = clone
		item_holder.add_child(item_atual)
		item_atual.translation = Vector3.ZERO
		# Força atualização de transforms antes de medir AABB
		item_atual.force_update_transform()
		var aabb = get_aabb_combinada(item_atual)
		if aabb.size.length() < 0.001:
			# Fallback se AABB veio vazia (meshes ainda não prontos / hierarquia estranha)
			aabb = AABB(Vector3(-0.1, -0.1, -0.1), Vector3(0.2, 0.2, 0.2))
		item_atual.translation = -(aabb.position + aabb.size / 2.0)
		var raio = aabb.size.length() / 2.0
		if raio <= 0.0:
			raio = 0.5
		var fov_rad = deg2rad(item_camera.fov)
		var distancia = (raio / sin(fov_rad / 2.0)) * 1.4
		item_camera.translation = Vector3(0, 0, distancia)
		item_camera.look_at(Vector3.ZERO, Vector3.UP)
		item_camera.near = 0.05
		item_camera.far = max(distancia * 3.0, 5.0)
		_reposicionar_luz(distancia)

	painel.visible = true
	get_tree().paused = true

func _clonar_visuais(origem: Node) -> Spatial:
	if origem == null or not is_instance_valid(origem):
		return null
	var root = Spatial.new()
	root.name = "PickupClone"
	_copiar_meshes(origem, root, origem)
	# Se não achou nenhum mesh, tenta de novo incluindo nós sob colliders
	if root.get_child_count() == 0:
		_copiar_meshes(origem, root, origem, true)
	return root

func _copiar_meshes(n: Node, dest_parent: Node, raiz: Node, forcar_sob_collider: bool = false) -> void:
	if n is MeshInstance:
		var mi = MeshInstance.new()
		mi.mesh = n.mesh
		if n.material_override:
			mi.material_override = n.material_override
		else:
			# Copia surface materials se existirem
			for i in range(n.get_surface_material_count()):
				var mat = n.get_surface_material(i)
				if mat:
					mi.set_surface_material(i, mat)
		mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		# Transform relativo à raiz do item
		mi.transform = raiz.global_transform.affine_inverse() * n.global_transform
		# Esconde outline (nome comum)
		var nome_l = n.name.to_lower()
		if "outline" in nome_l or "silhueta" in nome_l:
			mi.visible = false
		dest_parent.add_child(mi)

	for c in n.get_children():
		# Em modo normal: não entra em colliders (evita lixo). Em fallback: entra.
		if not forcar_sob_collider:
			if c is CollisionShape or c is CollisionPolygon:
				continue
			if c is Area or c is StaticBody:
				# Ainda assim procura meshes DENTRO do collider (caso comum)
				_copiar_meshes(c, dest_parent, raiz, true)
				continue
		else:
			if c is CollisionShape or c is CollisionPolygon:
				continue
		_copiar_meshes(c, dest_parent, raiz, forcar_sob_collider)

func mostrar_item(nome_item, texto_descricao, cena_item = null, forcar: bool = false):
	if not forcar and itens_ja_mostrados.has(nome_item):
		return

	itens_ja_mostrados[nome_item] = true

	titulo.text = "Item Adquirido"
	descricao.text = texto_descricao

	# remove o item anterior, se existir
	if item_atual:
		item_atual.queue_free()
		item_atual = null

	_garantir_luz()

	# instancia a cena nova — só se existir (evita crash "instance" em Nil)
	if cena_item != null:
		item_atual = cena_item.instance()
		item_holder.add_child(item_atual)
		item_atual.translation = Vector3.ZERO
		item_atual.force_update_transform()

		var aabb = get_aabb_combinada(item_atual)
		if aabb.size.length() < 0.001:
			aabb = AABB(Vector3(-0.1, -0.1, -0.1), Vector3(0.2, 0.2, 0.2))
		item_atual.translation = -(aabb.position + aabb.size / 2.0)

		var raio = aabb.size.length() / 2.0
		if raio <= 0:
			raio = 0.5
		var fov_rad = deg2rad(item_camera.fov)
		var distancia = (raio / sin(fov_rad / 2.0)) * 1.4
		item_camera.translation = Vector3(0, 0, distancia)
		item_camera.look_at(Vector3.ZERO, Vector3.UP)
		item_camera.near = 0.05
		item_camera.far = max(distancia * 3.0, 5.0)
		_reposicionar_luz(distancia)

	painel.visible = true
	get_tree().paused = true

func _reposicionar_luz(distancia: float) -> void:
	if is_instance_valid(_luz_item):
		_luz_item.translation = Vector3(distancia * 0.45, distancia * 0.55, distancia * 0.9)
		_luz_item.omni_range = max(distancia * 4.0, 8.0)

# percorre recursivamente todos os filhos procurando VisualInstance (MeshInstance etc.)
# e soma as AABBs pra saber o tamanho real do modelo inteiro (com vários meshes)
func get_aabb_combinada(node: Node) -> AABB:
	var resultado = {"aabb": AABB(), "definida": false}
	_coletar_aabb(node, node, resultado)
	return resultado["aabb"]

func _coletar_aabb(raiz: Node, node: Node, resultado: Dictionary) -> void:
	if node is VisualInstance and node.visible:
		var transform_relativo = raiz.global_transform.affine_inverse() * node.global_transform
		var aabb_local = transform_relativo.xform(node.get_aabb())
		if not resultado["definida"]:
			resultado["aabb"] = aabb_local
			resultado["definida"] = true
		else:
			resultado["aabb"] = resultado["aabb"].merge(aabb_local)
	for filho in node.get_children():
		_coletar_aabb(raiz, filho, resultado)

func _input(event):
	if painel.visible and event.is_action_pressed("ui_cancel"):
		fechar()
		get_tree().set_input_as_handled()

func fechar():
	painel.visible = false
	get_tree().paused = false
	if item_atual:
		item_atual.queue_free()
		item_atual = null

	for manager in get_tree().get_nodes_in_group("tutorial_manager"):
		if manager.has_method("_processar_fila"):
			manager._processar_fila()
