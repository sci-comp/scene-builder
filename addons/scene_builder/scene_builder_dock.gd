@tool
extends EditorPlugin
class_name SceneBuilderDock

@onready var config: SceneBuilderConfig = SceneBuilderConfig.new()

# Paths
var data_dir: String = ""
var path_to_collection_names: String

# Constants
var num_collections: int = 24

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var toolbox: SceneBuilderToolbox = SceneBuilderToolbox.new()
var undo_redo: EditorUndoRedoManager = get_undo_redo()

# Godot controls
var base_control: Control
var btn_use_local_space: Button

# SceneBuilderDock controls
var scene_builder_dock: VBoxContainer
var tab_container: TabContainer
var btns_collection_tabs: Array = [] # set in _enter_tree()
# Options
var btn_use_surface_normal: CheckButton
var btn_surface_normal_x: CheckBox
var btn_surface_normal_y: CheckBox
var btn_surface_normal_z: CheckBox
var btn_parent_node_selector: Button
var btn_group_surface_orientation: ButtonGroup
var btn_find_world_3d: Button
var btn_reload_all_items: Button
var btn_force_root_node: CheckButton
# Path3D
var spinbox_separation_distance: SpinBox
var spinbox_jitter_x: SpinBox
var spinbox_jitter_y: SpinBox
var spinbox_jitter_z: SpinBox
var spinbox_y_offset: SpinBox
var btn_place_fence: Button
# Snap
var checkbox_snap_enabled: CheckButton
var spinbox_translate_snap: SpinBox
var spinbox_rotate_snap: SpinBox
var spinbox_scale_snap: SpinBox
var btn_enable_plane: CheckButton
var option_plane_mode: OptionButton  
var spinbox_plane_y_pos: SpinBox
# Misc
var btn_disable_hotkeys: CheckButton

# Indicators
var lbl_indicator_x: Label
var lbl_indicator_y: Label
var lbl_indicator_z: Label
var lbl_indicator_scale: Label

# Updated with update_world_3d()
var editor: EditorInterface
var physics_space: PhysicsDirectSpaceState3D
var world3d: World3D
var viewport: Viewport
var camera: Camera3D
var scene_root: Node3D

# Updated when reloading all collections
var collection_names: Array[String] = []
var items_by_collection: Dictionary = {} # A dictionary of dictionaries
var ordered_keys_by_collection: Dictionary = {}
var item_highlighters_by_collection: Dictionary = {}
# Also updated on tab button click
var selected_collection: Dictionary = {}
var selected_collection_name: String = ""
var selected_collection_index: int = 0
# Also updated on item click
var selected_item: SceneBuilderItem = null
var selected_item_name: String = ""
var preview_instance: Node3D = null
var preview_instance_rid_array: Array[RID] = []
var selected_parent_node: Node3D = null

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

var placement_mode_enabled: bool = false
var current_transform_mode: TransformMode = TransformMode.NONE
var is_dragging_to_rotate: bool = false
var rotation_sensitivity := 0.01

func is_transform_mode_enabled() -> bool:
	return current_transform_mode != TransformMode.NONE

# Preview item
var pos_offset_x: float = 0
var pos_offset_y: float = 0
var pos_offset_z: float = 0
var rot_offset_x: float = 0
var rot_offset_y: float = 0
var rot_offset_z: float = 0
var scale_offset: float = 0
var original_preview_position: Vector3 = Vector3.ZERO
var original_preview_basis: Basis = Basis.IDENTITY
var original_mouse_position: Vector2 = Vector2.ONE
var random_offset_y: float = 0
var original_preview_scale: Vector3 = Vector3.ONE
var scene_builder_temp: Node # Used as a parent to the preview item

# ---- Notifications -----------------------------------------------------------

func _enter_tree() -> void:
	path_to_collection_names = config.root_dir + "collection_names.tres"

	editor = get_editor_interface()
	base_control = EditorInterface.get_base_control()

	# Found using: https://github.com/Zylann/godot_editor_debugger_plugin
	var _panel : Panel = get_editor_interface().get_base_control()
	var _vboxcontainer15 : VBoxContainer = _panel.get_child(0)
	var _vboxcontainer26 : VBoxContainer = _vboxcontainer15.get_child(1).get_child(1).get_child(1).get_child(0)
	var _main_screen : VBoxContainer = _vboxcontainer26.get_child(0).get_child(0).get_child(0).get_child(1).get_child(0)
	var _hboxcontainer11486 : HBoxContainer = _main_screen.get_child(1).get_child(0).get_child(0).get_child(0)
	
	btn_use_local_space = _hboxcontainer11486.get_child(13)
	if !btn_use_local_space:
		printerr("[SceneBuilderDock] Unable to find use local space button")

	#region Initialize controls for the SceneBuilderDock
	
	var path : String = SceneBuilderToolbox.find_resource_with_dynamic_path("scene_builder_dock.tscn")
	if path == "":
		printerr("[SceneBuilderDock] scene_builder_dock.tscn was not found")
		return
	
	scene_builder_dock = load(path).instantiate()
	
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, scene_builder_dock)

	# Collection tabs
	tab_container = scene_builder_dock.get_node("Collection/TabContainer")
	for i: int in range(num_collections):
		var tab_button: Button = scene_builder_dock.get_node("Collection/Panel/Grid/%s" % str(i + 1))
		tab_button.pressed.connect(select_collection.bind(i))
		btns_collection_tabs.append(tab_button)

	# Options tab
	btn_use_surface_normal = scene_builder_dock.get_node("%UseSurfaceNormal")
	btn_surface_normal_x = scene_builder_dock.get_node("%Orientation/ButtonGroup/X")
	btn_surface_normal_y = scene_builder_dock.get_node("%Orientation/ButtonGroup/Y")
	btn_surface_normal_z = scene_builder_dock.get_node("%Orientation/ButtonGroup/Z")
	
	btn_parent_node_selector = scene_builder_dock.get_node("%ParentNodeSelector")
	var script_path = SceneBuilderToolbox.find_resource_with_dynamic_path("scene_builder_node_path_selector.gd")
	if script_path != "":
		btn_parent_node_selector.set_script(load(script_path))
		btn_parent_node_selector.path_selected.connect(set_parent_node)
	else:
		printerr("[SceneBuilderDock] Failed to find scene_builder_node_path_selector.gd")
	
	#
	btn_group_surface_orientation = ButtonGroup.new()
	btn_surface_normal_x.button_group = btn_group_surface_orientation
	btn_surface_normal_y.button_group = btn_group_surface_orientation
	btn_surface_normal_z.button_group = btn_group_surface_orientation
	#
	btn_find_world_3d = scene_builder_dock.get_node("%FindWorld3D")
	btn_reload_all_items = scene_builder_dock.get_node("%ReloadAllItems")
	btn_disable_hotkeys = scene_builder_dock.get_node("%DisableHotkeys")
	btn_force_root_node = scene_builder_dock.get_node("%ForceRootNode")
	btn_find_world_3d.pressed.connect(update_world_3d)
	btn_reload_all_items.pressed.connect(reload_all_items)
	btn_force_root_node.toggled.connect(on_force_root_toggled)

	# Path3D tab
	spinbox_separation_distance = scene_builder_dock.get_node("%Path3D/Separation/SpinBox")
	spinbox_jitter_x = scene_builder_dock.get_node("%Path3D/Jitter/X")
	spinbox_jitter_y = scene_builder_dock.get_node("%Path3D/Jitter/Y")
	spinbox_jitter_z = scene_builder_dock.get_node("%Path3D/Jitter/Z")
	spinbox_y_offset = scene_builder_dock.get_node("%Path3D/YOffset/Value")
	btn_place_fence = scene_builder_dock.get_node("%Path3D/PlaceFence")
	btn_place_fence.pressed.connect(place_fence)

	# Setup snap controls
	checkbox_snap_enabled = scene_builder_dock.get_node("%EnableSnap")
	spinbox_translate_snap = scene_builder_dock.get_node("%TranslateSnap/SpinBox")
	spinbox_rotate_snap = scene_builder_dock.get_node("%RotateSnap/SpinBox")
	spinbox_scale_snap = scene_builder_dock.get_node("%ScaleSnap/SpinBox")
	btn_enable_plane = scene_builder_dock.get_node("%EnablePlane")
	option_plane_mode = scene_builder_dock.get_node("%PlaneMode") 
	spinbox_plane_y_pos = scene_builder_dock.get_node("%PlaneYPosition")
	
	# Misc
	btn_disable_hotkeys.pressed.connect(disable_hotkeys)

	# Indicators
	lbl_indicator_x = scene_builder_dock.get_node("%Indicators/1")
	lbl_indicator_y = scene_builder_dock.get_node("%Indicators/2")
	lbl_indicator_z = scene_builder_dock.get_node("%Indicators/3")
	lbl_indicator_scale = scene_builder_dock.get_node("%Indicators/4")

	#endregion

	#
	reload_all_items()
	update_world_3d()

