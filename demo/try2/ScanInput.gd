extends Control
# S1-ScanInput (LAPTOP DEV ONLY; bukan UI untuk APK rilis).
# Godot 3.6.3.
# Impor gambar target dari file lokal: pilih -> preview -> nama/lebar -> simpan -> ekspor.
# Jalur ArUco (ar.gd / ar_marker_spawner.gd) tidak disentuh.
# Node UI opsional: FileDialog, Preview, PickButton, SaveButton, ExportButton,
# NameEdit, WidthSpin, StatusLabel. Node yang belum ada tidak akan membuat script crash.

var _lib: ARImageLibrary = null
var _picked_path: String = ""
var _picked_image: Image = null
var _preview_texture: ImageTexture = null


func _ready() -> void:
	_preview_texture = ImageTexture.new()
	_lib = _find_or_create_library()
	_setup_filedialog()
	_wire_buttons()
	_set_status("Mode pengembang: pilih file gambar, isi nama dan lebar, lalu Simpan.")


func _exit_tree() -> void:
	# ImageTexture tidak perlu dibebaskan manual. Bersihkan referensi agar UI
	# yang dibuat ulang tidak mempertahankan gambar lama.
	_picked_image = null
	_preview_texture = null


func _find_or_create_library() -> ARImageLibrary:
	var tree = get_tree()
	if tree == null:
		push_warning("[ScanInput] SceneTree belum tersedia; ARImageLibrary belum ditemukan.")
		return null

	var root = tree.current_scene
	if root != null:
		var found = _find_lib_recursive(root)
		if found != null:
			return found

	# Pasang library pada root scene, bukan sebagai anak Control ini, supaya
	# library tidak ikut hilang hanya karena panel ScanInput dihapus.
	var lib = ARImageLibrary.new()
	lib.name = "ARImageLibrary"
	if root != null:
		root.add_child(lib)
	else:
		tree.root.add_child(lib)
	return lib


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


func _setup_filedialog() -> void:
	var dialog = get_node_or_null("FileDialog")
	if dialog == null or not (dialog is FileDialog):
		return

	dialog.mode = FileDialog.MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.clear_filters()
	# FileDialog Godot 3 mengharapkan pola ekstensi, bukan judul filter biasa.
	dialog.add_filter("*.png, *.jpg, *.jpeg, *.bmp, *.webp ; Image files")

	var pictures_dir = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	var dir = Directory.new()
	if pictures_dir != "" and dir.dir_exists(pictures_dir):
		dialog.current_dir = pictures_dir

	if dialog.has_signal("file_selected") and not dialog.is_connected("file_selected", self, "_on_file_selected"):
		var err = dialog.connect("file_selected", self, "_on_file_selected")
		if err != OK:
			push_warning("[ScanInput] Gagal menghubungkan FileDialog.file_selected (error %d)." % err)


func _wire_buttons() -> void:
	_wire("PickButton", "pressed", "_on_pick_pressed")
	_wire("SaveButton", "pressed", "_on_save_pressed")
	_wire("ExportButton", "pressed", "_on_export_pressed")


func _wire(node_path: NodePath, signal_name: String, method_name: String) -> void:
	var node = get_node_or_null(node_path)
	if node == null:
		return
	if not node.has_signal(signal_name):
		push_warning("[ScanInput] Node '%s' tidak memiliki sinyal '%s'." % [str(node_path), signal_name])
		return
	if node.is_connected(signal_name, self, method_name):
		return
	var err = node.connect(signal_name, self, method_name)
	if err != OK:
		push_warning("[ScanInput] Gagal menghubungkan %s.%s (error %d)." % [str(node_path), signal_name, err])


func _on_pick_pressed() -> void:
	var dialog = get_node_or_null("FileDialog")
	if dialog == null or not (dialog is FileDialog):
		_set_status("Node FileDialog belum tersedia. Tambahkan FileDialog sebagai anak ScanInput.")
		return
	(dialog as FileDialog).popup_centered(Vector2(800, 600))


