------------------------------------------------------------------------

## 1. Catatan pekerjaan yang sudah dilakukan

-   [x] Memeriksakan lingkungan Java. Java 11 tersedia dan sudah dipilih
    untuk terminal saat ini:
    -   `JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64`
    -   Versi yang teruji: OpenJDK `11.0.32.1`
    -   **Catatan:** konfigurasi ini baru dilakukan melalui `export`;
        belum dipastikan permanen untuk terminal baru.
-   [x] Memeriksakan Android SDK:
    -   Lokasi: `/home/linuxlite/Android/Sdk`
    -   Platform Android yang tersedia mencakup `android-29` sampai
        `android-36`.
    -   Build-tools: `30.0.3`, `35.0.0`, `36.1.0` (plus `33.0.0` per panduan).
-   [x] Memeriksakan Android NDK:
    -   Lokasi NDK: `/home/linuxlite/Android/Sdk/ndk/23.2.8568313`
    -   Revision: `23.2.8568313` — toolchain `aarch64-linux-android21-clang++` tersedia ✅
-   [x] Mengunduh OpenCV Android SDK 5.0.0 dan menemukan foldernya:
    -   `/home/linuxlite/Development/OpenCV-android-sdk` (5.0.0, cadangan)
-   [x] Memastikan SDK OpenCV 5.0.0 memiliki library statis untuk
    `arm64-v8a` di `sdk/native/staticlibs/arm64-v8a/`.
-   [x] Memastikan library pihak ketiga tersedia di:
    -   `sdk/native/3rdparty/libs/arm64-v8a/` (5.0.0)
-   [x] Memeriksan header OpenCV 5.0.0:
    -   Header `opencv.hpp`, `calib3d.hpp`, `features2d.hpp`,
        `imgcodecs.hpp`, `imgproc.hpp` tersedia.
    -   Header lama `opencv2/aruco.hpp` tidak ditemukan.
    -   Header ArUco di `opencv2/objdetect/`: `aruco_detector.hpp`,
        `aruco_dictionary.hpp`, `aruco_board.hpp`, `charuco_detector.hpp`.
-   [x] Memeriksan kode proyek dan menemukan penggunaan
    `opencv2/aruco.hpp` serta modul `calib3d`, `features2d`,
    `imgcodecs`, dan `imgproc`.
-   [x] **Audit API OpenCV (Tahap 1) selesai:**

    **API ArUco lama** (butuh kode lama, hanya di desktop 4.6.0):
    -   `cv::aruco::getPredefinedDictionary()` — kembalikan `Ptr<Dictionary>`
    -   `cv::aruco::DetectorParameters::create()` — metode statik
    -   `cv::Ptr<cv::aruco::Dictionary>`, `Ptr<DetectorParameters>` — pointer
    -   `cv::aruco::detectMarkers()` (free function)
    -   `cv::aruco::estimatePoseSingleMarkers()` — **dihapus di 4.7.0/5.0.0**

    **API ArUco baru** (di Android SDK 4.7.0 & 5.0.0):
    -   Header: `opencv2/objdetect/aruco_detector.hpp`, `aruco_dictionary.hpp`, `aruco_board.hpp`
    -   `cv::aruco::getPredefinedDictionary()` — kembalikan `Dictionary` (value type)
    -   `cv::aruco::DetectorParameters()` — struct biasa
    -   `cv::aruco::ArucoDetector` class — untuk `detectMarkers()`
    -   `cv::aruco::drawDetectedMarkers()` — **tetap tersedia**
    -   `cv::aruco::CORNER_REFINE_SUBPIX` — enum tetap tersedia
-   [x] **API non-ArUco** (semua kompatibel dengan 4.7.0/5.0.0):
    -   `cv::VideoCapture`, `cv::Mat`, `cv::cvtColor`, `cv::resize`,
        `cv::equalizeHist`, `cv::GaussianBlur`, `cv::imread`,
        `cv::FileStorage`, `cv::FileNode`, `cv::ORB::create`,
        `cv::Ptr`, `cv::KeyPoint`, `cv::Vec3d`, `cv::Point2f`,
        `cv::Point3f`, `cv::Scalar`, `cv::BFMatcher`, `NORM_HAMMING`,
        `cv::DMatch`, `cv::findHomography`, `cv::solvePnP`,
        `cv::perspectiveTransform`, `cv::polylines`,
        `cv::getTickCount`, `cv::getTickFrequency`, `cv::Mat::zeros`
-   [x] Mengunduh OpenCV Android SDK **4.7.0** dan menemukan foldernya:
    -   `/home/linuxlite/Development/OpenCV-android-sdk 4.7.0`
