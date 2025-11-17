extends Node
class_name SceneBuilderToolbox

enum TransformMode {
	NONE,
	POSITION_X,
	POSITION_Y, 
	POSITION_Z,
	ROTATION_X,
	ROTATION_Y,
	ROTATION_Z,
	SCALE
}

enum ForwardAxis {
	POSITIVE_X,
	POSITIVE_Y,
	POSITIVE_Z,
	NEGATIVE_X,
	NEGATIVE_Y,
	NEGATIVE_Z
}

static func replace_first(s: String, pattern: String, replacement: String) -> String:
	var index = s.find(pattern)
	if index == -1:
		return s
	return s.substr(0, index) + replacement + s.substr(index + pattern.length())

static func replace_last(s: String, pattern: String, replacement: String) -> String:
	var index = s.rfind(pattern)
	if index == -1:
		return s
	return s.substr(0, index) + replacement + s.substr(index + pattern.length())

static func get_unique_name(base_name: String, parent: Node) -> String:
	if !parent.has_node(base_name):
		return base_name
		
	var counter = 1
	var new_name = base_name
	
	# Strip existing numeric suffix if present
	var regex = RegEx.new()
	regex.compile("^(.*?)(\\d+)$")
	var result = regex.search(base_name)
	
	if result:
		new_name = result.get_string(1)
		counter = int(result.get_string(2)) + 1
	
	# Find first available name
	while parent.has_node(new_name + str(counter)):
		counter += 1
		
	return new_name + str(counter)

static func find_resource_with_dynamic_path(file_name: String) -> String:
	# The recursive directory will exist when installing from a submodule
	
	var base_paths = [
		"res://addons/scene_builder/",
		"res://addons/scene_builder/addons/scene_builder/"
	]
	
	for path in base_paths:
		var full_path = path + file_name
		if ResourceLoader.exists(full_path):
			return full_path
	
	return ""

static func get_all_node_names(_node : Node) -> Array:
	var _all_node_names : Array = []
	for _child in _node.get_children():
		_all_node_names.append(_child.name)
		if _child.get_child_count() > 0:
			var _result = get_all_node_names(_child)
			for _item in _result:
				_all_node_names.append(_item)
	return _all_node_names

static func increment_name_until_unique(new_name : String, all_names : Array) -> String:
	var idx : int = all_names.find_custom(func(s: String) -> bool: return s.begins_with(new_name))
	
	if idx >= 0:
		var backup_name: String = new_name
		var suffix_counter: int = 1
		var increment_until: bool = true
		while increment_until:
			var _backup_name: String = backup_name + "-n" + str(suffix_counter)
			if _backup_name in all_names:
				suffix_counter += 1
			else:
				increment_until = false
				backup_name = _backup_name
			if suffix_counter > 9000:
				print("suffix_counter is over 9000, error?")
				increment_until = false
		return backup_name
	else:
		return new_name

static func get_forward_axis_rotation(axis: ForwardAxis) -> Basis:
	"""
	Returns a rotation basis to align the chosen forward axis with -Z (Godot's forward).
	Useful for placing objects along splines where models may have different forward axes.
	"""
	match axis:
		ForwardAxis.POSITIVE_X: # +X forward -> rotate -90° around Y
			return Basis(Quaternion(Vector3.UP, deg_to_rad(-90)))
		ForwardAxis.POSITIVE_Y: # +Y forward -> rotate 90° around X
			return Basis(Quaternion(Vector3.RIGHT, deg_to_rad(90)))
		ForwardAxis.POSITIVE_Z: # +Z forward -> rotate 180° around Y
			return Basis(Quaternion(Vector3.UP, deg_to_rad(180)))
		ForwardAxis.NEGATIVE_X: # -X forward -> rotate 90° around Y
			return Basis(Quaternion(Vector3.UP, deg_to_rad(90)))
		ForwardAxis.NEGATIVE_Y: # -Y forward -> rotate -90° around X
			return Basis(Quaternion(Vector3.RIGHT, deg_to_rad(-90)))
		ForwardAxis.NEGATIVE_Z: # -Z forward -> no rotation (Godot default)
			return Basis.IDENTITY
		_:
			printerr("[SceneBuilderToolbox] Invalid ForwardAxis value: ", axis)
			return Basis.IDENTITY

static func get_scene_dimensions(uid: String) -> Vector3:
	"""
	Gets the dimensions of a scene by instantiating it temporarily and calculating AABB.
	Returns Vector3.ZERO if the scene has no measurable geometry.
	"""
	var uid_int: int = ResourceUID.text_to_id(uid)
	
	if not ResourceUID.has_id(uid_int):
		printerr("[SceneBuilderToolbox] Invalid UID: ", uid)
		return Vector3.ZERO
	
	var path: String = ResourceUID.get_id_path(uid_int)
	
	if not ResourceLoader.exists(path):
		printerr("[SceneBuilderToolbox] Path does not exist: ", path)
		return Vector3.ZERO
	
	var loaded = load(path)
	if not loaded is PackedScene:
		printerr("[SceneBuilderToolbox] Resource is not a PackedScene: ", path)
		return Vector3.ZERO
	
	var instance = loaded.instantiate()
	if not instance is Node3D:
		instance.queue_free()
		printerr("[SceneBuilderToolbox] Scene root is not Node3D: ", path)
		return Vector3.ZERO
	
	# Calculate AABB by collecting all VisualInstance3D nodes
	var visuals := _get_all_visual_instances(instance)
	
	instance.queue_free()
	
	if visuals.is_empty():
		return Vector3.ZERO
	
	# Merge all AABBs
	var combined_aabb := visuals[0].global_transform * visuals[0].get_aabb()
	for i in range(1, visuals.size()):
		var visual := visuals[i]
		var global_aabb := visual.global_transform * visual.get_aabb()
		combined_aabb = combined_aabb.merge(global_aabb)
	
	return combined_aabb.size

static func _get_all_visual_instances(node: Node) -> Array[VisualInstance3D]:
	"""Recursively collect all VisualInstance3D nodes from a scene tree."""
	var visuals: Array[VisualInstance3D] = []
	
	if node is VisualInstance3D:
		var visual := node as VisualInstance3D
		if visual.get_aabb().has_volume():
			visuals.append(visual)
	
	for child in node.get_children():
		visuals.append_array(_get_all_visual_instances(child))
	
	return visuals