func _exit_tree() -> void:
	remove_control_from_docks(scene_builder_dock)
	scene_builder_dock.queue_free()

func _process(_delta: float) -> void:
	# Update preview item position
	if placement_mode_enabled:

		if not scene_root or not scene_root is Node3D or not scene_root.is_inside_tree():
			print("[SceneBuilderDock] Scene root invalid, ending placement mode")
			end_placement_mode()
			return

		if !is_transform_mode_enabled() and !is_dragging_to_rotate:
			if preview_instance:
				populate_preview_instance_rid_array(preview_instance)
			var result = perform_raycast_with_exclusion(preview_instance_rid_array)
			if result and result.position:
				var _preview_item = scene_root.get_node_or_null("SceneBuilderTemp")
				if _preview_item and _preview_item.get_child_count() > 0:
					var _instance: Node3D = _preview_item.get_child(0)

					var new_position: Vector3 = result.position

					new_position += Vector3(pos_offset_x, pos_offset_y, pos_offset_z)

					# This offset prevents z-fighting when placing overlapping quads
					if selected_item.use_random_vertical_offset:
						new_position.y += random_offset_y

					if not btn_use_surface_normal.button_pressed:
						new_position = snap_position_to_grid(new_position)

					_instance.global_transform.origin = new_position
					if btn_use_surface_normal.button_pressed:
						_instance.basis = align_up(_instance.global_transform.basis, result.normal)
						var quaternion = Quaternion(_instance.basis.orthonormalized())
						if btn_surface_normal_x.button_pressed:
							quaternion = quaternion * Quaternion(Vector3(1, 0, 0), deg_to_rad(90))
						elif btn_surface_normal_z.button_pressed:
							quaternion = quaternion * Quaternion(Vector3(0, 0, 1), deg_to_rad(90))

