extends Node
class_name ARImageLibrary

# Godot 3.6.3
# Library gambar target untuk jalur natural-image AR.
# Tidak mengubah jalur ArUco.
#
# Sumber data:
# - Dev-work: user://targets/index.json dan PNG di user://targets/.
# - Bundle:   res://targets/manifest.json dan PNG yang disertakan di proyek.
#
# Format entri kanonis:
# {name, image_path, width_m, keypoints, scene_path, bundled}
# Manifest lama yang memakai "image" / "scene" tetap diterima.

signal library_changed

const TARGETS_DIR = "user://targets"
const INDEX_PATH = "user://targets/index.json"
const BUNDLED_DIR = "res://targets"
const BUNDLED_MANIFEST = "res://targets/manifest.json"
const GDNS = "res://bin/gd_image_detector.gdns"
const MAX_WIDTH = 480
const MIN_KEYPOINTS = 150
const SUPPORTED_EXTS = ["png", "jpg", "jpeg", "bmp", "webp"]

var _targets = {} # Dev-work; name -> Dictionary
var _bundled = {} # Bundle; name -> Dictionary, read-only


func _ensure_dir():
	var dir = Directory.new()
	if not dir.dir_exists(TARGETS_DIR):
		var err = dir.make_dir_recursive(TARGETS_DIR)
		if err != OK:
			push_warning("[ARImageLibrary] Gagal membuat folder: " + TARGETS_DIR)


func _read_json_array(path):
	var file = File.new()
	if not file.file_exists(path):
		return []
	var err = file.open(path, File.READ)
	if err != OK:
		push_warning("[ARImageLibrary] Gagal membuka " + path + " (error %d)." % err)
		return []

	var parsed = JSON.parse(file.get_as_text())
	file.close()
	if parsed.error != OK:
		push_warning("[ARImageLibrary] JSON rusak di %s: %s (baris %d)." % [path, parsed.error_string, parsed.error_line])
		return []
	if not (parsed.result is Dictionary):
		push_warning("[ARImageLibrary] Format JSON harus berupa object: " + path)
		return []

	var root = parsed.result as Dictionary
	var entries = root.get("targets", [])
	if not (entries is Array):
		push_warning("[ARImageLibrary] Properti 'targets' harus berupa Array: " + path)
		return []
	return entries


func _normalize_entry(raw, bundled):
	if not (raw is Dictionary):
		return {}
	var entry = (raw as Dictionary).duplicate(true)
	var name = str(entry.get("name", "")).strip_edges()
	var image_path = str(entry.get("image_path", entry.get("image", ""))).strip_edges()
	var scene_path = str(entry.get("scene_path", entry.get("scene", ""))).strip_edges()
	var width_m = float(entry.get("width_m", 0.0))

	if name == "" or image_path == "" or width_m <= 0.0:
		return {}

	entry["name"] = name
	entry["image_path"] = image_path
	entry["scene_path"] = scene_path
	entry["width_m"] = width_m
	entry["keypoints"] = int(entry.get("keypoints", 0))
	entry["bundled"] = bool(bundled)
	return entry


func load():
	_ensure_dir()
	_targets.clear()
	_bundled.clear()

	for raw in _read_json_array(INDEX_PATH):
		var entry = _normalize_entry(raw, false)
		if entry.empty():
			push_warning("[ARImageLibrary] Entri target dev-work tidak valid; dilewati.")
			continue
		_targets[str(entry["name"])] = entry

	# Bundle bersifat read-only. Target dev-work dengan nama sama menang.
	for raw in _read_json_array(BUNDLED_MANIFEST):
		var entry = _normalize_entry(raw, true)
		if entry.empty():
			push_warning("[ARImageLibrary] Entri target bundle tidak valid; dilewati.")
			continue
		var name = str(entry["name"])
		if not _targets.has(name):
			_bundled[name] = entry

	emit_signal("library_changed")


func save():
	_ensure_dir()
	var entries = []
	var keys = _targets.keys()
	keys.sort()
	for key in keys:
		var entry = (_targets[key] as Dictionary).duplicate(true)
		entry.erase("bundled")
		entries.append(entry)

	var file = File.new()
	var err = file.open(INDEX_PATH, File.WRITE)
	if err != OK:
		push_warning("[ARImageLibrary] Gagal menulis index.json (error %d)." % err)
		return false
	file.store_string(JSON.print({"targets": entries}, "\t"))
	file.close()
	return true


# Gabungan bundle + dev-work; dev-work menang untuk nama yang sama.
func list_targets():
	var out = []
	var seen = {}
	var keys = _targets.keys()
	keys.sort()
	for key in keys:
		out.append((_targets[key] as Dictionary).duplicate(true))
		seen[str(key)] = true

	var bundle_keys = _bundled.keys()
	bundle_keys.sort()
	for key in bundle_keys:
		if not seen.has(str(key)):
			out.append((_bundled[key] as Dictionary).duplicate(true))
	return out


