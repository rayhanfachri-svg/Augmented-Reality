
#include "own_opencv_processing.h"

#include <opencv2/opencv.hpp>

#include <Godot.hpp>

#include <string>

// OpenCV 4.7.0+ / 5.x: ArUco API changed to class-based (ArucoDetector).
// OpenCV 4.6.x: uses old Ptr-based free-function API.
// estimatePoseSingleMarkers was removed in 4.7.0+; replaced by manual solvePnP.

// Constructor
OpenCVProcessing::OpenCVProcessing()
{
#if CV_MAJOR_VERSION >= 5 || (CV_MAJOR_VERSION == 4 && CV_MINOR_VERSION >= 7)
    // --- New API (OpenCV 4.7.0+ / 5.x) ---
    dictionary =
        cv::aruco::getPredefinedDictionary(cv::aruco::DICT_4X4_50);

    // DetectorParameters is now a struct (not a Ptr-wrapped class);
    // use default constructor instead of the removed ::create().
    detector_params = cv::aruco::DetectorParameters();
    detector_params.cornerRefinementMethod = cv::aruco::CORNER_REFINE_SUBPIX;

    // Build the ArucoDetector once and reuse it every frame.
    aruco_detector = cv::aruco::ArucoDetector(dictionary, detector_params);
#else
    // --- Old API (OpenCV 4.6.x and earlier) ---
    dictionary =
        cv::aruco::getPredefinedDictionary(cv::aruco::DICT_4X4_50);

    // Cache sekali saja (jangan create() tiap frame).
    detector_params = cv::aruco::DetectorParameters::create();
    detector_params->cornerRefinementMethod = cv::aruco::CORNER_REFINE_SUBPIX;
#endif

    dist_coeffs = cv::Mat::zeros(5, 1, CV_64F);

    // --- LOG: Cek backend kamera OpenCV di ponsel ---
    godot::Godot::print("[AR] Checking OpenCV camera backends:");
    for (auto b : cv::videoio_registry::getCameraBackends())
    {
        std::string name = cv::videoio_registry::getBackendName(b);
        if (!name.empty())
        {
            godot::Godot::print(String("[AR] backend kamera OpenCV: ") + String(name.c_str()));
        }
    }
    // --- AKHIR LOG ---

    godot::Godot::print(
        "[AR] OpenCVProcessing berhasil dibuat."
    );

    godot::Godot::print(
        "[AR] Dictionary ArUco DICT_4X4_50 siap digunakan."
    );
}

// Atur apakah overlay (border/ID/axes) digambar pada frame output.
// Deteksi tetap berjalan bila do_detect=true. Dipisahkan agar model 3D
// bisa muncul tanpa overlay visual mengganggu di produksi.
void OpenCVProcessing::set_draw_debug(bool draw)
{
    draw_debug = draw;
}

// Matriks kamera perkiraan, mengikuti resolusi aktual frame.
// fx = fy = 0.9 * width, cx = width/2, cy = height/2.
void OpenCVProcessing::ensure_camera_matrix(int width, int height)
{
    if (width <= 0 || height <= 0)
        return;

    if (width == calib_width && height == calib_height && !camera_matrix.empty())
        return;

    const double fx = 0.9 * static_cast<double>(width);
    const double fy = 0.9 * static_cast<double>(width);
    const double cx = static_cast<double>(width) * 0.5;
    const double cy = static_cast<double>(height) * 0.5;

    camera_matrix = (cv::Mat_<double>(3, 3) <<
        fx, 0.0, cx,
        0.0, fy, cy,
        0.0, 0.0, 1.0);

    calib_width = width;
    calib_height = height;
}


void OpenCVProcessing::set_marker_length(float meters)
{
    if (meters > 0.0f)
        marker_length_m = meters;
}


// Destructor
OpenCVProcessing::~OpenCVProcessing()
{
    godot::Godot::print(
        "[AR] OpenCVProcessing dihentikan."
    );
}