func forward_3d_gui_input(_camera: Camera3D, event: InputEvent) -> AfterGUIInput:
	if config.disable_hotkeys:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	
	if event is InputEventMouseMotion:
		if placement_mode_enabled:
			if is_dragging_to_rotate:
				# rotate around Y axis based on horizontal mouse movement
				var y_rotation: float = event.relative.x * rotation_sensitivity
				var y_quaternion := Quaternion(Vector3.UP, y_rotation)

				if btn_use_local_space.button_pressed:
					preview_instance.basis = preview_instance.basis * Basis(y_quaternion)
				else:
					preview_instance.basis = Basis(y_quaternion) * preview_instance.basis

				return EditorPlugin.AFTER_GUI_INPUT_STOP

			var relative_motion: float
			if abs(event.relative.x) > abs(event.relative.y):
				relative_motion = event.relative.x
			else:
				relative_motion = -event.relative.y
			relative_motion *= 0.01 # Sensitivity factor

			match current_transform_mode:
				TransformMode.POSITION_X:
					pos_offset_x += relative_motion
					var new_pos = original_preview_position + Vector3(pos_offset_x, 0, 0)
					preview_instance.global_position  = snap_position_to_grid(new_pos)
				TransformMode.POSITION_Y:
					pos_offset_y += relative_motion
					var new_pos = original_preview_position + Vector3(0, pos_offset_y, 0)
					preview_instance.global_position  = snap_position_to_grid(new_pos)
				TransformMode.POSITION_Z:
					pos_offset_z += relative_motion
					var new_pos = original_preview_position + Vector3(0, 0, pos_offset_z)
					preview_instance.global_position  = snap_position_to_grid(new_pos)
				TransformMode.ROTATION_X:
					rot_offset_x += relative_motion
					var snapped_offset = rot_offset_x
					if checkbox_snap_enabled.button_pressed:
						var snap_radians = deg_to_rad(spinbox_rotate_snap.value)
						snapped_offset = round(rot_offset_x / snap_radians) * snap_radians
					snapped_offset = fmod(snapped_offset, TAU)
					if snapped_offset < 0:
						snapped_offset += TAU
					if btn_use_local_space.button_pressed:
						var local_quat = Quaternion(Vector3(1, 0, 0), snapped_offset)
						preview_instance.basis = original_preview_basis * Basis(local_quat)
					else:
						var global_quat = Quaternion(Vector3(1, 0, 0), snapped_offset)
						preview_instance.basis = Basis(global_quat) * original_preview_basis
				TransformMode.ROTATION_Y:
					rot_offset_y += relative_motion
					var snapped_offset = rot_offset_y
					if checkbox_snap_enabled.button_pressed:
						var snap_radians = deg_to_rad(spinbox_rotate_snap.value)
						snapped_offset = round(rot_offset_y / snap_radians) * snap_radians
					snapped_offset = fmod(snapped_offset, TAU)
					if snapped_offset < 0:
						snapped_offset += TAU
					if btn_use_local_space.button_pressed:
						var local_quat = Quaternion(Vector3(0, 1, 0), snapped_offset)
						preview_instance.basis = original_preview_basis * Basis(local_quat)
					else:
						var global_quat = Quaternion(Vector3(0, 1, 0), snapped_offset)
						preview_instance.basis = Basis(global_quat) * original_preview_basis
				TransformMode.ROTATION_Z:
					rot_offset_z += relative_motion
					var snapped_offset = rot_offset_z
					if checkbox_snap_enabled.button_pressed:
						var snap_radians = deg_to_rad(spinbox_rotate_snap.value)
						snapped_offset = round(rot_offset_z / snap_radians) * snap_radians
					snapped_offset = fmod(snapped_offset, TAU)
					if snapped_offset < 0:
						snapped_offset += TAU
					if btn_use_local_space.button_pressed:
						var local_quat = Quaternion(Vector3(0, 0, 1), snapped_offset)
						preview_instance.basis = original_preview_basis * Basis(local_quat)
					else:
						var global_quat = Quaternion(Vector3(0, 0, 1), snapped_offset)
						preview_instance.basis = Basis(global_quat) * original_preview_basis
				TransformMode.SCALE:
					scale_offset += relative_motion
					scale_offset = clamp(scale_offset, -0.95, 20.0)
					var new_scale: Vector3 = original_preview_scale * (1 + scale_offset)
					preview_instance.scale = snap_scale_to_grid(new_scale)

	if event is InputEventMouseButton:
		if placement_mode_enabled:
			var mouse_pos = viewport.get_mouse_position()
			if mouse_pos.x >= 0 and mouse_pos.y >= 0:
				if mouse_pos.x <= viewport.size.x and mouse_pos.y <= viewport.size.y:
					if event.is_pressed() and !event.is_echo():
						if event.button_index == MOUSE_BUTTON_LEFT:
							if is_transform_mode_enabled():
								original_preview_basis = preview_instance.basis
								original_preview_scale = preview_instance.scale
								end_transform_mode()
								viewport.warp_mouse(original_mouse_position)
							elif is_dragging_to_rotate:
								# technically, should never get here since we check for is_dragging_to_rotate above
								instantiate_selected_item_at_position()
								_end_drag_rotation()
							else:
								_start_drag_rotation()

							return EditorPlugin.AFTER_GUI_INPUT_STOP

						elif event.button_index == MOUSE_BUTTON_RIGHT:
							if is_transform_mode_enabled():
								# Revert preview transformations
								print("[SceneBuilderDock] warping to: ", original_mouse_position)
								preview_instance.basis = original_preview_basis
								preview_instance.scale = original_preview_scale
								end_transform_mode()
								viewport.warp_mouse(original_mouse_position)

								return EditorPlugin.AFTER_GUI_INPUT_STOP

					elif not event.is_pressed():  # mouse button released
						if event.button_index == MOUSE_BUTTON_LEFT and is_dragging_to_rotate:
							instantiate_selected_item_at_position()
							_end_drag_rotation()
							return EditorPlugin.AFTER_GUI_INPUT_STOP

	elif event is InputEventKey:
		if event.is_pressed() and !event.is_echo():

			if !event.alt_pressed and !event.ctrl_pressed:

				if event.shift_pressed:

					if event.keycode == KEY_1:
						
						if is_transform_mode_enabled():
							if current_transform_mode == TransformMode.POSITION_X:
								end_transform_mode()
							else:
								end_transform_mode()
								start_transform_mode(TransformMode.POSITION_X)
						else:
							start_transform_mode(TransformMode.POSITION_X)

					elif event.keycode == KEY_2:
						if is_transform_mode_enabled():
							if current_transform_mode == TransformMode.POSITION_Y:
								end_transform_mode()
							else:
								end_transform_mode()
								start_transform_mode(TransformMode.POSITION_Y)
						else:
							start_transform_mode(TransformMode.POSITION_Y)

					elif event.keycode == KEY_3:
						if is_transform_mode_enabled():
							if current_transform_mode == TransformMode.POSITION_Z:
								end_transform_mode()
							else:
								end_transform_mode()
								start_transform_mode(TransformMode.POSITION_Z)
						else:
							start_transform_mode(TransformMode.POSITION_Z)

				else:

					if event.keycode == KEY_1:
						
						if is_transform_mode_enabled():
							if current_transform_mode == TransformMode.ROTATION_X:
								end_transform_mode()
							else:
								end_transform_mode()
								start_transform_mode(TransformMode.ROTATION_X)
						else:
							start_transform_mode(TransformMode.ROTATION_X)

					elif event.keycode == KEY_2:
						if is_transform_mode_enabled():
							if current_transform_mode == TransformMode.ROTATION_Y:
								end_transform_mode()
							else:
								end_transform_mode()
								start_transform_mode(TransformMode.ROTATION_Y)
						else:
							start_transform_mode(TransformMode.ROTATION_Y)

					elif event.keycode == KEY_3:
						if is_transform_mode_enabled():
							if current_transform_mode == TransformMode.ROTATION_Z:
								end_transform_mode()
							else:
								end_transform_mode()
								start_transform_mode(TransformMode.ROTATION_Z)
						else:
							start_transform_mode(TransformMode.ROTATION_Z)

					elif event.keycode == KEY_4:
						if is_transform_mode_enabled():
							if current_transform_mode == TransformMode.SCALE:
								end_transform_mode()
							else:
								end_transform_mode()
								start_transform_mode(TransformMode.SCALE)
						else:
							start_transform_mode(TransformMode.SCALE)

					elif event.keycode == KEY_5:
						if is_transform_mode_enabled():
							end_transform_mode()
						reroll_preview_instance_transform()

				if event.keycode == KEY_ESCAPE:
					end_placement_mode()

			if placement_mode_enabled:

				if event.shift_pressed:
					if event.keycode == KEY_LEFT:
						select_previous_item()
					elif event.keycode == KEY_RIGHT:
						select_next_item()

				if event.alt_pressed:
					if event.keycode == KEY_LEFT:
						select_previous_collection()
					elif event.keycode == KEY_RIGHT:
						select_next_collection()
				
				elif event.keycode == KEY_BRACKETLEFT:
					preview_instance.rotate_y(deg_to_rad(-90))
				
				elif event.keycode == KEY_BRACKETRIGHT:
					preview_instance.rotate_y(deg_to_rad(90))

	return EditorPlugin.AFTER_GUI_INPUT_PASS

