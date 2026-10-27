extends Spatial
class_name ARImageSpawner

# Godot 3.6.3
# Membuat dan mengatur instance 3D untuk image target.
# Jalur ArUco tidak disentuh.
# Handler utama: _on_images(names, translations, rotations).

signal spawned(name, instance)
signal despawned(name)

export var auto_create_session: bool = true
export var session_node: NodePath
export var target_map: Dictionary = {}
export var smooth_factor: float = 12.0
export var smooth_rot: float = 8.0
export var hold_frames: int = 5
export var max_jump: float = 0.30
export var target_width_m: float = 0.10
export var fallback_cube: bool = true
export var debug_mode: bool = true
export var status_label_path: NodePath

var _session: ARImageSession = null
var _library: ARImageLibrary = null
var _instances: Dictionary = {} # nama target -> Spatial
var _missed: Dictionary = {} # nama target -> jumlah frame tidak terlihat
var _spawned: Dictionary = {} # nama target -> pernah ditampilkan pada instance aktif


func _ready() -> void:
	_find_or_create_session()
	_find_library_and_connect()
	_refresh_from_library()

	if _session == null:
		_set_status("ARImageSession tidak ditemukan.")
		push_warning("[ARImageSpawner] Tidak ada ARImageSession.")
		return

	if not _session.is_connected("image_detected", self, "_on_images"):
		_session.connect("image_detected", self, "_on_images")
	if not _session.is_connected("status_changed", self, "_on_status"):
		_session.connect("status_changed", self, "_on_status")

	if not _session.is_running():
		_session.start()
	_set_status("Menunggu image target...")


func _exit_tree() -> void:
	if _session != null and is_instance_valid(_session):
		if _session.is_connected("image_detected", self, "_on_images"):
			_session.disconnect("image_detected", self, "_on_images")
		if _session.is_connected("status_changed", self, "_on_status"):
			_session.disconnect("status_changed", self, "_on_status")
	if _library != null and is_instance_valid(_library):
		if _library.is_connected("library_changed", self, "_on_library_changed"):
			_library.disconnect("library_changed", self, "_on_library_changed")


func _find_or_create_session() -> void:
	_session = null

	if session_node != NodePath(""):
		var candidate = get_node_or_null(session_node)
		if candidate is ARImageSession:
			_session = candidate as ARImageSession
			return

	var root = get_tree().current_scene if get_tree() != null else null
	if root != null:
		_session = _find_session_recursive(root)
	if _session != null:
		return

	if auto_create_session:
		_session = ARImageSession.new()
		_session.name = "ARImageSession"
		add_child(_session)


func _find_session_recursive(n: Node) -> ARImageSession:
	if n == null:
		return null
	if n is ARImageSession:
		return n as ARImageSession
	for child in n.get_children():
		var found = _find_session_recursive(child)
		if found != null:
			return found
	return null


func _find_library_and_connect() -> void:
	_library = _find_library()
	if _library != null and not _library.is_connected("library_changed", self, "_on_library_changed"):
		_library.connect("library_changed", self, "_on_library_changed")
	if _session != null and _library != null:
		_session.set_library(_library)


func _find_library() -> ARImageLibrary:
	var tree = get_tree()
	if tree == null or tree.current_scene == null:
		return null
	return _find_library_recursive(tree.current_scene)


func _find_library_recursive(n: Node) -> ARImageLibrary:
	if n == null:
		return null
	if n is ARImageLibrary:
		return n as ARImageLibrary
	for child in n.get_children():
		var found = _find_library_recursive(child)
		if found != null:
			return found
	return null


func _on_library_changed() -> void:
	_refresh_from_library()
	if _session != null and is_instance_valid(_session) and _library != null:
		_session.set_library(_library)


func _refresh_from_library() -> void:
	if _library == null or not is_instance_valid(_library):
		_library = _find_library()
	if _library == null:
		return

	for entry in _library.list_targets():
		if not (entry is Dictionary):
			continue
		var nm = str(entry.get("name", "")).strip_edges()
		var scene_path = str(entry.get("scene_path", entry.get("scene", ""))).strip_edges()
		if nm == "" or scene_path == "":
			continue
		if target_map.has(nm):
			continue
		if not ResourceLoader.exists(scene_path):
			if debug_mode:
				push_warning("[ARImageSpawner] Scene target tidak ditemukan: %s (%s)" % [nm, scene_path])
			continue

		var resource = load(scene_path)
		if resource is PackedScene:
			target_map[nm] = resource
		elif debug_mode:
			push_warning("[ARImageSpawner] Resource target bukan PackedScene: %s (%s)" % [nm, scene_path])


