extends RigidBody
# Stub: sistema de empurrar objetos pela Sombra foi removido.
# Este arquivo existe só pra não quebrar cenas que ainda apontam pro script.
# Pode remover o script do nó no editor quando quiser.

func _ready() -> void:
	mode = MODE_STATIC
	sleeping = true

func receber_empurrão_sombra(_impulso: Vector3) -> void:
	pass

func set_foco(_ativo: bool) -> void:
	pass

func interagir(_player) -> void:
	pass