# ---- Buttons -----------------------------------------------------------------

func is_collection_populated(tab_index: int) -> bool:
	var _collection_name: String = collection_names[tab_index]
	if _collection_name == "" or _collection_name == " ":
		return false
	else:
		if _collection_name in items_by_collection:
			var _items: Dictionary = items_by_collection[_collection_name]
			if _items.is_empty():
				return false
			else:
				return true
		else:
			return false

func select_collection(tab_index: int) -> void:
	if collection_names.size() == 0:
		print("[SceneBuilderDock] Unable to select collection, none exist")
		return

	end_placement_mode()

	for button: Button in btns_collection_tabs:
		button.button_pressed = false

	tab_container.current_tab = tab_index
	selected_collection_name = collection_names[tab_index]
	selected_collection_index = tab_index

	if selected_collection_name == "" or selected_collection_name == " ":
		selected_collection = {}
	else:
		if selected_collection_name in items_by_collection:
			selected_collection = items_by_collection[selected_collection_name]
		else:
			selected_collection = {}
			printerr("Missing collection folder: " + selected_collection_name)

func on_item_icon_clicked(_button_name: String) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var item = selected_collection[_button_name]
		EditorInterface.edit_resource(item)
		var tabs = EditorInterface.get_inspector().get_parent().get_parent() as TabContainer
		tabs.current_tab = tabs.get_tab_idx_from_control(EditorInterface.get_inspector().get_parent())
		return
	
	if !update_world_3d():
		return

	if placement_mode_enabled:
		end_placement_mode()
	elif selected_item_name != _button_name:
		select_item(selected_collection_name, _button_name)

var previous_parent_node: Node3D = null
func on_force_root_toggled(pressed: bool) -> void:
	if pressed:
		if selected_parent_node:
			previous_parent_node = selected_parent_node
		set_parent_node(NodePath())
	else:
		if previous_parent_node and previous_parent_node != scene_root:
			set_parent_node(scene_root.get_path_to(previous_parent_node))
		else:
			set_parent_node(NodePath())

func set_parent_node(node_path: NodePath) -> void:
	if not scene_root:
		return
	
	# Force root node or empty path both default to scene root
	print("btn_force_root_node.button_pressed: ", btn_force_root_node.button_pressed)
	if btn_force_root_node.button_pressed or node_path.is_empty() or str(node_path) == "":
		selected_parent_node = scene_root
		if scene_root:
			var node_name := scene_root.get_class().split(".")[-1]
			var node_icon := get_editor_interface().get_base_control().get_theme_icon(node_name, "EditorIcons")
			
			if node_icon == get_editor_interface().get_base_control().get_theme_icon("invalid icon", "EditorIcons"):
				node_icon = get_editor_interface().get_base_control().get_theme_icon("Node", "EditorIcons")
			
			btn_parent_node_selector.set_node_info(scene_root, node_icon)
		else:
			btn_parent_node_selector.set_node_info(null, null)
		return

	selected_parent_node = scene_root.get_node(node_path)
	previous_parent_node = selected_parent_node
	if not selected_parent_node:
		# Fall back to scene root if path not found
		selected_parent_node = scene_root
		btn_parent_node_selector.set_node_info(scene_root, get_editor_interface().get_base_control().get_theme_icon("Node", "EditorIcons"))
		printerr("[SceneBuilderDock] ", node_path, " not found in scene, defaulting to scene root")
		return

	var node_name := selected_parent_node.get_class().split(".")[-1]
	var node_icon := get_editor_interface().get_base_control().get_theme_icon(node_name, "EditorIcons")

	# if there's an invalid icon, we use the default node icon
	if node_icon == get_editor_interface().get_base_control().get_theme_icon("invalid icon", "EditorIcons"):
		node_icon = get_editor_interface().get_base_control().get_theme_icon("Node", "EditorIcons")

	btn_parent_node_selector.set_node_info(selected_parent_node, node_icon)
	print("[SceneBuilderDock] Parent node set to ", selected_parent_node.name)

func reload_all_items() -> void:
	print("[SceneBuilderDock] Freeing all texture buttons")
	for i in range(1, num_collections + 1):
		var grid_container: GridContainer = tab_container.get_node("%s/Grid" % i)
		for _node in grid_container.get_children():
			_node.queue_free()

	refresh_collection_names()

	print("[SceneBuilderDock] Loading all items from all collections")
	var i = 0
	for collection_name in collection_names:
		i += 1

		if collection_name != "" and DirAccess.dir_exists_absolute(config.root_dir + "/%s" % collection_name):
			print("[SceneBuilderDock] Populating grid with icons")

			var grid_container: GridContainer = tab_container.get_node("%s/Grid" % i)

			load_items_from_collection_folder_on_disk(collection_name)

			item_highlighters_by_collection[collection_name] = {}

			for key: String in ordered_keys_by_collection[collection_name]:
				var item: SceneBuilderItem = items_by_collection[collection_name][key]
				var texture_button: TextureButton = TextureButton.new()
				texture_button.toggle_mode = true
				texture_button.texture_normal = item.texture
				texture_button.tooltip_text = item.item_name
				texture_button.ignore_texture_size = true
				texture_button.stretch_mode = TextureButton.STRETCH_SCALE
				texture_button.custom_minimum_size = Vector2(80, 80)
				#texture_button.pressed.connect(on_item_icon_clicked.bind(item.item_name))
				texture_button.pressed.connect(on_item_icon_clicked.bind(key))
				texture_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
				texture_button.button_mask = MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT
				
				grid_container.add_child(texture_button)

				var nine_patch: NinePatchRect = NinePatchRect.new()
				nine_patch.texture = CanvasTexture.new()
				nine_patch.draw_center = false
				nine_patch.set_anchors_preset(Control.PRESET_FULL_RECT)
				nine_patch.patch_margin_left = 4
				nine_patch.patch_margin_top = 4
				nine_patch.patch_margin_right = 4
				nine_patch.patch_margin_bottom = 4
				nine_patch.self_modulate = Color("000000") # black  # 6a9d2e green
				item_highlighters_by_collection[collection_name][key] = nine_patch
				texture_button.add_child(nine_patch)

	select_collection(0)

	# Info blurb
	var _num_populated_collections: int = 0
	for colletion_name in collection_names:
		if colletion_name != "":
			_num_populated_collections += 1
	var _total_items: int = 0
	for key: String in items_by_collection.keys():
		_total_items += items_by_collection[key].size()

	print("[SceneBuilderDock] Ready with %s collections and %s items" % [str(_num_populated_collections), str(_total_items)])

