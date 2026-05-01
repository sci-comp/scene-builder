@tool
extends EditorPlugin

var texture_prefix: String = "T_"
var nmap_suffix: String = "_n"
var emap_suffix: String = "_e"

func execute():
	assign_textures_to_materials()

func assign_textures_to_materials():
	var selected_paths = EditorInterface.get_selected_paths()
	var assigned_count = 0

	for path in selected_paths:
		if path.ends_with(".tres") or path.ends_with(".material"):
			var material = load(path) as StandardMaterial3D
			if material:
				var file_name = path.get_file()
				var material_name = file_name.get_basename()
				var object_name = material_name.replace("MI_", "")

				assigned_count += find_and_assign_textures(material, object_name, path)

	if assigned_count > 0:
		print("[Repair StandardMaterial3D] Successfully assigned " + str(assigned_count) + " textures to materials")
	else:
		print("[Repair StandardMaterial3D] No textures assigned. Make sure to select StandardMaterial3D resources.")

func find_and_assign_textures(material: StandardMaterial3D, object_name: String, material_path: String) -> int:
	var assigned_count = 0

	var texture_paths = find_matching_textures(object_name)

	var albedo_texture_path = texture_paths["albedo"]
	var normal_texture_path = texture_paths["normal"]
	var emission_texture_path = texture_paths["emission"]

	if albedo_texture_path:
		material.albedo_texture = load(albedo_texture_path)
		assigned_count += 1

	if normal_texture_path:
		material.normal_enabled = true
		material.normal_texture = load(normal_texture_path)
		assigned_count += 1

	if emission_texture_path:
		material.emission_enabled = true
		material.emission_texture = load(emission_texture_path)
		assigned_count += 1

	if assigned_count > 0:
		ResourceSaver.save(material, material_path)

	return assigned_count

func find_matching_textures(object_name: String) -> Dictionary:
	var result = {
		"albedo": "",
		"normal": "",
		"emission": ""
	}

	var all_files = get_all_filesystem_paths()

	var albedo_pattern = texture_prefix + object_name
	var normal_pattern = texture_prefix + object_name + nmap_suffix
	var emission_pattern = texture_prefix + object_name + emap_suffix

	for file_path in all_files:
		var file_name = file_path.get_file().get_basename()

		if file_name == albedo_pattern and (file_path.ends_with(".png") or file_path.ends_with(".jpg")):
			result["albedo"] = file_path
		elif file_name == normal_pattern and (file_path.ends_with(".png") or file_path.ends_with(".jpg")):
			result["normal"] = file_path
		elif file_name == emission_pattern and (file_path.ends_with(".png") or file_path.ends_with(".jpg")):
			result["emission"] = file_path

	return result

func get_all_filesystem_paths() -> Array:
	var paths = []
	_scan_directory("res://", paths)
	return paths

func _scan_directory(current_path: String, results: Array):
	var dir = DirAccess.open(current_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()

		while file_name != "":
			var full_path = current_path.path_join(file_name)

			if dir.current_is_dir():
				_scan_directory(full_path, results)
			else:
				if file_name.ends_with(".png") or file_name.ends_with(".jpg") or file_name.ends_with(".jpeg"):
					results.append(full_path)

			file_name = dir.get_next()

		dir.list_dir_end()