func get_target(name):
	if _targets.has(name):
		return (_targets[name] as Dictionary).duplicate(true)
	if _bundled.has(name):
		return (_bundled[name] as Dictionary).duplicate(true)
	return {}


func has_target(name):
	return _targets.has(name) or _bundled.has(name)


func is_bundled(name):
	return _bundled.has(name) and not _targets.has(name)


func _safe_file_stem(name):
	# Sanitasi deterministik untuk mencegah separator path dan nama kosong.
	var result = ""
	for i in range(name.length()):
		var ch = name.substr(i, 1)
		var code = ch.ord_at(0)
		if (code >= 97 and code <= 122) or (code >= 65 and code <= 90) or (code >= 48 and code <= 57) or ch == "_" or ch == "-":
			result += ch
		elif ch == " " or ch == ".":
			result += "_"
	while result.find("__") >= 0:
		result = result.replace("__", "_")
	result = result.strip_edges()
	while result.begins_with("_"):
		result = result.substr(1, result.length() - 1)
	while result.ends_with("_"):
		result = result.substr(0, result.length() - 1)
	return result


func _prepare_image(source_image):
	if source_image == null:
		return null
	if source_image.get_width() <= 0 or source_image.get_height() <= 0:
		return null

	var image = source_image.duplicate() as Image
	if image == null:
		return null
	if image.get_format() != Image.FORMAT_L8:
		image.convert(Image.FORMAT_L8)

	if image.get_width() > MAX_WIDTH:
		var scale = float(MAX_WIDTH) / float(image.get_width())
		var new_height = max(1, int(round(float(image.get_height()) * scale)))
		image.resize(MAX_WIDTH, new_height, Image.INTERPOLATE_BILINEAR)
	return image


func add_target(image, name, width_m, scene_path = ""):
	var clean_name = str(name).strip_edges()
	if clean_name == "":
		return "Nama target kosong."
	if float(width_m) <= 0.0:
		return "Lebar fisik harus > 0 (meter)."
	if image == null:
		return "Gambar null."

	# Nama target dibandingkan tanpa membedakan huruf besar/kecil.
	for key in _targets.keys():
		if str(key).to_lower() == clean_name.to_lower():
			return "Nama '%s' sudah ada." % clean_name

	var file_stem = _safe_file_stem(clean_name)
	if file_stem == "":
		return "Nama harus mengandung huruf atau angka ASCII."

	# Hindari tabrakan nama file akibat sanitasi (mis. "A B" dan "A_B").
	var png_path = TARGETS_DIR + "/" + file_stem + ".png"
	for key in _targets.keys():
		var existing_path = str((_targets[key] as Dictionary).get("image_path", ""))
		if existing_path.to_lower() == png_path.to_lower():
			return "Nama file target bertabrakan dengan target '%s'. Gunakan nama lain." % str(key)

	var processed = _prepare_image(image)
	if processed == null:
		return "Gambar tidak valid atau gagal diproses."

	# ORB native menjadi pemeriksaan utama jika backend tersedia.
	# Laplacian hanya fallback jika backend/probe tidak tersedia.
	_ensure_dir()
	var err = processed.save_png(png_path)
	if err != OK:
		return "Gagal menyimpan PNG (error %d)." % err

	var orb_keypoints = _probe_orb_keypoints(png_path)
	var keypoints = orb_keypoints
	if orb_keypoints < 0:
		keypoints = estimate_keypoints(processed)

	if keypoints < MIN_KEYPOINTS:
		var dir = Directory.new()
		if dir.file_exists(png_path):
			dir.remove(png_path)
		if orb_keypoints >= 0:
			return "DITOLAK (ORB): terlalu polos (%d keypoint, butuh >= %d). Ganti gambar bertekstur / cetak kertas." % [keypoints, MIN_KEYPOINTS]
		return "DITOLAK: estimasi tekstur terlalu rendah (%d, butuh >= %d). Ganti gambar bertekstur / cetak kertas." % [keypoints, MIN_KEYPOINTS]

	_targets[clean_name] = {
		"name": clean_name,
		"image_path": png_path,
		"width_m": float(width_m),
		"keypoints": int(keypoints),
		"scene_path": str(scene_path).strip_edges()
	}
	if not save():
		_targets.erase(clean_name)
		var cleanup = Directory.new()
		if cleanup.file_exists(png_path):
			cleanup.remove(png_path)
		return "Target diproses tetapi gagal menyimpan index.json."

	emit_signal("library_changed")
	return ""


