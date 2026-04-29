#ifndef DRAWING_UTILS_H
#define DRAWING_UTILS_H

#include <opencv2/opencv.hpp>

void drawDimensionLine(cv::Mat& img, cv::Point2f p1, cv::Point2f p2, float realValue, int offsetDirection);
void drawAngleDimension(cv::Mat& img, cv::Point2f center, cv::Point2f p1, cv::Point2f p2, float angleDeg);
void drawCircleDimension(cv::Mat& img, cv::Point2f center, float radiusPx, float radiusMm);

#endif  // DRAWING_UTILS_H
