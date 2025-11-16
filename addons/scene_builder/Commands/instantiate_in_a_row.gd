@tool
extends EditorPlugin
## Used to layout new assets in a row, a simple but often helpful task.

func execute(_spacing: int):
	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	var toolbox = SceneBuilderToolbox.new()

	var current_scene: Node = EditorInterface.get_edited_scene_root()
	var selected_paths: PackedStringArray = EditorInterface.get_selected_paths()

	if current_scene == null or selected_paths.is_empty():
		return

	undo_redo.create_action("Instantiate Scenes")

	var instantiated_nodes = []
	var x_offset = 0

	for path in selected_paths:
		if ResourceLoader.exists(path) and load(path) is PackedScene:
			var scene = load(path) as PackedScene
			var instance = scene.instantiate()
			
			instance.name = toolbox.get_unique_name(instance.name, current_scene)
			
			undo_redo.add_do_method(current_scene, "add_child", instance)
			undo_redo.add_do_method(instance, "set_owner", current_scene)
			undo_redo.add_do_method(instance, "set_global_position", Vector3(x_offset, 0, 0))
			undo_redo.add_undo_method(current_scene, "remove_child", instance)
			
			instantiated_nodes.append(instance)
			x_offset += _spacing
			
			print("Instantiated: " + instance.name)

	undo_redo.commit_action()
	
	var selection = EditorInterface.get_selection()
	selection.clear()
	
	# Select newly instantiated nodes
	for node in instantiated_nodes:
		selection.add_node(node)