static func file_filter_string():
	return "Images (*.png, *.jpg, *.jpeg, *.bmp, *.webp)"


func import_file(os_path, name, width_m, scene_path = ""):
	var clean_path = str(os_path).strip_edges()
	if clean_path == "":
		return "Pilih file gambar dulu."
	if str(name).strip_edges() == "":
		return "Nama target kosong."
	if float(width_m) <= 0.0:
		return "Lebar fisik harus > 0 (meter)."

	var dot = clean_path.find_last(".")
	if dot < 0:
		return "Ekstensi tak dikenal. Pakai: png, jpg, jpeg, bmp, webp."
	var extension = clean_path.substr(dot + 1).to_lower()
	if not SUPPORTED_EXTS.has(extension):
		return "Ekstensi .%s tak didukung. Pakai: png, jpg, jpeg, bmp, webp." % extension

	var dir = Directory.new()
	if not dir.file_exists(clean_path):
		return "File tidak ditemukan: " + clean_path

	var image = Image.new()
	var err = image.load(clean_path)
	if err != OK or image.get_width() <= 0 or image.get_height() <= 0:
		return "Gagal membaca gambar. File mungkin rusak: " + clean_path
	return add_target(image, str(name), float(width_m), str(scene_path))


func _probe_orb_keypoints(png_path):
	if not ResourceLoader.exists(GDNS):
		return -1
	var resource = load(GDNS)
	if resource == null or not (resource is NativeScript):
		return -1

	var native_script = resource as NativeScript
	if not native_script.can_instance():
		return -1

	var worker = native_script.new()
	if worker == null:
		return -1
	if not worker.has_method("probe_keypoints"):
		_free_probe_worker(worker)
		return -1

	var result = -1
	# Backend yang dipakai session menerima path gambar dan nama target.
	# probe_keypoints hanya boleh membaca file; tidak memulai capture kamera.
	result = int(worker.call("probe_keypoints", png_path))
	_free_probe_worker(worker)
	return result


func _free_probe_worker(worker):
	if worker == null:
		return
	if worker is Node:
		(worker as Node).free()
	elif worker is Reference:
		(worker as Reference).free()


static func is_dev_build():
	return OS.has_feature("editor") or OS.is_debug_build()


func update_scene(name, scene_path):
	if _targets.has(name):
		var entry = _targets[name] as Dictionary
		entry["scene_path"] = str(scene_path).strip_edges()
		if not save():
			return "Gagal menyimpan perubahan scene_path."
		emit_signal("library_changed")
		return ""
	if _bundled.has(name):
		return "Target bundle read-only. Tambahkan target dengan nama yang sama ke dev-work untuk menimpanya."
	return "Target '%s' tidak ada." % str(name)


func remove_target(name):
	if _bundled.has(name) and not _targets.has(name):
		return "Target bundle read-only, tidak bisa dihapus dari Library."
	if not _targets.has(name):
		return "Target '%s' tidak ada." % str(name)

	var entry = _targets[name] as Dictionary
	var image_path = str(entry.get("image_path", ""))
	_targets.erase(name)
	if not save():
		_targets[name] = entry
		return "Gagal menyimpan perubahan index.json. Target tidak dihapus."

	var dir = Directory.new()
	if image_path.begins_with("user://") and dir.file_exists(image_path):
		var remove_err = dir.remove(image_path)
		if remove_err != OK:
			push_warning("[ARImageLibrary] Target dihapus dari index, tetapi PNG gagal dihapus: " + image_path)

	# Kompatibilitas dengan metadata .yml dari versi lama.
	var legacy_yml = image_path.get_basename() + ".yml"
	if image_path.begins_with("user://") and dir.file_exists(legacy_yml):
		dir.remove(legacy_yml)

	emit_signal("library_changed")
	return ""


