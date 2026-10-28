extends Control
# S2-Library (LAPTOP DEV ONLY; bukan UI untuk APK rilis).
# Godot 3.6.3. Menampilkan daftar target + tombol kelola (hapus, ganti scene, export).
# Ikut pola ScanInput.gd: defensive get_node_or_null, _set_status, recursive library find.
# API ARImageLibrary: load(), list_targets(), remove_target(), update_scene(),
#   export_to_bundle() — semua mengembalikan String ("" = OK, else pesan error).

const BUNDLE_BADGE := "[BUNDLE]"

var _lib: ARImageLibrary = null
var _rows: Dictionary = {}     # nama -> Dictionary {root, info_label}


func _ready() -> void:
	var lib = _find_library()
	if lib == null:
		_set_status("ARImageLibrary tidak ditemukan. Tambahkan node ARImageLibrary sebagai anak Library.")
		return
	_lib = lib

	# Muat state (dev-work + bundle) sebelum refresh pertama.
	_lib.load()

	# Sambung sinyal library_changed untuk refresh otomatis.
	if not _lib.is_connected("library_changed", self, "_on_library_changed"):
		_lib.connect("library_changed", self, "_on_library_changed")

	# Wire tombol ekspor.
	_wire("BtnExport", "pressed", "_on_export_pressed")

	# Wire SceneDialog.
	_setup_scene_dialog()

	# Populate grid setelah sinyal terhubung (load() di atas sudah emit
	# library_changed tapi belum ada listener, jadi panggil refresh manual).
	_refresh()
	_set_status("Library dimuat: %d target." % _lib.list_targets().size())


# -- Library lookup ----------------------------------------------------------

func _find_library() -> ARImageLibrary:
	# Coba langsung anak bernama "ARImageLibrary" dulu (Library.tscn sudah menaruhnya di sana).
	var direct = get_node_or_null("ARImageLibrary")
	if direct != null and direct is ARImageLibrary:
		return direct as ARImageLibrary

	# Jatuh ke pencarian rekursif di scene tree (seperti ARImageSpawner pola).
	var tree = get_tree()
	if tree != null and tree.current_scene != null:
		return _find_lib_recursive(tree.current_scene)
	return null


func _find_lib_recursive(node: Node) -> ARImageLibrary:
	if node == null:
		return null
	if node is ARImageLibrary:
		return node as ARImageLibrary
	for child in node.get_children():
		var found = _find_lib_recursive(child)
		if found != null:
			return found
	return null


# -- Library signal ---------------------------------------------------------

func _on_library_changed() -> void:
	_refresh()


# -- Grid refresh ------------------------------------------------------------

func _refresh() -> void:
	if _lib == null:
		return

	var grid = get_node_or_null("Grid")
	if grid == null:
		return

	# Hapus semua baris lama.
	for child in grid.get_children():
		child.queue_free()
	_rows.clear()

	var targets = _lib.list_targets()
	for entry in targets:
		if not (entry is Dictionary):
			continue
		var name = str(entry.get("name", "")).strip_edges()
		if name == "":
			continue
		_add_row(grid, entry, name)


func _add_row(grid: GridContainer, entry: Dictionary, name: String) -> void:
	var root = Control.new()
	root.name = "Row_" + name

	# Thumbnail
	var thumb = TextureRect.new()
	thumb.expand = true
	_load_thumbnail(thumb, str(entry.get("image_path", "")))
	root.add_child(thumb)

	# Info label
	var info = Label.new()
	info.align = HALIGN_LEFT
	info.valign = VALIGN_TOP
	info.autowrap = true
	var kp = int(entry.get("keypoints", 0))
	var wm = float(entry.get("width_m", 0.0)) * 100.0
	var scene_path = str(entry.get("scene_path", "")).strip_edges()
	var badge = ""
	if bool(entry.get("bundled", false)):
		badge = " " + BUNDLE_BADGE
	var scene_display = scene_path if scene_path != "" else "(belum pilih scene)"
	info.text = "%s%s\n(kp=%d, W=%.1f cm)\n-> %s" % [name, badge, kp, wm, scene_display]
	root.add_child(info)

	# Tombol Hapus
	var btn_remove = Button.new()
	btn_remove.text = "Hapus"
	btn_remove.connect("pressed", self, "_on_remove_pressed", [name])
	root.add_child(btn_remove)

	# Tombol Ganti Scene
	var btn_scene = Button.new()
	btn_scene.text = "Ganti Scene"
	btn_scene.connect("pressed", self, "_on_scene_pressed", [name])
	root.add_child(btn_scene)

	grid.add_child(root)
	_rows[name] = { "root": root, "info_label": info }


