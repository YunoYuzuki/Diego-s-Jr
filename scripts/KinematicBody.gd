extends KinematicBody

#  Exportveis 
export var velocity        := 5.5
export var sprint_velocity := 10.5
export var sensi           := 0.1

export var max_stamina                : float = 100.0
export var stamina_drain_rate         : float = 14.3
export var stamina_regen_rate         : float = 5.0
export var stamina_regen_rate_stopped : float = 7.5

#  Nodes 
onready var camera   = $Camera
onready var raycast  : RayCast    = $Camera/RayCast
onready var target   : Position3D = $Camera/Position3D
onready var som_chuva             = $Camera/forest_sound
onready var passos                = $passos

#  Movimento 
const dist_range : float = 2.0
var gravity      : float = -20.0
var rot_x        : float = 0.0
var vel          := Vector3.ZERO

#  Passos 
var footstep_timer     : float = 0.001
var walk_step_interval : float = 0.5
var run_step_interval  : float = 0.3

#  Stamina 
var current_stamina : float = 100.0
var can_sprint      : bool  = true
var is_sprinting    : bool  = false

# 
func _ready():
	add_to_group("Persist")
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	current_stamina = max_stamina

	var cam = get_node_or_null("Camera")
	if cam:
		cam.target_pitch  = deg2rad(rot_x)
		cam.current_pitch = deg2rad(rot_x)

func _input(_event):
	pass

func _physics_process(delta):
	if get_tree().paused:
		return

	var dir = Vector3.ZERO
	if Input.is_action_pressed("w"): dir -= transform.basis.z
	if Input.is_action_pressed("s"): dir += transform.basis.z
	if Input.is_action_pressed("a"): dir -= transform.basis.x
	if Input.is_action_pressed("d"): dir += transform.basis.x
	dir.y = 0
	dir   = dir.normalized()

	var wants_to_sprint = Input.is_action_pressed("shift") and dir.length() > 0.1 and is_on_floor()
	is_sprinting        = wants_to_sprint and can_sprint and current_stamina > 0
	var current_speed   = sprint_velocity if is_sprinting else velocity

	if is_on_floor():
		vel.y = 0.0

	vel.x  = dir.x * current_speed
	vel.z  = dir.z * current_speed
	vel.y += gravity * delta
	move_and_slide(vel, Vector3.UP)

	_handle_footsteps(delta, dir)
	_handle_stamina(delta, dir)

#  Passos 
func _handle_footsteps(delta: float, dir: Vector3):
	var andando = Vector3(dir.x, 0, dir.z).length() > 0.1

	if andando and is_on_floor():
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			passos.play()
			footstep_timer = run_step_interval if is_sprinting else walk_step_interval
	else:
		footstep_timer = walk_step_interval
		passos.stop()

#  Stamina 
func _handle_stamina(delta: float, dir: Vector3):
	var andando = Vector3(dir.x, 0, dir.z).length() > 0.1

	if is_sprinting:
		current_stamina -= stamina_drain_rate * delta
		if current_stamina <= 0:
			current_stamina = 0
			is_sprinting    = false
			can_sprint      = false
	else:
		var regen_rate   = stamina_regen_rate_stopped if not andando else stamina_regen_rate
		current_stamina += regen_rate * delta
		if current_stamina >= max_stamina * 0.3:
			can_sprint = true

	current_stamina = clamp(current_stamina, 0, max_stamina)

#  Save 
func save():
	var lanterna_ligada = false
	if camera.lanterna_atual != null and "ligada" in camera.lanterna_atual:
		lanterna_ligada = camera.lanterna_atual.ligada

	return {
		"filename"          : get_filename(),
		"parent"            : get_parent().get_path(),
		"pos_x"             : translation.x,
		"pos_y"             : translation.y,
		"pos_z"             : translation.z,
		"scale_x"           : scale.x,
		"scale_y"           : scale.y,
		"scale_z"           : scale.z,
		"current_stamina"   : current_stamina,
		"rot_x"             : rot_x,
		"inventory"         : Inventory.get_save_data(),
		"lanterna_equipada" : camera.lanterna_atual != null,
		"lanterna_ligada"   : lanterna_ligada,
	}
