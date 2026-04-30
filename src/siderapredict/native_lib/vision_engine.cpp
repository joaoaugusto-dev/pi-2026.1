#include "drawing_utils.h"
#include <algorithm>
#include <cmath>
#include <fstream>
#include <iomanip>
#include <limits>
#include <opencv2/calib3d.hpp>
#include <opencv2/objdetect.hpp>
#include <opencv2/opencv.hpp>
#include <string>

namespace {

constexpr float kMarkerSquareMm = 10.0f;
constexpr float kWarpUpscale = 1.2f;
constexpr float kMinDisplayEdgeMm = 1.0f;
constexpr float kMinAngleDeviationDeg = 10.0f;
constexpr float kMinVertexAngleDeg = 30.0f;
constexpr size_t kMaxDisplayedEdges = 24U;
constexpr size_t kMaxDisplayedHoles = 6U;

struct MetricScale {
  float mm_per_px_x = 0.0f;
  float mm_per_px_y = 0.0f;
};

struct HoleCircle {
  cv::Point2f center;
  float radius_px = 0.0f;
  float score = 0.0f;
  // Arco parcial (ex: semicírculo): is_arc=true, ângulos em graus (conv.
  // OpenCV)
  bool is_arc = false;
  float arc_start_deg = 0.0f;
  float arc_end_deg = 360.0f;
};

cv::Point2f markerCenter(const std::vector<cv::Point2f> &corners) {
  cv::Point2f center(0.0f, 0.0f);
  for (const auto &p : corners) {
    center += p;
  }
  center *= (1.0f / static_cast<float>(corners.size()));
  return center;
}

std::array<cv::Point2f, 4>
orderCorners(const std::vector<cv::Point2f> &points) {
  std::array<cv::Point2f, 4> ordered{};

  double min_sum = std::numeric_limits<double>::max();
  double max_sum = std::numeric_limits<double>::lowest();
  double min_diff = std::numeric_limits<double>::max();
  double max_diff = std::numeric_limits<double>::lowest();

  for (const auto &p : points) {
    const double s = static_cast<double>(p.x + p.y);
    const double d = static_cast<double>(p.x - p.y);

    if (s < min_sum) {
      min_sum = s;
      ordered[0] = p; // TL
    }
    if (s > max_sum) {
      max_sum = s;
      ordered[2] = p; // BR
    }
    if (d > max_diff) {
      max_diff = d;
      ordered[1] = p; // TR
    }
    if (d < min_diff) {
      min_diff = d;
      ordered[3] = p; // BL
    }
  }

  return ordered;
}

bool hasRepeatedCorners(const std::array<cv::Point2f, 4> &corners) {
  constexpr float kMinDistance = 2.0f;
  for (size_t i = 0; i < corners.size(); ++i) {
    for (size_t j = i + 1; j < corners.size(); ++j) {
      if (cv::norm(corners[i] - corners[j]) < kMinDistance) {
        return true;
      }
    }
  }
  return false;
}

bool touchesBorder(const cv::Rect &bbox, int width, int height, int margin) {
  return bbox.x <= margin || bbox.y <= margin ||
         (bbox.x + bbox.width) >= (width - margin) ||
         (bbox.y + bbox.height) >= (height - margin);
}

float median(std::vector<float> values) {
  if (values.empty()) {
    return 0.0f;
  }
  std::sort(values.begin(), values.end());
  const size_t n = values.size();
  if ((n % 2U) == 0U) {
    return (values[(n / 2U) - 1U] + values[n / 2U]) * 0.5f;
  }
  return values[n / 2U];
}

float clampUnit(float value) { return std::max(-1.0f, std::min(1.0f, value)); }

float cross2d(const cv::Point2f &a, const cv::Point2f &b) {
  return (a.x * b.y) - (a.y * b.x);
}

float effectiveMmPerPx(const MetricScale &scale) {
  if (scale.mm_per_px_x <= 0.0f || scale.mm_per_px_y <= 0.0f) {
    return 0.0f;
  }
  return std::sqrt(scale.mm_per_px_x * scale.mm_per_px_y);
}

cv::Point2f toMetricPoint(const cv::Point2f &p, const MetricScale &scale) {
  return cv::Point2f(p.x * scale.mm_per_px_x, p.y * scale.mm_per_px_y);
}

float distanceMm(const cv::Point2f &p0, const cv::Point2f &p1,
                 const MetricScale &scale) {
  const cv::Point2f d = toMetricPoint(p1, scale) - toMetricPoint(p0, scale);
  return static_cast<float>(cv::norm(d));
}

float radiusMm(float radius_px, const MetricScale &scale) {
  return radius_px * effectiveMmPerPx(scale);
}

void mergeCircleCandidate(std::vector<HoleCircle> *circles,
                          const HoleCircle &candidate) {
  if (circles == nullptr || candidate.radius_px <= 0.0f) {
    return;
  }

  for (HoleCircle &existing : *circles) {
    const float center_dist =
        static_cast<float>(cv::norm(existing.center - candidate.center));
    const float radius_dist =
        std::fabs(existing.radius_px - candidate.radius_px);
    const float center_tol =
        std::max(4.0f, 0.35f * (existing.radius_px + candidate.radius_px));
    const float radius_tol =
        std::max(2.0f, 0.22f * (existing.radius_px + candidate.radius_px));

    if (center_dist <= center_tol && radius_dist <= radius_tol) {
      if (candidate.score > existing.score) {
        existing = candidate;
      }
      return;
    }
  }

  circles->push_back(candidate);
}

float circleEdgeSupportRatio(const cv::Mat &edge_map, const cv::Vec3f &circle) {
  if (edge_map.empty()) {
    return 0.0f;
  }

  const float cx = circle[0];
  const float cy = circle[1];
  const float radius = circle[2];
  if (radius <= 0.0f) {
    return 0.0f;
  }

  constexpr int kSamples = 96;
  int hits = 0;
  for (int i = 0; i < kSamples; ++i) {
    const float theta = static_cast<float>((2.0 * CV_PI * i) / kSamples);
    const int x = cvRound(cx + (std::cos(theta) * radius));
    const int y = cvRound(cy + (std::sin(theta) * radius));

    bool found = false;
    for (int dy = -1; dy <= 1 && !found; ++dy) {
      for (int dx = -1; dx <= 1; ++dx) {
        const int xx = x + dx;
        const int yy = y + dy;
        if (xx < 0 || yy < 0 || xx >= edge_map.cols || yy >= edge_map.rows) {
          continue;
        }
        if (edge_map.at<unsigned char>(yy, xx) > 0U) {
          found = true;
          ++hits;
          break;
        }
      }
    }
  }

  return static_cast<float>(hits) / static_cast<float>(kSamples);
}

// Detecta se um círculo detectado pelo Hough é na verdade um arco parcial
// (ex: semicírculo de furo/cavidade). Usa o edge_map (coordenadas locais da
// ROI) para amostrar quais ângulos têm suporte de borda. Retorna true se for
// arco, preenchendo arc_start/arc_end em graus (conv. OpenCV).
bool computeArcAngles(const cv::Mat &edge_map, const cv::Point2f &center_local,
                      float radius, float *arc_start, float *arc_end) {
  if (edge_map.empty() || radius <= 0.0f || arc_start == nullptr ||
      arc_end == nullptr) {
    return false;
  }

  constexpr int N = 360;
  std::vector<int> support(N, 0);

  for (int i = 0; i < N; ++i) {
    const float theta =
        static_cast<float>(i) * static_cast<float>(CV_PI) / 180.0f;
    const int bx = cvRound(center_local.x + std::cos(theta) * radius);
    const int by = cvRound(center_local.y + std::sin(theta) * radius);
    // Varrer vizinhança 5x5 para robustez a sub-pixel
    for (int dy = -2; dy <= 2 && support[i] == 0; ++dy) {
      for (int dx = -2; dx <= 2 && support[i] == 0; ++dx) {
        const int xx = bx + dx;
        const int yy = by + dy;
        if (xx >= 0 && yy >= 0 && xx < edge_map.cols && yy < edge_map.rows &&
            edge_map.at<uint8_t>(yy, xx) > 0) {
          support[i] = 1;
        }
      }
    }
  }

  int total = 0;
  for (int s : support) {
    total += s;
  }
  const float ratio = static_cast<float>(total) / static_cast<float>(N);

  // Se suporte > 72%: provavelmente círculo completo
  // Se suporte < 15%: sinal muito fraco, não confiável
  if (ratio >= 0.72f || ratio < 0.15f) {
    return false;
  }

  // Encontrar o maior bloco contíguo de suporte (tratando wraparound em 360°)
  int best_start = 0, best_len = 0;
  for (int s = 0; s < N; ++s) {
    if (support[s] == 0) {
      continue;
    }
    int len = 0;
    while (len < N && support[(s + len) % N] != 0) {
      ++len;
    }
    if (len > best_len) {
      best_len = len;
      best_start = s;
    }
  }

  if (best_len < 40) { // Menos de 40° de arco contíguo → ignora
    return false;
  }

  // Expandir levemente os extremos para garantir cobertura completa do arco
  const int margin = 4;
  best_start = (best_start - margin + N) % N;
  best_len = std::min(best_len + margin * 2, N - 1);

  *arc_start = static_cast<float>(best_start);
  *arc_end = static_cast<float>((best_start + best_len) % N);
  return true;
}

std::vector<HoleCircle>
detectHoleCircles(const cv::Mat &roi_gray, const cv::Rect &roi_rect,
                  const std::vector<cv::Point> &outer_contour,
                  const MetricScale &scale) {
  std::vector<HoleCircle> circles;
  if (roi_gray.empty() || outer_contour.size() < 8) {
    return circles;
  }

  const float mm_per_px = effectiveMmPerPx(scale);
  if (mm_per_px <= 0.0f) {
    return circles;
  }

  const int min_radius =
      std::max(3, static_cast<int>(std::round(1.5f / mm_per_px)));
  const int max_radius =
      std::max(min_radius + 2, static_cast<int>(std::round(40.0f / mm_per_px)));

  std::vector<cv::Point> outer_local;
  outer_local.reserve(outer_contour.size());
  for (const cv::Point &p : outer_contour) {
    outer_local.emplace_back(p.x - roi_rect.x, p.y - roi_rect.y);
  }

  cv::Mat piece_mask = cv::Mat::zeros(roi_gray.size(), CV_8U);
  if (!outer_local.empty()) {
    const std::vector<std::vector<cv::Point>> piece_contours = {outer_local};
    cv::drawContours(piece_mask, piece_contours, -1, cv::Scalar(255),
                     cv::FILLED);
  }

  cv::Mat dark_mask;
  cv::threshold(roi_gray, dark_mask, 0, 255,
                cv::THRESH_BINARY_INV | cv::THRESH_OTSU);
  cv::Mat hole_open =
      cv::getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(3, 3));
  cv::morphologyEx(dark_mask, dark_mask, cv::MORPH_OPEN, hole_open);

