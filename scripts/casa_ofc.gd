extends Spatial

func _ready():
	SaveManager.registrar_viewport_3d($ViewportContainer)
	# Godot 3.x: Viewport filho NÃO processa áudio 3D por padrão (só o root).
	# Sem isso, todo AudioStreamPlayer3D dentro do Viewport fica mudo,
	# enquanto AudioStreamPlayer (2D) continua normal.
	_habilitar_audio_3d_no_viewport()
	if has_node("ViewportContainer/Viewport/Camera"):
		$ViewportContainer/Viewport/Camera.current = false

func _habilitar_audio_3d_no_viewport() -> void:
	if not has_node("ViewportContainer/Viewport"):
		push_warning("casa_ofc: Viewport 3D não encontrado — áudio espacial pode ficar mudo")
		return
	var vp: Viewport = $ViewportContainer/Viewport
	vp.audio_listener_enable_3d = true
	vp.audio_listener_enable_2d = true
	print("🔊 Viewport 3D: audio_listener_enable_3d = ", vp.audio_listener_enable_3d)