-   [x] Memastikan SDK OpenCV 4.7.0 memiliki library statis untuk
    `arm64-v8a` di `sdk/native/staticlibs/arm64-v8a/`.
-   [x] Memastikan library pihak ketiga tersedia di:
    -   `sdk/native/3rdparty/libs/arm64-v8a/` (4.7.0)
-   [x] Memeriksan header OpenCV 4.7.0:
    -   Header `opencv.hpp`, `calib3d.hpp`, `features2d.hpp`,
        `imgcodecs.hpp`, `imgproc.hpp` tersedia
    -   Header lama `opencv2/aruco.hpp` **tidak ditemukan**
    -   Header ArUco di `opencv2/objdetect/`, termasuk `aruco_detector.hpp`,
        `aruco_dictionary.hpp`, `aruco_board.hpp`, dan
        `charuco_detector.hpp`
-   [x] Memastikan library statis OpenCV 4.7.0 untuk `arm64-v8a`:
    -   `libopencv_calib3d.a`, `libopencv_features2d.a`,
        `libopencv_aruco.a`, `libopencv_objdetect.a` — **nama format 4.x**
    -   Berbeda dengan 5.0.0 yang memakai `libopencv_calib.a`,
        `libopencv_features.a` (tanpa `aruco.a`)
-   [x] Membangun library `godot-cpp` untuk Android (Tahap 5):
    -   `scons platform=android android_arch=arm64v8 target=release -j$(nproc)`
    -   Output: `godot-cpp/bin/libgodot-cpp.android.release.64.a` ✅
-   [x] Menyetel `OPENCV_ANDROID_SDK` untuk terminal saat ini:
    -   `OPENCV_ANDROID_SDK="/home/linuxlite/Development/OpenCV-android-sdk 4.7.0"`
    -   **Catatan:** belum dipastikan permanen di `~/.bashrc`.
-   [x] **Build Android debug berhasil** (Tahap 6 & 7):
    -   `scons platform=android android_abi=arm64-v8a target=debug`
    -   Output: `demo/bin/android/arm64-v8a/libgdopencvexample.so` ✅
    -   Symbol verifikasi (`nm -D`): `ArucoDetector`, `solvePnP`,
        `getPredefinedDictionary` ada di `.so` ✅
    -   **Catatan:** build `release` belum — diperlukan untuk APK lebih kecil.
-   [x] **Build desktop berhasil:**
    -   `scons platform=x11 target=debug` (OpenCV 4.6.0 desktop)
    -   Output: `demo/bin/x11/libgdopencvexample.so` ✅
-   [x] **Adaptasi kode ArUco ke dual API:**
    -   `own_opencv_processing.h`: conditional include + conditional member types ✅
    -   `own_opencv_processing.cpp`: conditional constructor, `detectMarkers` via
        `ArucoDetector`, manual `solvePnP` mengganti `estimatePoseSingleMarkers` ✅
-   [x] **Perbaikan bug di `SConstruct` (Tahap 4):**
    1.  Path `3rdparty`: `3rdparty/arm64-v8a/` → `3rdparty/libs/arm64-v8a/`
    2.  `ocv_paths`: 3rdparty pakai `thirdparty_dir`, bukan `staticlib_dir`
    3.  OpenCV include path: ditambah `ocv_native + '/jni/include'` ke `CPPPATH`
    4.  godot-cpp library: hapus append duplikat, tambah `cpp_lib_overridden` guard

------------------------------------------------------------------------

## 2. Tahap berikutnya: pastikan versi OpenCV yang cocok

### Tahap 1 --- Audit kebutuhan API dari kode proyek

-   [x] **Selesai** — seluruh pemakaian API OpenCV dalam `src/` diperiksa.
-   [x] **Selesai** — fungsi ArUco yang dipanggil dicatat (lihat §1 di atas).
-   [x] **Selesai** — fungsi modul lain (non-ArUco) dicatat (lihat §1 di atas).
-   [x] **Selesai** — kode bergantung pada API lama yang berubah di 5.0.0
    sudah diadaptasi ke API baru (dual API support).

### Tahap 2 --- Tentukan kandidat versi OpenCV

-   [x] **OpenCV 4.7.0** dipilih sebagai versi utama untuk Android —
    karena kode sudah diadaptasi dan build debug berhasil ✅
-   [x] **OpenCV 5.0.0** disimpan sebagai cadangan — belum dihapus ✅
-   [x] OpenCV 4.7.0 Android SDK memiliki header & library yang diperlukan,
    termasuk modul ArUco ✅

