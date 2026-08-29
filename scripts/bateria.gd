extends Spatial
# =============================================================
# Bateria no chão — sistema de bateria REMOVIDO.
# O objeto no mundo não faz mais nada (não entra no inventário).
# Pode ser apagado da cena quando quiser.
# =============================================================

export var id_unico : String = ""
export(NodePath) var caminho_outline
export(PackedScene) var cena_pickup

var outline_mesh: Spatial = null

func _ready() -> void:
	# Remove do mundo: sistema de bateria desativado
	if id_unico != "" and typeof(SaveManager) != TYPE_NIL:
		SaveManager.marcar_item_coletado(id_unico)
	queue_free()

func set_foco(_ativo: bool) -> void:
	pass

func pode_interagir(_player) -> bool:
	return false

func interagir(_player) -> void:
	queue_free()