  cv::Mat not_dark;
  cv::bitwise_not(dark_mask, not_dark);

  cv::Mat cavity_mask;
  cv::bitwise_and(piece_mask, not_dark, cavity_mask);
  cv::morphologyEx(cavity_mask, cavity_mask, cv::MORPH_OPEN, hole_open);
  cv::morphologyEx(cavity_mask, cavity_mask, cv::MORPH_CLOSE, hole_open);

  cv::Mat edge_map;
  cv::Canny(roi_gray, edge_map, 45, 130, 3);

  cv::Mat blur;
  cv::medianBlur(roi_gray, blur, 5);

  // HoughCircles com param2 menor para detectar arcos parciais (semicírculos)
  std::vector<cv::Vec3f> hough;
  cv::HoughCircles(blur, hough, cv::HOUGH_GRADIENT, 1.5,
                   std::max(8, min_radius * 2), 80, 14, min_radius, max_radius);

  for (const cv::Vec3f &c : hough) {
    const int cx = cvRound(c[0]);
    const int cy = cvRound(c[1]);
    if (cx < 0 || cy < 0 || cx >= cavity_mask.cols || cy >= cavity_mask.rows) {
      continue;
    }

    if (cavity_mask.at<unsigned char>(cy, cx) == 0U) {
      continue;
    }

    const float support = circleEdgeSupportRatio(edge_map, c);
    // 0.20 permite semicírculos (só metade da circunferência visível)
    if (support < 0.18f) {
      continue;
    }

    HoleCircle candidate;
    candidate.center = cv::Point2f(c[0] + roi_rect.x, c[1] + roi_rect.y);
    candidate.radius_px = c[2];
    if (candidate.radius_px <= 0.0f) {
      continue;
    }

    if (cv::pointPolygonTest(outer_contour, candidate.center, false) < 0.0) {
      continue;
    }

    // Detectar se é arco parcial (semicírculo) usando edge_map local da ROI
    if (support < 0.72f) {
      float arc_s = 0.0f;
      float arc_e = 360.0f;
      if (computeArcAngles(edge_map, cv::Point2f(c[0], c[1]), c[2], &arc_s,
                           &arc_e)) {
        candidate.is_arc = true;
        candidate.arc_start_deg = arc_s;
        candidate.arc_end_deg = arc_e;
      }
    }

    candidate.score = candidate.radius_px * (0.6f + support);
    mergeCircleCandidate(&circles, candidate);
  }

  // Removido o segundo passe de arcos para evitar que quinas e sujeiras sejam
  // detectadas como furos.

  std::vector<std::vector<cv::Point>> hole_contours;
  cv::findContours(cavity_mask, hole_contours, cv::RETR_LIST,
                   cv::CHAIN_APPROX_SIMPLE);
  for (const std::vector<cv::Point> &contour : hole_contours) {
    const double area = cv::contourArea(contour);
    // Aceitar de 0.20*circulo_min a 2.2*circulo_max (inclui semicírculos)
    if (area < CV_PI * min_radius * min_radius * 0.20 ||
        area > CV_PI * max_radius * max_radius * 2.2) {
      continue;
    }

    const cv::Moments m = cv::moments(contour);
    if (m.m00 <= 1e-6) {
      continue;
    }

    HoleCircle candidate;
    candidate.center =
        cv::Point2f(static_cast<float>((m.m10 / m.m00) + roi_rect.x),
                    static_cast<float>((m.m01 / m.m00) + roi_rect.y));

    if (cv::pointPolygonTest(outer_contour, candidate.center, false) < 0.0) {
      continue;
    }

    const float perimeter = static_cast<float>(cv::arcLength(contour, true));
    if (perimeter < 1.0f) {
      continue;
    }

    const float circularity =
        static_cast<float>((4.0 * CV_PI * area) / (perimeter * perimeter));
    // 0.30 permite semicírculos (circularity real de semicirculo~0.39)
    if (circularity < 0.30f) {
      continue;
    }

    float radius_px = 0.0f;
    cv::Point2f c_local;
    cv::minEnclosingCircle(contour, c_local, radius_px);
    if (radius_px < static_cast<float>(min_radius) ||
        radius_px > static_cast<float>(max_radius)) {
      continue;
    }

    candidate.radius_px = radius_px;
    // Verificar também se o contorno é arco parcial (circularity < 0.72 = não
    // círculo completo)
    if (circularity < 0.72f) {
      float arc_s = 0.0f;
      float arc_e = 360.0f;
      const cv::Point2f local_center(static_cast<float>(m.m10 / m.m00),
                                     static_cast<float>(m.m01 / m.m00));
      if (computeArcAngles(edge_map, local_center, radius_px, &arc_s, &arc_e)) {
        candidate.is_arc = true;
        candidate.arc_start_deg = arc_s;
        candidate.arc_end_deg = arc_e;
      }
    }
    candidate.score = circularity * radius_px;
    mergeCircleCandidate(&circles, candidate);
  }

  std::sort(circles.begin(), circles.end(),
            [](const HoleCircle &a, const HoleCircle &b) {
              return a.score > b.score;
            });

  if (circles.size() > kMaxDisplayedHoles) {
    circles.resize(kMaxDisplayedHoles);
  }

  return circles;
}

bool estimateScaleFromMarkers(
    const std::vector<std::vector<cv::Point2f>> &marker_corners,
    const cv::Mat &perspective_matrix, MetricScale *scale) {
  if (scale == nullptr) {
    return false;
  }

  std::vector<float> horizontal_samples;
  std::vector<float> vertical_samples;
  horizontal_samples.reserve(marker_corners.size() * 2U);
  vertical_samples.reserve(marker_corners.size() * 2U);

  for (const auto &marker : marker_corners) {
    if (marker.size() != 4) {
      continue;
    }

    std::vector<cv::Point2f> warped_marker;
    cv::perspectiveTransform(marker, warped_marker, perspective_matrix);
    if (warped_marker.size() != 4) {
      continue;
    }

    const float top =
        static_cast<float>(cv::norm(warped_marker[1] - warped_marker[0]));
    const float bottom =
        static_cast<float>(cv::norm(warped_marker[2] - warped_marker[3]));
    const float right =
        static_cast<float>(cv::norm(warped_marker[2] - warped_marker[1]));
    const float left =
        static_cast<float>(cv::norm(warped_marker[3] - warped_marker[0]));

    if (top < 2.0f || bottom < 2.0f || left < 2.0f || right < 2.0f) {
      continue;
    }

    horizontal_samples.push_back(top);
    horizontal_samples.push_back(bottom);
    vertical_samples.push_back(left);
    vertical_samples.push_back(right);
  }

  if (horizontal_samples.empty() || vertical_samples.empty()) {
    return false;
  }

  const float marker_px_h = median(horizontal_samples);
  const float marker_px_v = median(vertical_samples);
  if (marker_px_h <= 0.0f || marker_px_v <= 0.0f) {
    return false;
  }

  std::vector<float> abs_dev_h;
  std::vector<float> abs_dev_v;
  abs_dev_h.reserve(horizontal_samples.size());
  abs_dev_v.reserve(vertical_samples.size());

  for (const float side : horizontal_samples) {
    abs_dev_h.push_back(std::fabs(side - marker_px_h));
  }
  for (const float side : vertical_samples) {
    abs_dev_v.push_back(std::fabs(side - marker_px_v));
  }

  const float mad_h = median(abs_dev_h);
  const float mad_v = median(abs_dev_v);
  const float rel_dispersion_h = mad_h / marker_px_h;
  const float rel_dispersion_v = mad_v / marker_px_v;
  if (rel_dispersion_h > 0.08f || rel_dispersion_v > 0.08f) {
    return false;
  }

  scale->mm_per_px_x = kMarkerSquareMm / marker_px_h;
  scale->mm_per_px_y = kMarkerSquareMm / marker_px_v;

  // Rejeita retificações muito distorcidas entre os eixos.
  const float max_scale = std::max(scale->mm_per_px_x, scale->mm_per_px_y);
  const float min_scale = std::min(scale->mm_per_px_x, scale->mm_per_px_y);
  if (min_scale <= 0.0f) {
    return false;
  }
  const float anisotropy = (max_scale / min_scale) - 1.0f;
  if (anisotropy > 0.25f) {
    return false;
  }

  return true;
}

