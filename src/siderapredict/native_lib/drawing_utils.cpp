#include "drawing_utils.h"

void drawDimensionLine(cv::Mat& img, cv::Point2f p1, cv::Point2f p2, float realValue, int offsetDirection) {
    if (cv::norm(p1 - p2) < 2.0) return;

    cv::Point2f d = p2 - p1;
    float len = std::sqrt(d.x*d.x + d.y*d.y);
    cv::Point2f u(d.x / len, d.y / len);
    cv::Point2f n(-u.y, u.x);

    float offset = 35.0f * offsetDirection;
    cv::Point2f pt1_ext = p1 + n * offset;
    cv::Point2f pt2_ext = p2 + n * offset;
    cv::Point2f pt1_ext_end = pt1_ext + n * (12.0f * offsetDirection);
    cv::Point2f pt2_ext_end = pt2_ext + n * (12.0f * offsetDirection);

    cv::Scalar color(0, 0, 0);
    int thickness = 1;

    cv::line(img, p1, pt1_ext_end, color, thickness, cv::LINE_AA);
    cv::line(img, p2, pt2_ext_end, color, thickness, cv::LINE_AA);
    cv::line(img, pt1_ext, pt2_ext, color, thickness, cv::LINE_AA);

    // Setas
    float arrowSize = 8.0f;
    float arrowWidth = 4.0f;
    cv::Point2f arrow1_1 = pt1_ext + d * (arrowSize / len) + n * arrowWidth;
    cv::Point2f arrow1_2 = pt1_ext + d * (arrowSize / len) - n * arrowWidth;
    std::vector<cv::Point> pts1 = {pt1_ext, arrow1_1, arrow1_2};
    std::vector<std::vector<cv::Point>> arrow1_pts = {pts1};
    cv::fillPoly(img, arrow1_pts, color, cv::LINE_AA);

    cv::Point2f arrow2_1 = pt2_ext - d * (arrowSize / len) + n * arrowWidth;
    cv::Point2f arrow2_2 = pt2_ext - d * (arrowSize / len) - n * arrowWidth;
    std::vector<cv::Point> pts2 = {pt2_ext, arrow2_1, arrow2_2};
    std::vector<std::vector<cv::Point>> arrow2_pts = {pts2};
    cv::fillPoly(img, arrow2_pts, color, cv::LINE_AA);
    
    char text[32];
    snprintf(text, sizeof(text), "%.1f", realValue);
    std::string textStr = text;

    int baseline = 0;
    double fontScale = 0.5;
    int fontThickness = 1;
    cv::Size textSize = cv::getTextSize(textStr, cv::FONT_HERSHEY_SIMPLEX, fontScale, fontThickness, &baseline);

    cv::Point2f mid = (pt1_ext + pt2_ext) * 0.5f;
    cv::Point2f textPos = mid - n * (12.0f * offsetDirection);
    textPos.x -= textSize.width / 2.0f;
    textPos.y += textSize.height / 2.0f;

    // Fundo branco
    cv::rectangle(img, textPos - cv::Point2f(3, textSize.height + 3), textPos + cv::Point2f(textSize.width + 3, 4), cv::Scalar(255, 255, 255), cv::FILLED);
    cv::putText(img, textStr, textPos, cv::FONT_HERSHEY_SIMPLEX, fontScale, cv::Scalar(0, 0, 200), fontThickness, cv::LINE_AA);
}

void drawAngleDimension(cv::Mat& img, cv::Point2f center, cv::Point2f p1, cv::Point2f p2, float angleDeg) {
    if (angleDeg < 2.0f || angleDeg > 178.0f) return;
    
    cv::Point2f v1 = p1 - center;
    cv::Point2f v2 = p2 - center;
    float l1 = cv::norm(v1);
    float l2 = cv::norm(v2);
    if(l1 < 1.0f || l2 < 1.0f) return;

    v1 /= l1;
    v2 /= l2;

    float r = 25.0f;
    float ang1 = std::atan2(v1.y, v1.x) * 180.0 / CV_PI;
    float ang2 = std::atan2(v2.y, v2.x) * 180.0 / CV_PI;
    
    if (ang1 < 0) ang1 += 360;
    if (ang2 < 0) ang2 += 360;
    float startAng = std::min(ang1, ang2);
    float endAng = std::max(ang1, ang2);
    if (endAng - startAng > 180) {
        startAng = std::max(ang1, ang2);
        endAng = std::min(ang1, ang2) + 360;
    }
    
    cv::ellipse(img, center, cv::Size(r, r), 0, startAng, endAng, cv::Scalar(0, 0, 0), 2, cv::LINE_AA);
    
    cv::Point2f bisec = v1 + v2;
    float lBisec = cv::norm(bisec);
    if (lBisec > 1e-3) {
        bisec /= lBisec;
        char text[32];
        snprintf(text, sizeof(text), "%.1f", angleDeg);
        int baseline = 0;
        double fontScale = 0.45;
        int fontThickness = 1;
        cv::Size textSize = cv::getTextSize(text, cv::FONT_HERSHEY_SIMPLEX, fontScale, fontThickness, &baseline);
        
        cv::Point2f textCenter = center + bisec * (r + 15.0f);
        textCenter.x -= textSize.width/2.0f;
        textCenter.y += textSize.height/2.0f;
        
        cv::rectangle(img, textCenter - cv::Point2f(2, textSize.height + 2), textCenter + cv::Point2f(textSize.width + 2, 3), cv::Scalar(255, 255, 255), cv::FILLED);
        cv::putText(img, text, textCenter, cv::FONT_HERSHEY_SIMPLEX, fontScale, cv::Scalar(0, 150, 200), fontThickness, cv::LINE_AA);
    }
}

void drawCircleDimension(cv::Mat& img, cv::Point2f center, float radiusPx, float radiusMm) {
    int crossSize = 8;
    cv::line(img, center - cv::Point2f(crossSize, 0), center + cv::Point2f(crossSize, 0), cv::Scalar(0,0,0), 1, cv::LINE_AA);
    cv::line(img, center - cv::Point2f(0, crossSize), center + cv::Point2f(0, crossSize), cv::Scalar(0,0,0), 1, cv::LINE_AA);
    
    char text[32];
    snprintf(text, sizeof(text), "R%.1f", radiusMm);
    double fontScale = 0.5;
    int fontThickness = 1;
    
    cv::Point2f ptEdge = center + cv::Point2f(0.707f*radiusPx, -0.707f*radiusPx);
    cv::Point2f ptText = ptEdge + cv::Point2f(20.0f, -20.0f);
    
    cv::line(img, center, ptEdge, cv::Scalar(0, 0, 0), 1, cv::LINE_AA);
    cv::line(img, ptEdge, ptText, cv::Scalar(0, 0, 0), 1, cv::LINE_AA);

    int baseline = 0;
    cv::Size textSize = cv::getTextSize(text, cv::FONT_HERSHEY_SIMPLEX, fontScale, fontThickness, &baseline);
    
    cv::Point2f textPos = ptText + cv::Point2f(4, -4);
    cv::rectangle(img, textPos - cv::Point2f(3, textSize.height + 3), textPos + cv::Point2f(textSize.width + 3, 4), cv::Scalar(255, 255, 255), cv::FILLED);
    cv::putText(img, text, textPos, cv::FONT_HERSHEY_SIMPLEX, fontScale, cv::Scalar(0, 0, 200), fontThickness, cv::LINE_AA);
}
