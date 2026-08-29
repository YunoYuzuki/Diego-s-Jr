extends Node

func escapar(nodo: Node) -> void:
	var pai_atual = nodo.get_parent()
	if pai_atual:
		pai_atual.remove_child(nodo)
	get_tree().root.call_deferred("add_child", nodo)