void refineDetectedMarkerCorners(
    const cv::Mat &gray,
    std::vector<std::vector<cv::Point2f>> *marker_corners) {
  if (marker_corners == nullptr || gray.empty()) {
    return;
  }

  const cv::Size win_size(5, 5);
  const cv::Size zero_zone(-1, -1);
  const cv::TermCriteria criteria(
      cv::TermCriteria::EPS + cv::TermCriteria::MAX_ITER, 30, 0.01);

  for (auto &marker : *marker_corners) {
    if (marker.size() == 4) {
      cv::cornerSubPix(gray, marker, win_size, zero_zone, criteria);
    }
  }
}

float polygonSignedArea(const std::vector<cv::Point2f> &polygon) {
  if (polygon.size() < 3) {
    return 0.0f;
  }

  double area = 0.0;
  for (size_t i = 0; i < polygon.size(); ++i) {
    const cv::Point2f &p0 = polygon[i];
    const cv::Point2f &p1 = polygon[(i + 1) % polygon.size()];
    area +=
        (static_cast<double>(p0.x) * p1.y) - (static_cast<double>(p1.x) * p0.y);
  }
  return static_cast<float>(0.5 * area);
}

std::vector<cv::Point2f>
approximatePolygon(const std::vector<cv::Point> &contour) {
  std::vector<cv::Point2f> polygon;
  if (contour.size() < 3) {
    return polygon;
  }

  const double perimeter = cv::arcLength(contour, true);
  std::vector<cv::Point> approx;
  double epsilon = std::max(2.0, perimeter * 0.0055);
  cv::approxPolyDP(contour, approx, epsilon, true);

  if (approx.size() < 3) {
    cv::RotatedRect rect = cv::minAreaRect(contour);
    cv::Point2f rect_pts[4];
    rect.points(rect_pts);
    polygon.assign(rect_pts, rect_pts + 4);
  } else {
    polygon.reserve(approx.size());
    for (const cv::Point &p : approx) {
      polygon.emplace_back(static_cast<float>(p.x), static_cast<float>(p.y));
    }
  }

  if (polygon.size() >= 3) {
    size_t start_index = 0;
    for (size_t i = 1; i < polygon.size(); ++i) {
      const bool lower_y = polygon[i].y < polygon[start_index].y;
      const bool same_y_lower_x =
          (std::fabs(polygon[i].y - polygon[start_index].y) < 1e-3f) &&
          (polygon[i].x < polygon[start_index].x);
      if (lower_y || same_y_lower_x) {
        start_index = i;
      }
    }
    std::rotate(polygon.begin(),
                polygon.begin() + static_cast<std::ptrdiff_t>(start_index),
                polygon.end());
  }

  return polygon;
}

void computePolygonMetrics(const std::vector<cv::Point2f> &polygon,
                           const MetricScale &scale,
                           std::vector<float> *edges_mm,
                           std::vector<float> *angles_deg,
                           float *perimeter_mm) {
  if (edges_mm == nullptr || angles_deg == nullptr || perimeter_mm == nullptr) {
    return;
  }
  edges_mm->clear();
  angles_deg->clear();
  *perimeter_mm = 0.0f;

  if (polygon.size() < 3 || scale.mm_per_px_x <= 0.0f ||
      scale.mm_per_px_y <= 0.0f) {
    return;
  }

  const bool is_ccw = polygonSignedArea(polygon) > 0.0f;
  edges_mm->reserve(polygon.size());
  angles_deg->reserve(polygon.size());

  for (size_t i = 0; i < polygon.size(); ++i) {
    const cv::Point2f &prev =
        polygon[(i + polygon.size() - 1) % polygon.size()];
    const cv::Point2f &curr = polygon[i];
    const cv::Point2f &next = polygon[(i + 1) % polygon.size()];

    const float edge_len_mm = distanceMm(curr, next, scale);
    edges_mm->push_back(edge_len_mm);
    *perimeter_mm += edge_len_mm;

    const cv::Point2f prev_m = toMetricPoint(prev, scale);
    const cv::Point2f curr_m = toMetricPoint(curr, scale);
    const cv::Point2f next_m = toMetricPoint(next, scale);

    const cv::Point2f v1 = prev_m - curr_m;
    const cv::Point2f v2 = next_m - curr_m;
    const float n1 = static_cast<float>(cv::norm(v1));
    const float n2 = static_cast<float>(cv::norm(v2));
    if (n1 < 1e-3f || n2 < 1e-3f) {
      angles_deg->push_back(0.0f);
      continue;
    }

    const float cos_theta = clampUnit((v1.x * v2.x + v1.y * v2.y) / (n1 * n2));
    float angle = static_cast<float>(std::acos(cos_theta) * 180.0 / CV_PI);

    const cv::Point2f e1 = curr_m - prev_m;
    const cv::Point2f e2 = next_m - curr_m;
    const float cross = e1.x * e2.y - e1.y * e2.x;
    const bool is_concave = is_ccw ? (cross < 0.0f) : (cross > 0.0f);
    if (is_concave) {
      angle = 360.0f - angle;
    }
    angles_deg->push_back(angle);
  }
}

std::vector<cv::Point2f>
simplifyPolygonForTechnicalDrawing(const std::vector<cv::Point2f> &polygon,
                                   float mm_per_px) {
  if (polygon.size() < 3) {
    return polygon;
  }

  std::vector<cv::Point2f> simplified = polygon;
  const float safe_mm_per_px = std::max(1e-4f, mm_per_px);
  const float min_edge_px = std::max(2.0f, 3.0f / safe_mm_per_px);
  const float collinear_tol_deg = 5.0f;

  const size_t max_iterations = simplified.size() * 2U;
  for (size_t iter = 0; iter < max_iterations && simplified.size() > 3;
       ++iter) {
    bool removed_vertex = false;

    for (size_t i = 0; i < simplified.size(); ++i) {
      const cv::Point2f &prev =
          simplified[(i + simplified.size() - 1) % simplified.size()];
      const cv::Point2f &curr = simplified[i];
      const cv::Point2f &next = simplified[(i + 1) % simplified.size()];

      const float len_prev = static_cast<float>(cv::norm(curr - prev));
      const float len_next = static_cast<float>(cv::norm(next - curr));
      const float len_skip = static_cast<float>(cv::norm(next - prev));

      if (len_prev < 1.0f || len_next < 1.0f || len_skip < 1.0f) {
        simplified.erase(simplified.begin() + static_cast<std::ptrdiff_t>(i));
        removed_vertex = true;
        break;
      }

      const cv::Point2f v1 = prev - curr;
      const cv::Point2f v2 = next - curr;
      const float n1 = static_cast<float>(cv::norm(v1));
      const float n2 = static_cast<float>(cv::norm(v2));
      if (n1 < 1e-3f || n2 < 1e-3f) {
        simplified.erase(simplified.begin() + static_cast<std::ptrdiff_t>(i));
        removed_vertex = true;
        break;
      }

      const float cos_theta =
          clampUnit((v1.x * v2.x + v1.y * v2.y) / (n1 * n2));
      const float angle =
          static_cast<float>(std::acos(cos_theta) * 180.0 / CV_PI);
      const bool nearly_collinear =
          std::fabs(180.0f - angle) <= collinear_tol_deg;
      const bool tiny_kink =
          ((len_prev < min_edge_px) || (len_next < min_edge_px)) &&
          (std::fabs(180.0f - angle) <= 15.0f);

      if (nearly_collinear || tiny_kink) {
        simplified.erase(simplified.begin() + static_cast<std::ptrdiff_t>(i));
        removed_vertex = true;
        break;
      }
    }

    if (!removed_vertex) {
      break;
    }
  }

  if (simplified.size() < 3) {
    return polygon;
  }
  return simplified;
}

