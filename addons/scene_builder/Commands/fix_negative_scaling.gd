@tool
extends EditorPlugin
## Takes the absolute value of transform scale values.

func execute():
	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	var selection: EditorSelection = EditorInterface.get_selection()
	var selected_nodes: Array[Node] = selection.get_selected_nodes()

	if selected_nodes.is_empty():
		return

	undo_redo.create_action("Fix negative scaling")

	for selected in selected_nodes:
		if not selected is Node3D:
			continue
		
		var new_scale: Vector3 = selected.scale
		if selected.scale.x < 0 or selected.scale.y < 0 or selected.scale.z < 0:
			new_scale = Vector3(abs(selected.scale.x), abs(selected.scale.y), abs(selected.scale.z))
			
			print("[Fix Negative Scaling] Negative scale found for: ", selected.name)
		
		undo_redo.add_do_method(selected, "set_scale", new_scale)
		undo_redo.add_undo_method(selected, "set_scale", selected.scale)
	
	undo_redo.commit_action()
