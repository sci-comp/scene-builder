@tool
extends EditorPlugin
class_name SceneBuilderCommands

var reusable_instance
var config: SceneBuilderConfig
var command_palette

enum SceneCommands
{
	alphabetize_nodes = 1,
	change_places = 8,
	create_scene_builder_items = 10,
	create_standard_material_3d = 12,
	fix_negative_scaling = 20,
	instantiate_in_a_row_1 = 32,
	instantiate_in_a_row_2 = 33,
	instantiate_in_a_row_3 = 34,
	push_to_grid = 45,
	push_parent_offset_to_child = 46,
	reset_node_name = 50,
	reset_transform = 61,
	select_children = 70,
	select_parents = 71,
	set_visibility = 75,
	swap_nodes = 80,
	create_audio_stream_player_3d = 90,
	add_streams_to_randomizer = 91
}

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
					select_children()
				elif event.physical_keycode == KEY_LEFT:
					select_parents()

func _enter_tree():
	# Initialize command palette
	command_palette = preload("./scene_builder_command_palette.gd").new()
	command_palette.command_selected.connect(_on_command_palette_selected)
	add_child(command_palette)

	# Setup command list for palette
	var commands: Array[Dictionary] = []
	commands.append({"id": SceneCommands.add_streams_to_randomizer, "name": "Add audio streams to randomizer"})
	commands.append({"id": SceneCommands.alphabetize_nodes, "name": "Alphabetize nodes"})
	commands.append({"id": SceneCommands.change_places, "name": "Change places"})
	commands.append({"id": SceneCommands.create_audio_stream_player_3d, "name": "Create audio stream player 3d"})
	commands.append({"id": SceneCommands.create_scene_builder_items, "name": "Create scene builder items"})
	commands.append({"id": SceneCommands.create_standard_material_3d, "name": "Create StandardMaterial3D"})
	commands.append({"id": SceneCommands.fix_negative_scaling, "name": "Fix negative scaling"})
	commands.append({"id": SceneCommands.instantiate_in_a_row_1, "name": "Instantiate selected paths in a row (1m)"})
	commands.append({"id": SceneCommands.instantiate_in_a_row_2, "name": "Instantiate selected paths in a row (5m)"})
	commands.append({"id": SceneCommands.instantiate_in_a_row_3, "name": "Instantiate selected paths in a row (10m)"})
	commands.append({"id": SceneCommands.push_to_grid, "name": "Push to grid"})
	commands.append({"id": SceneCommands.push_parent_offset_to_child, "name": "Push parent offset to child"})
	commands.append({"id": SceneCommands.reset_node_name, "name": "Reset node names"})
	commands.append({"id": SceneCommands.reset_transform, "name": "Reset transform"})
	commands.append({"id": SceneCommands.select_children, "name": "Select children"})
	commands.append({"id": SceneCommands.select_parents, "name": "Select parents"})
	commands.append({"id": SceneCommands.set_visibility, "name": "Set visibility"})
	commands.append({"id": SceneCommands.swap_nodes, "name": "Swap nodes"})
	command_palette.setup_commands(commands)

func _on_command_palette_selected(id: int):
	_on_scene_submenu_item_selected(id)

func _on_scene_submenu_item_selected(id: int):
	match id:
		SceneCommands.add_streams_to_randomizer:
			add_streams_to_randomizer()
		SceneCommands.alphabetize_nodes:
			alphabetize_nodes()
		SceneCommands.change_places:
			change_places()
		SceneCommands.create_audio_stream_player_3d:
			create_audio_stream_player_3d()
		SceneCommands.create_scene_builder_items:
			create_scene_builder_items()
		SceneCommands.create_standard_material_3d:
			create_standard_material_3d()
		SceneCommands.fix_negative_scaling:
			fix_negative_scaling()
		SceneCommands.instantiate_in_a_row_1:
			instantiate_in_a_row(1)
		SceneCommands.instantiate_in_a_row_2:
			instantiate_in_a_row(5)
		SceneCommands.instantiate_in_a_row_3:
			instantiate_in_a_row(10)
		SceneCommands.push_to_grid:
			push_to_grid()
		SceneCommands.push_parent_offset_to_child:
			push_parent_offset_to_child()
		SceneCommands.reset_node_name:
			reset_node_name()
		SceneCommands.reset_transform:
			reset_transform()
		SceneCommands.select_children:
			select_children()
		SceneCommands.select_parents:
			select_parents()
		SceneCommands.set_visibility:
			set_visibility()
		SceneCommands.swap_nodes:
			swap_nodes()

func add_streams_to_randomizer():
	var _instance = preload("./Commands/add_streams_to_randomizer.gd").new()
	_instance.execute()
	
func alphabetize_nodes():
	var _instance = preload("./Commands/alphabetize_nodes.gd").new()
	_instance.execute()

func change_places():
	var _instance = preload("./Commands/change_places.gd").new()
	_instance.execute()

func create_scene_builder_items():
	reusable_instance = preload("./Commands/create_scene_builder_items.gd").new()
	add_child(reusable_instance)
	reusable_instance.done.connect(_on_reusable_instance_done)
	reusable_instance.execute(config.root_dir)

func create_standard_material_3d():
	reusable_instance = preload("./Commands/create_standard_material_3d.gd").new()
	add_child(reusable_instance)
	reusable_instance.done.connect(_on_reusable_instance_done)
	reusable_instance.execute()

func create_audio_stream_player_3d():
	var _instance = preload("./Commands/create_audio_stream_player_3d.gd").new()
	_instance.execute()

func fix_negative_scaling():
	var _instance = preload("./Commands/fix_negative_scaling.gd").new()
	_instance.execute()

func instantiate_in_a_row(_space):
	var _instance = preload("./Commands/instantiate_in_a_row.gd").new()
	_instance.execute(_space)

func push_to_grid():
	var _instance = preload("./Commands/push_to_grid.gd").new()
	_instance.execute()

func push_parent_offset_to_child():
	var _instance = preload("./Commands/push_parent_offset_to_child.gd").new()
	_instance.execute()

func reset_node_name():
	var _instance = preload("./Commands/reset_node_name.gd").new()
	_instance.execute()

func reset_transform():
	var _instance = preload("./Commands/reset_transform.gd").new()
	_instance.execute()

func select_children():
	var _instance = preload("./Commands/select_children.gd").new()
	_instance.execute()

func select_parents():
	var _instance = preload("./Commands/select_parents.gd").new()
	_instance.execute()

func set_visibility():
	var _instance = preload("./Commands/set_visibility.gd").new()
	_instance.execute()

func swap_nodes():
	var _instance = preload("./Commands/swap_nodes.gd").new()
	_instance.execute()

func temporary_debug():
	var _instance = preload("./Commands/temporary_debug.gd").new()
	_instance.execute()

func update_config(new_config) -> void:
	config = new_config

# ------------------------------------------------------------------------------

func _on_reusable_instance_done():
	if reusable_instance != null:
		print("Freeing reusable instance")
		reusable_instance.queue_free()