std::vector<size_t>
selectDisplayedDimensionIndices(const std::vector<float> &edges_mm,
                                const std::vector<float> &angles_deg) {
  std::vector<size_t> candidates;
  candidates.reserve(edges_mm.size());

  for (size_t i = 0; i < edges_mm.size(); ++i) {
    const float edge = edges_mm[i];
    // Exibe qualquer aresta >= kMinDisplayEdgeMm (sem filtro de corner)
    if (edge >= kMinDisplayEdgeMm) {
      candidates.push_back(i);
    }
  }

  if (candidates.empty()) {
    if (edges_mm.empty()) {
      return {};
    }
    // Fallback: exibir a maior aresta
    size_t max_index = 0;
    for (size_t i = 1; i < edges_mm.size(); ++i) {
      if (edges_mm[i] > edges_mm[max_index]) {
        max_index = i;
      }
    }
    return {max_index};
  }

  if (candidates.size() > kMaxDisplayedEdges) {
    // Priorizar as mais longas
    std::vector<size_t> ranked = candidates;
    std::sort(ranked.begin(), ranked.end(), [&edges_mm](size_t a, size_t b) {
      return edges_mm[a] > edges_mm[b];
    });
    ranked.resize(kMaxDisplayedEdges);
    std::sort(ranked.begin(), ranked.end());
    return ranked;
  }

  return candidates;
}

int chooseOutsideOffsetDirection(const std::vector<cv::Point2f> &polygon,
                                 const cv::Point2f &p0, const cv::Point2f &p1) {
  if (polygon.size() < 3) {
    return 1;
  }

  const cv::Point2f d = p1 - p0;
  const float len = static_cast<float>(cv::norm(d));
  if (len < 1e-3f) {
    return 1;
  }

  const cv::Point2f u = d * (1.0f / len);
  const cv::Point2f n(-u.y, u.x);
  const cv::Point2f mid = (p0 + p1) * 0.5f;
  const float probe = std::max(6.0f, std::min(16.0f, len * 0.18f));

  const float side_pos = static_cast<float>(
      cv::pointPolygonTest(polygon, mid + (n * probe), true));
  const float side_neg = static_cast<float>(
      cv::pointPolygonTest(polygon, mid - (n * probe), true));

  if (side_pos < 0.0f && side_neg >= 0.0f) {
    return 1;
  }
  if (side_neg < 0.0f && side_pos >= 0.0f) {
    return -1;
  }

  return (side_pos < side_neg) ? 1 : -1;
}

struct LineModel {
  cv::Point2f point;
  cv::Point2f dir;
  bool valid = false;
};

LineModel fitLineToContourEdge(const std::vector<cv::Point> &contour,
                               const cv::Point2f &edge_start,
                               const cv::Point2f &edge_end) {
  LineModel model;

  const cv::Point2f edge_vec = edge_end - edge_start;
  const float edge_len = static_cast<float>(cv::norm(edge_vec));
  const float edge_len_sq = edge_len * edge_len;
  if (edge_len < 3.0f) {
    return model;
  }

  const float tol_px = std::max(2.0f, edge_len * 0.035f);
  std::vector<cv::Point2f> samples;
  samples.reserve(contour.size());

  for (const cv::Point &cp : contour) {
    const cv::Point2f p(static_cast<float>(cp.x), static_cast<float>(cp.y));
    const cv::Point2f ap = p - edge_start;
    const float t = (ap.x * edge_vec.x + ap.y * edge_vec.y) / edge_len_sq;
    if (t < -0.10f || t > 1.10f) {
      continue;
    }

    const float dist = std::fabs(cross2d(edge_vec, ap)) / edge_len;
    if (dist <= tol_px) {
      samples.push_back(p);
    }
  }

  if (samples.size() < 8U) {
    return model;
  }

  cv::Vec4f line;
  cv::fitLine(samples, line, cv::DIST_L2, 0, 0.01, 0.01);
  cv::Point2f dir(line[0], line[1]);
  const float dir_norm = static_cast<float>(cv::norm(dir));
  if (dir_norm < 1e-4f) {
    return model;
  }
  dir *= (1.0f / dir_norm);

  if ((dir.x * edge_vec.x + dir.y * edge_vec.y) < 0.0f) {
    dir *= -1.0f;
  }

  model.point = cv::Point2f(line[2], line[3]);
  model.dir = dir;
  model.valid = true;
  return model;
}

// Versão que usa pontos de borda Canny para maior precisão
LineModel fitLineToCannyEdge(const cv::Mat &edge_map,
                             const cv::Point2f &edge_start,
                             const cv::Point2f &edge_end) {
  LineModel model;

  const cv::Point2f edge_vec = edge_end - edge_start;
  const float edge_len = static_cast<float>(cv::norm(edge_vec));
  if (edge_len < 3.0f) {
    return model;
  }

  const float edge_len_sq = edge_len * edge_len;
  const cv::Point2f u = edge_vec * (1.0f / edge_len);
  const cv::Point2f n(-u.y, u.x); // normal

  // Varrer pixels de borda Canny em uma faixa estreita ao redor da aresta
  const float tol_px = std::max(3.0f, edge_len * 0.04f);
  const int search_band = cvRound(tol_px) + 1;
  std::vector<cv::Point2f> samples;
  samples.reserve(static_cast<size_t>(edge_len * 2));

  // Bounding box da região de busca
  const int x_min =
      std::max(0, cvRound(std::min(edge_start.x, edge_end.x)) - search_band);
  const int x_max =
      std::min(edge_map.cols - 1,
               cvRound(std::max(edge_start.x, edge_end.x)) + search_band);
  const int y_min =
      std::max(0, cvRound(std::min(edge_start.y, edge_end.y)) - search_band);
  const int y_max =
      std::min(edge_map.rows - 1,
               cvRound(std::max(edge_start.y, edge_end.y)) + search_band);

  for (int y = y_min; y <= y_max; ++y) {
    const unsigned char *row = edge_map.ptr<unsigned char>(y);
    for (int x = x_min; x <= x_max; ++x) {
      if (row[x] == 0)
        continue;

      const cv::Point2f p(static_cast<float>(x), static_cast<float>(y));
      const cv::Point2f ap = p - edge_start;
      const float t = (ap.x * edge_vec.x + ap.y * edge_vec.y) / edge_len_sq;
      if (t < -0.05f || t > 1.05f)
        continue;

      const float dist = std::fabs(cross2d(edge_vec, ap)) / edge_len;
      if (dist <= tol_px) {
        samples.push_back(p);
      }
    }
  }

  if (samples.size() < 10U) {
    return model;
  }

  cv::Vec4f line;
  cv::fitLine(samples, line, cv::DIST_HUBER, 0, 0.01,
              0.01); // HUBER é mais robusto a outliers
  cv::Point2f dir(line[0], line[1]);
  const float dir_norm = static_cast<float>(cv::norm(dir));
  if (dir_norm < 1e-4f) {
    return model;
  }
  dir *= (1.0f / dir_norm);

  if ((dir.x * edge_vec.x + dir.y * edge_vec.y) < 0.0f) {
    dir *= -1.0f;
  }

  model.point = cv::Point2f(line[2], line[3]);
  model.dir = dir;
  model.valid = true;
  return model;
}

bool intersectLines(const LineModel &a, const LineModel &b, cv::Point2f *out) {
  if (out == nullptr || !a.valid || !b.valid) {
    return false;
  }

  const float det = cross2d(a.dir, b.dir);
  if (std::fabs(det) < 1e-4f) {
    return false;
  }

  const cv::Point2f diff = b.point - a.point;
  const float t = cross2d(diff, b.dir) / det;
  *out = a.point + a.dir * t;
  return true;
}

std::vector<cv::Point2f>
refinePolygonWithLineIntersections(const std::vector<cv::Point2f> &polygon,
                                   const std::vector<cv::Point> &contour,
                                   const cv::Mat &edge_map) {
  if (polygon.size() < 3 || contour.size() < 20) {
    return polygon;
  }

  const size_t n = polygon.size();
  std::vector<LineModel> lines(n);
  for (size_t i = 0; i < n; ++i) {
    const cv::Point2f &p0 = polygon[i];
    const cv::Point2f &p1 = polygon[(i + 1U) % n];

    // Tentar primeiro com pontos de Canny (mais preciso)
    if (!edge_map.empty()) {
      lines[i] = fitLineToCannyEdge(edge_map, p0, p1);
    }
    // Fallback: usar pontos do contorno
    if (!lines[i].valid) {
      lines[i] = fitLineToContourEdge(contour, p0, p1);
    }
    if (!lines[i].valid) {
      cv::Point2f dir = p1 - p0;
      const float len = static_cast<float>(cv::norm(dir));
      if (len > 1e-3f) {
        dir *= (1.0f / len);
        lines[i].point = p0;
        lines[i].dir = dir;
        lines[i].valid = true;
      }
    }
  }

  std::vector<cv::Point2f> refined = polygon;
  for (size_t i = 0; i < n; ++i) {
    const LineModel &prev_line = lines[(i + n - 1U) % n];
    const LineModel &curr_line = lines[i];
    cv::Point2f intersection;
    if (!intersectLines(prev_line, curr_line, &intersection)) {
      continue;
    }

    const cv::Point2f prev = polygon[(i + n - 1U) % n];
    const cv::Point2f curr = polygon[i];
    const cv::Point2f next = polygon[(i + 1U) % n];
    const float local_span =
        std::min(static_cast<float>(cv::norm(curr - prev)),
                 static_cast<float>(cv::norm(next - curr)));
    const float max_shift = std::max(3.0f, local_span * 0.25f);

    if (cv::norm(intersection - curr) <= max_shift) {
      refined[i] = intersection;
    }
  }

  return refined;
}

