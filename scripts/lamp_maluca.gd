extends OmniLight

export(float, 0.0, 100.0) var chance_de_piscar := 10.0  # % de chance
export(float) var velocidade_piscar := 0.12          # quanto menor, mais rpido

var piscando := false
var timer : Timer

func _ready() -> void:
	timer = Timer.new()
	timer.wait_time = velocidade_piscar
	timer.one_shot = false
	timer.connect("timeout", self, "_piscar")
	add_child(timer)
	
	# Detecta quando a luz  ligada/desligada
	connect("visibility_changed", self, "_on_visibility_changed")
	
	# Caso j comece ligada
	if visible:
		_on_visibility_changed()

func _on_visibility_changed() -> void:
	if visible:
		# Luz foi ligada (pelo interruptor ou manualmente)
		tentar_iniciar_piscar()
	else:
		# Luz foi desligada (principalmente pela Sombra)
		parar_piscar()

func tentar_iniciar_piscar() -> void:
	if rand_range(0, 100) < chance_de_piscar:
		piscando = true
		timer.start()
		print(" ", name, " entrou em modo maluco!")
	else:
		piscando = false
		light_energy = 1.0

func _piscar() -> void:
	if not piscando or not visible:
		return
	light_energy = 0.0 if light_energy > 0.3 else 1.0   # pisca forte

func parar_piscar() -> void:
	piscando = false
	if timer:
		timer.stop()
	light_energy = 1.0   # garante que volte ao normal

# Caso queira forar manualmente
func forcar_piscar() -> void:
	piscando = true
	timer.start()
