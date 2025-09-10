extends Node
class_name SceneBuilderToolbox

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

static func get_all_node_names(_node):
	var _all_node_names = []
	for _child in _node.get_children():
		_all_node_names.append(_child.name)
		if _child.get_child_count() > 0:
			var _result = get_all_node_names(_child)
			for _item in _result:
				_all_node_names.append(_item)
	return _all_node_names

static func increment_name_until_unique(new_name, all_names) -> String:
	var idx = all_names.find_custom(func(s: String) -> bool: return s.begins_with(new_name))
	var name_match = all_names[idx] if idx >= 0 else null	

	if name_match:
		var backup_name = new_name
		var suffix_counter = 1
		var increment_until = true
		while (increment_until):
			var _backup_name = backup_name + "-n" + str(suffix_counter)
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
