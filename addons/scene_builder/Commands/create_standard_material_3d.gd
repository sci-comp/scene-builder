@tool
extends EditorPlugin

var material_prefix : String = "MI_"
var texture_prefix : String = "T_"
var nmap_suffix : String = "_n"
var emap_suffix : String = "_e"

var popup_instance : PopupPanel
var vbox : VBoxContainer
var lbl_title : Label
var lbl_transparency : Label
var lbl_vertex_color : Label
var lbl_back_lighting : Label
var lbl_shadows : Label
var lbl_billboard : Label
var lbl_use_particle_settings : Label

var checkbox_set_alpha_transparency : CheckBox
var checkbox_use_vertex_color_as_albedo : CheckBox
var checkbox_vertex_color_is_srgb : CheckBox
var checkbox_enable_back_lighting : CheckBox
var checkbox_set_backlight_to_white : CheckBox
var checkbox_disable_receive_shadows : CheckBox
var checkbox_set_mode_to_particle_billboard : CheckBox
var checkbox_keep_scale_with_billboards : CheckBox
var checkbox_use_particle_settings : CheckBox

var ok_button : Button

signal done

var toolbox = SceneBuilderToolbox.new()

func execute():
	
	# Popup
	popup_instance = PopupPanel.new()
	add_child(popup_instance)
	popup_instance.popup_centered(Vector2(300, 200))
	# VBox
	vbox = VBoxContainer.new()
	popup_instance.add_child(vbox)

	# -- Title -----------------------------------------------------------------
	
	lbl_title = Label.new()
	lbl_title.text = "Create a BaseMaterial3D for the current selection in FileSystem"
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl_title)

	# -- Transparency ----------------------------------------------------------

	lbl_transparency = Label.new()
	lbl_transparency.text = "Transparency"
	vbox.add_child(lbl_transparency)

	# Set alpha transparency
	checkbox_set_alpha_transparency = CheckBox.new()
	checkbox_set_alpha_transparency.text = "Use alpha transparency"
	vbox.add_child(checkbox_set_alpha_transparency)

	# -- Vertex Color ----------------------------------------------------------
	
	lbl_vertex_color = Label.new()
	lbl_vertex_color.text = "Vertex Color"
	vbox.add_child(lbl_vertex_color)
	
	# Use vertex color as albedo
	checkbox_use_vertex_color_as_albedo = CheckBox.new()
	checkbox_use_vertex_color_as_albedo.text = "Use as albedo"
	vbox.add_child(checkbox_use_vertex_color_as_albedo)
	
	# Vertex color is sRGB
	checkbox_vertex_color_is_srgb = CheckBox.new()
	checkbox_vertex_color_is_srgb.text = "Is sRGB"
	vbox.add_child(checkbox_vertex_color_is_srgb)
	
	# -- Back Lighting ---------------------------------------------------------
	
	lbl_back_lighting = Label.new()
	lbl_back_lighting.text = "Back Lighting"
	vbox.add_child(lbl_back_lighting)
	
	# Enable back lighting
	checkbox_enable_back_lighting = CheckBox.new()
	checkbox_enable_back_lighting.text = "Enabled"
	vbox.add_child(checkbox_enable_back_lighting)
	
	# Set backlight color to ffffff
	checkbox_set_backlight_to_white = CheckBox.new()
	checkbox_set_backlight_to_white.text = "Set backlight color to white"
	vbox.add_child(checkbox_set_backlight_to_white)
	
	# -- Shadows ---------------------------------------------------------------
	
	lbl_shadows = Label.new()
	lbl_shadows.text = "Shadows"
	vbox.add_child(lbl_shadows)
	
	# Disable receive shadows
	checkbox_disable_receive_shadows = CheckBox.new()
	checkbox_disable_receive_shadows.text = "Disable receive shadows"
	vbox.add_child(checkbox_disable_receive_shadows)
	
	# -- Billboard -------------------------------------------------------------
	
	lbl_billboard = Label.new()
	lbl_billboard.text = "Billboard"
	vbox.add_child(lbl_billboard)
	
	# Set mode to particle billboard
	checkbox_set_mode_to_particle_billboard = CheckBox.new()
	checkbox_set_mode_to_particle_billboard.text = "Set mode to particle billboard"
	vbox.add_child(checkbox_set_mode_to_particle_billboard)
	
	# Keep scale with billboards
	checkbox_keep_scale_with_billboards = CheckBox.new()
	checkbox_keep_scale_with_billboards.text = "Keep scale with billboards"
	vbox.add_child(checkbox_keep_scale_with_billboards)
	
	# -- Set all true ----------------------------------------------------------
	
	lbl_use_particle_settings = Label.new()
	lbl_use_particle_settings.text = "-- Use settings for particle materials --"
	vbox.add_child(lbl_use_particle_settings)
	
	checkbox_use_particle_settings = CheckBox.new()
	checkbox_use_particle_settings.text = "Use settings for particle materials"
	vbox.add_child(checkbox_use_particle_settings)
	
	# -- End CheckBox group --
	
	# Ok button
	ok_button = Button.new()
	ok_button.text = "Ok"
	ok_button.pressed.connect(_on_ok_pressed)
	vbox.add_child(ok_button)

