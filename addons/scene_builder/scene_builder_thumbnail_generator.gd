@tool
extends Node
class_name SceneBuilderThumbnailGenerator

var icon_studio: Node3D
var viewport: SubViewport
var camera: Camera3D
var thumbnail_cache: Dictionary = {}

# Batch rendering: items are placed in an items_per_row × items_per_row grid in one viewport,
# rendered once, then the image is sliced into individual thumbnails.
const items_per_row: int = 5
const thumbnail_px: int = 80
const cell_spacing: float = 1.0
const item_fill: float = .8

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
	var image = Image.create(thumbnail_px, thumbnail_px, false, Image.FORMAT_RGB8)
	image.fill(Color.RED)
	return ImageTexture.create_from_image(image)


func generate_thumbnails_batch(scene_paths: Array, force_regenerate: bool = false) -> Dictionary:
	if not is_inside_tree():
		await tree_entered
	await get_tree().process_frame
 
	if not viewport:
		setup_viewport()
		await get_tree().process_frame
 
	var results: Dictionary = {}
 
	var paths_to_render: Array = []
	for path in scene_paths:
		if not force_regenerate and thumbnail_cache.has(path):
			results[path] = thumbnail_cache[path]
		else:
			paths_to_render.append(path)
 
	if paths_to_render.is_empty():
		return results
 
	var original_viewport_size = viewport.size
	var grid_viewport_px = items_per_row * thumbnail_px
	viewport.size = Vector2i(grid_viewport_px, grid_viewport_px)
 
	var items_per_batch = items_per_row * items_per_row
	var total = paths_to_render.size()
	var num_batches = ceili(float(total) / items_per_batch)
	var batch_start = 0
	var batch_num = 0
 
	print("[ThumbnailGenerator] Batch rendering %d items in %d batches (%dx%d grid)" % [total, num_batches, items_per_row, items_per_row])
 
	while batch_start < total:
		var batch_end = mini(batch_start + items_per_batch, total)
		var batch_paths = paths_to_render.slice(batch_start, batch_end)
		var batch_results = await _render_grid_batch(batch_paths)
		results.merge(batch_results)
		batch_num += 1
		print("[ThumbnailGenerator] Completed batch %d/%d" % [batch_num, num_batches])
		batch_start = batch_end
 
	viewport.size = original_viewport_size
	return results
 
 
func _render_grid_batch(batch_paths: Array) -> Dictionary:
	var results: Dictionary = {}
	var instances: Array = []
	var valid_entries: Array = []
 
	# Camera at the same angle as single-item render
	var grid_origin = Vector3.ZERO
	var look_dir = Vector3(0.5, 0.3, 1.0).normalized()
	camera.position = grid_origin + look_dir * 50.0
	camera.look_at(grid_origin, Vector3.UP)
	camera.size = float(items_per_row) * cell_spacing
	await get_tree().process_frame
 
	# Layout items along camera's view plane so each cell maps to thumbnail_px pixels
	var cam_right = camera.global_transform.basis.x
	var cam_up = camera.global_transform.basis.y
 
	var grid_idx = 0
	for path in batch_paths:
		if not ResourceLoader.exists(path):
			results[path] = _get_error_thumbnail()
			continue
 
		var packed_scene = load(path)
		if not packed_scene is PackedScene:
			results[path] = _get_error_thumbnail()
			continue
 
		var instance = packed_scene.instantiate()
		if not instance is Node3D:
			instance.queue_free()
			results[path] = _get_error_thumbnail()
			continue
 
		var col = grid_idx % items_per_row
		var row = grid_idx / items_per_row
		viewport.add_child(instance)
 
		var aabb = get_visual_aabb(instance)
		if aabb.size == Vector3.ZERO:
			aabb = AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1, 1, 1))
 
		var center_offset = aabb.get_center() - instance.global_position
		var projected_size = _get_projected_aabb_size(aabb, cam_right, cam_up)
		var max_projected = max(projected_size.x, projected_size.y)
		var target_size = cell_spacing * item_fill
		var scale_factor = target_size / max_projected if max_projected > 0.001 else 1.0
 
		var x_off = (col - (items_per_row - 1) / 2.0) * cell_spacing
		var y_off = ((items_per_row - 1) / 2.0 - row) * cell_spacing
		var cell_center = grid_origin + cam_right * x_off + cam_up * y_off
 
		instance.scale *= scale_factor
		instance.global_position = cell_center - center_offset * scale_factor
	
		valid_entries.append({"path": path, "col": col, "row": row})
		instances.append(instance)
		grid_idx += 1
	
	if valid_entries.is_empty():
		return results
	
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await get_tree().process_frame
	
	var full_image = viewport.get_texture().get_image()
	
	for entry in valid_entries:
		var col: int = entry["col"]
		var row: int = entry["row"]
		var path: String = entry["path"]
	
		var region = Rect2i(col * thumbnail_px, row * thumbnail_px, thumbnail_px, thumbnail_px)
		var tile_image = full_image.get_region(region)
		var thumbnail = ImageTexture.create_from_image(tile_image)
	
		thumbnail_cache[path] = thumbnail
		results[path] = thumbnail
		thumbnail_generated.emit(path, thumbnail)
	
	for instance in instances:
		instance.queue_free()
	
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	return results
	
func _get_projected_aabb_size(aabb: AABB, cam_right: Vector3, cam_up: Vector3) -> Vector2:
	var min_r = INF
	var max_r = -INF
	var min_u = INF
	var max_u = -INF
	var pos = aabb.position
	var sz = aabb.size
	for x in [0.0, 1.0]:
		for y in [0.0, 1.0]:
			for z in [0.0, 1.0]:
				var corner = pos + Vector3(sz.x * x, sz.y * y, sz.z * z)
				var r = corner.dot(cam_right)
				var u = corner.dot(cam_up)
				min_r = min(min_r, r)
				max_r = max(max_r, r)
				min_u = min(min_u, u)
				max_u = max(max_u, u)
	return Vector2(max_r - min_r, max_u - min_u)
