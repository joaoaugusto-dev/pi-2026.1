#include <opencv2/opencv.hpp>
#include <opencv2/objdetect.hpp>
void test(cv::aruco::CharucoBoard& board, cv::Mat& expected_board) {
    board.generateImage(cv::Size(100, 100), expected_board, 0, 1);
}
