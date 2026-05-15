#ifndef DRAWING_UTILS_H
#define DRAWING_UTILS_H

#include <opencv2/opencv.hpp>
#include <string>
#include <vector>

namespace DrawColors {
const cv::Scalar kDimLine(140, 80, 10);
const cv::Scalar kDimText(180, 60, 0);
const cv::Scalar kRadiusLine(60, 140, 30);
const cv::Scalar kRadiusText(40, 130, 20);
const cv::Scalar kAngleLine(20, 120, 220);
const cv::Scalar kAngleText(10, 100, 200);
const cv::Scalar kOutlineStraight(30, 30, 30);
const cv::Scalar kOutlineArc(160, 80, 20);
const cv::Scalar kHoleOutline(100, 100, 100);
const cv::Scalar kCenterLine(180, 180, 180);
const cv::Scalar kFrameBorder(60, 60, 60);
const cv::Scalar kFrameText(80, 80, 80);
const cv::Scalar kGridLine(235, 235, 235);
const cv::Scalar kTextBg(255, 255, 255);
const cv::Scalar kTextBgAlpha(245, 248, 252);
} // namespace DrawColors

void drawDimensionLine(cv::Mat &img, cv::Point2f p1, cv::Point2f p2,
                       float realValue, int offsetDirection);

void drawAngleDimension(cv::Mat &img, cv::Point2f center, cv::Point2f p1,
                        cv::Point2f p2, float angleDeg);

void drawCircleDimension(cv::Mat &img, cv::Point2f center, float radiusPx,
                         float radiusMm);

void drawDiameterDimension(cv::Mat &img, cv::Point2f center, float radiusPx,
                           float diameterMm);

void drawSlotDimension(cv::Mat &img, cv::Point2f center, float widthMm,
                       float lengthMm, float angleDeg);

void drawSlotContour(cv::Mat &img, cv::Point2f center, float widthPx,
                     float lengthPx, float angleDeg);

void drawCenterLines(cv::Mat &img, cv::Point2f center, float radiusPx);

class LabelManager {
public:
  static LabelManager &getInstance() {
    static LabelManager instance;
    return instance;
  }

  void clear() {
    occupied.clear();
    piece_polygons.clear();
  }

  void addRect(const cv::Rect &r) { occupied.push_back(r); }

  void addPiecePolygon(const std::vector<cv::Point> &poly) {
    piece_polygons.push_back(poly);
  }

  bool overlaps(const cv::Rect &r) const {
    for (const auto &o : occupied) {
      if ((o & r).area() > 0) {
        return true;
      }
    }

    for (const auto &p : piece_polygons) {
      cv::Point corners[4] = {
          {r.x, r.y},
          {r.x + r.width, r.y},
          {r.x, r.y + r.height},
          {r.x + r.width, r.y + r.height},
      };
      for (int i = 0; i < 4; ++i) {
        if (cv::pointPolygonTest(p, corners[i], false) >= 0) {
          return true;
        }
      }
    }

    return false;
  }

  cv::Point2f getClearPos(cv::Point2f preferred, cv::Size sz, float pad);

private:
  LabelManager() = default;

  std::vector<cv::Rect> occupied;
  std::vector<std::vector<cv::Point>> piece_polygons;
};

void drawTechnicalFrame(cv::Mat &img, float mmPerPx, int edgeCount,
                        int holeCount, int arcCount);

void drawReferenceGrid(cv::Mat &img, float mmPerPx);

#endif // DRAWING_UTILS_H
