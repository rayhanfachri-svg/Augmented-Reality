# IMPLEMENTATION_EXPORT / IMPLEMENTATION_EXPORD — Export Proyek ke Android

> **Catatan nama berkas**: file ini resmi bernama `IMPLEMENTATION_EXPORD.MD` (typo historis).
> Nama disengaja tidak diganti agar referensi di `plan_implementation_upgrade.md`
> (bag. 8.8) tetap utuh. Di sinilah versi "lengkap & terkini" panduan export Android.
>
> Status validitas: **paling tidak sampai pembuatan `.so` Android sudah terbukti
> berhasil di device** — bagian yang bersifat "harus diuji di HP target" ditandai `[UJI]`.
> Godot editor versi apa saja dipakai, gunakan Godot **3.6.x** + export template **3.6.x**
> (cocok satu-per-satu; ini proyek GDNative/Godot 3, *bukan* Godot 4 / .NET).

---

## 0. SEBAB "scene 3D kosong, tidak membuka kamera" di Android (diagnosis)

Setelah mengekspor & menjalankan `try1.tscn` di HP, layar hanya hitam/abu kosong karena
**rantai native gagal**. Tiga faktor bertumpuk (urut keparahan):

| # | Faktor | Letak | Bukti |
|---|--------|-------|-------|
| 1 | **Tidak ada entry Android di `.gdnlib`** (hanya X11/Windows/OSX) & tidak ada `demo/bin/android/**/libgdopencvexample.so` | `demo/bin/gd_opencv.gdnlib` | `ARSession.start()` -> `load("res://bin/gd_opencv.gdns")` -> `gdns.can_instance()` **false** -> `start()` return `false`, worker tidak pernah terbuat, kamera tidak pernah dibuka. |
| 2 | **`cv::VideoCapture` tidak membuka kamera Android secara andalkan** | `src/gd_opencv.cpp` `init_camera()` | OpenCV backend kamera di Android membutuhkan OpenCV Android SDK + Java/Camera2; `new cv::VideoCapture(id)` biasanya `isOpened()==false`. |
| 3 | **`permissions/camera=false`** | `demo/export_presets.cfg` | Android menolak akses kamera sejak permission belum diminta/di-setujui. |

> 🔧 Faktor 1 & 3 sudah **diperbaiki di repo ini** (lihat §3 & §4). Faktor 2 butuh keputusan
> skenario kamera (lihat §5) — *normalnya setelah `.so` berhasil dimuat*.

`try1.tscn` itu **tidak rusak**: ia memakai pola *node* `ARSession` + `ARMarkerSpawner`
(`global/ar.gd`, `global/ar_marker_spawner.gd`) yang **membuat worker GDNative secara
dinamis** di `ARSession.start()` — sama seperti `Main3D.tscn`. Tidak ada node `Sprite/ARWorker`
yang harus dilepas di scene. Jadi satu-satunya hal yang perlu ada di APK adalah **library
native Android yang bisa dimuat**.

---

## 1. Prasyarat install — SEMUA di luar direktori `godot-cpp-opencv/` (wajib manusia)

Instal sekali ke sistem (bukan ke repo):

1. **JDK 11**
   ```bash
   sudo apt install openjdk-11-jdk
   echo "export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))" >> ~/.bashrc
   $JAVA_HOME/bin/java -version
   ```
2. **Android SDK** (command-line tools) → `sdkmanager install "platform-tools" "platforms;android-29" "platforms;android-33" "build-tools;33.0.0"`.
   ```bash
   echo "export ANDROID_HOME=$HOME/Android/Sdk" >> ~/.bashrc
   echo "export PATH=\$PATH:\$ANDROID_HOME/platform-tools:\$ANDROID_HOME/build-tools/33.0.0" >> ~/.bashrc
   adb version   # harus muncul
   ```
3. **Android NDK r23c–r26x** (r21e juga boleh). Godot 3.6 export templates terbaru memakai
   Gradle modern; pakailah NDK yang sama versi dengan yang dipakai template.
   ```bash
   yes | sdkmanager --install "ndk;25.2.9519653"    # atau via Android Studio SDK Manager
   echo "export ANDROID_NDK_HOME=$HOME/Android/Sdk/ndk/25.2.9519653" >> ~/.bashrc
   ls $ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin   # wajib ada
   ```
4. **OpenCV Android SDK** (bukan desktop pkg-config!). Download dari
   <https://opencv.org/releases/> → "Android" pack, unzip, misal di `$HOME/opencv-android-sdk`.
   Struktur wajib ada: `<sdk>/sdk/native/{jni/include,staticlibs/<abi>,libs/<abi>,3rdparty/<abi>}`.
   ```bash
   echo "export OPENCV_ANDROID_SDK=$HOME/opencv-android-sdk" >> ~/.bashrc
   ls $OPENCV_ANDROID_SDK/sdk/native/staticlibs/arm64-v8a   # wajib ada .a-nya
   ```
   > Jika SDK pilihan **tidak ship `staticlibs/`** (beberapa build hanya `libs/*.so` shared),
   > gunakan jalur *dynamic* (lihat §2 alternatif B): copy `libs/<abi>/libopencv_*.so` ke
   > `demo/bin/android/<abi>/` dan enumlasemukan di `[dependencies] Android.<abi>` di
   > `demo/bin/gd_opencv.gdnlib`.