func update_world_3d() -> bool:
	var new_scene_root = EditorInterface.get_edited_scene_root()
	if new_scene_root != null and new_scene_root is Node3D:
		if scene_root == new_scene_root:
			return true
		end_placement_mode()
		scene_root = new_scene_root
		viewport = EditorInterface.get_editor_viewport_3d()
		world3d = viewport.find_world_3d()
		physics_space = world3d.direct_space_state
		camera = viewport.get_camera_3d()
		set_parent_node(NodePath())
		return true
	else:
		print("[SceneBuilderDock] Failed to update world 3d")
		end_placement_mode()
		scene_root = null
		viewport = null
		world3d = null
		physics_space = null
		camera = null
		set_parent_node(NodePath())
		return false

func disable_hotkeys() -> void:
	config.disable_hotkeys = btn_disable_hotkeys.button_pressed
	var config_path = SceneBuilderToolbox.find_resource_with_dynamic_path("scene_builder_config.tres")
	if config_path != "":
		ResourceSaver.save(config, config_path)
		print("[SceneBuilderDock] Hotkeys ", "disabled" if btn_disable_hotkeys.button_pressed else "enabled")

# ---- Helpers -----------------------------------------------------------------

func align_up(node_basis, normal) -> Basis:
	var result: Basis = Basis()
	var scale: Vector3 = node_basis.get_scale()
	var orientation: String = btn_group_surface_orientation.get_pressed_button().name

	var arbitrary_vector: Vector3 = Vector3(1, 0, 0) if abs(normal.dot(Vector3(1, 0, 0))) < 0.999 else Vector3(0, 1, 0)
	var cross1: Vector3
	var cross2: Vector3

	match orientation:
		"X":
			cross1 = normal.cross(node_basis.y).normalized()
			if cross1.length_squared() < 0.001:
				cross1 = normal.cross(arbitrary_vector).normalized()
			cross2 = cross1.cross(normal).normalized()
			result = Basis(normal, cross2, cross1)
		"Y":
			cross1 = normal.cross(node_basis.z).normalized()
			if cross1.length_squared() < 0.001:
				cross1 = normal.cross(arbitrary_vector).normalized()
			cross2 = cross1.cross(normal).normalized()
			result = Basis(cross1, normal, cross2)
		"Z":
			arbitrary_vector = Vector3(0, 0, 1) if abs(normal.dot(Vector3(0, 0, -1))) < 0.99 else Vector3(-1, 0, 0)
			cross1 = normal.cross(node_basis.x).normalized()
			if cross1.length_squared() < 0.001:
				cross1 = normal.cross(arbitrary_vector).normalized()
			cross2 = cross1.cross(normal).normalized()
			result = Basis(cross2, cross1, normal)

	result = result.orthonormalized()
	result.x *= scale.x
	result.y *= scale.y
	result.z *= scale.z

	return result

func clear_preview_instance() -> void:
	preview_instance = null
	preview_instance_rid_array = []

	if scene_root != null:
		scene_builder_temp = scene_root.get_node_or_null("SceneBuilderTemp")
		if scene_builder_temp:
			for child in scene_builder_temp.get_children():
				child.queue_free()

func create_preview_instance() -> void:
	if scene_root == null:
		printerr("[SceneBuilderDock] scene_root is null inside create_preview_item_instance")
		return

	clear_preview_instance()

	is_dragging_to_rotate = false

	scene_builder_temp = scene_root.get_node_or_null("SceneBuilderTemp")
	if not scene_builder_temp:
		scene_builder_temp = Node.new()
		scene_builder_temp.name = "SceneBuilderTemp"
		scene_root.add_child(scene_builder_temp)
		scene_builder_temp.owner = scene_root

	preview_instance = get_instance_from_path(selected_item.uid)
	scene_builder_temp.add_child(preview_instance)
	preview_instance.owner = scene_root

	reroll_preview_instance_transform()

	# Instantiating a node automatically selects it, which is annoying.
	# Let's re-select scene_root instead,
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(scene_root)

func end_placement_mode() -> void:
	clear_preview_instance()
	end_transform_mode()

	placement_mode_enabled = false

	if selected_item_name != "":
		if item_highlighters_by_collection.has(selected_collection_name):
			var item_highlighters: Dictionary = item_highlighters_by_collection[selected_collection_name]
			if item_highlighters.has(selected_item_name):
				var selected_nine_path: NinePatchRect = item_highlighters[selected_item_name]
				if selected_nine_path:
					selected_nine_path.self_modulate = Color.BLACK
				else:
					print("[SceneBuilderDock] NinePatchRect is null for selected_item_name: ", selected_item_name)
			else:
				print("[SceneBuilderDock] Key missing from highlighter collection, key: ", selected_item_name, ", from collection: ", selected_collection_name)
		else:
			print("[SceneBuilderDock] Highlighter collection missing for collection: ", selected_collection_name)

	selected_item = null
	selected_item_name = ""

func end_transform_mode() -> void:
	current_transform_mode = TransformMode.NONE
	reset_indicators()

func _start_drag_rotation() -> void:
	is_dragging_to_rotate = true
	original_preview_basis = preview_instance.basis


func _end_drag_rotation() -> void:
	is_dragging_to_rotate = false
	preview_instance.basis = original_preview_basis


func load_items_from_collection_folder_on_disk(_collection_name: String):
	print("[SceneBuilderDock] Collecting items from collection folder")

	var items = {}
	var ordered_item_keys = []
	var file_paths = []  #

	var dir = DirAccess.open(config.root_dir + _collection_name)
	if dir:
		dir.list_dir_begin()
		var item_filename = dir.get_next()
		
		# First pass: collect file paths and queue threaded requests
		while item_filename != "":
			var item_path = config.root_dir + _collection_name + "/" + item_filename
			file_paths.append(item_path)
			ResourceLoader.load_threaded_request(item_path, "Resource", false, 1)
			item_filename = dir.get_next()
		
		dir.list_dir_end()
		
		# Second pass: retrieve loaded resources
		for item_path in file_paths:
			var resource = ResourceLoader.load_threaded_get(item_path)
			if resource and resource is SceneBuilderItem:
				var scene_builder_item: SceneBuilderItem = resource
				#print("[SceneBuilderDock] Loaded item: ", item_path.get_file())
				items[scene_builder_item.item_name] = scene_builder_item
				ordered_item_keys.append(scene_builder_item.item_name)
			else:
				print("[SceneBuilderDock] The resource is not a SceneBuilderItem or failed to load, item_path: ", item_path)

	items_by_collection[_collection_name] = items
	ordered_keys_by_collection[_collection_name] = ordered_item_keys

