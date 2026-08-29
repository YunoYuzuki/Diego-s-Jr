extends Node

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	
func _input(event) -> void:
	if not event.is_action_pressed("esc") or event.echo:
		return
		
	var save_uis = get_tree().get_nodes_in_group("save_ui")
	if save_uis.size() > 0:
		save_uis[0].close()
		get_tree().set_input_as_handled()
		return
		
	var camera = get_tree().get_nodes_in_group("camera_player")
	if camera.size() > 0:
		if get_tree().paused:
			camera[0].unpause_game()
		else:
			camera[0].pause_game()
		get_tree().set_input_as_handled()
