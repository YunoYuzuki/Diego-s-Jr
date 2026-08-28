extends Spatial
# =============================================================
# TESTE MÍNIMO — AudioStreamPlayer3D (Godot 3.6)
# =============================================================
# Como usar:
# 1) Crie um Spatial vazio na casa (dentro do Viewport 3D, perto do player).
# 2) Anexe este script.
# 3) Arraste um AudioStream que JÁ funciona em AudioStreamPlayer 2D no export.
# 4) Rode o jogo e aproxime-se do Spatial.
# 5) Tecla F9 (ou o que definir em input "teste_audio_3d") força play.
#
# O que este teste isola:
# - Bus Master (ignora SFX)
# - Atenuação DESLIGADA
# - unit_db = 0, max_distance bem alto
# - play() no _ready e de novo com input
# - Imprime posição, playing, bus, viewport flags
#
# Interpretação:
# A) Se ESTE teste tocar e os outros não → problema na config dos players do jogo
# B) Se ESTE teste também ficar mudo → Viewport/Listener/AudioServer (não é o stream)
# C) Se tocar só com F9 perto e não de longe → atenuação/distância (esperado se reativar)
# =============================================================

export(AudioStream) var stream_teste
export var autoplay_no_ready : bool = true
export var tecla_replay : int = KEY_F9

var _player: AudioStreamPlayer3D

func _ready() -> void:
	_player = AudioStreamPlayer3D.new()
	_player.name = "TesteAudio3D"
	_player.bus = "Master"
	_player.unit_db = 0.0
	_player.unit_size = 1.0
	_player.max_distance = 100.0
	# Godot 3.6: sem atenuação espacial para o teste mínimo
	_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	if stream_teste:
		_player.stream = stream_teste
	add_child(_player)

	_diagnosticar()

	if autoplay_no_ready and stream_teste:
		_player.play()
		print("🔊 [teste 3D] play() no ready — playing=", _player.playing)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.scancode == tecla_replay:
			if stream_teste == null:
				push_warning("[teste 3D] stream_teste não configurado")
				return
			_player.stream = stream_teste
			_player.play()
			_diagnosticar()
			print("🔊 [teste 3D] replay manual — playing=", _player.playing)

func _diagnosticar() -> void:
	print("======== DIAGNÓSTICO AUDIO 3D ========")
	print("Fonte global_transform.origin = ", global_transform.origin)
	print("Player 3D in tree = ", is_inside_tree())
	print("Stream = ", _player.stream)
	print("Bus = ", _player.bus, " | idx=", AudioServer.get_bus_index(_player.bus))
	print("unit_db=", _player.unit_db, " max_distance=", _player.max_distance)
	print("attenuation_model=", _player.attenuation_model)
	print("playing=", _player.playing)

	# Viewport ancestral
	var n: Node = self
	while n:
		if n is Viewport:
			var vp: Viewport = n
			print("Viewport path=", vp.get_path())
			print("  audio_listener_enable_3d=", vp.audio_listener_enable_3d)
			print("  audio_listener_enable_2d=", vp.audio_listener_enable_2d)
			print("  own_world=", vp.own_world)
			break
		n = n.get_parent()

	# Listener current
	var listeners = get_tree().get_nodes_in_group("listener") if false else []
	# Busca Listener na árvore
	var found_listener = false
	for cam in get_tree().get_nodes_in_group("camera_player"):
		for c in cam.get_children():
			if c is Listener:
				found_listener = true
				print("Listener sob camera: path=", c.get_path(), " current=", c.current)
	if not found_listener:
		print("⚠️ Nenhum Listener encontrado sob camera_player")
	print("=====================================")
