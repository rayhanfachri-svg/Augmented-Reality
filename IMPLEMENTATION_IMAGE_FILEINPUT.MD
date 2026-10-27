# IMPLEMENTATION_IMAGE_FILEINPUT — S1 Input Target dari File (Laptop Dev)

> Berlaku: Godot 3.6.3, GDNative `.so` yang sama (TANPA rebuild utk MVP).
> Aturan repo: `.tscn` HANYA manual di editor — file ini berisi INSTRUKSI,
> bukan `.tscn` jadi. `.gd`/`.json` boleh via kode (sudah dibuatkan:
> `demo/try2/ScanInput.gd`, `import_file()` di `ar_image_library.gd`).
> Jalur ArUco (`ar.gd`, `ar_marker_spawner.gd`, `own_opencv_processing.*`,
> `gd_opencv.*`) NOL perubahan — jangan sentuh.

## 0. Ringkasan alur (dev-only, tidak ikut APK)

```
ScanInput.tscn (Run di laptop)
  [Pilih File] -> FileDialog OS (*.png;*.jpg;*.jpeg;*.bmp;*.webp)
  -> Preview TextureRect + prefill Nama
  [Simpan] -> ARImageLibrary.import_file(path, nama, lebar_m)
  -> user://targets/<nama>.png + user://targets/index.json
  [Export ke Bundle] -> res://targets/<nama>.png + res://targets/manifest.json
```

## 1. Lengkapi `demo/try2/ScanInput.tscn` MANUAL di editor (wajib)

Scene stub saat ini hanya `Control + Preview`. Tambahkan node berikut
(nama HARUS persis — `ScanInput.gd` mencari pakai `get_node_or_null`):

1. Buka `demo/try2/ScanInput.tscn` di editor Godot 3.6.3.
2. Pilih root `Control` -> Attach Script -> pilih `demo/try2/ScanInput.gd`.
3. Tambah node anak (Add Child Node), susunan bebas (VBoxContainer disarankan):
   - `Preview` (SUDAH ADA, TextureRect, `expand = true`) — biarkan.
   - `PickButton` (Button, text = "Pilih File...").
   - `NameEdit` (LineEdit, placeholder = "nama_target (huruf/angka/_/-)").
   - `WidthSpin` (SpinBox, min=5, max=50, step=0.5, value=20,
     suffix = " cm", tooltip = "Lebar fisik cetakan, ukur pakai penggaris").
   - `SaveButton` (Button, text = "Simpan Target").
   - `ExportButton` (Button, text = "Export ke Bundle").
   - `StatusLabel` (Label, text = "status", autowrap = on).
   - `FileDialog` (FileDialog) — tanpa setup manual; mode/filter/diisi
     otomatis oleh `ScanInput.gd::_setup_filedialog()` saat Run.
   - `ARImageLibrary` (Node + script `res://global/ar_image_library.gd`).
     Opsional: script otomatis membuat bila belum ada, tapi pasang manual
     lebih rapi (sinyal `library_changed` terlihat di editor).
4. TIDAK perlu konek sinyal manual di editor — semua dikonek via kode
   (`pressed`, `file_selected`). Save scene (Ctrl+S).
5. Verifikasi: Scene -> Reload, pastikan tidak ada ikon error script.

## 2. Cara pakai (Run di laptop)

1. Main Scene = `demo/try2/ScanInput.tscn` -> Run (F5).
2. Klik `Pilih File...` -> pilih `jpg/png/jpeg/bmp/webp` master resolusi penuh.
   Preview tampil + Nama terprefill dari nama file.
3. Isi Nama unik (`poster_kopi`) + Lebar cm hasil ukur penggaris (mis. 20).
4. Klik `Simpan Target`:
   - `OK tersimpan` -> lanjut file berikut.
   - `DITOLAK: terlalu polos (N keypoint...)` -> GANTI gambar bertekstur.
     Jangan naikkan threshold — gambar polos tak akan bisa di-track ORB.
5. Klik `Export ke Bundle` setelah semua target masuk.
6. Cek: `demo/targets/<nama>.png` ada + `manifest.json` bertambah.
7. `git add demo/targets demo/try2/ScanInput.gd demo/global/ar_image_library.gd`.

## 3. Mode pengembang: user TIDAK bisa tambah gambar

Tidak ada sistem login di Godot — proteksi = scene dev tidak ikut APK:

1. Project -> Export -> Android preset -> tab Resources -> Filters:
   - Exclude: `demo/try2/ScanInput.tscn`, `demo/try2/ScanInput.gd`,
     `demo/Library.tscn` (bila nanti dibuat).
   - Include (wajib ikut): `demo/targets/*`, `demo/models/*`.
2. `ScanOutput.tscn` (rilis) HANYA baca bundle `res://targets/manifest.json`.
   Dev-work `user://` otomatis kosong di install baru — benar begitu.
3. Helper GDScript: `ARImageLibrary.is_dev_build()` (true di editor/debug,
   false di APK rilis) — pakai untuk sembunyikan tombol dev bila suatu
   scene dipakai ganda.
4. Jangan pernah panggil `import_file()` / `add_target()` dari scene rilis.

## 4. Catatan format file

- Input S1 menerima: `png, jpg, jpeg, bmp, webp`
  (`Image.load` Godot 3.6 + `cv::imread` C++ dua-duanya bisa).
- Yang disimpan SELALU `.png` (`user://targets/<nama>.png`,
  lalu `res://targets/<nama>.png`) — matcher C++ baca via `imread`
  grayscale, jadi format simpan diseragamkan png.
- Estimator S1 = ORB C++ asli (Fase 2, `.so` sudah rebuild):
  `ARImageLibrary.add_target()` menyimpan png dulu, lalu memanggil
  `GDImageDetector.probe_keypoints()` (read-only, tanpa masuk DB, tanpa
  kamera jalan). Bila probe sukses, angka ORB dipakai utk keputusan
  terima/tolak (`DITOLAK (ORB): ...`, file png dihapus bila ditolak);
  bila `.so` lama/backend tak ada (return -1), fallback ke Laplacian GDScript.
  Angka probe IDENTIK dgn log `[IMG] target '<nama>' dimuat (N kp)` karena
  pipeline-nya sama persis (`loadGray -> preprocess -> ORB(750)`).
  Uji threshold: tekstur acak 750 kp = LOLOS, abu polos 0 kp = DITOLAK.

## 5. Troubleshooting

| Gejala | Sebab & obat |
|---|---|
| `FileDialog belum ada` | §1 belum dikerjakan — tambah node `FileDialog` bernama persis itu. |
| `Pilih file gambar dulu` | Klik Pilih File dulu sebelum Simpan; `_picked_path` kosong. |
| `Ekstensi tak didukung` | File `.tiff/.heic/.pdf` — convert dulu ke jpg/png. |
| `Gagal baca gambar` | File rusak / path non-ASCII bermasalah — coba copy ke path sederhana. |
| Manifest placeholder `contoh_poster` gagal load | File png-nya memang tidak ada di repo — kosongkan `targets: []` atau timpa via Export setelah import real pertama. |
| ArUco ikut rusak | STOP. `git status`: `ar.gd`, `ar_marker_spawner.gd`, `own_opencv_processing.*`, `gd_opencv.*` harus NOL diff. |
