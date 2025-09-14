@tool
extends EditorPlugin

var path_root = "res://Data/scene_builder/"
var editor: EditorInterface
var popup_instance: PopupPanel

# Nodes
var create_items: VBoxContainer
var collection_line_edit: LineEdit
var randomize_vertical_offset_checkbox: CheckButton
var randomize_rotation_checkbox: CheckButton
var randomize_scale_checkbox: CheckButton
var vertical_offset_spin_box_min: SpinBox
var vertical_offset_spin_box_max: SpinBox
var rotx_slider: HSlider
var roty_slider: HSlider
var rotz_slider: HSlider
var scale_spin_box_min: SpinBox
var scale_spin_box_max: SpinBox
var ok_button: Button

signal done


func execute(root_dir: String):
	if !root_dir.is_empty():
		path_root = root_dir
	
	print("[Create Scene Builder Items] Requesting user input...")
	
	editor = get_editor_interface()
	
	popup_instance = PopupPanel.new()
	add_child(popup_instance)
	popup_instance.popup_centered(Vector2(500, 300))
	
	var create_items_scene_path = SceneBuilderToolbox.find_resource_with_dynamic_path("scene_builder_create_items.tscn")
	if create_items_scene_path == "":
		printerr("[Create Scene Builder Items] Could not find scene_builder_create_items.tscn")
		return
	
	var create_items_scene := load(create_items_scene_path)
	create_items = create_items_scene.instantiate()
	popup_instance.add_child(create_items)

	collection_line_edit = create_items.get_node("Collection/LineEdit")
	randomize_vertical_offset_checkbox = create_items.get_node("Boolean/VerticalOffset")
	randomize_rotation_checkbox = create_items.get_node("Boolean/Rotation")
	randomize_scale_checkbox = create_items.get_node("Boolean/Scale")
	vertical_offset_spin_box_min = create_items.get_node("VerticalOffset/min")
	vertical_offset_spin_box_max = create_items.get_node("VerticalOffset/max")
	rotx_slider = create_items.get_node("Rotation/x")
	roty_slider = create_items.get_node("Rotation/y")
	rotz_slider = create_items.get_node("Rotation/z")
	scale_spin_box_min = create_items.get_node("Scale/min")
	scale_spin_box_max = create_items.get_node("Scale/max")
	ok_button = create_items.get_node("Okay")
	
	ok_button.pressed.connect(_on_ok_pressed)


func _on_ok_pressed():
	print("[Create Scene Builder Items] On okay pressed")
	
	var selected_paths = EditorInterface.get_selected_paths()
	print("[Create Scene Builder Items] Selected paths: " + str(selected_paths.size()))
	
	for path in selected_paths:
		_create_resource(path)
	
	popup_instance.queue_free()
	done.emit()


func _create_resource(path: String):
	if not ResourceLoader.exists(path):
		return
	
	var packed_scene: PackedScene = load(path)
	if packed_scene == null:
		return
	
	var uid = ResourceUID.id_to_text(ResourceLoader.get_resource_uid(path))
	var item_name = path.get_file().get_basename()
	var collection_name = collection_line_edit.text if not collection_line_edit.text.is_empty() else "Unnamed"
	
	var settings = {
		"use_random_vertical_offset": randomize_vertical_offset_checkbox.button_pressed,
		"use_random_rotation": randomize_rotation_checkbox.button_pressed,
		"use_random_scale": randomize_scale_checkbox.button_pressed,
		"random_offset_y_min": vertical_offset_spin_box_min.value,
		"random_offset_y_max": vertical_offset_spin_box_max.value,
		"random_rot_x": rotx_slider.value,
		"random_rot_y": roty_slider.value,
		"random_rot_z": rotz_slider.value,
		"random_scale_min": scale_spin_box_min.value,
		"random_scale_max": scale_spin_box_max.value
	}
	
	var database_path = path_root + "scene_builder_database.tres"
	var database = SceneBuilderDatabase.new() if not ResourceLoader.exists(database_path) else load(database_path)
	
	database.add_item(collection_name, item_name, uid, settings)
	database.save_database(database_path)
	
	print("[Create Scene Builder Items] Added to database: " + collection_name + "/" + item_name)
