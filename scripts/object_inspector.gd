extends StaticBody

export(NodePath) var caminho_outline
onready var outline = get_node(caminho_outline) if caminho_outline else null

func _ready():
	add_to_group("interagivel")
	if outline:
		outline.visible = false

func set_foco(ativo: bool):
	if outline:
		outline.visible = ativo

func interagir(camera):
	camera.iniciar_inspecao(self)
