#include <opencv2/opencv.hpp>
#include <opencv2/objdetect.hpp>
#include <opencv2/aruco/charuco.hpp>
#include <iostream>

int main() {
    cv::aruco::Dictionary dictionary = cv::aruco::getPredefinedDictionary(cv::aruco::DICT_4X4_250);
    cv::aruco::CharucoBoard board(cv::Size(18, 12), 15.0f, 11.0f, dictionary);
    cv::Mat img;
    // test if generateImage works
    board.generateImage(cv::Size(18*10, 12*10), img, 0, 1);
    std::cout << "Generated image: " << img.cols << "x" << img.rows << std::endl;
    return 0;
}