// ===== Detecção de arcos em arestas do polígono =====

struct EdgeArcInfo {
  bool is_arc = false;
  cv::Point2f center;
  float radius_px = 0.0f;
  float arc_start_deg = 0.0f;
  float arc_end_deg = 0.0f;
  std::vector<cv::Point> arc_points; // pontos do contorno para polyline suave
};

size_t nearestContourIdx(const std::vector<cv::Point> &contour,
                         const cv::Point2f &pt) {
  size_t best = 0;
  float best_dist = std::numeric_limits<float>::max();
  for (size_t i = 0; i < contour.size(); ++i) {
    const float d = static_cast<float>(cv::norm(
        cv::Point2f(static_cast<float>(contour[i].x),
                    static_cast<float>(contour[i].y)) -
        pt));
    if (d < best_dist) {
      best_dist = d;
      best = i;
    }
  }
  return best;
}

std::vector<cv::Point> extractContourSegment(
    const std::vector<cv::Point> &contour, size_t idx_a, size_t idx_b) {
  const size_t n = contour.size();
  if (n == 0) return {};

  // Caminho mais curto entre idx_a e idx_b (frente ou trás)
  size_t fwd_len = (idx_b >= idx_a) ? (idx_b - idx_a + 1)
                                     : (n - idx_a + idx_b + 1);
  size_t bwd_len = (idx_a >= idx_b) ? (idx_a - idx_b + 1)
                                     : (n - idx_b + idx_a + 1);

  std::vector<cv::Point> seg;
  if (fwd_len <= bwd_len) {
    seg.reserve(fwd_len);
    for (size_t k = 0; k < fwd_len; ++k) {
      seg.push_back(contour[(idx_a + k) % n]);
    }
  } else {
    seg.reserve(bwd_len);
    for (size_t k = 0; k < bwd_len; ++k) {
      seg.push_back(contour[(idx_a + n - k) % n]);
    }
  }
  return seg;
}

// Ajuste de círculo por mínimos quadrados — método algébrico de Kasa.
// Retorna true se o fit for razoável.
bool fitCircleLeastSquares(const std::vector<cv::Point> &pts,
                           cv::Point2f *center, float *radius) {
  if (pts.size() < 5 || center == nullptr || radius == nullptr) {
    return false;
  }

  // Resolver o sistema A * [a, b, c]^T = d  onde:
  //   (x - cx)^2 + (y - cy)^2 = r^2
  //   x^2 + y^2 + a*x + b*y + c = 0
  //   cx = -a/2, cy = -b/2, r = sqrt(cx^2 + cy^2 - c)
  double sum_x = 0, sum_y = 0, sum_x2 = 0, sum_y2 = 0;
  double sum_xy = 0, sum_x3 = 0, sum_y3 = 0;
  double sum_x2y = 0, sum_xy2 = 0;
  const double n = static_cast<double>(pts.size());

  for (const cv::Point &p : pts) {
    const double x = static_cast<double>(p.x);
    const double y = static_cast<double>(p.y);
    sum_x += x;
    sum_y += y;
    sum_x2 += x * x;
    sum_y2 += y * y;
    sum_xy += x * y;
    sum_x3 += x * x * x;
    sum_y3 += y * y * y;
    sum_x2y += x * x * y;
    sum_xy2 += x * y * y;
  }

  // Montar sistema 3x3
  double A11 = sum_x2, A12 = sum_xy, A13 = sum_x;
  double A21 = sum_xy, A22 = sum_y2, A23 = sum_y;
  double A31 = sum_x, A32 = sum_y, A33 = n;

  double B1 = -(sum_x3 + sum_xy2);
  double B2 = -(sum_x2y + sum_y3);
  double B3 = -(sum_x2 + sum_y2);

  // Resolver via Cramer
  double det = A11 * (A22 * A33 - A23 * A32) -
               A12 * (A21 * A33 - A23 * A31) +
               A13 * (A21 * A32 - A22 * A31);
  if (std::fabs(det) < 1e-10) {
    return false;
  }

  double a = (B1 * (A22 * A33 - A23 * A32) -
              A12 * (B2 * A33 - A23 * B3) +
              A13 * (B2 * A32 - A22 * B3)) /
             det;
  double b = (A11 * (B2 * A33 - A23 * B3) -
              B1 * (A21 * A33 - A23 * A31) +
              A13 * (A21 * B3 - B2 * A31)) /
             det;
  double c = (A11 * (A22 * B3 - B2 * A32) -
              A12 * (A21 * B3 - B2 * A31) +
              B1 * (A21 * A32 - A22 * A31)) /
             det;

  double cx = -a / 2.0;
  double cy = -b / 2.0;
  double r2 = cx * cx + cy * cy - c;
  if (r2 <= 0.0) {
    return false;
  }

  *center = cv::Point2f(static_cast<float>(cx), static_cast<float>(cy));
  *radius = static_cast<float>(std::sqrt(r2));

  // Validar qualidade do fit: erro médio deve ser < 15% do raio
  double err_sum = 0.0;
  for (const cv::Point &p : pts) {
    const double dx = static_cast<double>(p.x) - cx;
    const double dy = static_cast<double>(p.y) - cy;
    const double dist = std::sqrt(dx * dx + dy * dy);
    err_sum += std::fabs(dist - *radius);
  }
  const double avg_err = err_sum / n;
  if (avg_err > *radius * 0.10) {
    return false;
  }

  return true;
}

// Analisa cada aresta do polígono para detectar se é reta ou curvada
std::vector<EdgeArcInfo>
detectEdgeArcs(const std::vector<cv::Point2f> &polygon,
               const std::vector<cv::Point> &contour,
               const MetricScale &scale) {
  const size_t np = polygon.size();
  std::vector<EdgeArcInfo> arcs(np);
  if (np < 3 || contour.size() < 30) {
    return arcs;
  }

  for (size_t i = 0; i < np; ++i) {
    const cv::Point2f &pa = polygon[i];
    const cv::Point2f &pb = polygon[(i + 1) % np];
    const float edge_len = static_cast<float>(cv::norm(pb - pa));
    if (edge_len < 8.0f) {
      continue;
    }

    // Extrair pontos do contorno entre pa e pb
    const size_t idx_a = nearestContourIdx(contour, pa);
    const size_t idx_b = nearestContourIdx(contour, pb);
    if (idx_a == idx_b) {
      continue;
    }

    std::vector<cv::Point> seg = extractContourSegment(contour, idx_a, idx_b);
    if (seg.size() < 8) {
      continue;
    }

    // Medir desvio máximo dos pontos do contorno em relação à reta pa→pb
    const cv::Point2f edge_vec = pb - pa;
    float max_dev = 0.0f;
    for (const cv::Point &cp : seg) {
      const cv::Point2f p(static_cast<float>(cp.x), static_cast<float>(cp.y));
      const cv::Point2f ap = p - pa;
      const float dist = std::fabs(cross2d(edge_vec, ap)) / edge_len;
      if (dist > max_dev) {
        max_dev = dist;
      }
    }

    // Se desvio > 5% do comprimento e > 5px absolutos → é curva
    const float dev_ratio = max_dev / edge_len;
    if (dev_ratio < 0.05f || max_dev < 5.0f) {
      continue;
    }

    // Ajustar círculo aos pontos
    cv::Point2f circ_center;
    float circ_radius = 0.0f;
    if (!fitCircleLeastSquares(seg, &circ_center, &circ_radius)) {
      continue;
    }

    // Validar: raio não pode ser absurdamente grande (>6x comprimento da aresta)
    // nem minúsculo (<45% do comprimento, semicírculo quase perfeito é 50%)
    if (circ_radius > edge_len * 6.0f || circ_radius < edge_len * 0.45f) {
      continue;
    }

    // Calcular ângulos de início e fim do arco
    const float sa = std::atan2(pa.y - circ_center.y, pa.x - circ_center.x);
    const float ea = std::atan2(pb.y - circ_center.y, pb.x - circ_center.x);

    float sa_deg = sa * 180.0f / static_cast<float>(CV_PI);
    float ea_deg = ea * 180.0f / static_cast<float>(CV_PI);

    // Determinar a direção correta do arco (deve passar pelos pontos do contorno)
    // Testar um ponto do meio do segmento
    const cv::Point &mid_pt = seg[seg.size() / 2];
    const float mid_ang = std::atan2(
        static_cast<float>(mid_pt.y) - circ_center.y,
        static_cast<float>(mid_pt.x) - circ_center.x) *
        180.0f / static_cast<float>(CV_PI);

    // Normalizar para [0, 360)
    auto normAngle = [](float a) -> float {
      while (a < 0.0f) a += 360.0f;
      while (a >= 360.0f) a -= 360.0f;
      return a;
    };

    sa_deg = normAngle(sa_deg);
    ea_deg = normAngle(ea_deg);
    float mid_deg = normAngle(mid_ang);

    // Verificar se mid_deg está entre sa_deg→ea_deg no sentido horário
    auto angleBetween = [](float start, float end, float test) -> bool {
      if (start <= end) {
        return test >= start && test <= end;
      }
      return test >= start || test <= end;
    };

    if (!angleBetween(sa_deg, ea_deg, mid_deg)) {
      // Inverter: trocar start e end
      std::swap(sa_deg, ea_deg);
    }

    EdgeArcInfo info;
    info.is_arc = true;
    info.center = circ_center;
    info.radius_px = circ_radius;
    info.arc_start_deg = sa_deg;
    info.arc_end_deg = ea_deg;
    info.arc_points = seg;
    arcs[i] = info;
  }

  return arcs;
}