func get_all_node_names(_node) -> Array[String]:
	var _all_node_names = []
	for _child in _node.get_children():
		_all_node_names.append(_child.name)
		if _child.get_child_count() > 0:
			var _result = get_all_node_names(_child)
			for _item in _result:
				_all_node_names.append(_item)
	return _all_node_names

func instantiate_selected_item_at_position() -> void:
	if preview_instance == null or selected_item == null:
		printerr("[SceneBuilderDock] Preview instance or selected item is null")
		return

	populate_preview_instance_rid_array(preview_instance)
	var result = perform_raycast_with_exclusion(preview_instance_rid_array)

	if result and result.position:
		var instance = get_instance_from_path(selected_item.uid)
		if selected_parent_node:
			selected_parent_node.add_child(instance)
		else:
			scene_root.add_child(instance)
		instance.owner = scene_root
		initialize_node_name(instance, selected_item.item_name)

		var new_position: Vector3 = result.position
		if selected_item.use_random_vertical_offset:
			new_position.y += random_offset_y
		
		var preview_global_position = preview_instance.global_position
		var preview_global_rotation = preview_instance.global_rotation
		var preview_scale = preview_instance.scale
		
		instance.global_position = preview_global_position
		instance.global_rotation = preview_global_rotation
		instance.scale = preview_scale
		

		undo_redo.create_action("Instantiate selected item")
		undo_redo.add_undo_method(scene_root, "remove_child", instance)
		undo_redo.add_do_reference(instance)
		undo_redo.commit_action()

	else:
		print("[SceneBuilderDock] Raycast missed, items must be instantiated on a StaticBody with a CollisionShape")

func initialize_node_name(node: Node3D, new_name: String) -> void:
	var all_names = toolbox.get_all_node_names(scene_root)
	node.name = toolbox.increment_name_until_unique(new_name, all_names)

func perform_raycast_with_exclusion(exclude_rids: Array = []) -> Dictionary:
	if viewport == null:
		update_world_3d()
		if viewport == null:
			print("[SceneBuilderDock] The editor's root scene must be of type Node3D, deselecting item")
			end_placement_mode()
			return {}

	var mouse_pos = viewport.get_mouse_position()
	var origin = camera.project_ray_origin(mouse_pos)
	var end = origin + camera.project_ray_normal(mouse_pos) * 1000
	var query = PhysicsRayQueryParameters3D.new()
	query.from = origin
	query.to = end
	query.exclude = exclude_rids
	
	var collision_result = physics_space.intersect_ray(query)
	
	if not btn_enable_plane.button_pressed:
		return collision_result
	
	# Calculate plane intersection
	var plane = Plane(Vector3.UP, spinbox_plane_y_pos.value)
	var ray_direction = (end - origin).normalized()
	var plane_intersection = plane.intersects_ray(origin, ray_direction)
	var plane_result = {}
	plane_result.position = plane_intersection

	if plane_result.position == null:
		printerr("[SceneBuilderDocl] plane_result.position == null")
		return collision_result
	
	match option_plane_mode.selected:
		0: # Prefer colliders
			if collision_result and collision_result.position:
				return collision_result
			return plane_result
		1: # Closest wins
			if collision_result and collision_result.position:
				var collision_distance = (collision_result.position - origin).length_squared()
				var plane_distance = (plane_result.position - origin).length_squared()
				if collision_distance < plane_distance:
					return collision_result
			return plane_result
		2: # Ignore colliders
			if collision_result and "collider" in collision_result:
				plane_result["collider"] = collision_result["collider"]
			return plane_result
			
	return plane_result

func populate_preview_instance_rid_array(instance: Node) -> void:
	# This function prevents us from trying to raycast against our preview item.
	if instance is PhysicsBody3D:
		preview_instance_rid_array.append(instance.get_rid())

	for child in instance.get_children():
		populate_preview_instance_rid_array(child)

