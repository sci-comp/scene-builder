@tool
extends EditorPlugin
## If selected nodes have a scene file path, then rename them to their name in
## FileSystem. A suffix is applied for duplicates: -n1, -n2, and so on.

func execute():
	var toolbox: SceneBuilderToolbox = SceneBuilderToolbox.new()

	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	var current_scene: Node = EditorInterface.get_edited_scene_root()
	var selection: EditorSelection = EditorInterface.get_selection()
	var selected_nodes: Array[Node] = selection.get_selected_nodes()

	if selected_nodes.is_empty():
		return

	undo_redo.create_action("Reset node name")

	var all_names = toolbox.get_all_node_names(current_scene)

	for node in selected_nodes:

		if node.scene_file_path:
			var path_name = node.scene_file_path.get_file().get_basename()
			var new_name = toolbox.increment_name_until_unique(path_name, all_names)
			undo_redo.add_do_method(node, "set_name", new_name)
			undo_redo.add_undo_method(node, "set_name", node.name)
		else:
			print("[Reset Node Name] Passing over: " + node.name)

	undo_redo.commit_action()