### Tahap 3 --- Unduh dan verifikasi SDK kandidat

-   [x] **Selesai** — SDK 4.7.0 diunduh & diekstrak ke folder terpisah ✅
-   [x] **Selesai** — versi diverifikasi dari `version.hpp` (4.7.0) ✅
-   [x] **Selesai** — semua header termasuk `aruco_detector.hpp` tersedia ✅
-   [x] **Selesai** — library statis untuk `arm64-v8a` tersedia ✅
-   [x] **Catatan lokasi:** `/home/linuxlite/Development/OpenCV-android-sdk 4.7.0`

### Tahap 4 --- Sesuaikan konfigurasi `SConstruct`

-   [x] **Selesai** — bagian Android `SConstruct` diperiksa & diperbaiki:
    -   Path `3rdparty` → `3rdparty/libs/arm64-v8a/` ✅
    -   `ocv_paths` memakai `thirdparty_dir` untuk 3rdparty ✅
    -   Include path → `sdk/native/jni/include` ✅
    -   Nama library OpenCV 4.7.0 vs 5.0.0 diverifikasi (`glob` dinamis) ✅

### Tahap 5 --- Periksa toolchain Android

-   [x] **Selesai** — `JAVA_HOME`, Android SDK, `ANDROID_NDK_HOME` ditemukan ✅
-   [x] **Selesai** — NDK `23.2.8568313` kompatibel (r23c–r26x didukung) ✅
-   [x] **Selesai** — Build-tools `30.0.3`, `35.0.0`, `36.1.0`, `33.0.0` tersedia ✅
-   [x] **Selesai** — `godot-cpp` Android lib sudah dibangun ✅
-   [ ] **Tugas untuk manusia:** Pastikan var env **permanen** di `~/.bashrc`

### Tahap 6 --- Validasi sebelum build penuh

-   [x] **Selesai** — `OPENCV_ANDROID_SDK` → 4.7.0 ✅
-   [x] **Selesai** — `scons platform=android -n` tidak error ✅
-   [x] **Selesai** — Build Android `arm64-v8a` berhasil (debug) ✅
-   [ ] **Tugas untuk manusia:** Jalankan build **release** untuk APK optimal:
    -   `scons platform=android android_abi=arm64-v8a target=release`

### Tahap 7 --- Verifikasi hasil build

-   [x] **Selesai** — `demo/bin/android/arm64-v8a/libgdopencvexample.so` ada ✅
-   [x] **Selesai** — `.gdnlib` menunjuk ke `.so` yang benar ✅
-   [x] **Selesai** — Symbol `ArucoDetector`, `solvePnP` ada di `.so` ✅
-   [x] **Selesai** — Build desktop juga berhasil (referensi) ✅

### Tahap 8 --- Export dan uji APK

-   [x] **[Manusia]** Pastikan Godot 3.6.x editor + export template terpasang ✅ versi
-   [ ] **[Manusia]** Build `release` selesai (lihat Tahap 6) [catatan manusia: masih ditargetkan membuat apk debug]
-   [ ] **[Manusia]** Export APK dari editor Godot
    -   `Project → Export → Android → Export Project`
-   [ ] **[Manusia]** Instal APK ke perangkat: `adb install -r "Godot CPP OpenCV.apk"`
-   [ ] **[Manusia]** Beri izin kamera di HP
-   [ ] **[Manusia]** Uji marker ArUco (cetak kertas, bukan layar):
    -   `adb logcat | grep -i godot`
    -   Harus ada: `[AR] OpenCVProcessing berhasil dibuat.` + `[AR] MARKER TERDETEKSI!`

------------------------------------------------------------------------

## 3. Kondisi saat ini

**Status:** ✅ Build .so Android berhasil (debug). **Siap untuk release build & export APK.**

Prioritas terdekat:

1.  **[Manusia]** Jalankan `scons platform=android target=release` untuk .so final.
2.  **[Manusia]** Export APK dari editor Godot 3.6.x.
3.  **[Manusia]** Instal APK ke HP & uji marker ArUco.
4.  **[AI]** Jika CV membuka kamera (Scenario B): implement `process_bytes()`
    di `gd_opencv.cpp` bila diperlukan.

OpenCV 5.0.0 **tidak dihapus** — tersedia sebagai cadangan.
Library file **tidak dipindah** — `OPENCV_ANDROID_SDK` mengarah ke 4.7.0 via env var.
Build Android **sudah berhasil** — `.so` mengandung simbol ArUco yang benar.