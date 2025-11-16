@tool
extends EditorPlugin
## Round the position of selected nodes to the nearest whole grid value.

func execute():
	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	
	var selection: EditorSelection = EditorInterface.get_selection()
	var selected_nodes: Array[Node] = selection.get_selected_nodes()
	
	if selected_nodes.is_empty():
		return
	
	undo_redo.create_action("Snap to Grid")
	
	var grid_size: float = 0.25 # Todo: this should be adjustable by the user
	
	for selected in selected_nodes:
		if not selected is Node3D:
			continue
		
		var old_pos = selected.position
		var new_pos = Vector3(
			round(selected.position.x / grid_size) * grid_size,
			round(selected.position.y / grid_size) * grid_size,
			round(selected.position.z / grid_size) * grid_size
		)
		
		undo_redo.add_do_property(selected, "position", new_pos)
		undo_redo.add_undo_property(selected, "position", old_pos)
	
	undo_redo.commit_action()
