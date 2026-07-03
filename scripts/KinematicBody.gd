extends KinematicBody

# Exportáveis
export var velocity       := 5.5   # mais lento que antes (era 8), vibe mais pesada
export var crouch_velocity := 3.0

export var sensi := 0.1

# Crouch — câmera desce suavemente
export var camera_crouch_offset : float = -0.5  # o quanto a câmera desce
export var crouch_lerp_speed    : float = 10.0  # velocidade do lerp

# Nodes
onready var camera  = $Camera
onready var raycast : RayCast    = $Camera/RayCast
onready var target  : Position3D = $Camera/Position3D
onready var som_chuva             = $Camera/forest_sound
onready var passos                = $passos

# Movimento
const dist_range : float = 2.0
var gravity      : float = -20.0
var rot_x        : float = 0.0
var vel          := Vector3.ZERO

# Passos
var footstep_timer      : float = 0.001
var walk_step_interval  : float = 0.55
var crouch_step_interval: float = 0.8   # passo mais devagar agachado

# Crouch
var is_crouching     : bool  = false
var camera_normal_y  : float = 0.0     # gravado no _ready

func _ready():
	add_to_group("Persist")
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	camera_normal_y = camera.translation.y

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

	# Crouch: só funciona quando está no chão
	is_crouching = Input.is_action_pressed("ctrl") and is_on_floor()

	var current_speed = crouch_velocity if is_crouching else velocity

	if is_on_floor():
		vel.y = 0.0

	vel.x  = dir.x * current_speed
	vel.z  = dir.z * current_speed
	vel.y += gravity * delta
	move_and_slide(vel, Vector3.UP)

	# Câmera desce suavemente ao agachar
	var target_cam_y = camera_normal_y + (camera_crouch_offset if is_crouching else 0.0)
	camera.translation.y = lerp(camera.translation.y, target_cam_y, crouch_lerp_speed * delta)

	_handle_footsteps(delta, dir)

# Passos
func _handle_footsteps(delta: float, dir: Vector3):
	var andando = Vector3(dir.x, 0, dir.z).length() > 0.1

	if andando and is_on_floor():
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			passos.play()
			footstep_timer = crouch_step_interval if is_crouching else walk_step_interval
	else:
		footstep_timer = walk_step_interval
		passos.stop()

# Save
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
		"rot_x"             : rot_x,
		"inventory"         : Inventory.get_save_data(),
		"lanterna_equipada" : camera.lanterna_atual != null,
		"lanterna_ligada"   : lanterna_ligada,
	}
