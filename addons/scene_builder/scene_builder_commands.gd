@tool
extends EditorPlugin
class_name SceneBuilderCommands

var reusable_instance
var config: SceneBuilderConfig
var command_palette

var commands: Array[Dictionary] = [
	{"name": "Add audio streams to randomizer", "script": preload("./Commands/add_streams_to_randomizer.gd")},
	{"name": "Alphabetize nodes", "script": preload("./Commands/alphabetize_nodes.gd")},
	{"name": "Change places", "script": preload("./Commands/change_places.gd")},
	{"name": "Create audio stream player 3d", "script": preload("./Commands/create_audio_stream_player_3d.gd")},
	{"name": "Create scene builder items", "script": preload("./Commands/create_scene_builder_items.gd"), "persistent": true, "arg_source": "root_dir"},
	{"name": "Create StandardMaterial3D", "script": preload("./Commands/create_standard_material_3d.gd"), "persistent": true},
	{"name": "Fix negative scaling", "script": preload("./Commands/fix_negative_scaling.gd")},
	{"name": "Instantiate selected paths in a row (1m)", "script": preload("./Commands/instantiate_in_a_row.gd"), "arg": 1},
	{"name": "Instantiate selected paths in a row (5m)", "script": preload("./Commands/instantiate_in_a_row.gd"), "arg": 5},
	{"name": "Instantiate selected paths in a row (10m)", "script": preload("./Commands/instantiate_in_a_row.gd"), "arg": 10},
	{"name": "Push to grid", "script": preload("./Commands/push_to_grid.gd")},
	{"name": "Push parent offset to child", "script": preload("./Commands/push_parent_offset_to_child.gd")},
	{"name": "Reset node names", "script": preload("./Commands/reset_node_name.gd")},
	{"name": "Reset transform", "script": preload("./Commands/reset_transform.gd")},
	{"name": "Select children", "script": preload("./Commands/select_children.gd")},
	{"name": "Select parents", "script": preload("./Commands/select_parents.gd")},
	{"name": "Set visibility", "script": preload("./Commands/set_visibility.gd")},
	{"name": "Swap nodes", "script": preload("./Commands/swap_nodes.gd")},
]

func _unhandled_input(event: InputEvent):

	if config.disable_hotkeys:
		return

	if event is InputEventKey:
		if event.is_pressed() and !event.is_echo():

			if event.physical_keycode == config.command_palette_key and not event.shift_pressed and not event.ctrl_pressed and not event.alt_pressed:
				if command_palette:
					command_palette.show_palette()
					get_viewport().set_input_as_handled()

			elif event.ctrl_pressed:
				if event.physical_keycode == KEY_RIGHT:
					run_command_by_name("Select children")
				elif event.physical_keycode == KEY_LEFT:
					run_command_by_name("Select parents")

func _enter_tree():
	command_palette = preload("./scene_builder_command_palette.gd").new()
	command_palette.command_selected.connect(run_command)
	add_child(command_palette)
	command_palette.setup_commands(commands)

func run_command(command: Dictionary) -> void:
	var arg = command.get("arg")
	if command.get("arg_source", "") == "root_dir":
		arg = config.root_dir

	var instance = command["script"].new()

	if command.get("persistent", false):
		reusable_instance = instance
		add_child(reusable_instance)
		reusable_instance.done.connect(_on_reusable_instance_done)
		if arg != null:
			reusable_instance.execute(arg)
		else:
			reusable_instance.execute()
	else:
		if arg != null:
			instance.execute(arg)
		else:
			instance.execute()

func run_command_by_name(command_name: String) -> void:
	for command in commands:
		if command["name"] == command_name:
			run_command(command)
			return

func update_config(new_config) -> void:
	config = new_config

# ------------------------------------------------------------------------------

func _on_reusable_instance_done():
	if reusable_instance != null:
		print("Freeing reusable instance")
		reusable_instance.queue_free()