func export_to_bundle(names = []):
	# Hanya dapat menulis res:// saat proyek berada di editor/filesystem writable.
	var dir = Directory.new()
	if not dir.dir_exists(BUNDLED_DIR):
		var make_err = dir.make_dir_recursive(BUNDLED_DIR)
		if make_err != OK:
			return "Gagal membuat folder res://targets/ (error %d)." % make_err

	var selected = {}
	if names.empty():
		for key in _targets.keys():
			selected[str(key)] = (_targets[key] as Dictionary).duplicate(true)
	else:
		for requested_name in names:
			var requested = str(requested_name)
			if _targets.has(requested):
				selected[requested] = (_targets[requested] as Dictionary).duplicate(true)

	if selected.empty():
		return "Tidak ada target dev-work untuk diekspor."

	# Pertahankan target bundle yang sudah ada, lalu timpa hanya nama yang diekspor.
	var manifest_by_name = {}
	for key in _bundled.keys():
		manifest_by_name[str(key)] = (_bundled[key] as Dictionary).duplicate(true)
	# Target dari manifest lama juga perlu dipertahankan meskipun sudah ditimpa dev-work.
	for raw in _read_json_array(BUNDLED_MANIFEST):
		var old_entry = _normalize_entry(raw, true)
		if not old_entry.empty() and not manifest_by_name.has(str(old_entry["name"])):
			manifest_by_name[str(old_entry["name"])] = old_entry

	var selected_keys = selected.keys()
	selected_keys.sort()
	var copied_paths = []
	for key in selected_keys:
		var entry = selected[key] as Dictionary
		var name = str(entry.get("name", key))
		var source_png = str(entry.get("image_path", ""))
		if source_png == "":
			return "Path gambar kosong untuk target: " + name
		if not dir.file_exists(source_png):
			return "File gambar target tidak ditemukan: " + source_png

		var file_stem = _safe_file_stem(name)
		if file_stem == "":
			return "Nama target tidak valid untuk bundle: " + name
		var destination_png = BUNDLED_DIR + "/" + file_stem + ".png"
		if source_png != destination_png:
			var copy_err = dir.copy(source_png, destination_png)
			if copy_err != OK:
				return "Gagal menyalin PNG untuk '%s' (error %d)." % [name, copy_err]
		copied_paths.append(destination_png)

		manifest_by_name[name] = {
			"name": name,
			"image": destination_png,
			"image_path": destination_png,
			"width_m": float(entry.get("width_m", 0.0)),
			"keypoints": int(entry.get("keypoints", 0)),
			"scene": str(entry.get("scene_path", "")),
			"scene_path": str(entry.get("scene_path", ""))
		}

	var manifest = []
	var manifest_keys = manifest_by_name.keys()
	manifest_keys.sort()
	for key in manifest_keys:
		var entry = (manifest_by_name[key] as Dictionary).duplicate(true)
		# Normalisasi format yang ditulis agar konsisten.
		var image_path = str(entry.get("image_path", entry.get("image", "")))
		var scene_path = str(entry.get("scene_path", entry.get("scene", "")))
		entry["image"] = image_path
		entry["image_path"] = image_path
		entry["scene"] = scene_path
		entry["scene_path"] = scene_path
		entry["bundled"] = true
		manifest.append(entry)

	# Tulis manifest sementara dahulu supaya file manifest lama tidak terpotong jika gagal.
	var temporary_manifest = BUNDLED_MANIFEST + ".tmp"
	var file = File.new()
	var open_err = file.open(temporary_manifest, File.WRITE)
	if open_err != OK:
		return "Gagal membuat manifest sementara (error %d)." % open_err
	file.store_string(JSON.print({"targets": manifest}, "\t"))
	file.close()

	# Godot 3 Directory.rename mengganti nama file; hapus manifest lama terlebih dahulu
	# untuk kompatibilitas lintas platform, lalu rename file sementara.
	if dir.file_exists(BUNDLED_MANIFEST):
		var remove_manifest_err = dir.remove(BUNDLED_MANIFEST)
		if remove_manifest_err != OK:
			dir.remove(temporary_manifest)
			return "Gagal mengganti manifest.json (error %d)." % remove_manifest_err
	var rename_err = dir.rename(temporary_manifest, BUNDLED_MANIFEST)
	if rename_err != OK:
		return "Gagal menyelesaikan manifest.json (error %d)." % rename_err
	return ""


static func estimate_keypoints(image):
	# Estimasi tekstur berbasis varians Laplacian; bukan jumlah ORB sesungguhnya.
	if image == null or image.get_width() < 8 or image.get_height() < 8:
		return 0

	var was_locked = image.is_locked()
	if not was_locked:
		image.lock()
	var width = image.get_width()
	var height = image.get_height()
	var sample_width = min(width - 1, 60)
	var sample_height = min(height - 1, 60)
	var origin_x = int((width - sample_width) / 2)
	var origin_y = int((height - sample_height) / 2)
	var total = 0.0
	var total_squared = 0.0
	var count = 0

	for y in range(origin_y + 1, origin_y + sample_height - 1):
		for x in range(origin_x + 1, origin_x + sample_width - 1):
			var center = image.get_pixel(x, y).r * 255.0
			var laplacian = (image.get_pixel(x - 1, y).r + image.get_pixel(x + 1, y).r + image.get_pixel(x, y - 1).r + image.get_pixel(x, y + 1).r) * 255.0 - 4.0 * center
			total += laplacian
			total_squared += laplacian * laplacian
			count += 1

	if not was_locked:
		image.unlock()
	if count <= 0:
		return 0

	var mean = total / float(count)
	var variance = max(0.0, total_squared / float(count) - mean * mean)
	return int(clamp(variance / 40.0, 0.0, 5000.0))
