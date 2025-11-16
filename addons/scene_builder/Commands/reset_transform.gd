@tool
extends EditorPlugin
## Sets selected nodes' position, rotation, and scale to initial values.

func execute():
	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	var selection: EditorSelection = EditorInterface.get_selection()
	var selected_nodes: Array[Node] = selection.get_selected_nodes()
	
	if selected_nodes.is_empty():
		return
	
	undo_redo.create_action("Reset transform")
	
	for selected in selected_nodes:
		if not selected is Node3D:
			continue
		
		undo_redo.add_do_method(selected, "set_position", Vector3(0, 0, 0))
		undo_redo.add_undo_method(selected, "set_position", selected.position)
		
		undo_redo.add_do_method(selected, "set_rotation_degrees", Vector3(0, 0, 0))
		undo_redo.add_undo_method(selected, "set_rotation_degrees", selected.rotation_degrees)
		
		undo_redo.add_do_method(selected, "set_scale", Vector3(1, 1, 1))
		undo_redo.add_undo_method(selected, "set_scale", selected.scale)
	
	undo_redo.commit_action()