func _on_ok_pressed():
	var selected_paths = get_editor_interface().get_selected_paths()
	var texture_to_material = {}  # Maps from albedo texture path to material instance

	# Generate materials for albedo textures
	for path in selected_paths:
		var file_name = path.get_file()
		var base_name = file_name.get_basename()

		if base_name == "" or path.ends_with(".import"):
			continue

		if base_name.begins_with(texture_prefix) and !base_name.ends_with(nmap_suffix) and !base_name.ends_with(emap_suffix):
			var new_mat_name = material_prefix + toolbox.replace_first(base_name, texture_prefix, "")
			var albedo_texture = load(path)
			var mat = StandardMaterial3D.new()
			mat.albedo_texture = albedo_texture
			
			texture_to_material[path] = mat

	# Attach normal maps to materials
	for path in texture_to_material.keys():
		var file_name = path.get_file()
		var base_name = file_name.get_basename()
		var nmap_path = toolbox.replace_last(path, base_name, base_name + nmap_suffix)

		if nmap_path in selected_paths:
			var normal_texture = load(nmap_path)
			var mat : StandardMaterial3D = texture_to_material[path]
			mat.normal_enabled = true
			mat.normal_texture = normal_texture
			
	# Attach emissive maps to materials
	for path in texture_to_material.keys():
		var file_name = path.get_file()
		var base_name = file_name.get_basename()
		var emap_path = toolbox.replace_last(path, base_name, base_name + emap_suffix)

		if emap_path in selected_paths:
			var emissive_texture = load(emap_path)
			var mat : StandardMaterial3D = texture_to_material[path]
			mat.emission_enabled = true
			mat.emission_texture = emissive_texture

	# Set other properties
	var use_particle_settings : bool = checkbox_use_particle_settings.is_pressed()
	
	for mat : StandardMaterial3D in texture_to_material.values():
		
		# Transparency
		
		if checkbox_set_alpha_transparency.is_pressed() or use_particle_settings:
			mat.transparency = mat.TRANSPARENCY_ALPHA
		
		# Vertex Color
		
		if checkbox_use_vertex_color_as_albedo.is_pressed() or use_particle_settings:
			mat.vertex_color_use_as_albedo = true
		
		if checkbox_vertex_color_is_srgb.is_pressed() or use_particle_settings:
			mat.vertex_color_is_srgb = true
		
		# Back Lighting
		
		if checkbox_enable_back_lighting.is_pressed() or use_particle_settings:
			mat.backlight_enabled = true
		
		if checkbox_set_backlight_to_white.is_pressed() or use_particle_settings:
			mat.backlight = Color.WHITE
		
		# Shadows
		
		if checkbox_disable_receive_shadows.is_pressed() or use_particle_settings:
			mat.disable_receive_shadows = true
		
		# Billboard
		
		if checkbox_set_mode_to_particle_billboard.is_pressed() or use_particle_settings:
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		
		if checkbox_keep_scale_with_billboards.is_pressed() or use_particle_settings:
			mat.billboard_keep_scale = true

	# Save materials
	for path in texture_to_material.keys():
		var dir = path.get_base_dir()
		var file_name = path.get_file()
		var base_name = file_name.get_basename()
		var new_mat_name = material_prefix + toolbox.replace_first(base_name, texture_prefix, "")
		var save_path = dir.path_join(new_mat_name + ".tres")

		ResourceSaver.save(texture_to_material[path], save_path)

	popup_instance.queue_free()
	done.emit()