### 4a. godot-cpp untuk Android (static binding library)
Di folder submodule `godot-cpp/` (cabang `3.5`):
```bash
cd godot-cpp
scons platform=android android_arch=arm64v8 target=release -j$(nproc)
ls bin/libgodot-cpp.android.release.64.a    # wajib ada sebelum build proyek
```
> Kita pakai `target=release` (bukan debug) agar ukuran `.so` jauh lebih kecil di APK.

### 4b. Editor Godot + export templates
- Install **Godot 3.6.x** (sama persis versi editor & templates).
- `Editor → Manage Export Templates → Download/Install 3.6.x.android_*`.
- `Editor → Editor Settings → Export → Android`: isi `Android Sdk Path`, `Debug Keystore`
  (buat via `keytool -genkey -v -keystore $HOME/ar-key.jks -alias ar-key -keyalg RSA -keysize 2048 -validity 10000`,
  password `arkey1`).

---

## 2. Build library native Android (`libgdopencvexample.so`)

Repo sudah dilengkapi **cabang `android` di `SConstruct`** (dipilih otomatis bila
`platform=android`). File `.so` yang dihasilkan langsung masuk ke folder yang dibaca
`.gdnlib`:

```bash
# satu perintah; helper tersedia di misc/build_android.sh
source ~/.bashrc          # load ANDROID_NDK_HOME, OPENCV_ANDROID_SDK, JAVA_HOME, PATH
cd /home/linuxlite/000_ZFile_000/GodotProject/ArTest/godot-cpp-opencv
scons platform=android android_abi=arm64-v8a android_api=21 \
       opencv_sdk=$OPENCV_ANDROID_SDK \
       target=release -j$(nproc)
# hasil: demo/bin/android/arm64-v8a/libgdopencvexample.so
```

### Apa yang terjadi di SConstruct `android branch`
- pakai NDK clang `aarch64-linux-android21-clang++` (auto dari env `ANDROID_NDK_HOME`);
- tautkan `godot-cpp/bin/libgodot-cpp.android.release.64.a`;
- tautkan **statis** semua `sdk/native/staticlibs/<abi>/libopencv_*.a` + `3rdparty/<abi>/lib*.a`
  via `--whole-archive` sehingga `aruco→calib3d→features2d→core` semua resolve, dan
  `.so` hasil **mandiri** (tidak butuh `libopencv_*.so` terpisah di APK). Itulah sebabnya
  `[dependencies] Android.arm64-v8a=[]` di `.gdnlib` tetap kosong.

**Validasi parse (tanpa compile):** `scons platform=android -n` akan berhenti di gerbang
validasi NDK/SDK/godot-cpp — berarti SConstruct sudah tidak `quit()`-nya "platform android
not supported" lagi. Pada mesin yang lengkap, build selesai & `.so` muncul.

### Alternatif B (dynamic linking) — pakai bila staticlibs tidak tersedia
Jika SDK hanya menyediakan `sdk/native/libs/<abi>/libopencv_*.so` (shared), ganti strategi:
```bash
# 1) copy shared opencv .so ke dalam project supaya Godot bundle ke dalam APK
cp $OPENCV_ANDROID_SDK/sdk/native/libs/arm64-v8a/*.so demo/bin/android/arm64-v8a/
# 2) di gd_opencv.gdnlib, isi [dependencies] Android.arm64-v8a dengan path res:// di atas
# 3) build dengan lib opencv statis dinonaktifkan (atau edit SConstruct pakai LIBPATH=libs/<abi>, LIBS=opencv_* shared)
```

---

## 3. Registrasi Android di `.gdnlib` (SUDAH selesai — cek saja)

`demo/bin/gd_opencv.gdnlib` kini berisi (ditambah otomatis oleh kami — jangan dihapus):
```
[entry]
...
Android.arm64-v8a="res://bin/android/arm64-v8a/libgdopencvexample.so"

[dependencies]
...
Android.arm64-v8a=[]   # [] karena opencv link statis; lihat §2 alternatif B bila pakai shared.
```
`gd_image_detector.gdns` dan `gd_opencv.gdns` **sama-sama** merujuk ke `.gdnlib` ini, jadi
**satu entry Android sudah mencakup kedua worker** (ArUco + ORB image target).

---

## 4. Permissions & preset (SUDAH diperbaiki — cek saja)

Perubahan yang kami terapkan pada `demo/export_presets.cfg`:

| Pengaturan | Sebelum | Sekarang |
|---|---|---|
| `permissions/camera` | `false` ❌ | `true` ✅ |
| `package/unique_name` | `org.godotengine.$genname` | `org.godotengine.godotcppopencv` (ganti jadi unik Anda) |