func _on_images(names: Array, translations: Array, rotations: Array) -> void:
	var seen: Dictionary = {}
	var count = min(names.size(), min(translations.size(), rotations.size()))

	for i in range(count):
		var nm = str(names[i]).strip_edges()
		if nm == "":
			continue
		if not (translations[i] is Vector3) or not (rotations[i] is Vector3):
			if debug_mode:
				push_warning("[ARImageSpawner] Pose target '%s' bukan Vector3." % nm)
			continue

		seen[nm] = true
		_missed[nm] = 0

		# Session mengirim pose dalam koordinat backend; konversi sumbu dilakukan di sini.
		var translation: Vector3 = translations[i]
		var position = Vector3(translation.x, -translation.y, -translation.z)
		var basis = ARImageSession.basis_from_rvec(rotations[i])
		var instance = _ensure_instance(nm)
		if instance == null:
			continue

		if not bool(_spawned.get(nm, false)):
			instance.transform = Transform(basis, position)
			instance.visible = true
			_spawned[nm] = true
			emit_signal("spawned", nm, instance)
		else:
			var target_position: Vector3 = position
			if max_jump > 0.0:
				var delta_position: Vector3 = target_position - instance.translation
				var distance = delta_position.length()
				if distance > max_jump and distance > 0.000001:
					target_position = instance.translation + delta_position / distance * max_jump

			var delta_time = get_process_delta_time()
			var position_weight = clamp(smooth_factor * delta_time, 0.0, 1.0)
			var rotation_weight = clamp(smooth_rot * delta_time, 0.0, 1.0)
			var new_basis: Basis = instance.transform.basis.slerp(basis, rotation_weight)
			var new_position: Vector3 = instance.translation.linear_interpolate(target_position, position_weight)
			instance.transform = Transform(new_basis, new_position)
			instance.visible = true

	_tick_missed(seen)


func _ensure_instance(nm: String) -> Spatial:
	if _instances.has(nm):
		var existing = _instances[nm] as Spatial
		if existing != null and is_instance_valid(existing):
			return existing
		_instances.erase(nm)
		_spawned.erase(nm)

	var node: Spatial = null
	var scene_resource = target_map.get(nm, null)
	if scene_resource is String:
		var scene_path = str(scene_resource)
		if ResourceLoader.exists(scene_path):
			scene_resource = load(scene_path)
		if not (scene_resource is PackedScene):
			scene_resource = null

	if scene_resource is PackedScene:
		var created = (scene_resource as PackedScene).instance()
		if created is Spatial:
			node = created as Spatial
		else:
			if created != null:
				created.free()
			if debug_mode:
				push_warning("[ARImageSpawner] Root scene target '%s' harus turunan Spatial." % nm)

	if node == null:
		if not debug_mode or not fallback_cube:
			if debug_mode:
				push_warning("[ARImageSpawner] Tidak ada scene untuk target '%s'; fallback tidak aktif." % nm)
			return null
		node = _make_cube(nm)

	if node == null:
		return null
	add_child(node)
	node.visible = false
	_instances[nm] = node
	_missed[nm] = 0
	return node


func _make_cube(nm: String) -> MeshInstance:
	var mesh_instance = MeshInstance.new()
	var cube = CubeMesh.new()
	var width = max(target_width_m, 0.001)
	cube.size = Vector3(width, width, width)
	mesh_instance.mesh = cube

	var material = SpatialMaterial.new()
	var hash_value = abs(nm.hash())
	var hue = fmod(float(hash_value) / 2147483647.0 + 0.08, 1.0)
	var color = Color.from_hsv(hue, 0.85, 1.0)
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	mesh_instance.set_surface_material(0, material)
	return mesh_instance


func _tick_missed(seen: Dictionary) -> void:
	for key in _instances.keys():
		var nm = str(key)
		if seen.has(nm):
			continue

		_missed[nm] = int(_missed.get(nm, 0)) + 1
		if int(_missed[nm]) > max(hold_frames, 0):
			var node = _instances.get(nm, null) as Spatial
			if node != null and is_instance_valid(node):
				node.visible = false
				emit_signal("despawned", nm)
				node.queue_free()
			_instances.erase(nm)
			_spawned.erase(nm)
			_missed.erase(nm)

	if _instances.empty() or _all_hidden():
		_set_status("Menunggu image target...")


func _all_hidden() -> bool:
	for key in _instances.keys():
		var node = _instances.get(key, null) as Spatial
		if node != null and is_instance_valid(node) and node.visible:
			return false
	return true


func _on_status(text: String) -> void:
	_set_status(text)


func _set_status(text: String) -> void:
	if not debug_mode:
		return
	if status_label_path != NodePath(""):
		var label_node = get_node_or_null(status_label_path)
		if label_node is Label:
			(label_node as Label).text = text


func add_target_scene(nm: String, scene: PackedScene) -> void:
	var clean_name = nm.strip_edges()
	if clean_name == "" or scene == null:
		return
	target_map[clean_name] = scene


func remove_target_scene(nm: String) -> void:
	target_map.erase(nm)
	if _instances.has(nm):
		var node = _instances[nm] as Spatial
		if node != null and is_instance_valid(node):
			node.queue_free()
		_instances.erase(nm)
	_spawned.erase(nm)
	_missed.erase(nm)


func clear_targets() -> void:
	target_map.clear()
	for key in _instances.keys():
		var node = _instances.get(key, null) as Spatial
		if node != null and is_instance_valid(node):
			node.queue_free()
	_instances.clear()
	_missed.clear()
	_spawned.clear()


func target_names() -> Array:
	var names = target_map.keys()
	names.sort()
	return names