func _load_thumbnail(rect: TextureRect, image_path: String) -> void:
	if image_path == "":
		return
	# load() bekerja untuk res:// dan user:// (Godot 3). PNG langsung jadi ImageTexture.
	if not ResourceLoader.exists(image_path):
		return
	var resource = load(image_path)
	if resource is Texture:
		rect.texture = resource as Texture
	elif resource is Image:
		var tex = ImageTexture.new()
		tex.create_from_image(resource as Image)
		rect.texture = tex


# -- Tombol aksi per-baris ---------------------------------------------------

func _on_remove_pressed(name: String) -> void:
	if _lib == null:
		return
	var err = _lib.remove_target(name)
	if err == "":
		_set_status("'%s' dihapus." % name)
	else:
		_set_status(err)


func _on_scene_pressed(name: String) -> void:
	var dialog = get_node_or_null("SceneDialog")
	if dialog == null or not (dialog is FileDialog):
		_set_status("Node SceneDialog belum tersedia. Tambahkan FileDialog bernama 'SceneDialog' sebagai anak Library.")
		return
	# Simpan nama target yang sedang dipilih untuk lookup di file_selected.
	dialog.set_meta("_pending_target", name)
	(dialog as FileDialog).popup_centered(Vector2(800, 600))


# -- SceneDialog (ganti scene wrapper) ---------------------------------------

func _setup_scene_dialog() -> void:
	var dialog = get_node_or_null("SceneDialog")
	if dialog == null or not (dialog is FileDialog):
		return
	if dialog.has_signal("file_selected") and not dialog.is_connected("file_selected", self, "_on_scene_dialog_file_selected"):
		(dialog as FileDialog).connect("file_selected", self, "_on_scene_dialog_file_selected")


func _on_scene_dialog_file_selected(path: String) -> void:
	if _lib == null:
		return
	var dialog = get_node_or_null("SceneDialog")
	var name = ""
	if dialog != null:
		name = str(dialog.get_meta("_pending_target", ""))
		dialog.set_meta("_pending_target", "")
	if name == "":
		_set_status("Target tidak ditentukan untuk ganti scene.")
		return
	var err = _lib.update_scene(name, path)
	if err == "":
		_set_status("Scene '%s' terpasang untuk '%s'." % [path, name])
	else:
		_set_status(err)


# -- Export ------------------------------------------------------------------

func _on_export_pressed() -> void:
	if _lib == null:
		_set_status("ARImageLibrary tidak tersedia.")
		return
	var err = _lib.export_to_bundle()
	if err == "":
		_set_status("Export OK → res://targets/. Periksa perubahan proyek sebelum commit.")
	else:
		_set_status("Export gagal: " + err)


# -- Helpers -----------------------------------------------------------------

func _wire(node_path: NodePath, signal_name: String, method_name: String) -> void:
	var node = get_node_or_null(node_path)
	if node == null:
		return
	if not node.has_signal(signal_name):
		push_warning("[Library] Node '%s' tidak memiliki sinyal '%s'." % [str(node_path), signal_name])
		return
	if node.is_connected(signal_name, self, method_name):
		return
	var err = node.connect(signal_name, self, method_name)
	if err != OK:
		push_warning("[Library] Gagal menghubungkan %s.%s (error %d)." % [str(node_path), signal_name, err])


func _set_status(message: String) -> void:
	var label = get_node_or_null("StatusLabel")
	if label != null and label is Label:
		(label as Label).text = message
	print("[Library] ", message)