// Fungsi pemrosesan gambar
// do_detect: apakah marker dideteksi + pose diestimasi (selalu dijalankan bila true)
// draw_debug: apakah overlay border/ID/axes digambar pada output (hanya untuk visual)
cv::Mat OpenCVProcessing::process_image(
    cv::Mat input,
    bool do_detect,
    bool draw_debug
)
{
    // Pastikan input gambar valid.
    if (input.empty())
    {
        static bool warned_empty_image = false;

        if (!warned_empty_image)
        {
            godot::Godot::print(
                "[AR] PERINGATAN: Gambar input kosong."
            );

            warned_empty_image = true;
        }

        return input;
    }

    // Salin gambar asli agar hasil anotasi tidak mengubah input.
    cv::Mat output = input.clone();

    // Status diagnostik untuk menghindari spam Output.
    static bool warned_processing_disabled = false;
    static bool processing_started = false;
    static bool previous_marker_found = false;

    // Jika deteksi dimatikan, bersihkan cache pose + kembalikan frame mentah
    // (tanpa overlay). draw_debug tetap dihormati pada frame berikutnya.
    if (!do_detect)
    {
        if (!warned_processing_disabled)
        {
            godot::Godot::print(
                "[AR] PEMROSESAN NONAKTIF: do_detect = false."
            );

            godot::Godot::print(
                "[AR] Periksa nilai do_detect (show_processed) di GDScript."
            );

            warned_processing_disabled = true;
        }

        processing_started = false;
        previous_marker_found = false;

        last_ids.clear();
        last_rvecs.clear();
        last_tvecs.clear();

        return output;
    }

    // Cetak pesan hanya ketika pemrosesan mulai aktif.
    if (!processing_started)
    {
        godot::Godot::print(
            "[AR] Pemrosesan aktif. Siap menerima ArUco Marker."
        );

        processing_started = true;
        warned_processing_disabled = false;
    }

    // Siapkan wadah hasil deteksi.
    std::vector<int> markerIds;

    std::vector<std::vector<cv::Point2f>> markerCorners;
    std::vector<std::vector<cv::Point2f>> rejectedCandidates;

#if CV_MAJOR_VERSION >= 5 || (CV_MAJOR_VERSION == 4 && CV_MINOR_VERSION >= 7)
    // --- New API (OpenCV 4.7.0+ / 5.x): detect via ArucoDetector member ---
    aruco_detector.detectMarkers(
        input,
        markerCorners,
        markerIds,
        rejectedCandidates
    );
#else
    // --- Old API (OpenCV 4.6.x): free-function detectMarkers ---
    cv::Ptr<cv::aruco::DetectorParameters> parameters = detector_params;
    cv::aruco::detectMarkers(
        input,
        dictionary,
        markerCorners,
        markerIds,
        parameters,
        rejectedCandidates
    );
#endif

    // Periksa apakah ada marker yang terdeteksi.
    const bool marker_found = !markerIds.empty();

    // Selalu segarkan cache pose frame terakhir agar Godot bisa
    // menyembunyikan objek saat marker hilang.
    last_ids = markerIds;
    last_rvecs.clear();
    last_tvecs.clear();

    if (marker_found)
    {
        ensure_camera_matrix(input.cols, input.rows);

        std::vector<cv::Vec3d> rvecs, tvecs;
#if CV_MAJOR_VERSION >= 5 || (CV_MAJOR_VERSION == 4 && CV_MINOR_VERSION >= 7)
        // OpenCV 4.7.0+ / 5.x: cv::aruco::estimatePoseSingleMarkers was REMOVED.
        // Replicate its behaviour with cv::solvePnP per detected marker:
        //   - build 3D object points for a square marker (centered at origin, Z=0)
        //   - call solvePnP for each marker using its 4 detected 2D corners
        {
            const float halfSize = marker_length_m * 0.5f;
            std::vector<cv::Point3f> objPts;
            objPts.reserve(4);
            objPts.push_back(cv::Point3f(-halfSize,  halfSize, 0));  // top-left
            objPts.push_back(cv::Point3f( halfSize,  halfSize, 0));  // top-right
            objPts.push_back(cv::Point3f( halfSize, -halfSize, 0));  // bottom-right
            objPts.push_back(cv::Point3f(-halfSize, -halfSize, 0));  // bottom-left

            rvecs.reserve(markerCorners.size());
            tvecs.reserve(markerCorners.size());

            for (size_t i = 0; i < markerCorners.size(); ++i)
            {
                cv::Vec3d rvec, tvec;
                cv::solvePnP(objPts, markerCorners[i],
                             camera_matrix, dist_coeffs, rvec, tvec);
                rvecs.push_back(rvec);
                tvecs.push_back(tvec);
            }
        }
#else
        // OpenCV 4.6.x: estimatePoseSingleMarkers free function still available
        cv::aruco::estimatePoseSingleMarkers(
            markerCorners,
            marker_length_m,
            camera_matrix,
            dist_coeffs,
            rvecs,
            tvecs
        );
#endif

        last_rvecs = rvecs;
        last_tvecs = tvecs;

        // Gambar overlay (border + ID + sumbu) HANYA bila diminta (debug visual).
        // Deteksi + pose tetap dihitung di atas — tidak tergantung draw_debug.
        if (draw_debug)
        {
            // Gambar garis batas dan ID marker pada output.
            cv::aruco::drawDetectedMarkers(
                output,
                markerCorners,
                markerIds
            );

            // Gambar sumbu pose 3D (bukti visual estimasi pose jalan).
            // OpenCV 4.6: pakai cv::drawFrameAxes (aruco::drawAxis belum ada).
            for (size_t i = 0; i < markerIds.size(); ++i)
            {
                cv::drawFrameAxes(
                    output,
                    camera_matrix,
                    dist_coeffs,
                    rvecs[i],
                    tvecs[i],
                    marker_length_m * 0.5f
                );
            }
        }

        // Cetak ID hanya ketika marker baru terdeteksi
        // atau ketika kumpulan ID marker berubah.
        static std::string previous_marker_ids = "";

        std::string current_marker_ids;

        for (size_t i = 0; i < markerIds.size(); ++i)
        {
            if (i > 0)
            {
                current_marker_ids += ", ";
            }

            current_marker_ids += std::to_string(markerIds[i]);
        }

        if (!previous_marker_found ||
            current_marker_ids != previous_marker_ids)
        {
            godot::Godot::print(
                godot::String("[AR] MARKER TERDETEKSI! ID: ")
                + godot::String(current_marker_ids.c_str())
            );
        }

        previous_marker_ids = current_marker_ids;
    }
    else
    {
        // Cetak pesan ketika marker yang sebelumnya ditemukan
        // sudah tidak terlihat lagi.
        if (previous_marker_found)
        {
            godot::Godot::print(
                "[AR] Marker hilang. Menunggu marker berikutnya..."
            );
        }
    }

    previous_marker_found = marker_found;

    return output;
}