void writeMeasurementDetailsJson(const std::string &json_path,
                                 bool calibration_success, bool object_found,
                                 const std::vector<float> &edges_mm,
                                 const std::vector<float> &angles_deg,
                                 const std::vector<float> &hole_radii_mm,
                                 const std::vector<float> &semi_circle_radii_mm,
                                 float perimeter_mm, float area_mm2) {
  std::ofstream out(json_path, std::ios::trunc);
  if (!out.is_open()) {
    return;
  }

  out << std::fixed << std::setprecision(4);
  out << "{\n";
  out << "  \"calibrationSuccess\": "
      << (calibration_success ? "true" : "false") << ",\n";
  out << "  \"objectFound\": " << (object_found ? "true" : "false") << ",\n";
  out << "  \"edgeCount\": " << edges_mm.size() << ",\n";
  out << "  \"perimeterMm\": " << perimeter_mm << ",\n";
  out << "  \"areaMm2\": " << area_mm2 << ",\n";
  out << "  \"markerSizeMm\": " << kMarkerSquareMm << ",\n";

  out << "  \"edgesMm\": [";
  for (size_t i = 0; i < edges_mm.size(); ++i) {
    if (i > 0)
      out << ", ";
    out << edges_mm[i];
  }
  out << "],\n";

  out << "  \"anglesDeg\": [";
  for (size_t i = 0; i < angles_deg.size(); ++i) {
    if (i > 0)
      out << ", ";
    out << angles_deg[i];
  }
  out << "],\n";

  out << "  \"holeRadiiMm\": [";
  for (size_t i = 0; i < hole_radii_mm.size(); ++i) {
    if (i > 0)
      out << ", ";
    out << hole_radii_mm[i];
  }
  out << "],\n";
  out << "  \"semiCircleRadiiMm\": [";
  for (size_t i = 0; i < semi_circle_radii_mm.size(); ++i) {
    if (i > 0)
      out << ", ";
    out << semi_circle_radii_mm[i];
  }
  out << "]\n";
  out << "}\n";
}

} // namespace

