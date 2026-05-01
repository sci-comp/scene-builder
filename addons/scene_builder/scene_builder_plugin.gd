@tool
extends EditorPlugin

const BASE_PATHS = [
	"res://addons/scene_builder/",
	"res://addons/scene_builder/addons/scene_builder/"
]

var scene_builder_dock : SceneBuilderDock
var scene_builder_commands : SceneBuilderCommands
var scene_builder_config : SceneBuilderConfig

func _enter_tree() -> void:
	var base_path = _find_valid_base_path()
	if not base_path:
		printerr("SceneBuilder addon files not found in expected locations.")
		return

	if not _load_or_create_components(base_path):
		return

	scene_builder_dock.update_config(scene_builder_config)
	scene_builder_commands.update_config(scene_builder_config)
	
	add_child(scene_builder_commands)
	add_child(scene_builder_dock)

func _find_valid_base_path() -> String:
	for path in BASE_PATHS:
		if ResourceLoader.exists(path + "scene_builder_dock.gd") and \
		   ResourceLoader.exists(path + "scene_builder_commands.gd") and \
		   ResourceLoader.exists(path + "scene_builder_config.gd"):
			return path
	return ""

func _load_or_create_components(base_path: String) -> bool:
	scene_builder_dock = load(base_path + "scene_builder_dock.gd").new()
	scene_builder_commands = load(base_path + "scene_builder_commands.gd").new()
	
	var config_path = base_path + "scene_builder_config.tres"
	var config_script = load(base_path + "scene_builder_config.gd")
	
	if ResourceLoader.exists(config_path):
		scene_builder_config = load(config_path)
	else:
		scene_builder_config = config_script.new()
		var err = ResourceSaver.save(scene_builder_config, config_path)
		print("[SceneBuilderPlugin] Configuration file not found, a new one has been saved to: ", config_path)
		if err != OK:
			printerr("[SceneBuilderPlugin] Failed to save new config file")
			return false
	return true

func _exit_tree():
	if scene_builder_commands:
		scene_builder_commands.queue_free()
	if scene_builder_dock:
		scene_builder_dock.queue_free()

func _handles(object):
	return object is Node3D

func _forward_3d_gui_input(camera : Camera3D, event : InputEvent) -> AfterGUIInput:
	return scene_builder_dock.forward_3d_gui_input(camera, event)
