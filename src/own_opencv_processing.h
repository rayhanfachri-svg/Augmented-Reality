#ifndef OPENCVPROCESSING_H
#define OPENCVPROCESSING_H

#include <opencv2/imgproc.hpp>
#include <opencv2/opencv.hpp>
#include <vector>

// OpenCV 4.7.0+ and 5.x: ArUco moved to objdetect module with class-based API.
// OpenCV 4.6.x and earlier: ArUco is a standalone module with Ptr-based API.
// This macro selects the correct API at compile time.
#if CV_MAJOR_VERSION >= 5 || (CV_MAJOR_VERSION == 4 && CV_MINOR_VERSION >= 7)
    #include <opencv2/objdetect/aruco_detector.hpp>
#else
    #include <opencv2/aruco.hpp>
#endif

// Class untuk pemrosesan ArUco Marker menggunakan OpenCV
class OpenCVProcessing
{
    private:
#if CV_MAJOR_VERSION >= 5 || (CV_MAJOR_VERSION == 4 && CV_MINOR_VERSION >= 7)
        // New API (OpenCV 4.7.0+ / 5.x): value types + ArucoDetector class
        cv::aruco::Dictionary dictionary;
        cv::aruco::DetectorParameters detector_params;
        cv::aruco::ArucoDetector aruco_detector;
#else
        // Old API (OpenCV 4.6.x and earlier): Ptr-based wrapper
        cv::Ptr<cv::aruco::Dictionary> dictionary;
        cv::Ptr<cv::aruco::DetectorParameters> detector_params;
#endif

        cv::Mat camera_matrix;
        cv::Mat dist_coeffs;
        float marker_length_m = 0.05f; // sisi marker fisik (meter), default 5 cm
        bool draw_debug = false;      // true = gambar overlay border/ID/axes (untuk debug visual)
        int calib_width = 0;
        int calib_height = 0;

        void ensure_camera_matrix(int width, int height);

    public:
        // Hasil pose frame terakhir (diisi tiap process_image, dikosongkan saat hilang)
        std::vector<int> last_ids;
        std::vector<cv::Vec3d> last_rvecs;
        std::vector<cv::Vec3d> last_tvecs;

        OpenCVProcessing();
        ~OpenCVProcessing();

        void set_marker_length(float meters);
        void set_draw_debug(bool draw);

        // do_detect: deteksi marker + estimasi pose (selalu dijalankan bila true)
        // draw_debug: gambar overlay border/ID/sumbu pada output (independen dari deteksi)
        cv::Mat process_image(cv::Mat input, bool do_detect, bool draw_debug);
};

#endif