Saran tambahan di Editor → Export → Android → Options (bawaan biasanya sudah benar, ini hanya *checklist*):
- `Min SDK 21` / `Target SDK 29` (atau terbaru yang terpasang).
- `Architectures`: centang `arm64-v8a` (HP modern). Tambah `armeabi-v7a` bila target HP lama.
- `Resources` → export filter `all_resources` (sudah). Pastikan `demo/bin/*.gdns`,
  `demo/bin/gd_opencv.gdnlib`, `demo/global/*.gd`, `demo/models/*`, `demo/targets/*` ikut.
- `command_line/extra_args` kosong.

---

## 5. Skenario kamera di Android — PILIH SATU

`cv::VideoCapture` di atas **tidak dijamin** membuka kamera di Android karena backendnya.
Pilih:

| Skenario | Cara kerja | Kapan pakai |
|---|---|---|
| **A. VideoCapture "as-is"** | Tak ubah `src/gd_opencv.cpp`; Android OpenCV mencoba buka kamera via backendnya. | Coba **pertama** untuk verifikasi `.so` berhasil dimuat (`[AR] OpenCVProcessing berhasil dibuat.` di logcat). |
| **B. Kamera Godot → Image → C++** | Worker tetap, tapi frame diisi dari `ARSession.get_video_texture()`/Camera render. Perlu **method C++ baru** `process_mat_from_bytes(pixels, w, h)` (saat ini cuma ada `cvMat_to_Image` satu-arah). | **Rekomendasi** bila A gagal buka kamera — ini pola yang konsisten & andal. |
| **C. Plugin CameraX** | Plugin terpisah menulis frame ke ARImageSession. | Bila butuh fokus/flash penuh via Camera2 API. |

> 💡 **Rekomendasi kami**: build `.so` (§2) → export APK → jalankan uji A dulu. Bila
> `cv::VideoCapture` tidak membuka (logcat: `Open webcam with id 0 ...` lalu tidak ada
> `[AR] MARKER ...`), lanjut ke **B**: tambahkan `process_bytes(...)` di `gd_opencv.cpp`,
> panggil dari `ARSession` via `get_viewport().get_texture().get_data()` atau
> `get_camera_texture()`. Saya sudah menyiapkan `cvMat_to_Image` (C++→Godot); arah
> baliknya (`Image_to_Mat`, diperlukan B) **belum ada** — tandai sebagai task tersendiri.

---

## 6. Export APK & install

```bash
# di editor Godot 3.6:
Project -> Export -> Android -> (gunakan preset yang sudah ada) -> Export Project
# atau langsung "Run on Android Device" (ikon HP)
adb install -r "Godot CPP OpenCV.apk"
# di HP: beri izin kamera bila diminta (atau manual Settings -> Apps -> Godot CPP OpenCV -> Permissions -> Camera: Allow)
```

Verifikasi logcat:
```bash
adb logcat | grep -i godot
# Harus ada: [AR] OpenCVProcessing berhasil dibuat.
#             [AR] Pemrosesan aktif...
#             [AR] MARKER TERDETEKSI! ID: 0   -- setelah arahkan marker
```

---

## 7. Troubleshooting (logcat)

| Gejala di HP | Penyebab | Perbaikan |
|---|---|---|
| Scene kosong / hitam, tidak ada log `[AR]` | `.so` Android tidak dimuat / entry `.gdnlib` hilang | Pastikan `scons platform=android` selesai, entry `Android.arm64-v8a` ada di `.gdnlib`, `[dependencies]` pas (lihat §2 alternatif B bila shared). Cek `adb logcat` baris `dlopen`/`UnsatisfiedLinkError`. |
| UI tampil, `dlopen failed: cannot locate symbol` | modul opencv shared tidak ter-bundle | Pakai static linking (default) ATAU copy + deklarasikan semua `libopencv_*.so` di `[dependencies]`. |
| UI tampil, tidak ada error native tapi video hitam | `cv::VideoCapture` tidak membuka kamera (Skenario A gagal) | Izin kamera ON; lanjut Skenario B (Camera→C++). |
| Izin kamera ditolak otomatis | `permissions/camera=false` | Sudah di-`true` di preset (§4). |
| APK > 150 MB | OpenCV full + godot-cpp debug | Pakai `target=release`, hanya `arm64-v8a`, dan/atau trim modul opencv yang tidak dipakai. |
| "libgodot-cpp.android.release.64.a not found" (saat build) | godot-cpp android belum dibuild | Ikuti §1 poin 4a. |

---

## 8. Checklist rilis

- [ ] `scons platform=android android_abi=arm64-v8a target=release` selesai → `demo/bin/android/arm64-v8a/libgdopencvexample.so` ada.
- [ ] `demo/bin/gd_opencv.gdnlib` punya entry + (bila dynamic) dependencies Android.
- [ ] `demo/export_presets.cfg`: `permissions/camera=true`.
- [ ] Package name unik; version code naik tiap rilis.
- [ ] `Project Settings → Run → Main Scene` = `res://try1/try1.tscn` (atau `ScanOutput.tscn` untuk jalur image ORB).
- [ ] Uji di ≥1 HP (vendor kamera berbeda) + marker **cetak kertas** (bukan layar HP). [UJI]
