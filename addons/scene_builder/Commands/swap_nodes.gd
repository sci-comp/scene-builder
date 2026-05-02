@tool
extends EditorPlugin
## Replaces each selected node in the Scene with an instance of the selected
## PackedScene from the FileSystem.
##
## The instantiated PackedScene inherits transform information from the node it
## replaces. Exactly one PackedScene should be selected in the FileSystem and
## at least one node should be selected in the Scene.
##
## * Undo is not supported — the original nodes are freed immediately.
##
## * Assumes that the selected PackedScene path, and selected nodes all
##	 have a Node3D as their root, skips selected nodes otherwise.

var utilities = SceneBuilderToolbox.new()

func execute():
	var current_scene: Node = EditorInterface.get_edited_scene_root()
	var selection: EditorSelection = EditorInterface.get_selection()
	var selected_nodes: Array[Node] = selection.get_selected_nodes()
	var selected_paths: PackedStringArray = EditorInterface.get_selected_paths()

	# Verify that only one FileSystem path is selected
	if selected_paths.size() != 1:
		print("[Swap Nodes] Please select exactly one PackedScene in the FileSystem.")
		return

	# Verify that selected Filesystem item is a PackedScene
	var selected_path = selected_paths[0]
	var resource = load(selected_path)
	if not resource or not resource is PackedScene:
		print("[Swap Nodes] The selected path is not a PackedScene.")
		return

	# Verify selected nodes
	if selected_nodes.is_empty():
		print("[Swap Nodes] Select at least one node in the Scene.")
		return

	for node in selected_nodes:

		if not node is Node3D:
			print("[Swap Nodes] Skipping non-Node3D node: " + node.name)
			continue

		var instance = resource.instantiate()
		if not instance is Node3D:
			print("[Swap Nodes] Skipping, instantiated scene root is not a Node3D")
			instance.queue_free()
			continue

		instance.transform = node.transform

		var parent = node.get_parent()
		if parent:
			parent.add_child(instance)
			instance.owner = current_scene
			instance.name = utilities.get_unique_name(instance.name, parent)
			node.queue_free()

			print("[Swap Nodes] Node has been swapped: " + node.name)
		else:
			printerr("[Swap Nodes] parent not found for node: " + node.name)
