@tool
extends Node
class_name SceneBuilderThumbnailGenerator

var icon_studio: Node3D
var viewport: SubViewport
var camera: Camera3D
var thumbnail_cache: Dictionary = {}

signal thumbnail_generated(scene_path: String, thumbnail: Texture2D)


func _ready():
	setup_viewport()


func _exit_tree():
	thumbnail_cache.clear()
	if viewport and viewport.world_3d:
		viewport.world_3d = null
	if icon_studio:
		icon_studio.queue_free()


func setup_viewport():
	var studio_path = SceneBuilderToolbox.find_resource_with_dynamic_path("icon_studio.tscn")
	print("Studio path: ", studio_path)
	if studio_path == "":
		push_error("icon_studio.tscn not found")
		return
	
	var studio_scene = load(studio_path)
	print("Studio scene loaded: ", studio_scene)
	icon_studio = studio_scene.instantiate()
	print("Icon studio instantiated: ", icon_studio)
	add_child(icon_studio)
	
	viewport = icon_studio.get_node("SubViewport")
	viewport.world_3d = World3D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	print("Viewport found: ", viewport)
	camera = viewport.get_node("Camera3D")
	print("Camera found: ", camera)


func generate_thumbnail(scene_path: String, force_regenerate: bool = false) -> Texture2D:
	
	if not is_inside_tree():
		await tree_entered
	
	await get_tree().process_frame
	
	if not viewport:
		setup_viewport()
		await get_tree().process_frame
	
	if not force_regenerate and thumbnail_cache.has(scene_path):
		return thumbnail_cache[scene_path]
	
	if not ResourceLoader.exists(scene_path):
		push_error("[ThumbnailGenerator] Scene not found: " + scene_path)
		return _get_error_thumbnail()
	
	var scene = load(scene_path)
	if not scene is PackedScene:
		push_error("[ThumbnailGenerator] Resource is not a PackedScene: " + scene_path)
		return _get_error_thumbnail()
	
	var instance = scene.instantiate()
	if not instance is Node3D:
		push_error("[ThumbnailGenerator] Scene root is not Node3D: " + scene_path)
		instance.queue_free()
		return _get_error_thumbnail()
	
	viewport.add_child(instance)
	
	# Frame the object
	var aabb = get_visual_aabb(instance)
	if aabb.size == Vector3.ZERO:
		# Fallback
		aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
	
	position_camera_for_bounds(aabb)
	
	# Render a single frame
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await get_tree().process_frame
	var image = viewport.get_texture().get_image()
	var thumbnail = ImageTexture.create_from_image(image)
	thumbnail_cache[scene_path] = thumbnail
	
	# Cleanup
	instance.queue_free()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	
	# Emit signal for UI updates
	thumbnail_generated.emit(scene_path, thumbnail)
	
	return thumbnail


func get_visual_aabb(node: Node3D) -> AABB:
	return _collect_visual_aabb_recursive(node)


func _collect_visual_aabb_recursive(node: Node3D) -> AABB:
	var aabb = AABB()
	var has_bounds = false
	
	# Check for visual components
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		if mesh_instance.mesh != null:
			var mesh_aabb = mesh_instance.get_aabb()
			if mesh_aabb.size != Vector3.ZERO:
				var transformed_aabb = node.global_transform * mesh_aabb
				aabb = transformed_aabb
				has_bounds = true
	
	elif node is CSGShape3D:
		var csg = node as CSGShape3D
		var csg_aabb = csg.get_aabb()
		if csg_aabb.size != Vector3.ZERO:
			var transformed_aabb = node.global_transform * csg_aabb
			if has_bounds:
				aabb = aabb.merge(transformed_aabb)
			else:
				aabb = transformed_aabb
				has_bounds = true
	
	elif node is GPUParticles3D:
		var particles = node as GPUParticles3D
		var particles_aabb = particles.get_aabb()
		if particles_aabb.size != Vector3.ZERO:
			var transformed_aabb = node.global_transform * particles_aabb
			if has_bounds:
				aabb = aabb.merge(transformed_aabb)
			else:
				aabb = transformed_aabb
				has_bounds = true
	
	# Recurse through children
	for child in node.get_children():
		if child is Node3D:
			var child_aabb = _collect_visual_aabb_recursive(child)
			if child_aabb.size != Vector3.ZERO:
				if has_bounds:
					aabb = aabb.merge(child_aabb)
				else:
					aabb = child_aabb
					has_bounds = true
	
	return aabb


func position_camera_for_bounds(aabb: AABB):
	var center = aabb.get_center()
	var size = aabb.size
	
	# Calculate optimal distance and angle (similar to Terrain3D approach)
	var max_extent = max(size.x, max(size.y, size.z))
	var distance = max_extent * 1.5
	
	# Position camera at optimal angle
	var camera_offset = Vector3(distance * 0.5, distance * 0.3, distance)
	camera.position = center + camera_offset
	camera.look_at(center, Vector3.UP)
	
	# Adjust orthogonal size to frame object properly
	var ortho_size = max(size.x, size.y) * 0.6
	camera.size = max(ortho_size, 1.0)


func get_cached_thumbnail(scene_path: String) -> Texture2D:
	return thumbnail_cache.get(scene_path, null)


func has_cached_thumbnail(scene_path: String) -> bool:
	return thumbnail_cache.has(scene_path)


func remove_from_cache(scene_path: String):
	thumbnail_cache.erase(scene_path)


func get_cache_size() -> int:
	return thumbnail_cache.size()


func _get_error_thumbnail() -> Texture2D:
	# Create simple error texture
	var image = Image.create(128, 128, false, Image.FORMAT_RGB8)
	image.fill(Color.RED)
	return ImageTexture.create_from_image(image)