extern "C" {
struct MeasurementResult {
  float width_mm;
  float height_mm;
  bool calibration_success;
  bool object_found;
};

MeasurementResult process_image(const char *input_path,
                                const char *output_path) {
  MeasurementResult result = {0.0f, 0.0f, false, false};

  std::vector<float> edges_mm;
  std::vector<float> angles_deg;
  std::vector<float> hole_radii_mm;
  std::vector<float> semi_circle_radii_mm;
  float perimeter_mm = 0.0f;
  float area_mm2 = 0.0f;

  cv::Mat src = cv::imread(input_path);
  if (src.empty())
    return result;

  cv::Mat src_gray;
  cv::cvtColor(src, src_gray, cv::COLOR_BGR2GRAY);

  // 1. Detectar ArUcos
  cv::aruco::Dictionary dictionary =
      cv::aruco::getPredefinedDictionary(cv::aruco::DICT_4X4_50);
  cv::aruco::DetectorParameters detectorParams;
  cv::aruco::ArucoDetector detector(dictionary, detectorParams);

  std::vector<int> markerIds;
  std::vector<std::vector<cv::Point2f>> markerCorners;
  detector.detectMarkers(src_gray, markerCorners, markerIds);

  if (markerIds.size() < 4)
    return result;

  refineDetectedMarkerCorners(src_gray, &markerCorners);

  // 2. Selecionar os 4 marcadores mais externos e ordenar em TL, TR, BR, BL
  std::vector<cv::Point2f> centers;
  centers.reserve(markerCorners.size());
  for (const auto &corners : markerCorners) {
    centers.push_back(markerCenter(corners));
  }

  std::vector<cv::Point2f> quad;
  if (centers.size() == 4) {
    quad = centers;
  } else {
    auto min_x_it = std::min_element(
        centers.begin(), centers.end(),
        [](const cv::Point2f &a, const cv::Point2f &b) { return a.x < b.x; });
    auto max_x_it = std::max_element(
        centers.begin(), centers.end(),
        [](const cv::Point2f &a, const cv::Point2f &b) { return a.x < b.x; });
    auto min_y_it = std::min_element(
        centers.begin(), centers.end(),
        [](const cv::Point2f &a, const cv::Point2f &b) { return a.y < b.y; });
    auto max_y_it = std::max_element(
        centers.begin(), centers.end(),
        [](const cv::Point2f &a, const cv::Point2f &b) { return a.y < b.y; });

    quad = {*min_x_it, *max_x_it, *min_y_it, *max_y_it};

    // Remove duplicados preservando ordem
    std::vector<cv::Point2f> unique_quad;
    unique_quad.reserve(4);
    for (const auto &p : quad) {
      bool exists = false;
      for (const auto &u : unique_quad) {
        if (cv::norm(p - u) < 1.0f) {
          exists = true;
          break;
        }
      }
      if (!exists) {
        unique_quad.push_back(p);
      }
    }

    if (unique_quad.size() != 4) {
      return result;
    }
    quad = unique_quad;
  }

  const auto ordered_array = orderCorners(quad);
  if (hasRepeatedCorners(ordered_array)) {
    return result;
  }
  std::vector<cv::Point2f> ordered_points(ordered_array.begin(),
                                          ordered_array.end());

  // 3. Corrigir perspectiva sem assumir orientação fixa horizontal/vertical da
  // captura
  const float top_px =
      static_cast<float>(cv::norm(ordered_points[1] - ordered_points[0]));
  const float bottom_px =
      static_cast<float>(cv::norm(ordered_points[2] - ordered_points[3]));
  const float left_px =
      static_cast<float>(cv::norm(ordered_points[3] - ordered_points[0]));
  const float right_px =
      static_cast<float>(cv::norm(ordered_points[2] - ordered_points[1]));

  const float src_width_px = (top_px + bottom_px) * 0.5f;
  const float src_height_px = (left_px + right_px) * 0.5f;
  if (src_width_px < 20.0f || src_height_px < 20.0f) {
    return result;
  }

  // 3. Retificação pela geometria observada (sem assumir distâncias fixas da
  // impressão).
  const int img_w = std::max(1, cvRound(src_width_px * kWarpUpscale));
  const int img_h = std::max(1, cvRound(src_height_px * kWarpUpscale));

  std::vector<cv::Point2f> real_world_points = {
      cv::Point2f(0.0f, 0.0f), cv::Point2f(static_cast<float>(img_w - 1), 0.0f),
      cv::Point2f(static_cast<float>(img_w - 1), static_cast<float>(img_h - 1)),
      cv::Point2f(0.0f, static_cast<float>(img_h - 1))};

  cv::Mat perspective_matrix =
      cv::getPerspectiveTransform(ordered_points, real_world_points);
  cv::Mat flat_image;
  cv::warpPerspective(src, flat_image, perspective_matrix,
                      cv::Size(img_w, img_h));
  result.calibration_success = true;

  // 3.1 Escala baseada apenas no tamanho conhecido dos quadrados ArUco (23 mm).
  MetricScale metric_scale;
  const bool has_marker_scale = estimateScaleFromMarkers(
      markerCorners, perspective_matrix, &metric_scale);
  const float mm_per_px = effectiveMmPerPx(metric_scale);
  if (!has_marker_scale || mm_per_px <= 0.0f) {
    result.calibration_success = false;
    return result;
  }

  // 4. Detecção do objeto central — pipeline edge-first para precisão máxima
  cv::Mat gray;
  cv::cvtColor(flat_image, gray, cv::COLOR_BGR2GRAY);
  cv::GaussianBlur(gray, gray, cv::Size(3, 3), 0.0);

  const int roi_margin =
      std::max(8, static_cast<int>(std::min(img_w, img_h) * 0.04f));
  if ((img_w <= roi_margin * 2) || (img_h <= roi_margin * 2)) {
    cv::imwrite(output_path, flat_image);
    return result;
  }

  const cv::Rect roi_rect(roi_margin, roi_margin, img_w - (roi_margin * 2),
                          img_h - (roi_margin * 2));
  cv::Mat roi_gray = gray(roi_rect).clone();

  // --- Canny edge map global para reuso (line fitting, holes, etc) ---
  cv::Mat canny_roi;
  cv::Canny(roi_gray, canny_roi, 30, 100, 3, true); // L2gradient para sub-pixel

  // ===== PIPELINE A: Edge-first (precisão máxima, sem bloating) =====
  // Dilatar edges levemente para fechar micro-gaps de 1px
  cv::Mat edge_closed;
  cv::dilate(canny_roi, edge_closed,
             cv::getStructuringElement(cv::MORPH_RECT, cv::Size(3, 3)));

  // Flood-fill a partir dos 4 cantos marca o fundo
  cv::Mat bg_seed = edge_closed.clone();
  cv::bitwise_not(bg_seed, bg_seed);
  // Inundar a partir de cada canto da ROI
  cv::Mat flood_mask_full =
      cv::Mat::zeros(bg_seed.rows + 2, bg_seed.cols + 2, CV_8U);
  const cv::Point flood_seeds[] = {
      cv::Point(0, 0), cv::Point(bg_seed.cols - 1, 0),
      cv::Point(0, bg_seed.rows - 1),
      cv::Point(bg_seed.cols - 1, bg_seed.rows - 1)};
  for (const cv::Point &seed : flood_seeds) {
    if (bg_seed.at<unsigned char>(seed.y, seed.x) == 255) {
      cv::floodFill(bg_seed, flood_mask_full, seed, cv::Scalar(0));
    }
  }
  // O que sobrou em bg_seed (ainda 255) é o objeto
  cv::Mat edge_object_mask = bg_seed;

  // Erodir 1px para compensar a dilatação das edges
  cv::erode(edge_object_mask, edge_object_mask,
            cv::getStructuringElement(cv::MORPH_RECT, cv::Size(3, 3)));

  // ===== PIPELINE B: Fallback com Otsu (caso edge-first falhe) =====
  cv::Mat mask_otsu;
  cv::threshold(roi_gray, mask_otsu, 0, 255,
                cv::THRESH_BINARY_INV | cv::THRESH_OTSU);
  // Erosão leve para compensar bias do threshold
  cv::erode(mask_otsu, mask_otsu,
            cv::getStructuringElement(cv::MORPH_RECT, cv::Size(2, 2)));

  // ===== Seleção do melhor contorno =====
  std::vector<cv::Mat> candidate_masks = {edge_object_mask, mask_otsu};
  cv::Mat morph_open_k =
      cv::getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(7, 7));

  const double roi_area = static_cast<double>(roi_rect.area());
  const double min_area = roi_area * 0.0012;
  const double max_area = roi_area * 0.92;
  const cv::Point2f image_center(img_w * 0.5f, img_h * 0.5f);
  const double max_diag =
      std::sqrt(static_cast<double>(img_w * img_w + img_h * img_h));

  double best_quality = -1.0;
  std::vector<cv::Point> best_contour_global;

  for (cv::Mat mask : candidate_masks) {
    cv::morphologyEx(mask, mask, cv::MORPH_OPEN, morph_open_k);
    cv::morphologyEx(mask, mask, cv::MORPH_CLOSE, morph_open_k);

    std::vector<std::vector<cv::Point>> contours;
    cv::findContours(mask, contours, cv::RETR_EXTERNAL,
                     cv::CHAIN_APPROX_NONE); // APPROX_NONE para todos os pontos

    for (size_t i = 0; i < contours.size(); ++i) {
      const double area = cv::contourArea(contours[i]);
      if (area < min_area || area > max_area) {
        continue;
      }

      const cv::Rect bbox_local = cv::boundingRect(contours[i]);
      const bool border_touch =
          touchesBorder(bbox_local, roi_rect.width, roi_rect.height, 1);
      if (border_touch && area < (roi_area * 0.08)) {
        continue;
      }

      const double bbox_area = static_cast<double>(bbox_local.area());
      if (bbox_area <= 0.0) {
        continue;
      }

      const double fill_ratio = area / bbox_area;
      if (fill_ratio < 0.18) {
        continue;
      }

      std::vector<cv::Point> hull;
      cv::convexHull(contours[i], hull);
      const double hull_area = cv::contourArea(hull);
      if (hull_area <= 1.0) {
        continue;
      }
      const double solidity = area / hull_area;
      if (solidity < 0.58) {
        continue;
      }

      const cv::RotatedRect min_rect_local = cv::minAreaRect(contours[i]);
      const double min_rect_area =
          static_cast<double>(min_rect_local.size.width) *
          static_cast<double>(min_rect_local.size.height);
      if (min_rect_area <= 1.0) {
        continue;
      }

      const double rectangularity = area / min_rect_area;
      if (rectangularity < 0.32) {
        continue;
      }

      const cv::Moments moments = cv::moments(contours[i]);
      if (moments.m00 <= 1e-6) {
        continue;
      }

      const cv::Point2f center(
          static_cast<float>((moments.m10 / moments.m00) + roi_rect.x),
          static_cast<float>((moments.m01 / moments.m00) + roi_rect.y));

      const double dist_norm =
          cv::norm(center - image_center) / std::max(1.0, max_diag);
      const double area_norm = area / std::max(1.0, roi_area);
      const double perimeter = cv::arcLength(contours[i], true);
      const double compactness =
          (perimeter > 1.0) ? ((4.0 * CV_PI * area) / (perimeter * perimeter))
                            : 0.0;

      const double border_penalty = border_touch ? 0.08 : 0.0;

      const double quality = (0.36 * area_norm) + (0.18 * fill_ratio) +
                             (0.16 * solidity) + (0.14 * rectangularity) +
                             (0.10 * compactness) + (0.06 * (1.0 - dist_norm)) -
                             border_penalty;

      if (quality > best_quality) {
        best_quality = quality;
        best_contour_global.clear();
        best_contour_global.reserve(contours[i].size());
        for (const cv::Point &p : contours[i]) {
          best_contour_global.emplace_back(p.x + roi_rect.x, p.y + roi_rect.y);
        }
      }
    }

    if (best_quality >= 0.65) {
      break;
    }
  }

  if (!best_contour_global.empty()) {
    result.object_found = true;
    cv::RotatedRect min_rect = cv::minAreaRect(best_contour_global);

    cv::Point2f rect_vertices[4];
    min_rect.points(rect_vertices);
    const float rect_side_0 =
        distanceMm(rect_vertices[0], rect_vertices[1], metric_scale);
    const float rect_side_1 =
        distanceMm(rect_vertices[1], rect_vertices[2], metric_scale);
    result.width_mm = std::max(rect_side_0, rect_side_1);
    result.height_mm = std::min(rect_side_0, rect_side_1);
    perimeter_mm =
        static_cast<float>(cv::arcLength(best_contour_global, true)) *
        mm_per_px;
    area_mm2 = static_cast<float>(cv::contourArea(best_contour_global)) *
               metric_scale.mm_per_px_x * metric_scale.mm_per_px_y;

    const std::vector<cv::Point2f> polygon_raw =
        approximatePolygon(best_contour_global);

    // Criar edge map em coordenadas globais para line fitting preciso
    cv::Mat canny_global =
        cv::Mat::zeros(flat_image.rows, flat_image.cols, CV_8U);
    canny_roi.copyTo(canny_global(roi_rect));

    const std::vector<cv::Point2f> polygon_refined =
        refinePolygonWithLineIntersections(polygon_raw, best_contour_global,
                                           canny_global);
    std::vector<cv::Point2f> polygon =
        simplifyPolygonForTechnicalDrawing(polygon_refined, mm_per_px);

    std::vector<float> polygon_edges_mm;
    std::vector<float> polygon_angles_deg;
    float polygon_perimeter_mm = 0.0f;
    computePolygonMetrics(polygon, metric_scale, &polygon_edges_mm,
                          &polygon_angles_deg, &polygon_perimeter_mm);

    const std::vector<size_t> display_indices =
        selectDisplayedDimensionIndices(polygon_edges_mm, polygon_angles_deg);

    edges_mm = polygon_edges_mm;
    angles_deg = polygon_angles_deg;
    perimeter_mm = polygon_perimeter_mm;
    if (polygon.size() >= 3) {
      area_mm2 = std::fabs(polygonSignedArea(polygon)) *
                 metric_scale.mm_per_px_x * metric_scale.mm_per_px_y;
    }

    if (polygon.size() >= 3) {
      // ===== Detectar arcos nas arestas do polígono =====
      // Analisa cada aresta para ver se o contorno real desvia de uma reta
      const std::vector<EdgeArcInfo> edge_arcs =
          detectEdgeArcs(polygon, best_contour_global, metric_scale);

      // Preencher edges_mm apenas com arestas que NÃO são arcos
      edges_mm.clear();
      for (size_t i = 0; i < polygon_edges_mm.size(); ++i) {
        if (!edge_arcs[i].is_arc) {
          edges_mm.push_back(polygon_edges_mm[i]);
        }
      }

      // Detectar furos internos (círculos completos dentro da peça)
      const std::vector<HoleCircle> holes = detectHoleCircles(
          roi_gray, roi_rect, best_contour_global, metric_scale);

      // ===== Desenhar polígono: arcos suaves para curvas, retas para o resto =====
      for (size_t pi = 0; pi < polygon.size(); ++pi) {
        const cv::Point2f &pa = polygon[pi];
        const cv::Point2f &pb = polygon[(pi + 1) % polygon.size()];

        if (edge_arcs[pi].is_arc) {
          // Desenhar arco suave com cv::ellipse (alta resolução, antialiased)
          const EdgeArcInfo &arc = edge_arcs[pi];
          double ea_draw = static_cast<double>(arc.arc_end_deg);
          if (ea_draw <= static_cast<double>(arc.arc_start_deg)) {
            ea_draw += 360.0;
          }
          // Apagar a linha reta nessa região desenhando sobre ela com o fundo
          // (não necessário se desenharmos o arco por cima com espessura maior)
          cv::ellipse(
              flat_image,
              cv::Point(cvRound(arc.center.x), cvRound(arc.center.y)),
              cv::Size(cvRound(arc.radius_px), cvRound(arc.radius_px)), 0.0,
              static_cast<double>(arc.arc_start_deg), ea_draw,
              cv::Scalar(0, 0, 0), 2, cv::LINE_AA);
        } else {
          // Aresta reta
          cv::line(flat_image, pa, pb, cv::Scalar(0, 0, 0), 2, cv::LINE_AA);
        }
      }

      // ===== Anotar raio dos arcos detectados nas arestas =====
      // Agrupar arcos adjacentes para evitar anotações duplicadas
      std::vector<bool> arc_annotated(polygon.size(), false);
      for (size_t pi = 0; pi < polygon.size(); ++pi) {
        if (!edge_arcs[pi].is_arc || arc_annotated[pi]) {
          continue;
        }

        // Verificar se arcos adjacentes são do mesmo círculo (merge)
        const EdgeArcInfo &arc = edge_arcs[pi];
        cv::Point2f merged_center = arc.center;
        float merged_radius = arc.radius_px;
        arc_annotated[pi] = true;

        // Verificar próximas arestas adjacentes
        for (size_t j = (pi + 1) % polygon.size();
             j != pi && edge_arcs[j].is_arc;
             j = (j + 1) % polygon.size()) {
          const float center_dist = static_cast<float>(
              cv::norm(edge_arcs[j].center - merged_center));
          const float radius_diff =
              std::fabs(edge_arcs[j].radius_px - merged_radius);
          if (center_dist < merged_radius * 0.3f &&
              radius_diff < merged_radius * 0.2f) {
            // Mesmo arco — merge
            merged_center = (merged_center + edge_arcs[j].center) * 0.5f;
            merged_radius = (merged_radius + edge_arcs[j].radius_px) * 0.5f;
            arc_annotated[j] = true;
          } else {
            break;
          }
        }

        // Anotar o raio do arco
        const float r_mm = radiusMm(merged_radius, metric_scale);
        drawCircleDimension(flat_image, merged_center, merged_radius, r_mm);
        semi_circle_radii_mm.push_back(r_mm);
      }

      // ===== Desenhar furos internos (círculos completos) =====
      hole_radii_mm.clear();
      hole_radii_mm.reserve(holes.size());
      for (const HoleCircle &hole : holes) {
        const float r_mm = radiusMm(hole.radius_px, metric_scale);
        hole_radii_mm.push_back(r_mm);
        if (hole.is_arc) {
          double ea_draw = static_cast<double>(hole.arc_end_deg);
          if (ea_draw <= static_cast<double>(hole.arc_start_deg)) {
            ea_draw += 360.0;
          }
          cv::ellipse(
              flat_image,
              cv::Point(cvRound(hole.center.x), cvRound(hole.center.y)),
              cv::Size(cvRound(hole.radius_px), cvRound(hole.radius_px)), 0.0,
              static_cast<double>(hole.arc_start_deg), ea_draw,
              cv::Scalar(0, 0, 0), 2, cv::LINE_AA);
        } else {
          // Círculo completo
          cv::circle(flat_image,
                     cv::Point(cvRound(hole.center.x), cvRound(hole.center.y)),
                     cvRound(hole.radius_px), cv::Scalar(0, 0, 0), 2,
                     cv::LINE_AA);
        }
        drawCircleDimension(flat_image, hole.center, hole.radius_px, r_mm);
      }

      // ===== Anotar dimensões lineares (apenas arestas retas) =====
      for (size_t k = 0; k < display_indices.size(); ++k) {
        const size_t i = display_indices[k];
        if (i >= polygon.size() || i >= polygon_edges_mm.size()) {
          continue;
        }

        // Pular arestas que são arcos — não faz sentido mostrar comprimento
        if (edge_arcs[i].is_arc) {
          continue;
        }

        const cv::Point2f p0 = polygon[i];
        const cv::Point2f p1 = polygon[(i + 1) % polygon.size()];
        const int offset_dir = chooseOutsideOffsetDirection(polygon, p0, p1);
        drawDimensionLine(flat_image, p0, p1, polygon_edges_mm[i], offset_dir);
      }

      // ===== Anotar ângulos (apenas cantos entre arestas retas) =====
      for (const size_t i : display_indices) {
        if (i >= polygon.size() || i >= polygon_angles_deg.size()) {
          continue;
        }

        // Pular vértices que são junção de arco com reta
        const size_t prev_edge = (i + polygon.size() - 1) % polygon.size();
        if (edge_arcs[i].is_arc || edge_arcs[prev_edge].is_arc) {
          continue;
        }

        const cv::Point2f prev =
            polygon[(i + polygon.size() - 1) % polygon.size()];
        const cv::Point2f curr = polygon[i];
        const cv::Point2f next = polygon[(i + 1) % polygon.size()];

        const float e1 = static_cast<float>(cv::norm(prev - curr));
        const float e2 = static_cast<float>(cv::norm(next - curr));
        const float display_angle = (polygon_angles_deg[i] > 180.0f)
                                        ? (360.0f - polygon_angles_deg[i])
                                        : polygon_angles_deg[i];

        const float deviation_from_straight = std::fabs(180.0f - display_angle);
        if (e1 > 5.0f && e2 > 5.0f && display_angle >= 10.0f &&
            deviation_from_straight >= 8.0f) {
          drawAngleDimension(flat_image, curr, prev, next, display_angle);
        }
      }
    } else {
      for (int i = 0; i < 4; ++i) {
        cv::line(flat_image, rect_vertices[i], rect_vertices[(i + 1) % 4],
                 cv::Scalar(0, 0, 0), 2);
      }
    }

    // --- ADIÇÃO: Desenhar a bounding box (Largura e Altura Geral) em azul ---
    for (int i = 0; i < 4; ++i) {
      cv::line(flat_image, rect_vertices[i], rect_vertices[(i + 1) % 4],
               cv::Scalar(255, 0, 0), 2, cv::LINE_AA);
    }

    auto drawBBoxText = [&](cv::Point2f pos, float val) {
      char buf[64];
      snprintf(buf, sizeof(buf), "%.1f", val);
      std::string txt = buf;
      int baseline = 0;
      cv::Size sz =
          cv::getTextSize(txt, cv::FONT_HERSHEY_SIMPLEX, 0.6, 2, &baseline);
      cv::Point2f textPos = pos;
      textPos.x -= sz.width * 0.5f;
      textPos.y += sz.height * 0.5f;
      cv::rectangle(flat_image, textPos - cv::Point2f(4, sz.height + 4),
                    textPos + cv::Point2f(sz.width + 4, 5),
                    cv::Scalar(255, 255, 255), cv::FILLED);
      cv::putText(flat_image, txt, textPos, cv::FONT_HERSHEY_SIMPLEX, 0.6,
                  cv::Scalar(255, 0, 0), 2, cv::LINE_AA);
    };

    cv::Point2f bbox_mid_0 = (rect_vertices[0] + rect_vertices[1]) * 0.5f;
    cv::Point2f bbox_mid_1 = (rect_vertices[1] + rect_vertices[2]) * 0.5f;

    float dx0 = std::fabs(rect_vertices[0].x - rect_vertices[1].x);
    float dy0 = std::fabs(rect_vertices[0].y - rect_vertices[1].y);

    if (dx0 > dy0) {
      drawBBoxText(bbox_mid_0, rect_side_0);
      drawBBoxText(bbox_mid_1, rect_side_1);
    } else {
      drawBBoxText(bbox_mid_0, rect_side_0);
      drawBBoxText(bbox_mid_1, rect_side_1);
    }
    // -----------------------------------------------------------------------
  }

  // Salva a imagem processada para o Flutter mostrar
  cv::imwrite(output_path, flat_image);
  writeMeasurementDetailsJson(std::string(output_path) + ".json",
                              result.calibration_success, result.object_found,
                              edges_mm, angles_deg, hole_radii_mm,
                              semi_circle_radii_mm, perimeter_mm, area_mm2);

  return result;
}
}