func _on_file_selected(path: String) -> void:
	var selected_path = path.strip_edges()
	if selected_path == "":
		_set_status("Tidak ada file yang dipilih.")
		return

	var image = Image.new()
	var err = image.load(selected_path)
	if err != OK or image.get_width() <= 0 or image.get_height() <= 0:
		_set_status("Gagal membaca gambar (error %d): %s" % [err, selected_path])
		return

	_picked_path = selected_path
	_picked_image = image
	_show_preview(image)

	var filename = selected_path.get_file()
	_set_status("Dipilih: %s (%d x %d). Isi nama dan lebar fisik, lalu Simpan." % [filename, image.get_width(), image.get_height()])

	var name_edit = get_node_or_null("NameEdit")
	if name_edit != null and name_edit is LineEdit:
		if (name_edit as LineEdit).text.strip_edges() == "":
			(name_edit as LineEdit).text = filename.get_basename().replace(" ", "_")


func _on_save_pressed() -> void:
	# Coba cari lagi jika UI siap lebih dahulu daripada library.
	if _lib == null or not is_instance_valid(_lib):
		_lib = _find_or_create_library()
	if _lib == null:
		_set_status("ARImageLibrary tidak ditemukan dan gagal dibuat.")
		return

	if _picked_path == "" or _picked_image == null:
		_set_status("Pilih file gambar terlebih dahulu.")
		return

	var name_edit = get_node_or_null("NameEdit")
	if name_edit == null or not (name_edit is LineEdit):
		_set_status("Node NameEdit belum ada atau bukan LineEdit.")
		return
	var target_name = (name_edit as LineEdit).text.strip_edges()
	if target_name == "":
		_set_status("Nama target tidak boleh kosong.")
		return

	var width_cm = 20.0
	var width_spin = get_node_or_null("WidthSpin")
	if width_spin != null:
		if not (width_spin is SpinBox):
			_set_status("Node WidthSpin harus berupa SpinBox.")
			return
		width_cm = (width_spin as SpinBox).value
	if width_cm <= 0.0:
		_set_status("Lebar fisik harus lebih besar dari 0 cm.")
		return

	var error_message = _lib.import_file(_picked_path, target_name, width_cm / 100.0)
	if error_message == "":
		_set_status("Target '%s' tersimpan (lebar %.2f cm)." % [target_name, width_cm])
	else:
		_set_status(error_message)


func _on_export_pressed() -> void:
	if _lib == null or not is_instance_valid(_lib):
		_lib = _find_or_create_library()
	if _lib == null:
		_set_status("ARImageLibrary tidak ditemukan; ekspor dibatalkan.")
		return

	var error_message = _lib.export_to_bundle()
	if error_message == "":
		_set_status("Ekspor berhasil: res://targets/manifest.json dan PNG diperbarui. Periksa perubahan proyek sebelum commit.")
	else:
		_set_status("Ekspor gagal: " + error_message)


func _show_preview(source_image: Image) -> void:
	var preview = get_node_or_null("Preview")
	if preview == null or not (preview is TextureRect):
		return

	var display_image = source_image
	# Pastikan format cocok untuk ditampilkan sebagai ImageTexture.
	if display_image.get_format() != Image.FORMAT_RGB8 and display_image.get_format() != Image.FORMAT_RGBA8:
		display_image = source_image.duplicate() as Image
		if display_image == null:
			_set_status("Gagal menyiapkan gambar untuk preview.")
			return
		display_image.convert(Image.FORMAT_RGB8)

	if _preview_texture == null:
		_preview_texture = ImageTexture.new()
	_preview_texture.create_from_image(display_image, Texture.FLAG_FILTER)
	(preview as TextureRect).texture = _preview_texture


func _set_status(message: String) -> void:
	var label = get_node_or_null("StatusLabel")
	if label != null and label is Label:
		(label as Label).text = message
	print("[ScanInput] ", message)
