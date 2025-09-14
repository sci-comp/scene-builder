@tool
extends Resource
class_name SceneBuilderDatabase


## Dictionary structure: collections[collection_name][item_name] = item_data_dict
@export var collections: Dictionary = {}


func add_item(collection_name: String, item_name: String, uid: String, settings: Dictionary = {}) -> void:
	if not collections.has(collection_name):
		collections[collection_name] = {}
	
	collections[collection_name][item_name] = {
		"uid": uid,
		"use_random_vertical_offset": settings.get("use_random_vertical_offset", false),
		"use_random_rotation": settings.get("use_random_rotation", false),
		"use_random_scale": settings.get("use_random_scale", false),
		"random_offset_y_min": settings.get("random_offset_y_min", 0.0),
		"random_offset_y_max": settings.get("random_offset_y_max", 0.0),
		"random_rot_x": settings.get("random_rot_x", 0.0),
		"random_rot_y": settings.get("random_rot_y", 0.0),
		"random_rot_z": settings.get("random_rot_z", 0.0),
		"random_scale_min": settings.get("random_scale_min", 0.9),
		"random_scale_max": settings.get("random_scale_max", 1.1)
	}


func remove_item(collection_name: String, item_name: String) -> bool:
	if collections.has(collection_name) and collections[collection_name].has(item_name):
		collections[collection_name].erase(item_name)
		# Remove collection if empty
		if collections[collection_name].is_empty():
			collections.erase(collection_name)
		return true
	return false


func get_collection(collection_name: String) -> Dictionary:
	return collections.get(collection_name, {})


func get_item(collection_name: String, item_name: String) -> Dictionary:
	var collection = get_collection(collection_name)
	return collection.get(item_name, {})


func has_collection(collection_name: String) -> bool:
	return collections.has(collection_name) and not collections[collection_name].is_empty()


func has_item(collection_name: String, item_name: String) -> bool:
	return collections.has(collection_name) and collections[collection_name].has(item_name)


func get_collection_names() -> Array[String]:
	var names: Array[String] = []
	for key in collections.keys():
		names.append(key)
	return names


func get_item_names(collection_name: String) -> Array[String]:
	var names: Array[String] = []
	var collection = get_collection(collection_name)
	for key in collection.keys():
		names.append(key)
	return names


func save_database(path: String) -> Error:
	return ResourceSaver.save(self, path)


func load_database(path: String) -> SceneBuilderDatabase:
	if ResourceLoader.exists(path):
		return load(path) as SceneBuilderDatabase
	return null


## Debug helper
func print_database_stats() -> void:
	print("[SceneBuilderDatabase] Collections: ", collections.size())
	for collection_name in collections.keys():
		var item_count = collections[collection_name].size()
		print("  - ", collection_name, ": ", item_count, " items")