func refresh_collection_names() -> void:
	print("[SceneBuilderDock] Refreshing collection names")

	if !DirAccess.dir_exists_absolute(config.root_dir):
		DirAccess.make_dir_recursive_absolute(config.root_dir)
		print("[SceneBuilderDock] Creating a new data folder: ", config.root_dir)

	if !ResourceLoader.exists(path_to_collection_names):
		var _collection_names: CollectionNames = CollectionNames.new()
		print("[SceneBuilderDock] path_to_collection_names: ", path_to_collection_names)
		var save_result = ResourceSaver.save(_collection_names, path_to_collection_names)
		print("[SceneBuilderDock] A CollectionNames resource has been created at location: ", path_to_collection_names)

		if save_result != OK:
			printerr("[SceneBuilderDock] We were unable to create a CollectionNames resource at location: ", path_to_collection_names)
			collection_names = Array()
			collection_names.resize(24)
			collection_names.fill("")

			return

	var _names: CollectionNames = load(path_to_collection_names)
	if _names != null:
			var new_collection_names: Array[String] = []
			var new_collection_font_colors: Array[Color] = []

			# Row 1
			new_collection_names.append(_names.name_01)
			new_collection_names.append(_names.name_02)
			new_collection_names.append(_names.name_03)
			new_collection_names.append(_names.name_04)
			new_collection_names.append(_names.name_05)
			new_collection_names.append(_names.name_06)
			new_collection_font_colors.append(_names.font_color_01)
			new_collection_font_colors.append(_names.font_color_02)
			new_collection_font_colors.append(_names.font_color_03)
			new_collection_font_colors.append(_names.font_color_04)
			new_collection_font_colors.append(_names.font_color_05)
			new_collection_font_colors.append(_names.font_color_06)

			# Row 2
			new_collection_names.append(_names.name_07)
			new_collection_names.append(_names.name_08)
			new_collection_names.append(_names.name_09)
			new_collection_names.append(_names.name_10)
			new_collection_names.append(_names.name_11)
			new_collection_names.append(_names.name_12)
			new_collection_font_colors.append(_names.font_color_07)
			new_collection_font_colors.append(_names.font_color_08)
			new_collection_font_colors.append(_names.font_color_09)
			new_collection_font_colors.append(_names.font_color_10)
			new_collection_font_colors.append(_names.font_color_11)
			new_collection_font_colors.append(_names.font_color_12)

			# Row 3
			new_collection_names.append(_names.name_13)
			new_collection_names.append(_names.name_14)
			new_collection_names.append(_names.name_15)
			new_collection_names.append(_names.name_16)
			new_collection_names.append(_names.name_17)
			new_collection_names.append(_names.name_18)
			new_collection_font_colors.append(_names.font_color_13)
			new_collection_font_colors.append(_names.font_color_14)
			new_collection_font_colors.append(_names.font_color_15)
			new_collection_font_colors.append(_names.font_color_16)
			new_collection_font_colors.append(_names.font_color_17)
			new_collection_font_colors.append(_names.font_color_18)

			# Row 4
			new_collection_names.append(_names.name_19)
			new_collection_names.append(_names.name_20)
			new_collection_names.append(_names.name_21)
			new_collection_names.append(_names.name_22)
			new_collection_names.append(_names.name_23)
			new_collection_names.append(_names.name_24)
			new_collection_font_colors.append(_names.font_color_19)
			new_collection_font_colors.append(_names.font_color_20)
			new_collection_font_colors.append(_names.font_color_21)
			new_collection_font_colors.append(_names.font_color_22)
			new_collection_font_colors.append(_names.font_color_23)
			new_collection_font_colors.append(_names.font_color_24)

			# Validate
			for _name in new_collection_names:
				if _name != "":
					var dir = DirAccess.open(config.root_dir + _name)
					if dir:
						dir.list_dir_begin()
						var item = dir.get_next()
						if item != "":
							print("[SceneBuilderDock] Collection directory is present and contains items: " + _name)
						else:
							printerr("[SceneBuilderDock] Directory exists, but contains no items: " + _name)
						dir.list_dir_end()
					else:
						printerr("[SceneBuilderDock] Collection directory does not exist: " + _name)
			collection_names = new_collection_names

			for i in range(num_collections):
				var collection_name = collection_names[i]
				if collection_name == "":
					collection_name = " "
				btns_collection_tabs[i].text = collection_name
				btns_collection_tabs[i].add_theme_color_override("font_color", new_collection_font_colors[i])

	else:
		printerr("[SceneBuilderDock] An unknown file exists at location %s. A resource of type CollectionNames should exist here.".format(path_to_collection_names))
		collection_names = Array()
		collection_names.resize(24)
		collection_names.fill("")

	#endregion

# ---- Shortcut ----------------------------------------------------------------

func place_fence():
	var selection: EditorSelection = EditorInterface.get_selection()
	var selected_nodes: Array[Node] = selection.get_selected_nodes()

	if scene_root == null:
		print("[SceneBuilderDock] Scene root is null")
		return

	if selected_nodes.size() != 1:
		printerr("[SceneBuilderDock] Exactly one node sould be selected in the scene")
		return

	if not selected_nodes[0] is Path3D:
		printerr("[SceneBuilderDock] The selected node should be of type Node3D")
		return

	undo_redo.create_action("Make a fence")

	var path: Path3D = selected_nodes[0]

	var fence_piece_names: Array = ordered_keys_by_collection[selected_collection_name]
	var path_length: float = path.curve.get_baked_length()

	for distance in range(0, path_length, spinbox_separation_distance.value):

		var transform: Transform3D = path.curve.sample_baked_with_rotation(distance)
		var position: Vector3 = transform.origin
		var basis: Basis = transform.basis.rotated(Vector3(0, 1, 0), deg_to_rad(spinbox_y_offset.value))

		var chosen_piece_name: String = fence_piece_names[randi() % fence_piece_names.size()]
		var chosen_piece = items_by_collection[selected_collection_name][chosen_piece_name]
		var instance = get_instance_from_path(chosen_piece.scene_path)

		undo_redo.add_do_method(scene_root, "add_child", instance)
		undo_redo.add_do_method(instance, "set_owner", scene_root)
		undo_redo.add_do_method(instance, "set_global_transform", Transform3D(
			basis.rotated(Vector3(1, 0, 0), randf() * deg_to_rad(spinbox_jitter_x.value))
				 .rotated(Vector3(0, 1, 0), randf() * deg_to_rad(spinbox_jitter_y.value))
				 .rotated(Vector3(0, 0, 1), randf() * deg_to_rad(spinbox_jitter_z.value)),
			position
		))

		undo_redo.add_undo_method(scene_root, "remove_child", instance)

	print("[SceneBuilderDock] Commiting action")
	undo_redo.commit_action()

func reroll_preview_instance_transform() -> void:
	if preview_instance == null:
		printerr("[SceneBuilderDock] preview_instance is null inside reroll_preview_instance_transform()")
		return

	random_offset_y = rng.randf_range(selected_item.random_offset_y_min, selected_item.random_offset_y_max)

	if selected_item.use_random_scale:
		var random_scale: float = rng.randf_range(selected_item.random_scale_min, selected_item.random_scale_max)
		original_preview_scale = Vector3(random_scale, random_scale, random_scale)
	else:
		original_preview_scale = Vector3(1, 1, 1)

	preview_instance.scale = original_preview_scale

	if selected_item.use_random_rotation:
		var x_rot: float = rng.randf_range(0, selected_item.random_rot_x)
		var y_rot: float = rng.randf_range(0, selected_item.random_rot_y)
		var z_rot: float = rng.randf_range(0, selected_item.random_rot_z)
		preview_instance.rotation = Vector3(deg_to_rad(x_rot), deg_to_rad(y_rot), deg_to_rad(z_rot))
		original_preview_basis = preview_instance.basis
	else:
		preview_instance.rotation = Vector3(0, 0, 0)
		original_preview_basis = preview_instance.basis

	original_preview_basis = preview_instance.basis

	pos_offset_x = 0
	pos_offset_y = 0
	pos_offset_z = 0
	rot_offset_x = 0
	rot_offset_y = 0
	rot_offset_z = 0
	scale_offset = 0

func select_item(collection_name: String, item_name: String) -> void:
	end_placement_mode()
	var nine_path: NinePatchRect = item_highlighters_by_collection[collection_name][item_name]
	nine_path.self_modulate = Color.GREEN
	selected_item_name = item_name
	selected_item = selected_collection[selected_item_name]
	placement_mode_enabled = true;
	create_preview_instance()

