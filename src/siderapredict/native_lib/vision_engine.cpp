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
constexpr float kWarpUpscale = 1.0f;
constexpr float kMinWarpOutputPx = 2400.0f;
constexpr float kMaxWarpOutputPx = 5200.0f;
constexpr float kMinDisplayEdgeMm = 4.0f;
constexpr float kMinAngleDeviationDeg = 6.0f;
constexpr float kMinVertexAngleDeg = 25.0f;
constexpr float kMaxExternalArcRadiusMm = 22.0f;
constexpr float kMinHoughCircleSupport = 0.28f;
constexpr float kMinContourCircleSupport = 0.30f;
constexpr float kMinContourCircularity = 0.48f;
constexpr float kElongatedCavityAspectRatio = 1.35f;

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

struct SlotInfo {
  cv::Point2f center;
  float width_mm = 0.0f;
  float length_mm = 0.0f;
  float angle_deg = 0.0f;
  float width_px = 0.0f;
  float length_px = 0.0f;
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

void drawFilledContourMask(const std::vector<cv::Point> &contour,
                           cv::Mat *mask) {
  if (mask == nullptr || mask->empty() || contour.empty()) {
    return;
  }
  const std::vector<std::vector<cv::Point>> contours = {contour};
  cv::drawContours(*mask, contours, -1, cv::Scalar(255), cv::FILLED);
}

float distanceToContour(const std::vector<cv::Point> &contour,
                        const cv::Point2f &point) {
  if (contour.empty()) {
    return -std::numeric_limits<float>::max();
  }
  return static_cast<float>(cv::pointPolygonTest(contour, point, true));
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

float normalizeAngle360(float angle_deg) {
  while (angle_deg < 0.0f) {
    angle_deg += 360.0f;
  }
  while (angle_deg >= 360.0f) {
    angle_deg -= 360.0f;
  }
  return angle_deg;
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

bool isSameHoleCandidate(const HoleCircle &a, const HoleCircle &b) {
  if (a.radius_px <= 0.0f || b.radius_px <= 0.0f) {
    return false;
  }

  const float center_dist = static_cast<float>(cv::norm(a.center - b.center));
  const float max_radius = std::max(a.radius_px, b.radius_px);
  const float min_radius = std::min(a.radius_px, b.radius_px);
  const float radius_dist = std::fabs(a.radius_px - b.radius_px);

  const bool similar_radius =
      radius_dist <= std::max(2.0f, 0.20f * (a.radius_px + b.radius_px));
  const bool same_center =
      center_dist <= std::max(3.0f, 0.42f * max_radius);
  const bool nested_candidate =
      center_dist <= std::max(3.0f, 0.30f * max_radius) &&
      min_radius >= max_radius * 0.42f;

  return (same_center && similar_radius) || nested_candidate;
}

bool shouldReplaceHoleCandidate(const HoleCircle &current,
                                const HoleCircle &candidate) {
  if (current.is_arc != candidate.is_arc) {
    if (!candidate.is_arc && candidate.score >= current.score * 0.45f) {
      return true;
    }
    if (candidate.is_arc && current.score >= candidate.score * 0.45f) {
      return false;
    }
  }

  if (candidate.radius_px > current.radius_px * 1.12f &&
      candidate.score >= current.score * 0.70f) {
    return true;
  }

  return candidate.score > current.score;
}

void mergeCircleCandidate(std::vector<HoleCircle> *circles,
                          const HoleCircle &candidate) {
  if (circles == nullptr || candidate.radius_px <= 0.0f) {
    return;
  }

  for (HoleCircle &existing : *circles) {
    if (isSameHoleCandidate(existing, candidate)) {
      if (shouldReplaceHoleCandidate(existing, candidate)) {
        existing = candidate;
      }
      return;
    }
  }

  circles->push_back(candidate);
}

void consolidateHoleCandidates(std::vector<HoleCircle> *circles) {
  if (circles == nullptr || circles->size() < 2U) {
    return;
  }

  std::sort(circles->begin(), circles->end(),
            [](const HoleCircle &a, const HoleCircle &b) {
              if (a.is_arc != b.is_arc) {
                return !a.is_arc;
              }
              return a.score > b.score;
            });

  std::vector<HoleCircle> consolidated;
  consolidated.reserve(circles->size());
  for (const HoleCircle &candidate : *circles) {
    bool merged = false;
    for (HoleCircle &existing : consolidated) {
      if (!isSameHoleCandidate(existing, candidate)) {
        continue;
      }
      if (shouldReplaceHoleCandidate(existing, candidate)) {
        existing = candidate;
      }
      merged = true;
      break;
    }
    if (!merged) {
      consolidated.push_back(candidate);
    }
  }

  *circles = consolidated;
}

std::vector<int> sampleCircleAngularSupport(const cv::Mat &edge_map,
                                            const cv::Point2f &center,
                                            float radius) {
  constexpr int kSamples = 360;
  std::vector<int> support(kSamples, 0);
  if (edge_map.empty()) {
    return support;
  }

  if (radius <= 0.0f) {
    return support;
  }

  const int radial_tol =
      std::max(2, std::min(5, static_cast<int>(std::round(radius * 0.045f))));
  for (int i = 0; i < kSamples; ++i) {
    const float theta = static_cast<float>((2.0 * CV_PI * i) / kSamples);
    const float ct = std::cos(theta);
    const float st = std::sin(theta);

    for (int dr = -radial_tol; dr <= radial_tol && support[i] == 0; ++dr) {
      const float sample_radius = std::max(1.0f, radius + static_cast<float>(dr));
      const int x = cvRound(center.x + (ct * sample_radius));
      const int y = cvRound(center.y + (st * sample_radius));

      for (int dy = -1; dy <= 1 && support[i] == 0; ++dy) {
        for (int dx = -1; dx <= 1; ++dx) {
          const int xx = x + dx;
          const int yy = y + dy;
          if (xx < 0 || yy < 0 || xx >= edge_map.cols || yy >= edge_map.rows) {
            continue;
          }
          if (edge_map.at<unsigned char>(yy, xx) > 0U) {
            support[i] = 1;
            break;
          }
        }
      }
    }
  }

  return support;
}

void closeSmallAngularGaps(std::vector<int> *support, int max_gap_deg) {
  if (support == nullptr || support->empty() || max_gap_deg <= 0) {
    return;
  }

  const int n = static_cast<int>(support->size());
  std::vector<int> closed = *support;
  for (int i = 0; i < n; ++i) {
    if ((*support)[i] != 0) {
      continue;
    }

    int len = 0;
    while (len < n && (*support)[(i + len) % n] == 0) {
      ++len;
    }

    if (len <= max_gap_deg) {
      const int prev = (i - 1 + n) % n;
      const int next = (i + len) % n;
      if ((*support)[prev] != 0 && (*support)[next] != 0) {
        for (int k = 0; k < len; ++k) {
          closed[(i + k) % n] = 1;
        }
      }
    }
    i += std::max(0, len - 1);
  }
  *support = closed;
}

int countAngularSupport(const std::vector<int> &support) {
  int total = 0;
  for (const int v : support) {
    total += (v != 0) ? 1 : 0;
  }
  return total;
}

void longestAngularRun(const std::vector<int> &support, int *start, int *length) {
  if (start == nullptr || length == nullptr || support.empty()) {
    return;
  }

  const int n = static_cast<int>(support.size());
  *start = 0;
  *length = 0;
  for (int s = 0; s < n; ++s) {
    if (support[s] == 0) {
      continue;
    }
    int len = 0;
    while (len < n && support[(s + len) % n] != 0) {
      ++len;
    }
    if (len > *length) {
      *length = len;
      *start = s;
    }
    s += std::max(0, len - 1);
  }
}

float circleEdgeSupportRatio(const cv::Mat &edge_map, const cv::Vec3f &circle) {
  std::vector<int> support = sampleCircleAngularSupport(
      edge_map, cv::Point2f(circle[0], circle[1]), circle[2]);
  closeSmallAngularGaps(&support, 3);
  return static_cast<float>(countAngularSupport(support)) /
         static_cast<float>(std::max<size_t>(1U, support.size()));
}

float circleMaskFillRatio(const cv::Mat &mask, const cv::Point2f &center,
                          float radius) {
  if (mask.empty() || radius <= 1.0f) {
    return 0.0f;
  }

  const int min_x = std::max(0, cvFloor(center.x - radius));
  const int max_x = std::min(mask.cols - 1, cvCeil(center.x + radius));
  const int min_y = std::max(0, cvFloor(center.y - radius));
  const int max_y = std::min(mask.rows - 1, cvCeil(center.y + radius));
  const float radius_sq = radius * radius;
  int total = 0;
  int filled = 0;

  for (int y = min_y; y <= max_y; ++y) {
    for (int x = min_x; x <= max_x; ++x) {
      const float dx = static_cast<float>(x) - center.x;
      const float dy = static_cast<float>(y) - center.y;
      if ((dx * dx + dy * dy) > radius_sq) {
        continue;
      }
      ++total;
      if (mask.at<unsigned char>(y, x) > 0U) {
        ++filled;
      }
    }
  }

  if (total == 0) {
    return 0.0f;
  }
  return static_cast<float>(filled) / static_cast<float>(total);
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
  std::vector<int> support =
      sampleCircleAngularSupport(edge_map, center_local, radius);
  closeSmallAngularGaps(&support, std::max(4, static_cast<int>(radius * 0.035f)));

  const int total = countAngularSupport(support);
  const float ratio = static_cast<float>(total) / static_cast<float>(N);

  // Suporte quase completo é círculo, não arco. Suporte fraco vira ruído.
  if (ratio >= 0.86f || ratio < 0.16f) {
    return false;
  }

  int best_start = 0;
  int best_len = 0;
  longestAngularRun(support, &best_start, &best_len);

  if (best_len < 70 || best_len > 330) {
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

bool fitCircleLeastSquares(const std::vector<cv::Point> &pts,
                           cv::Point2f *center, float *radius);

bool fitCircleRobust(const std::vector<cv::Point> &pts, cv::Point2f *center,
                     float *radius, float *mean_abs_error,
                     float *inlier_ratio);

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
      std::max(2, static_cast<int>(std::round(0.8f / mm_per_px)));
  const int max_radius =
      std::max(min_radius + 2, static_cast<int>(std::round(80.0f / mm_per_px)));

  std::vector<cv::Point> outer_local;
  outer_local.reserve(outer_contour.size());
  for (const cv::Point &p : outer_contour) {
    outer_local.emplace_back(p.x - roi_rect.x, p.y - roi_rect.y);
  }

  cv::Mat piece_mask = cv::Mat::zeros(roi_gray.size(), CV_8U);
  if (!outer_local.empty()) {
    drawFilledContourMask(outer_local, &piece_mask);
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

  // --- ADIÇÃO: Detecção de furos escuros (slots/pílulas) dentro da peça ---
  // Tenta encontrar regiões significativamente mais escuras que a média da peça usando threshold adaptativo
  cv::Mat internal_dark;
  cv::adaptiveThreshold(roi_gray, internal_dark, 255, cv::ADAPTIVE_THRESH_GAUSSIAN_C, cv::THRESH_BINARY_INV, 45, 10);
  // Dilatar um pouco para fundir possíveis ruídos internos
  cv::Mat internal_holes;
  cv::bitwise_and(internal_dark, piece_mask, internal_holes);

  // Unir com a cavity_mask original (que pega furos claros/vazados)
  cv::Mat combined_holes;
  cv::bitwise_or(cavity_mask, internal_holes, combined_holes);
  cv::morphologyEx(combined_holes, combined_holes, cv::MORPH_CLOSE, hole_open);
  
  // Reatribuir para cavity_mask para que o resto da lógica (contours, circularity) funcione
  cavity_mask = combined_holes;

  cv::Mat blur;
  cv::medianBlur(roi_gray, blur, 5);
  cv::GaussianBlur(blur, blur, cv::Size(3, 3), 0.0);

  // HoughCircles é usado como gerador de candidatos; a aceitação vem do suporte
  // angular e do merge com contornos ajustados por círculo.
  std::vector<cv::Vec3f> hough;
  cv::HoughCircles(blur, hough, cv::HOUGH_GRADIENT, 1.2,
                   std::max(8, min_radius * 2), 90, 20, min_radius, max_radius);

  for (const cv::Vec3f &c : hough) {
    const int cx = cvRound(c[0]);
    const int cy = cvRound(c[1]);
    if (cx < 0 || cy < 0 || cx >= cavity_mask.cols || cy >= cavity_mask.rows) {
      continue;
    }

    const float support = circleEdgeSupportRatio(edge_map, c);
    if (support < kMinHoughCircleSupport) {
      continue;
    }

    const bool center_on_cavity = cavity_mask.at<unsigned char>(cy, cx) > 0U;
    const float cavity_fill =
        circleMaskFillRatio(cavity_mask, cv::Point2f(c[0], c[1]),
                            std::max(2.0f, c[2] * 0.70f));
    if (!center_on_cavity && cavity_fill < 0.08f && support < 0.55f) {
      continue;
    }

    HoleCircle candidate;
    candidate.center = cv::Point2f(c[0] + roi_rect.x, c[1] + roi_rect.y);
    candidate.radius_px = c[2];
    if (candidate.radius_px <= 0.0f) {
      continue;
    }

    const float contour_dist = distanceToContour(outer_contour, candidate.center);
    if (contour_dist <= std::max(1.0f, candidate.radius_px * 0.08f)) {
      continue;
    }

    // Detectar se é arco parcial usando edge_map local da ROI.
    if (support < 0.86f) {
      float arc_s = 0.0f;
      float arc_e = 360.0f;
      if (computeArcAngles(edge_map, cv::Point2f(c[0], c[1]), c[2], &arc_s,
                           &arc_e)) {
        candidate.is_arc = true;
        candidate.arc_start_deg = arc_s;
        candidate.arc_end_deg = arc_e;
      } else {
        // Se não tem suporte para círculo completo e falhou no teste
        // de arco, descarta
        continue;
      }
    }

    candidate.score = candidate.radius_px * (0.6f + support);
    mergeCircleCandidate(&circles, candidate);
  }

  // Removido o segundo passe de arcos para evitar que quinas e sujeiras sejam
  // detectadas como furos.

  std::vector<std::vector<cv::Point>> hole_contours;
  cv::findContours(cavity_mask, hole_contours, cv::RETR_LIST,
                   cv::CHAIN_APPROX_NONE);
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

    const float perimeter = static_cast<float>(cv::arcLength(contour, true));
    if (perimeter < 1.0f) {
      continue;
    }

    const float circularity =
        static_cast<float>((4.0 * CV_PI * area) / (perimeter * perimeter));
    if (circularity < kMinContourCircularity) {
      continue;
    }

    const cv::RotatedRect rr = cv::minAreaRect(contour);
    const float side_a = std::max(1.0f, rr.size.width);
    const float side_b = std::max(1.0f, rr.size.height);
    const float aspect = std::max(side_a, side_b) / std::min(side_a, side_b);
    if (aspect > kElongatedCavityAspectRatio && circularity < 0.90f) {
      // Rasgos/pílulas alongados são tratados por detectSlots; aqui eles
      // geram falsos círculos nas extremidades.
      continue;
    }

    float fit_error = 0.0f;
    float inlier_ratio = 0.0f;
    float radius_px = 0.0f;
    cv::Point2f c_local;
    if (!fitCircleRobust(contour, &c_local, &radius_px, &fit_error,
                         &inlier_ratio)) {
      continue;
    }
    if (radius_px < static_cast<float>(min_radius) ||
        radius_px > static_cast<float>(max_radius)) {
      continue;
    }

    const float area_ratio =
        static_cast<float>(area / (CV_PI * radius_px * radius_px));
    if (area_ratio < 0.36f || area_ratio > 1.30f) {
      continue;
    }

    HoleCircle candidate;
    candidate.center =
        cv::Point2f(c_local.x + static_cast<float>(roi_rect.x),
                    c_local.y + static_cast<float>(roi_rect.y));
    const float contour_dist = distanceToContour(outer_contour, candidate.center);
    if (contour_dist <= std::max(1.0f, radius_px * 0.08f)) {
      continue;
    }

    const cv::Vec3f fitted_circle(c_local.x, c_local.y, radius_px);
    const float support = circleEdgeSupportRatio(edge_map, fitted_circle);
    if (support < kMinContourCircleSupport) {
      continue;
    }
    if (area_ratio < 0.58f && support < 0.38f) {
      continue;
    }

    candidate.radius_px = radius_px;
    if (support < 0.86f && circularity < 0.88f) {
      float arc_s = 0.0f;
      float arc_e = 360.0f;
      if (computeArcAngles(edge_map, c_local, radius_px, &arc_s, &arc_e)) {
        candidate.is_arc = true;
        candidate.arc_start_deg = arc_s;
        candidate.arc_end_deg = arc_e;
      } else {
        // Não é círculo completo nem arco válido
        continue;
      }
    }
    candidate.score =
        radius_px * (0.45f + circularity + support + (0.25f * inlier_ratio)) -
        fit_error;
    mergeCircleCandidate(&circles, candidate);
  }

  consolidateHoleCandidates(&circles);
  std::sort(circles.begin(), circles.end(),
            [](const HoleCircle &a, const HoleCircle &b) {
              if (a.is_arc != b.is_arc) {
                return !a.is_arc;
              }
              return a.score > b.score;
            });


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

bool estimateBoardQuadFromMarkers(
    const std::vector<std::vector<cv::Point2f>> &marker_corners,
    std::vector<cv::Point2f> *quad) {
  if (quad == nullptr || marker_corners.size() < 4) {
    return false;
  }

  std::vector<cv::Point2f> all_corners;
  all_corners.reserve(marker_corners.size() * 4U);
  for (const auto &marker : marker_corners) {
    if (marker.size() != 4) {
      continue;
    }
    for (const auto &p : marker) {
      all_corners.push_back(p);
    }
  }

  if (all_corners.size() < 4) {
    return false;
  }

  std::vector<cv::Point2f> hull;
  cv::convexHull(all_corners, hull);
  if (hull.size() < 4) {
    return false;
  }

  const double perimeter = cv::arcLength(hull, true);
  std::vector<cv::Point2f> approx;
  const float eps_candidates[] = {0.015f, 0.02f, 0.03f, 0.04f, 0.05f};
  for (float eps_ratio : eps_candidates) {
    const double eps = std::max(2.0, perimeter * eps_ratio);
    cv::approxPolyDP(hull, approx, eps, true);
    if (approx.size() == 4) {
      *quad = approx;
      return true;
    }
  }

  cv::RotatedRect rect = cv::minAreaRect(hull);
  cv::Point2f rect_pts[4];
  rect.points(rect_pts);
  quad->assign(rect_pts, rect_pts + 4);
  return true;
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
approximatePolygon(const std::vector<cv::Point> &contour, bool is_gallery) {
  std::vector<cv::Point2f> polygon;
  if (contour.size() < 3) {
    return polygon;
  }

  const double perimeter = cv::arcLength(contour, true);
  std::vector<cv::Point> approx;
  // Reduzido o fator de 0.005 para 0.0035 para maior fidelidade aos detalhes
  double epsilon = std::max(1.5, perimeter * (is_gallery ? 0.006 : 0.0035));
  cv::approxPolyDP(contour, approx, epsilon, true);

  if (approx.size() < 3) {
    cv::RotatedRect rect = cv::minAreaRect(contour);
    cv::Point2f rect_pts[4];
    rect.points(rect_pts);
    polygon.assign(rect_pts, rect_pts + 4);
  } else {
    polygon.reserve(approx.size());
    // Refinamento: snap para os pontos reais do contorno original
    for (const cv::Point &p_approx : approx) {
      cv::Point2f best_p = static_cast<cv::Point2f>(p_approx);
      double min_dist = 1e10;
      
      // Busca local no contorno original para encontrar o ponto exato da aresta
      // (approxPolyDP às vezes desloca o ponto ligeiramente para fora da curva real)
      for (const cv::Point &p_orig : contour) {
        double dx = p_approx.x - p_orig.x;
        double dy = p_approx.y - p_orig.y;
        double d2 = dx*dx + dy*dy;
        if (d2 < min_dist) {
          min_dist = d2;
          best_p = static_cast<cv::Point2f>(p_orig);
        }
      }
      polygon.push_back(best_p);
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
                                   float mm_per_px, bool is_gallery) {
  if (polygon.size() < 3) {
    return polygon;
  }

  std::vector<cv::Point2f> simplified = polygon;
  const float safe_mm_per_px = std::max(1e-4f, mm_per_px);
  // Reduzido para preservar dentes e detalhes pequenos
  const float min_edge_px = std::max(1.5f, (is_gallery ? 3.0f : 1.5f) / safe_mm_per_px);
  const float collinear_tol_deg = is_gallery ? 5.0f : 3.5f;

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

      const float triangle_height =
          std::fabs(cross2d(next - prev, curr - prev)) / std::max(1.0f, len_skip);

      // Remove só picos rasos de ruído. Ângulos agudos com altura real devem
      // sobreviver para medição.
      const bool is_spike =
          (angle < 45.0f) && (len_prev < min_edge_px * 2.0f) &&
          (len_next < min_edge_px * 2.0f) &&
          (triangle_height < min_edge_px * 0.75f);

      if (nearly_collinear || tiny_kink || is_spike) {
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

  const float tol_px = std::max(3.0f, edge_len * 0.045f);
  const float endpoint_trim =
      (edge_len > 30.0f) ? std::min(0.08f, std::max(0.02f, 6.0f / edge_len))
                         : 0.0f;
  std::vector<cv::Point2f> samples;
  samples.reserve(contour.size());

  for (const cv::Point &cp : contour) {
    const cv::Point2f p(static_cast<float>(cp.x), static_cast<float>(cp.y));
    const cv::Point2f ap = p - edge_start;
    const float t = (ap.x * edge_vec.x + ap.y * edge_vec.y) / edge_len_sq;
    if (t < endpoint_trim || t > (1.0f - endpoint_trim)) {
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
  const float endpoint_trim =
      (edge_len > 30.0f) ? std::min(0.08f, std::max(0.02f, 6.0f / edge_len))
                         : 0.0f;

  // Varrer pixels de borda Canny em uma faixa estreita ao redor da aresta
  const float tol_px = std::max(4.0f, edge_len * 0.05f);
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
      if (t < endpoint_trim || t > (1.0f - endpoint_trim))
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
    // Calcular ângulo entre as retas para determinar sensibilidade
    const float dot = prev_line.dir.x * curr_line.dir.x + prev_line.dir.y * curr_line.dir.y;
    const float angle_deg = std::acos(clampUnit(std::abs(dot))) * 180.0f / static_cast<float>(CV_PI);
    const float display_angle = (angle_deg > 180.0f) ? (360.0f - angle_deg) : angle_deg;
    // Se o ângulo é agudo (< 70), permitimos um shift maior pois a interseção
    // é geometricamente mais sensível
    const float shift_mult = (display_angle < 70.0f) ? 0.45f : 0.28f;
    const float max_shift = std::max(4.0f, local_span * shift_mult);

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
    const float d = static_cast<float>(
        cv::norm(cv::Point2f(static_cast<float>(contour[i].x),
                             static_cast<float>(contour[i].y)) -
                 pt));
    if (d < best_dist) {
      best_dist = d;
      best = i;
    }
  }
  return best;
}

std::vector<cv::Point>
extractContourSegment(const std::vector<cv::Point> &contour, size_t idx_a,
                      size_t idx_b) {
  const size_t n = contour.size();
  if (n == 0)
    return {};

  // Caminho mais curto entre idx_a e idx_b (frente ou trás)
  size_t fwd_len =
      (idx_b >= idx_a) ? (idx_b - idx_a + 1) : (n - idx_a + idx_b + 1);
  size_t bwd_len =
      (idx_a >= idx_b) ? (idx_a - idx_b + 1) : (n - idx_b + idx_a + 1);

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
  double det = A11 * (A22 * A33 - A23 * A32) - A12 * (A21 * A33 - A23 * A31) +
               A13 * (A21 * A32 - A22 * A31);
  if (std::fabs(det) < 1e-10) {
    return false;
  }

  double a = (B1 * (A22 * A33 - A23 * A32) - A12 * (B2 * A33 - A23 * B3) +
              A13 * (B2 * A32 - A22 * B3)) /
             det;
  double b = (A11 * (B2 * A33 - A23 * B3) - B1 * (A21 * A33 - A23 * A31) +
              A13 * (A21 * B3 - B2 * A31)) /
             det;
  double c = (A11 * (A22 * B3 - B2 * A32) - A12 * (A21 * B3 - B2 * A31) +
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
  if (avg_err > *radius * 0.15) {
    return false;
  }

  return true;
}

bool fitCircleRobust(const std::vector<cv::Point> &pts, cv::Point2f *center,
                     float *radius, float *mean_abs_error,
                     float *inlier_ratio) {
  if (pts.size() < 8 || center == nullptr || radius == nullptr) {
    return false;
  }

  std::vector<cv::Point> working = pts;
  cv::Point2f c;
  float r = 0.0f;

  for (int iter = 0; iter < 3; ++iter) {
    if (!fitCircleLeastSquares(working, &c, &r) || r <= 0.0f) {
      return false;
    }

    std::vector<cv::Point> inliers;
    inliers.reserve(working.size());
    const float residual_tol = std::max(2.0f, r * 0.10f);
    for (const cv::Point &p : pts) {
      const float d =
          static_cast<float>(cv::norm(cv::Point2f(static_cast<float>(p.x),
                                                  static_cast<float>(p.y)) -
                                      c));
      if (std::fabs(d - r) <= residual_tol) {
        inliers.push_back(p);
      }
    }

    if (inliers.size() < 8U ||
        inliers.size() < static_cast<size_t>(pts.size() * 0.52f)) {
      break;
    }
    if (inliers.size() == working.size()) {
      working = inliers;
      break;
    }
    working = inliers;
  }

  if (!fitCircleLeastSquares(working, &c, &r) || r <= 0.0f) {
    return false;
  }

  double err_sum = 0.0;
  int inliers = 0;
  const float residual_tol = std::max(2.0f, r * 0.12f);
  for (const cv::Point &p : pts) {
    const float d =
        static_cast<float>(cv::norm(cv::Point2f(static_cast<float>(p.x),
                                                static_cast<float>(p.y)) -
                                    c));
    const float err = std::fabs(d - r);
    err_sum += err;
    if (err <= residual_tol) {
      ++inliers;
    }
  }

  const float mean_err =
      static_cast<float>(err_sum / static_cast<double>(pts.size()));
  const float ratio =
      static_cast<float>(inliers) / static_cast<float>(std::max<size_t>(1U, pts.size()));
  if (mean_err > std::max(2.2f, r * 0.075f) || ratio < 0.58f) {
    return false;
  }

  *center = c;
  *radius = r;
  if (mean_abs_error != nullptr) {
    *mean_abs_error = mean_err;
  }
  if (inlier_ratio != nullptr) {
    *inlier_ratio = ratio;
  }
  return true;
}

bool compatibleArcModels(const EdgeArcInfo &a, const EdgeArcInfo &b) {
  if (!a.is_arc || !b.is_arc || a.radius_px <= 0.0f || b.radius_px <= 0.0f) {
    return false;
  }
  const float avg_radius = (a.radius_px + b.radius_px) * 0.5f;
  const float center_dist = static_cast<float>(cv::norm(a.center - b.center));
  const float radius_diff = std::fabs(a.radius_px - b.radius_px);
  return center_dist <= std::max(4.0f, avg_radius * 0.18f) &&
         radius_diff <= std::max(3.0f, avg_radius * 0.12f);
}

bool buildArcInfoFromCircle(const std::vector<cv::Point2f> &polygon,
                            const std::vector<cv::Point> &contour,
                            size_t edge_index, const cv::Point2f &center,
                            float radius, EdgeArcInfo *out) {
  if (out == nullptr || polygon.size() < 3 || radius <= 1.0f) {
    return false;
  }

  const size_t n = polygon.size();
  const cv::Point2f &pa = polygon[edge_index];
  const cv::Point2f &pb = polygon[(edge_index + 1U) % n];
  const float edge_len = static_cast<float>(cv::norm(pb - pa));
  if (edge_len < 3.0f || edge_len > radius * 1.65f) {
    return false;
  }

  const float endpoint_tol = std::max(2.0f, radius * 0.10f);
  const float da = std::fabs(static_cast<float>(cv::norm(pa - center)) - radius);
  const float db = std::fabs(static_cast<float>(cv::norm(pb - center)) - radius);
  if (da > endpoint_tol || db > endpoint_tol) {
    return false;
  }

  const size_t idx_a = nearestContourIdx(contour, pa);
  const size_t idx_b = nearestContourIdx(contour, pb);
  std::vector<cv::Point> seg = extractContourSegment(contour, idx_a, idx_b);
  if (seg.size() < 3U) {
    return false;
  }

  double err_sum = 0.0;
  float max_err = 0.0f;
  for (const cv::Point &cp : seg) {
    const cv::Point2f p(static_cast<float>(cp.x), static_cast<float>(cp.y));
    const float err = std::fabs(static_cast<float>(cv::norm(p - center)) - radius);
    err_sum += static_cast<double>(err);
    max_err = std::max(max_err, err);
  }
  const float mean_err =
      static_cast<float>(err_sum / static_cast<double>(seg.size()));
  if (mean_err > std::max(1.4f, radius * 0.045f) ||
      max_err > std::max(2.6f, radius * 0.09f)) {
    return false;
  }

  const cv::Point2f va = pa - center;
  const cv::Point2f vb = pb - center;
  const float va_len = static_cast<float>(cv::norm(va));
  const float vb_len = static_cast<float>(cv::norm(vb));
  if (va_len < 1.0f || vb_len < 1.0f) {
    return false;
  }
  const float arc_angle_deg =
      std::acos(clampUnit((va.x * vb.x + va.y * vb.y) / (va_len * vb_len))) *
      180.0f / static_cast<float>(CV_PI);
  if (arc_angle_deg < 5.0f || arc_angle_deg > 175.0f) {
    return false;
  }

  float sa_deg = normalizeAngle360(
      std::atan2(pa.y - center.y, pa.x - center.x) * 180.0f /
      static_cast<float>(CV_PI));
  float ea_deg = normalizeAngle360(
      std::atan2(pb.y - center.y, pb.x - center.x) * 180.0f /
      static_cast<float>(CV_PI));
  const cv::Point &mid_pt = seg[seg.size() / 2U];
  const float mid_deg = normalizeAngle360(
      std::atan2(static_cast<float>(mid_pt.y) - center.y,
                 static_cast<float>(mid_pt.x) - center.x) *
      180.0f / static_cast<float>(CV_PI));

  auto angleBetween = [](float start, float end, float test) -> bool {
    if (start <= end) {
      return test >= start && test <= end;
    }
    return test >= start || test <= end;
  };
  if (!angleBetween(sa_deg, ea_deg, mid_deg)) {
    std::swap(sa_deg, ea_deg);
  }

  out->is_arc = true;
  out->center = center;
  out->radius_px = radius;
  out->arc_start_deg = sa_deg;
  out->arc_end_deg = ea_deg;
  out->arc_points = seg;
  return true;
}

void bridgeShortArcGaps(const std::vector<cv::Point2f> &polygon,
                        const std::vector<cv::Point> &contour,
                        std::vector<EdgeArcInfo> *arcs) {
  if (arcs == nullptr || polygon.size() < 3 || arcs->size() != polygon.size()) {
    return;
  }

  const size_t n = polygon.size();
  for (int pass = 0; pass < 3; ++pass) {
    bool changed = false;
    for (size_t i = 0; i < n; ++i) {
      if ((*arcs)[i].is_arc) {
        continue;
      }

      const size_t prev = (i + n - 1U) % n;
      const size_t next = (i + 1U) % n;
      cv::Point2f ref_center;
      float ref_radius = 0.0f;
      bool has_ref = false;

      if ((*arcs)[prev].is_arc && (*arcs)[next].is_arc &&
          compatibleArcModels((*arcs)[prev], (*arcs)[next])) {
        ref_center = ((*arcs)[prev].center + (*arcs)[next].center) * 0.5f;
        ref_radius = ((*arcs)[prev].radius_px + (*arcs)[next].radius_px) * 0.5f;
        has_ref = true;
      } else if ((*arcs)[prev].is_arc) {
        ref_center = (*arcs)[prev].center;
        ref_radius = (*arcs)[prev].radius_px;
        has_ref = true;
      } else if ((*arcs)[next].is_arc) {
        ref_center = (*arcs)[next].center;
        ref_radius = (*arcs)[next].radius_px;
        has_ref = true;
      }

      if (!has_ref || ref_radius <= 1.0f) {
        continue;
      }

      EdgeArcInfo bridged;
      if (buildArcInfoFromCircle(polygon, contour, i, ref_center, ref_radius,
                                 &bridged)) {
        (*arcs)[i] = bridged;
        changed = true;
      }
    }
    if (!changed) {
      break;
    }
  }
}

float clockwiseArcSpanDeg(float start, float end) {
  float span = normalizeAngle360(end - start);
  if (span <= 0.0f) {
    span += 360.0f;
  }
  return span;
}

float smallerArcSpanDeg(float a, float b) {
  const float cw = clockwiseArcSpanDeg(a, b);
  return std::min(cw, 360.0f - cw);
}

float vertexInteriorAngleDeg(const cv::Point2f &prev, const cv::Point2f &curr,
                             const cv::Point2f &next) {
  const cv::Point2f v1 = prev - curr;
  const cv::Point2f v2 = next - curr;
  const float n1 = static_cast<float>(cv::norm(v1));
  const float n2 = static_cast<float>(cv::norm(v2));
  if (n1 < 1e-3f || n2 < 1e-3f) {
    return 180.0f;
  }
  return std::acos(clampUnit((v1.x * v2.x + v1.y * v2.y) / (n1 * n2))) *
         180.0f / static_cast<float>(CV_PI);
}

bool buildArcRunFromPolygon(const std::vector<cv::Point2f> &polygon,
                            const std::vector<cv::Point> &contour,
                            size_t start_edge, size_t edge_count,
                            float mm_per_px,
                            EdgeArcInfo *out) {
  if (out == nullptr || polygon.size() < 3 || edge_count < 2 ||
      edge_count >= polygon.size()) {
    return false;
  }

  const size_t n = polygon.size();
  const size_t end_vertex = (start_edge + edge_count) % n;
  const cv::Point2f &pa = polygon[start_edge];
  const cv::Point2f &pb = polygon[end_vertex];
  const size_t idx_a = nearestContourIdx(contour, pa);
  const size_t idx_b = nearestContourIdx(contour, pb);
  std::vector<cv::Point> seg = extractContourSegment(contour, idx_a, idx_b);
  if (seg.size() < 12U) {
    return false;
  }

  cv::Point2f center;
  float radius = 0.0f;
  float fit_error = 0.0f;
  float inlier_ratio = 0.0f;
  if (!fitCircleRobust(seg, &center, &radius, &fit_error, &inlier_ratio)) {
    return false;
  }
  if (radius * mm_per_px > kMaxExternalArcRadiusMm) {
    return false;
  }

  float chord_sum = 0.0f;
  float max_edge = 0.0f;
  float min_edge = std::numeric_limits<float>::max();
  float vertex_err_sum = 0.0f;
  float max_vertex_err = 0.0f;
  int positive_turns = 0;
  int negative_turns = 0;
  for (size_t k = 0; k <= edge_count; ++k) {
    const cv::Point2f &v = polygon[(start_edge + k) % n];
    const float err = std::fabs(static_cast<float>(cv::norm(v - center)) - radius);
    vertex_err_sum += err;
    max_vertex_err = std::max(max_vertex_err, err);
    if (k < edge_count) {
      const cv::Point2f &next = polygon[(start_edge + k + 1U) % n];
      const float edge_len = static_cast<float>(cv::norm(next - v));
      chord_sum += edge_len;
      max_edge = std::max(max_edge, edge_len);
      min_edge = std::min(min_edge, edge_len);
    }
    if (k > 0U && k < edge_count) {
      const cv::Point2f &prev = polygon[(start_edge + k - 1U) % n];
      const cv::Point2f &next = polygon[(start_edge + k + 1U) % n];
      const float angle = vertexInteriorAngleDeg(prev, v, next);
      if (angle < 118.0f) {
        return false;
      }
      const float turn = cross2d(v - prev, next - v);
      if (turn > 1e-3f) {
        ++positive_turns;
      } else if (turn < -1e-3f) {
        ++negative_turns;
      }
    }
  }

  if (positive_turns > 0 && negative_turns > 0) {
    return false;
  }

  const float mean_vertex_err =
      vertex_err_sum / static_cast<float>(edge_count + 1U);
  if (mean_vertex_err > std::max(1.8f, radius * 0.055f) ||
      max_vertex_err > std::max(3.0f, radius * 0.11f)) {
    return false;
  }
  if (fit_error > std::max(1.8f, radius * 0.055f) || inlier_ratio < 0.62f) {
    return false;
  }

  const float start_ang = normalizeAngle360(
      std::atan2(pa.y - center.y, pa.x - center.x) * 180.0f /
      static_cast<float>(CV_PI));
  const float end_ang = normalizeAngle360(
      std::atan2(pb.y - center.y, pb.x - center.x) * 180.0f /
      static_cast<float>(CV_PI));
  float span = smallerArcSpanDeg(start_ang, end_ang);
  if (span < 35.0f || span > 235.0f) {
    return false;
  }

  const float expected_arc_len =
      radius * span * static_cast<float>(CV_PI) / 180.0f;
  if (expected_arc_len <= 1.0f || chord_sum <= 1.0f) {
    return false;
  }
  const float length_ratio = chord_sum / expected_arc_len;
  if (length_ratio < 0.82f || length_ratio > 1.18f) {
    return false;
  }

  // Runs de arco são justamente cordas curtas consecutivas. Se uma aresta domina,
  // provavelmente é canto/chamfro, não raio contínuo.
  if (max_edge > chord_sum * 0.72f) {
    return false;
  }
  if (min_edge <= 1.0f || max_edge > min_edge * 1.55f) {
    return false;
  }

  const float mean_edge = chord_sum / static_cast<float>(edge_count);
  double edge_variance = 0.0;
  for (size_t k = 0; k < edge_count; ++k) {
    const cv::Point2f &v = polygon[(start_edge + k) % n];
    const cv::Point2f &next = polygon[(start_edge + k + 1U) % n];
    const float edge_len = static_cast<float>(cv::norm(next - v));
    const float diff = edge_len - mean_edge;
    edge_variance += static_cast<double>(diff * diff);
  }
  const float edge_cv =
      std::sqrt(edge_variance / static_cast<double>(edge_count)) /
      std::max(1.0f, mean_edge);
  if (edge_cv > 0.23f) {
    return false;
  }

  EdgeArcInfo info;
  if (!buildArcInfoFromCircle(polygon, contour, start_edge, center, radius, &info)) {
    return false;
  }

  // Corrige o fim do arco para cobrir o run inteiro, não só a primeira corda.
  info.arc_end_deg = end_ang;
  info.arc_points = seg;
  *out = info;
  return true;
}

void detectArcRunsFromPolygon(const std::vector<cv::Point2f> &polygon,
                              const std::vector<cv::Point> &contour,
                              float mm_per_px,
                              std::vector<EdgeArcInfo> *arcs) {
  if (arcs == nullptr || arcs->size() != polygon.size() || polygon.size() < 5) {
    return;
  }

  const size_t n = polygon.size();
  const size_t max_run = std::min<size_t>(8U, n - 1U);
  for (size_t run = max_run; run >= 2U; --run) {
    for (size_t start = 0; start < n; ++start) {
      bool already_arc = true;
      for (size_t k = 0; k < run; ++k) {
        if (!(*arcs)[(start + k) % n].is_arc) {
          already_arc = false;
          break;
        }
      }
      if (already_arc) {
        continue;
      }

      EdgeArcInfo run_arc;
      if (!buildArcRunFromPolygon(polygon, contour, start, run, mm_per_px,
                                  &run_arc)) {
        continue;
      }

      for (size_t k = 0; k < run; ++k) {
        EdgeArcInfo edge_arc;
        if (buildArcInfoFromCircle(polygon, contour, (start + k) % n,
                                   run_arc.center, run_arc.radius_px,
                                   &edge_arc)) {
          (*arcs)[(start + k) % n] = edge_arc;
        }
      }
    }

    if (run == 2U) {
      break;
    }
  }
}

// Analisa cada aresta do polígono para detectar se é reta ou curvada
std::vector<EdgeArcInfo> detectEdgeArcs(const std::vector<cv::Point2f> &polygon,
                                        const std::vector<cv::Point> &contour,
                                        const MetricScale &scale) {
  const size_t np = polygon.size();
  std::vector<EdgeArcInfo> arcs(np);
  if (np < 3 || contour.size() < 30) {
    return arcs;
  }
  const float mm_per_px = effectiveMmPerPx(scale);
  if (mm_per_px <= 0.0f) {
    return arcs;
  }
  const float min_dev_mm = 0.9f;
  const float min_dev_px = std::max(3.0f, min_dev_mm / mm_per_px);

  for (size_t i = 0; i < np; ++i) {
    const cv::Point2f &pa = polygon[i];
    const cv::Point2f &pb = polygon[(i + 1) % np];
    const float edge_len = static_cast<float>(cv::norm(pb - pa));
    if (edge_len < 20.0f) {
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

    // Desvio suficiente para curva real, mas sem exigir tanto que arcos
    // fechados/curtos sejam quebrados em segmentos retos.
    const float dev_ratio = max_dev / edge_len;
    if (dev_ratio < 0.04f || max_dev < min_dev_px) {
      continue;
    }

    // Ajustar círculo aos pontos
    cv::Point2f circ_center;
    float circ_radius = 0.0f;
    float fit_error = 0.0f;
    float inlier_ratio = 0.0f;
    if (!fitCircleRobust(seg, &circ_center, &circ_radius, &fit_error,
                         &inlier_ratio)) {
      continue;
    }

    // Validar: raio não pode ser absurdamente grande (>4x comprimento da
    // aresta) nem minúsculo (<45% do comprimento, semicírculo quase perfeito é
    // 50%)
    if (circ_radius > edge_len * 3.0f || circ_radius < edge_len * 0.35f) {
      continue;
    }
    if (radiusMm(circ_radius, scale) > kMaxExternalArcRadiusMm) {
      continue;
    }
    if (fit_error > std::max(2.0f, circ_radius * 0.06f) ||
        inlier_ratio < 0.64f) {
      continue;
    }

    const cv::Point2f va = pa - circ_center;
    const cv::Point2f vb = pb - circ_center;
    const float va_len = static_cast<float>(cv::norm(va));
    const float vb_len = static_cast<float>(cv::norm(vb));
    if (va_len < 1.0f || vb_len < 1.0f) {
      continue;
    }

    const float cos_angle =
        clampUnit((va.x * vb.x + va.y * vb.y) / (va_len * vb_len));
    const float arc_angle_deg =
        std::acos(cos_angle) * 180.0f / static_cast<float>(CV_PI);
    if (arc_angle_deg < 30.0f) {
      continue;
    }

    // Calcular ângulos de início e fim do arco
    const float sa = std::atan2(pa.y - circ_center.y, pa.x - circ_center.x);
    const float ea = std::atan2(pb.y - circ_center.y, pb.x - circ_center.x);

    float sa_deg = sa * 180.0f / static_cast<float>(CV_PI);
    float ea_deg = ea * 180.0f / static_cast<float>(CV_PI);

    // Determinar a direção correta do arco (deve passar pelos pontos do
    // contorno) Testar um ponto do meio do segmento
    const cv::Point &mid_pt = seg[seg.size() / 2];
    const float mid_ang =
        std::atan2(static_cast<float>(mid_pt.y) - circ_center.y,
                   static_cast<float>(mid_pt.x) - circ_center.x) *
        180.0f / static_cast<float>(CV_PI);

    sa_deg = normalizeAngle360(sa_deg);
    ea_deg = normalizeAngle360(ea_deg);
    float mid_deg = normalizeAngle360(mid_ang);

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

  bridgeShortArcGaps(polygon, contour, &arcs);
  detectArcRunsFromPolygon(polygon, contour, mm_per_px, &arcs);
  bridgeShortArcGaps(polygon, contour, &arcs);

  return arcs;
}

void writeMeasurementDetailsJson(const std::string &json_path,
                                 bool calibration_success, bool object_found,
                                 const std::vector<float> &edges_mm,
                                 const std::vector<float> &angles_deg,
                                 const std::vector<float> &hole_radii_mm,
                                 const std::vector<float> &semi_circle_radii_mm,
                                 const std::vector<float> &hole_diameters_mm,
                                 const std::vector<float> &hole_spacing_mm,
                                 const std::vector<SlotInfo> &detected_slots,
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
    if (i > 0) out << ", ";
    out << edges_mm[i];
  }
  out << "],\n";

  out << "  \"anglesDeg\": [";
  for (size_t i = 0; i < angles_deg.size(); ++i) {
    if (i > 0) out << ", ";
    out << angles_deg[i];
  }
  out << "],\n";

  out << "  \"holeRadiiMm\": [";
  for (size_t i = 0; i < hole_radii_mm.size(); ++i) {
    if (i > 0) out << ", ";
    out << hole_radii_mm[i];
  }
  out << "],\n";

  out << "  \"holeDiametersMm\": [";
  for (size_t i = 0; i < hole_diameters_mm.size(); ++i) {
    if (i > 0) out << ", ";
    out << hole_diameters_mm[i];
  }
  out << "],\n";

  out << "  \"holeSpacingMm\": [";
  for (size_t i = 0; i < hole_spacing_mm.size(); ++i) {
    if (i > 0) out << ", ";
    out << hole_spacing_mm[i];
  }
  out << "],\n";

  out << "  \"semiCircleRadiiMm\": [";
  for (size_t i = 0; i < semi_circle_radii_mm.size(); ++i) {
    if (i > 0) out << ", ";
    out << semi_circle_radii_mm[i];
  }
  out << "],\n";

  out << "  \"slotWidthsMm\": [";
  for (size_t i = 0; i < detected_slots.size(); ++i) {
    if (i > 0) out << ", ";
    out << detected_slots[i].width_mm;
  }
  out << "],\n";

  out << "  \"slotLengthsMm\": [";
  for (size_t i = 0; i < detected_slots.size(); ++i) {
    if (i > 0) out << ", ";
    out << detected_slots[i].length_mm;
  }
  out << "]\n";
  out << "}\n";
}

// ===== Detecção de slots/pílulas =====
std::vector<SlotInfo>
detectSlots(const cv::Mat &roi_gray, const cv::Rect &roi_rect,
            const std::vector<cv::Point> &outer_contour,
            const MetricScale &scale) {
  std::vector<SlotInfo> slots;
  if (roi_gray.empty() || outer_contour.size() < 8) {
    return slots;
  }

  const float mm_per_px = effectiveMmPerPx(scale);
  if (mm_per_px <= 0.0f) {
    return slots;
  }

  std::vector<cv::Point> outer_local;
  outer_local.reserve(outer_contour.size());
  for (const cv::Point &p : outer_contour) {
    outer_local.emplace_back(p.x - roi_rect.x, p.y - roi_rect.y);
  }

  cv::Mat piece_mask = cv::Mat::zeros(roi_gray.size(), CV_8U);
  if (!outer_local.empty()) {
    drawFilledContourMask(outer_local, &piece_mask);
  }

  // Detectar cavidades internas — adaptiveThreshold
  cv::Mat cavity_mask;
  cv::adaptiveThreshold(roi_gray, cavity_mask, 255,
                        cv::ADAPTIVE_THRESH_GAUSSIAN_C,
                        cv::THRESH_BINARY_INV, 45, 10);
  cv::bitwise_and(cavity_mask, piece_mask, cavity_mask);

  // Também vazados (claros)
  cv::Mat light_mask;
  cv::threshold(roi_gray, light_mask, 0, 255,
                cv::THRESH_BINARY | cv::THRESH_OTSU);
  cv::Mat light_cavities;
  cv::bitwise_and(light_mask, piece_mask, light_cavities);

  cv::Mat combined;
  cv::bitwise_or(cavity_mask, light_cavities, combined);
  cv::Mat morph_k =
      cv::getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(3, 3));
  cv::morphologyEx(combined, combined, cv::MORPH_CLOSE, morph_k);
  cv::morphologyEx(combined, combined, cv::MORPH_OPEN, morph_k);

  std::vector<std::vector<cv::Point>> contours;
  cv::findContours(combined, contours, cv::RETR_LIST,
                   cv::CHAIN_APPROX_SIMPLE);

  const int min_radius =
      std::max(3, static_cast<int>(std::round(1.5f / mm_per_px)));

  for (const std::vector<cv::Point> &contour : contours) {
    const double area = cv::contourArea(contour);
    const double perimeter = cv::arcLength(contour, true);
    if (perimeter < 1.0 ||
        area < CV_PI * min_radius * min_radius * 0.5) {
      continue;
    }

    const float circularity =
        static_cast<float>((4.0 * CV_PI * area) / (perimeter * perimeter));

    const cv::RotatedRect rr = cv::minAreaRect(contour);
    const float min_side = std::min(rr.size.width, rr.size.height);
    const float max_side = std::max(rr.size.width, rr.size.height);
    if (min_side < 3.0f) continue;

    const float aspect = max_side / min_side;

    // É slot se: aspect > 1.6, circularity < 0.88 e > 0.50
    if (aspect < 1.6f || circularity > 0.88f || circularity < 0.50f) {
      continue;
    }

    const cv::Moments m = cv::moments(contour);
    if (m.m00 <= 1e-6) continue;
    cv::Point2f slot_center(
        static_cast<float>((m.m10 / m.m00) + roi_rect.x),
        static_cast<float>((m.m01 / m.m00) + roi_rect.y));

    if (distanceToContour(outer_contour, slot_center) <= 1.0f) {
      continue;
    }

    SlotInfo slot;
    slot.center = slot_center;
    slot.width_px = min_side;
    slot.length_px = max_side;
    slot.width_mm = min_side * mm_per_px;
    slot.length_mm = max_side * mm_per_px;
    slot.angle_deg = rr.angle;
    slots.push_back(slot);
  }

  return slots;
}

// ===== Espaçamento entre furos consecutivos =====
std::vector<float> computeHoleSpacing(const std::vector<HoleCircle> &holes,
                                       const MetricScale &scale) {
  std::vector<float> spacings;
  if (holes.size() < 2) return spacings;

  std::vector<size_t> indices(holes.size());
  for (size_t i = 0; i < holes.size(); ++i) indices[i] = i;

  float dx_total = 0, dy_total = 0;
  for (size_t i = 1; i < holes.size(); ++i) {
    dx_total += std::fabs(holes[i].center.x - holes[0].center.x);
    dy_total += std::fabs(holes[i].center.y - holes[0].center.y);
  }

  if (dx_total >= dy_total) {
    std::sort(indices.begin(), indices.end(),
              [&](size_t a, size_t b) {
                return holes[a].center.x < holes[b].center.x;
              });
  } else {
    std::sort(indices.begin(), indices.end(),
              [&](size_t a, size_t b) {
                return holes[a].center.y < holes[b].center.y;
              });
  }

  spacings.reserve(holes.size() - 1);
  for (size_t i = 1; i < indices.size(); ++i) {
    const float d = distanceMm(holes[indices[i - 1]].center,
                               holes[indices[i]].center, scale);
    spacings.push_back(d);
  }
  return spacings;
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

  std::string input_path_str(input_path);
  bool is_gallery = false;
  size_t gallery_pos = input_path_str.find("__GALLERY__");
  if (gallery_pos != std::string::npos) {
    is_gallery = true;
    input_path_str.erase(gallery_pos, 11);
  }

  std::vector<float> edges_mm;
  std::vector<float> angles_deg;
  std::vector<float> hole_radii_mm;
  std::vector<float> semi_circle_radii_mm;
  float perimeter_mm = 0.0f;
  float area_mm2 = 0.0f;

  cv::Mat src = cv::imread(input_path_str);
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
  if (!estimateBoardQuadFromMarkers(markerCorners, &quad)) {
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
  const float min_src_dim = std::min(src_width_px, src_height_px);
  float warp_scale = kWarpUpscale;
  if (min_src_dim > 0.0f) {
    warp_scale = std::max(warp_scale, kMinWarpOutputPx / min_src_dim);
    if (kMaxWarpOutputPx > 0.0f) {
      warp_scale = std::min(warp_scale, kMaxWarpOutputPx / min_src_dim);
    }
  }
  const int img_w = std::max(1, cvRound(src_width_px * warp_scale));
  const int img_h = std::max(1, cvRound(src_height_px * warp_scale));

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
  if (is_gallery) {
    cv::medianBlur(gray, gray, 5);
    cv::GaussianBlur(gray, gray, cv::Size(5, 5), 0.0);
  } else {
    cv::medianBlur(gray, gray, 3);
    cv::GaussianBlur(gray, gray, cv::Size(3, 3), 0.0);
  }

  const int roi_margin =
      std::max(8, static_cast<int>(std::min(img_w, img_h) * 0.04f));
  if ((img_w <= roi_margin * 2) || (img_h <= roi_margin * 2)) {
    cv::imwrite(output_path, flat_image);
    return result;
  }

  const cv::Rect roi_rect(roi_margin, roi_margin, img_w - (roi_margin * 2),
                          img_h - (roi_margin * 2));
  cv::Mat roi_gray = gray(roi_rect).clone();

  const int min_dim = std::min(img_w, img_h);
  const int dilate_sz = std::max(3, static_cast<int>(min_dim * 0.008f));
  const int morph_sz = std::max(7, static_cast<int>(min_dim * 0.018f));
  const cv::Mat kernel_dilate =
      cv::getStructuringElement(cv::MORPH_RECT, cv::Size(dilate_sz, dilate_sz));

  // --- Canny edge map global para reuso (line fitting, holes, etc) ---
  cv::Mat canny_roi;
  cv::Canny(roi_gray, canny_roi, 45, 135, 3, true); // L2gradient para sub-pixel

  // ===== PIPELINE A: Edge-first (precisão máxima, sem bloating) =====
  // Dilatar edges levemente para fechar micro-gaps de 1px
  cv::Mat edge_closed;
  cv::dilate(canny_roi, edge_closed, kernel_dilate);

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
  cv::erode(edge_object_mask, edge_object_mask, kernel_dilate);

  // ===== PIPELINE B: Fallback com Otsu (caso edge-first falhe) =====
  cv::Mat mask_otsu;
  cv::threshold(roi_gray, mask_otsu, 0, 255,
                cv::THRESH_BINARY_INV | cv::THRESH_OTSU);
  // Erosão leve para compensar bias do threshold
  cv::erode(mask_otsu, mask_otsu,
            cv::getStructuringElement(cv::MORPH_RECT, cv::Size(2, 2)));

  // ===== Seleção do melhor contorno =====
  std::vector<cv::Mat> candidate_masks = {edge_object_mask, mask_otsu};
  cv::Mat morph_open_k = cv::getStructuringElement(
      cv::MORPH_ELLIPSE, cv::Size(morph_sz, morph_sz));

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
        approximatePolygon(best_contour_global, is_gallery);

    // Criar edge map em coordenadas globais para line fitting preciso
    cv::Mat canny_global =
        cv::Mat::zeros(flat_image.rows, flat_image.cols, CV_8U);
    canny_roi.copyTo(canny_global(roi_rect));

    const std::vector<cv::Point2f> polygon_refined =
        refinePolygonWithLineIntersections(polygon_raw, best_contour_global,
                                           canny_global);
    
    // Tighter simplification for tooth preservation
    std::vector<cv::Point2f> polygon =
        simplifyPolygonForTechnicalDrawing(polygon_refined, mm_per_px, is_gallery);

    // Refinamento subpixel final: cornerSubPix trabalha em coordenadas da ROI.
    if (polygon.size() >= 3 && !roi_gray.empty()) {
      try {
        cv::TermCriteria criteria(cv::TermCriteria::EPS + cv::TermCriteria::COUNT,
                                  40, 0.001);
        cv::Size winSize(5, 5);
        cv::Size zeroZone(-1, -1);

        std::vector<cv::Point2f> corners;
        corners.reserve(polygon.size());
        for (const cv::Point2f &p : polygon) {
          corners.emplace_back(p.x - static_cast<float>(roi_rect.x),
                               p.y - static_cast<float>(roi_rect.y));
        }
        cv::cornerSubPix(roi_gray, corners, winSize, zeroZone, criteria);

        for (size_t i = 0; i < polygon.size(); ++i) {
          const cv::Point2f refined(
              corners[i].x + static_cast<float>(roi_rect.x),
              corners[i].y + static_cast<float>(roi_rect.y));
          if (cv::norm(refined - polygon[i]) < 3.0) {
            polygon[i] = refined;
          }
        }
      } catch (...) {
        // Se falhar (ex: ROI muito pequena), mantém o polígono original
      }
    }

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

    // ===== Limpar gerenciador de labels para nova imagem =====
    LabelManager::getInstance().clear();
    
    // Adicionar polígono da peça para evitar que labels fiquem em cima dela
    std::vector<cv::Point> poly_pts;
    for(const auto& p : polygon) poly_pts.push_back(cv::Point(cvRound(p.x), cvRound(p.y)));
    LabelManager::getInstance().addPiecePolygon(poly_pts);

    // ===== Desenhar grid de referência (fundo sutil) =====
    drawReferenceGrid(flat_image, mm_per_px);

    if (polygon.size() >= 3) {
      // ===== Detectar arcos nas arestas do polígono =====
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

      // Detectar slots/pílulas
      std::vector<SlotInfo> detected_slots =
          detectSlots(roi_gray, roi_rect, best_contour_global, metric_scale);

      // Calcular espaçamento entre furos
      // Filtrar apenas furos completos (não arcos) para espaçamento
      std::vector<HoleCircle> full_holes;
      for (const HoleCircle &h : holes) {
        if (!h.is_arc) full_holes.push_back(h);
      }
      std::vector<float> hole_spacing_mm =
          computeHoleSpacing(full_holes, metric_scale);

      // Calcular diâmetros dos furos completos
      std::vector<float> hole_diameters_mm;
      hole_diameters_mm.reserve(full_holes.size());
      for (const HoleCircle &h : full_holes) {
        hole_diameters_mm.push_back(radiusMm(h.radius_px, metric_scale) * 2.0f);
      }

      // ===== Desenhar polígono: arcos suaves para curvas, retas para o resto
      // ===== Contorno com espessura maior e cores diferenciadas
      const int outline_thick = 3;
      for (size_t pi = 0; pi < polygon.size(); ++pi) {
        const cv::Point2f &pa = polygon[pi];
        const cv::Point2f &pb = polygon[(pi + 1) % polygon.size()];

        if (edge_arcs[pi].is_arc) {
          const EdgeArcInfo &arc = edge_arcs[pi];
          double ea_draw = static_cast<double>(arc.arc_end_deg);
          if (ea_draw <= static_cast<double>(arc.arc_start_deg)) {
            ea_draw += 360.0;
          }
          cv::ellipse(flat_image,
                      cv::Point(cvRound(arc.center.x), cvRound(arc.center.y)),
                      cv::Size(cvRound(arc.radius_px), cvRound(arc.radius_px)),
                      0.0, static_cast<double>(arc.arc_start_deg), ea_draw,
                      DrawColors::kOutlineArc, outline_thick, cv::LINE_AA);
        } else {
          cv::line(flat_image, pa, pb, DrawColors::kOutlineStraight,
                   outline_thick, cv::LINE_AA);
        }
      }

      // ===== Anotar raio dos arcos detectados nas arestas =====
      std::vector<bool> arc_annotated(polygon.size(), false);
      for (size_t pi = 0; pi < polygon.size(); ++pi) {
        if (!edge_arcs[pi].is_arc || arc_annotated[pi]) {
          continue;
        }

        const EdgeArcInfo &arc = edge_arcs[pi];
        cv::Point2f merged_center = arc.center;
        float merged_radius = arc.radius_px;
        arc_annotated[pi] = true;

        for (size_t j = (pi + 1) % polygon.size();
             j != pi && edge_arcs[j].is_arc; j = (j + 1) % polygon.size()) {
          const float center_dist =
              static_cast<float>(cv::norm(edge_arcs[j].center - merged_center));
          const float radius_diff =
              std::fabs(edge_arcs[j].radius_px - merged_radius);
          if (center_dist < merged_radius * 0.3f &&
              radius_diff < merged_radius * 0.2f) {
            merged_center = (merged_center + edge_arcs[j].center) * 0.5f;
            merged_radius = (merged_radius + edge_arcs[j].radius_px) * 0.5f;
            arc_annotated[j] = true;
          } else {
            break;
          }
        }

        const float r_mm = radiusMm(merged_radius, metric_scale);
        drawCircleDimension(flat_image, merged_center, merged_radius, r_mm);
        semi_circle_radii_mm.push_back(r_mm);
      }

      // ===== Desenhar furos internos =====
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
              DrawColors::kHoleOutline, 2, cv::LINE_AA);
          // Arco parcial: mostrar raio
          drawCircleDimension(flat_image, hole.center, hole.radius_px, r_mm);
        } else {
          // Círculo completo: desenhar com linhas de centro e diâmetro
          cv::circle(flat_image,
                     cv::Point(cvRound(hole.center.x), cvRound(hole.center.y)),
                     cvRound(hole.radius_px), DrawColors::kHoleOutline, 2,
                     cv::LINE_AA);
          const float d_mm = r_mm * 2.0f;
          drawDiameterDimension(flat_image, hole.center, hole.radius_px, d_mm);
        }
      }

      // ===== Desenhar slots/pílulas =====
      for (const SlotInfo &slot : detected_slots) {
        // Marcação visual do contorno
        drawSlotContour(flat_image, slot.center, slot.width_px, slot.length_px,
                        slot.angle_deg);
        // Cota dimensional
        drawSlotDimension(flat_image, slot.center, slot.width_mm,
                          slot.length_mm, slot.angle_deg);
      }

      // ===== Anotar dimensões lineares (apenas arestas retas) =====
      for (size_t k = 0; k < display_indices.size(); ++k) {
        const size_t i = display_indices[k];
        if (i >= polygon.size() || i >= polygon_edges_mm.size()) {
          continue;
        }

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
        const float e1_mm = e1 * mm_per_px;
        const float e2_mm = e2 * mm_per_px;
        const float display_angle = (polygon_angles_deg[i] > 180.0f)
                                        ? (360.0f - polygon_angles_deg[i])
                                        : polygon_angles_deg[i];

        const float deviation_from_straight = std::fabs(180.0f - display_angle);
        if (e1 > 3.0f && e2 > 3.0f && e1_mm >= 2.0f && e2_mm >= 2.0f &&
            display_angle >= 5.0f && deviation_from_straight >= 4.0f) {
          drawAngleDimension(flat_image, curr, prev, next, display_angle);
        }
      }

      // ===== Moldura técnica =====
      int arc_count = 0;
      for (const EdgeArcInfo &ea : edge_arcs) {
        if (ea.is_arc) ++arc_count;
      }
      arc_count += static_cast<int>(semi_circle_radii_mm.size());
      drawTechnicalFrame(flat_image, mm_per_px,
                         static_cast<int>(edges_mm.size()),
                         static_cast<int>(holes.size()), arc_count);

      // ===== Salvar JSON expandido =====
      writeMeasurementDetailsJson(
          std::string(output_path) + ".json", result.calibration_success,
          result.object_found, edges_mm, angles_deg, hole_radii_mm,
          semi_circle_radii_mm, hole_diameters_mm, hole_spacing_mm,
          detected_slots, perimeter_mm, area_mm2);

    } else {
      for (int i = 0; i < 4; ++i) {
        cv::line(flat_image, rect_vertices[i], rect_vertices[(i + 1) % 4],
                 DrawColors::kOutlineStraight, 3);
      }
      // Fallback JSON (sem polígono)
      writeMeasurementDetailsJson(
          std::string(output_path) + ".json", result.calibration_success,
          result.object_found, edges_mm, angles_deg, hole_radii_mm,
          semi_circle_radii_mm, {}, {}, {}, perimeter_mm, area_mm2);
    }
  }

  // Salva a imagem processada para o Flutter mostrar
  cv::imwrite(output_path, flat_image);

  return result;
}
}