func select_first_item() -> void:
	if (!ordered_keys_by_collection.has(selected_collection_name)):
		printerr("[SceneBuilderDock] Trying to select the first item, but the selected collection name does not exist: ", selected_collection_name)
		return
	var keys: Array = ordered_keys_by_collection[selected_collection_name]
	if keys.is_empty():
		printerr("[SceneBuilderDock] Trying to select the first item, but there are no items to select in this collection: ", selected_collection_name)
		return
	var _first_item: String = ordered_keys_by_collection[selected_collection_name][0]
	print(_first_item)
	select_item(selected_collection_name, _first_item)

func select_next_collection() -> void:
	end_placement_mode()
	for idx in range(selected_collection_index + 1, selected_collection_index + num_collections + 1):
		var next_idx = idx % num_collections
		if is_collection_populated(next_idx):
			select_collection(next_idx)
			select_first_item()
			break
		else:
			print("[SceneBuilderDock] Collection is not populated: ", collection_names[next_idx])

func select_next_item() -> void:
	var ordered_keys: Array = ordered_keys_by_collection[selected_collection_name]
	var idx = ordered_keys.find(selected_item_name)
	if idx >= 0:
		var next_idx = (idx + 1) % ordered_keys.size()
		var next_name = ordered_keys[next_idx]
		select_item(selected_collection_name, next_name)
	else:
		printerr("[SceneBuilderDock] Next item not found? Current index: ", idx)

func select_previous_item() -> void:
	var ordered_keys: Array = ordered_keys_by_collection[selected_collection_name]
	var idx = ordered_keys.find(selected_item_name)
	if idx >= 0:
		select_item(selected_collection_name, ordered_keys[(idx - 1) % ordered_keys.size()])
	else:
		printerr("[SceneBuilderDock] Previous item not found")

func select_previous_collection() -> void:
	end_placement_mode()
	for idx in range(selected_collection_index - 1, selected_collection_index - num_collections - 1, -1):
		var prev_idx = (idx + num_collections) % num_collections
		if is_collection_populated(prev_idx):
			select_collection(prev_idx)
			select_first_item()
			break
		else:
			print("[SceneBuilderDock] Collection is not populated: ", collection_names[prev_idx])

func start_transform_mode(mode: TransformMode) -> void:
	original_mouse_position = viewport.get_mouse_position()
	current_transform_mode = mode
	
	match mode:
		TransformMode.POSITION_X, TransformMode.POSITION_Y, TransformMode.POSITION_Z:
			original_preview_position = preview_instance.global_position
		TransformMode.ROTATION_X, TransformMode.ROTATION_Y, TransformMode.ROTATION_Z:
			if checkbox_snap_enabled.button_pressed:
				var current_rotation = preview_instance.basis.get_euler()
				var snapped_rotation = snap_rotation_to_grid(current_rotation)
				preview_instance.rotation = snapped_rotation
				original_preview_basis = preview_instance.basis
			else:
				original_preview_basis = preview_instance.basis
			rot_offset_x = 0
			rot_offset_y = 0
			rot_offset_z = 0
		TransformMode.SCALE:
			original_preview_scale = preview_instance.scale
			scale_offset = 0
	
	reset_indicators()
	
	match mode:
		TransformMode.POSITION_X, TransformMode.ROTATION_X:
			lbl_indicator_x.self_modulate = Color.GREEN
		TransformMode.POSITION_Y, TransformMode.ROTATION_Y:
			lbl_indicator_y.self_modulate = Color.GREEN
		TransformMode.POSITION_Z, TransformMode.ROTATION_Z:
			lbl_indicator_z.self_modulate = Color.GREEN
		TransformMode.SCALE:
			lbl_indicator_scale.self_modulate = Color.GREEN

func get_icon(collection_name: String, item_name: String) -> Texture:
	var icon_path: String = "res://Data/SceneBuilderCollections/%s/Thumbnail/%s.png" % [collection_name, item_name]
	var tex: Texture = load(icon_path) as Texture
	if tex == null:
		printerr("[SceneBuilderDock] Icon not found: ", icon_path)
		return null
	return tex

func get_instance_from_path(_uid: String) -> Node3D:
	var uid: int = ResourceUID.text_to_id(_uid)

	var path: String = ""
	if ResourceUID.has_id(uid):
		path = ResourceUID.get_id_path(uid)
	else:
		printerr("[SceneBuilderDock] Does not have uid: ", ResourceUID.id_to_text(uid))
		return

	if ResourceLoader.exists(path):
		var loaded = load(path)
		if loaded is PackedScene:
			var instance = loaded.instantiate()
			if instance is Node3D:
				return instance
			else:
				printerr("[SceneBuilderDock] The instantiated scene's root is not a Node3D: ", loaded.name)
		else:
			printerr("[SceneBuilderDock] Loaded resource is not a PackedScene: ", path)
	else:
		printerr("[SceneBuilderDock] Path does not exist: ", path)
	return null

# --

func update_config(_config: SceneBuilderConfig) -> void:
	config = _config

func reset_indicators() -> void:
	lbl_indicator_x.self_modulate = Color.WHITE
	lbl_indicator_y.self_modulate = Color.WHITE
	lbl_indicator_z.self_modulate = Color.WHITE
	lbl_indicator_scale.self_modulate = Color.WHITE

func snap_position_to_grid(position: Vector3) -> Vector3:
	if !checkbox_snap_enabled.button_pressed:
		return position
	if btn_use_local_space.button_pressed:
		print("Snapping is disabled when local space is enabled")
		return position
	var snap_size = spinbox_translate_snap.value
	return Vector3(
		round(position.x / snap_size) * snap_size,
		round(position.y / snap_size) * snap_size,
		round(position.z / snap_size) * snap_size
	)

func snap_rotation_to_grid(rotation: Vector3) -> Vector3:
	if !checkbox_snap_enabled.button_pressed:
		return rotation
	if btn_use_local_space.button_pressed:
		print("Snapping is disabled when local space is enabled")
		return rotation
	var snap_radians = deg_to_rad(spinbox_rotate_snap.value)
	return Vector3(
		round(rotation.x / snap_radians) * snap_radians,
		round(rotation.y / snap_radians) * snap_radians,
		round(rotation.z / snap_radians) * snap_radians
	)

func snap_scale_to_grid(scale: Vector3) -> Vector3:
	if !checkbox_snap_enabled.button_pressed:
		return scale
	if btn_use_local_space.button_pressed:
		print("Snapping is disabled when local space is enabled")
		return scale
	var snap_amount = spinbox_scale_snap.value / 100.0
	return Vector3(
		round(scale.x / snap_amount) * snap_amount,
		round(scale.y / snap_amount) * snap_amount,
		round(scale.z / snap_amount) * snap_amount
	)
