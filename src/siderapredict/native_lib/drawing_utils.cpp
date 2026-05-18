#include "drawing_utils.h"

namespace {

float clampScale(float value, float min_value, float max_value) {
    if (value < min_value) return min_value;
    if (value > max_value) return max_value;
    return value;
}

float annotationScale(const cv::Mat &img) {
    const int min_dim = (img.cols < img.rows) ? img.cols : img.rows;
    if (min_dim <= 0) return 1.0f;
    const float scale = static_cast<float>(min_dim) / 1700.0f;
    return clampScale(scale, 0.55f, 1.4f);
}

int scaledThickness(float scale, int base) {
    int value = static_cast<int>(base * scale + 0.5f);
    if (value < 1) value = 1;
    return value;
}

cv::Point2f keepLabelInsideImage(const cv::Mat &img, cv::Point2f baseline,
                                 cv::Size textSize, float pad) {
    if (img.empty()) return baseline;

    cv::Point2f tl = baseline - cv::Point2f(pad, textSize.height + pad);
    cv::Point2f br = baseline + cv::Point2f(textSize.width + pad, pad + 2.0f);
    const float minCoord = 2.0f;
    const float maxX = static_cast<float>(img.cols - 3);
    const float maxY = static_cast<float>(img.rows - 3);

    if (tl.x < minCoord) baseline.x += minCoord - tl.x;
    if (tl.y < minCoord) baseline.y += minCoord - tl.y;
    if (br.x > maxX) baseline.x -= br.x - maxX;
    if (br.y > maxY) baseline.y -= br.y - maxY;

    return baseline;
}

// Desenha seta preenchida na ponta de uma linha
void drawArrowHead(cv::Mat &img, cv::Point2f tip, cv::Point2f along,
                   float arrowLen, float arrowWidth, const cv::Scalar &color) {
    const float len = static_cast<float>(cv::norm(along));
    if (len < 1e-3f) return;
    const cv::Point2f u = along * (1.0f / len);
    const cv::Point2f n(-u.y, u.x);

    const cv::Point2f p1 = tip - u * arrowLen + n * arrowWidth;
    const cv::Point2f p2 = tip - u * arrowLen - n * arrowWidth;

    std::vector<cv::Point> pts = {
        cv::Point(cvRound(tip.x), cvRound(tip.y)),
        cv::Point(cvRound(p1.x), cvRound(p1.y)),
        cv::Point(cvRound(p2.x), cvRound(p2.y))};
    std::vector<std::vector<cv::Point>> arrow_pts = {pts};
    cv::fillPoly(img, arrow_pts, color, cv::LINE_AA);
}

// Desenha texto com fundo semitransparente e retorno do tamanho
cv::Size drawTextWithBackground(cv::Mat &img, const std::string &text,
                                cv::Point2f pos, double fontScale,
                                int fontThickness, const cv::Scalar &textColor,
                                const cv::Scalar &bgColor, float pad) {
    int baseline = 0;
    cv::Size textSize = cv::getTextSize(text, cv::FONT_HERSHEY_SIMPLEX,
                                        fontScale, fontThickness, &baseline);

    // Ajusta posição se houver sobreposição
    cv::Point2f clearPos = LabelManager::getInstance().getClearPos(pos, textSize, pad);
    clearPos = keepLabelInsideImage(img, clearPos, textSize, pad);
    
    cv::Point2f tl = clearPos - cv::Point2f(pad, textSize.height + pad);
    cv::Point2f br = clearPos + cv::Point2f(textSize.width + pad, pad + 2.0f);

    // Registrar região como ocupada
    LabelManager::getInstance().addRect(cv::Rect(cvRound(tl.x), cvRound(tl.y), 
                                                cvRound(br.x - tl.x), cvRound(br.y - tl.y)));

    // Fundo com cantos arredondados simulados (retângulo sólido)
    cv::rectangle(img, tl, br, bgColor, cv::FILLED);
    // Borda fina
    cv::rectangle(img, tl, br,
                  cv::Scalar(bgColor[0] * 0.85, bgColor[1] * 0.85,
                             bgColor[2] * 0.85),
                  1, cv::LINE_AA);

    cv::putText(img, text, clearPos, cv::FONT_HERSHEY_SIMPLEX, fontScale, textColor,
                fontThickness, cv::LINE_AA);

    return textSize;
}

} // namespace

cv::Point2f LabelManager::getClearPos(cv::Point2f preferred, cv::Size sz, float pad) {
    cv::Rect r(cvRound(preferred.x - pad), cvRound(preferred.y - sz.height - pad), 
               cvRound(sz.width + pad * 2.0f), cvRound(sz.height + pad * 2.0f));

    if (!overlaps(r)) return preferred;

    // Busca em espiral para encontrar o espaço livre mais próximo
    const float step_x = sz.width * 0.5f;
    const float step_y = (sz.height + pad * 2.0f);
    
    // Tenta 4 "voltas" da espiral
    for (int ring = 1; ring <= 4; ++ring) {
        // Direções: Cima, Baixo, Esquerda, Direita e Diagonais
        for (int dy = -ring; dy <= ring; ++dy) {
            for (int dx = -ring; dx <= ring; ++dx) {
                if (std::abs(dx) < ring && std::abs(dy) < ring) continue; // Pular anel interno

                cv::Point2f tryPos = preferred + cv::Point2f(dx * step_x, dy * step_y);
                cv::Rect tryRect(cvRound(tryPos.x - pad), cvRound(tryPos.y - sz.height - pad), 
                                 cvRound(sz.width + pad * 2.0f), cvRound(sz.height + pad * 2.0f));
                if (!overlaps(tryRect)) return tryPos;
            }
        }
    }

    return preferred;
}

void drawDimensionLine(cv::Mat &img, cv::Point2f p1, cv::Point2f p2,
                       float realValue, int offsetDirection) {
    if (cv::norm(p1 - p2) < 2.0) return;

    const float scale = annotationScale(img);
    const cv::Scalar &lineColor = DrawColors::kDimLine;
    const cv::Scalar &textColor = DrawColors::kDimText;

    cv::Point2f d = p2 - p1;
    float len = std::sqrt(d.x * d.x + d.y * d.y);
    cv::Point2f u(d.x / len, d.y / len);
    cv::Point2f n(-u.y, u.x);

    // Extension lines — mais longas, com gap na ponta
    float offset = 38.0f * scale * offsetDirection;
    float extGap = 3.0f * scale; // gap entre o ponto e o início da extension
    float extExtra = 14.0f * scale;

    cv::Point2f ext1_start = p1 + n * extGap * offsetDirection;
    cv::Point2f ext1_end =
        p1 + n * (offset + extExtra * offsetDirection);
    cv::Point2f ext2_start = p2 + n * extGap * offsetDirection;
    cv::Point2f ext2_end =
        p2 + n * (offset + extExtra * offsetDirection);

    int thinLine = scaledThickness(scale, 1);
    int dimLine = scaledThickness(scale, 1);

    // Extension lines (finas)
    cv::line(img, ext1_start, ext1_end, lineColor, thinLine, cv::LINE_AA);
    cv::line(img, ext2_start, ext2_end, lineColor, thinLine, cv::LINE_AA);

    // Dimension line (entre as extensões)
    cv::Point2f dim1 = p1 + n * offset;
    cv::Point2f dim2 = p2 + n * offset;
    cv::line(img, dim1, dim2, lineColor, dimLine, cv::LINE_AA);

    // Setas preenchidas nas extremidades
    float arrowLen = 10.0f * scale;
    float arrowWidth = 3.5f * scale;
    drawArrowHead(img, dim1, d, arrowLen, arrowWidth, lineColor);
    drawArrowHead(img, dim2, d * (-1.0f), arrowLen, arrowWidth, lineColor);

    // Texto com valor e unidade
    char text[32];
    snprintf(text, sizeof(text), "%.1f mm", realValue);
    std::string textStr = text;

    int baseline = 0;
    double fontScale_val = 0.48 * scale;
    int fontThickness = scaledThickness(scale, 1);
    cv::Size textSize = cv::getTextSize(textStr, cv::FONT_HERSHEY_SIMPLEX,
                                        fontScale_val, fontThickness, &baseline);

    cv::Point2f mid = (dim1 + dim2) * 0.5f;
    cv::Point2f textPos = mid - n * (14.0f * scale * offsetDirection);
    textPos.x -= textSize.width / 2.0f;
    textPos.y += textSize.height / 2.0f;

    const float pad = 4.0f * scale;
    drawTextWithBackground(img, textStr, textPos, fontScale_val, fontThickness,
                           textColor, DrawColors::kTextBgAlpha, pad);
}

void drawAngleDimension(cv::Mat &img, cv::Point2f center, cv::Point2f p1,
                        cv::Point2f p2, float angleDeg) {
    if (angleDeg < 2.0f || angleDeg > 178.0f) return;

    const float scale = annotationScale(img);
    const cv::Scalar &lineColor = DrawColors::kAngleLine;
    const cv::Scalar &textColor = DrawColors::kAngleText;

    cv::Point2f v1 = p1 - center;
    cv::Point2f v2 = p2 - center;
    float l1 = static_cast<float>(cv::norm(v1));
    float l2 = static_cast<float>(cv::norm(v2));
    if (l1 < 1.0f || l2 < 1.0f) return;

    v1 /= l1;
    v2 /= l2;

    float r = 28.0f * scale;
    int arcThickness = scaledThickness(scale, 2);

    float ang1 = std::atan2(v1.y, v1.x) * 180.0f / static_cast<float>(CV_PI);
    float ang2 = std::atan2(v2.y, v2.x) * 180.0f / static_cast<float>(CV_PI);

    if (ang1 < 0) ang1 += 360;
    if (ang2 < 0) ang2 += 360;
    float startAng = std::min(ang1, ang2);
    float endAng = std::max(ang1, ang2);
    if (endAng - startAng > 180) {
        startAng = std::max(ang1, ang2);
        endAng = std::min(ang1, ang2) + 360;
    }

    // Arco do ângulo
    cv::ellipse(img, center, cv::Size(static_cast<int>(r), static_cast<int>(r)),
                0, startAng, endAng, lineColor, arcThickness, cv::LINE_AA);

    // Setas nas extremidades do arco
    float arrowLen = 7.0f * scale;
    float arrowWidth = 2.5f * scale;
    
    // Seta no início do arco
    float startRad = startAng * static_cast<float>(CV_PI) / 180.0f;
    cv::Point2f arcStart = center + cv::Point2f(std::cos(startRad), std::sin(startRad)) * r;
    cv::Point2f tangentStart(-std::sin(startRad), std::cos(startRad));
    drawArrowHead(img, arcStart, tangentStart * (-1.0f), arrowLen, arrowWidth, lineColor);

    // Seta no fim do arco
    float endRad = endAng * static_cast<float>(CV_PI) / 180.0f;
    cv::Point2f arcEnd = center + cv::Point2f(std::cos(endRad), std::sin(endRad)) * r;
    cv::Point2f tangentEnd(-std::sin(endRad), std::cos(endRad));
    drawArrowHead(img, arcEnd, tangentEnd, arrowLen, arrowWidth, lineColor);

    // Texto com símbolo de grau
    cv::Point2f bisec = v1 + v2;
    float lBisec = static_cast<float>(cv::norm(bisec));
    if (lBisec > 1e-3) {
        bisec /= lBisec;
        char textBuf[32];
        snprintf(textBuf, sizeof(textBuf), "%.1f", angleDeg);
        std::string textStr = textBuf;

        double fontScale_val = 0.42 * scale;
        int fontThickness = scaledThickness(scale, 1);
        int baseline = 0;
        
        // Medir o texto para posicionar o símbolo ao final
        cv::Size textSize = cv::getTextSize(textStr, cv::FONT_HERSHEY_SIMPLEX,
                                            fontScale_val, fontThickness, &baseline);
        
        // Espaço extra para o símbolo º
        float symbolGap = 4.0f * scale;
        float symbolRadius = 3.0f * scale;
        float totalWidth = textSize.width + symbolGap + symbolRadius * 2.0f;

        cv::Point2f textCenter = center + bisec * (r + 18.0f * scale);
        cv::Point2f drawPos = textCenter;
        drawPos.x -= totalWidth / 2.0f;
        drawPos.y += textSize.height / 2.0f;

        const float pad = 3.0f * scale;
        cv::Size occupiedSize(cvRound(totalWidth), textSize.height);
        drawPos = LabelManager::getInstance().getClearPos(drawPos, occupiedSize, pad);
        drawPos = keepLabelInsideImage(img, drawPos, occupiedSize, pad);

        // Desenha o fundo considerando o símbolo
        cv::Rect2f bgRect(drawPos.x - pad, drawPos.y - textSize.height - pad, 
                          totalWidth + pad * 2.0f, textSize.height + pad * 2.0f + 2.0f);
        LabelManager::getInstance().addRect(cv::Rect(cvRound(bgRect.x), cvRound(bgRect.y),
                                                     cvRound(bgRect.width),
                                                     cvRound(bgRect.height)));
        cv::rectangle(img, bgRect, DrawColors::kTextBgAlpha, cv::FILLED);
        cv::rectangle(img, bgRect, cv::Scalar(DrawColors::kTextBgAlpha[0]*0.85, 
                                              DrawColors::kTextBgAlpha[1]*0.85, 
                                              DrawColors::kTextBgAlpha[2]*0.85), 1, cv::LINE_AA);

        // Desenha o texto numérico
        cv::putText(img, textStr, drawPos, cv::FONT_HERSHEY_SIMPLEX, fontScale_val,
                    textColor, fontThickness, cv::LINE_AA);
        
        // Desenha o símbolo º (pequeno círculo no topo)
        cv::Point2f symbolCenter(drawPos.x + textSize.width + symbolGap + symbolRadius,
                                 drawPos.y - textSize.height + symbolRadius + 1.0f * scale);
        cv::circle(img, symbolCenter, cvRound(symbolRadius), textColor, 
                   scaledThickness(scale, 1), cv::LINE_AA);
    }
}

void drawCircleDimension(cv::Mat &img, cv::Point2f center, float radiusPx,
                         float radiusMm) {
    const float scale = annotationScale(img);
    const cv::Scalar &lineColor = DrawColors::kRadiusLine;
    const cv::Scalar &textColor = DrawColors::kRadiusText;
    int thickness = scaledThickness(scale, 1);

    // Cruz de centro
    int crossSize = scaledThickness(scale, 10);
    cv::line(img, center - cv::Point2f(static_cast<float>(crossSize), 0),
             center + cv::Point2f(static_cast<float>(crossSize), 0), lineColor, thickness,
             cv::LINE_AA);
    cv::line(img, center - cv::Point2f(0, static_cast<float>(crossSize)),
             center + cv::Point2f(0, static_cast<float>(crossSize)), lineColor, thickness,
             cv::LINE_AA);

    // Leader line do centro até a borda + extensão
    cv::Point2f ptEdge =
        center + cv::Point2f(0.707f * radiusPx, -0.707f * radiusPx);
    cv::Point2f ptText = ptEdge + cv::Point2f(22.0f * scale, -22.0f * scale);

    // Linha com seta na ponta
    cv::line(img, center, ptEdge, lineColor, thickness, cv::LINE_AA);
    cv::line(img, ptEdge, ptText, lineColor, thickness, cv::LINE_AA);

    // Seta no ponto da borda
    cv::Point2f dir = ptEdge - center;
    float arrowLen = 7.0f * scale;
    float arrowWidth = 2.5f * scale;
    drawArrowHead(img, ptEdge, dir, arrowLen, arrowWidth, lineColor);

    // Texto "R..." 
    char text[32];
    snprintf(text, sizeof(text), "R%.1f mm", radiusMm);

    double fontScale_val = 0.45 * scale;
    int fontThickness = scaledThickness(scale, 1);

    cv::Point2f textPos = ptText + cv::Point2f(4.0f * scale, -4.0f * scale);
    const float pad = 3.0f * scale;
    drawTextWithBackground(img, text, textPos, fontScale_val, fontThickness,
                           textColor, DrawColors::kTextBgAlpha, pad);
}

void drawDiameterDimension(cv::Mat &img, cv::Point2f center, float radiusPx,
                           float diameterMm) {
    const float scale = annotationScale(img);
    const cv::Scalar &lineColor = DrawColors::kRadiusLine;
    const cv::Scalar &textColor = DrawColors::kRadiusText;
    int thickness = scaledThickness(scale, 1);

    // Linhas de centro (traço-ponto) — mais longas que o raio
    drawCenterLines(img, center, radiusPx);

    // Linha de diâmetro passando pelo centro
    cv::Point2f pLeft = center - cv::Point2f(radiusPx, 0);
    cv::Point2f pRight = center + cv::Point2f(radiusPx, 0);
    cv::line(img, pLeft, pRight, lineColor, thickness, cv::LINE_AA);

    // Setas em ambas extremidades
    float arrowLen = 8.0f * scale;
    float arrowWidth = 3.0f * scale;
    cv::Point2f dirH(1.0f, 0.0f);
    drawArrowHead(img, pRight, dirH, arrowLen, arrowWidth, lineColor);
    drawArrowHead(img, pLeft, dirH * (-1.0f), arrowLen, arrowWidth, lineColor);

    // Leader line para cima-direita
    cv::Point2f ptEdge =
        center + cv::Point2f(0.707f * radiusPx, -0.707f * radiusPx);
    cv::Point2f ptText = ptEdge + cv::Point2f(20.0f * scale, -20.0f * scale);
    cv::line(img, ptEdge, ptText, lineColor, thickness, cv::LINE_AA);

    // Texto "D..."
    char text[32];
    snprintf(text, sizeof(text), "D%.1f mm", diameterMm);

    double fontScale_val = 0.48 * scale;
    int fontThickness = scaledThickness(scale, 1);

    cv::Point2f textPos = ptText + cv::Point2f(4.0f * scale, -4.0f * scale);
    const float pad = 4.0f * scale;
    drawTextWithBackground(img, text, textPos, fontScale_val, fontThickness,
                           textColor, DrawColors::kTextBgAlpha, pad);
}

void drawSlotDimension(cv::Mat &img, cv::Point2f center, float widthMm,
                       float lengthMm, float angleDeg) {
    const float scale = annotationScale(img);
    const cv::Scalar &textColor = DrawColors::kRadiusText;

    // Linhas de centro
    drawCenterLines(img, center, 15.0f * scale);

    // Leader line
    cv::Point2f ptText = center + cv::Point2f(25.0f * scale, -30.0f * scale);
    cv::line(img, center, ptText, DrawColors::kRadiusLine,
             scaledThickness(scale, 1), cv::LINE_AA);

    // Texto "WxL mm"
    char text[64];
    snprintf(text, sizeof(text), "Slot %.1fx%.1f mm", widthMm, lengthMm);

    double fontScale_val = 0.42 * scale;
    int fontThickness = scaledThickness(scale, 1);

    cv::Point2f textPos = ptText + cv::Point2f(4.0f * scale, -4.0f * scale);
    const float pad = 3.0f * scale;
    drawTextWithBackground(img, text, textPos, fontScale_val, fontThickness,
                           textColor, DrawColors::kTextBgAlpha, pad);
}

void drawSlotContour(cv::Mat &img, cv::Point2f center, float widthPx,
                     float lengthPx, float angleDeg) {
    const float scale = annotationScale(img);
    const float thickness = static_cast<float>(scaledThickness(scale, 2));
    const cv::Scalar &color = DrawColors::kOutlineArc;

    // Se o slot for quase um círculo ou dados inválidos, fallback para círculo
    if (lengthPx <= widthPx + 1.0f) {
        cv::circle(img, center, cvRound(widthPx * 0.5f), color, 
                   static_cast<int>(thickness), cv::LINE_AA);
        return;
    }

    float halfW = widthPx * 0.5f;
    float straightLen = lengthPx - widthPx;
    float halfSL = straightLen * 0.5f;

    float rad = angleDeg * static_cast<float>(CV_PI) / 180.0f;
    cv::Point2f dir(std::cos(rad), std::sin(rad));
    cv::Point2f normal(-dir.y, dir.x);

    // Centros dos arcos nas extremidades
    cv::Point2f c1 = center - dir * halfSL;
    cv::Point2f c2 = center + dir * halfSL;

    // Linhas paralelas
    cv::Point2f p1a = c1 + normal * halfW;
    cv::Point2f p2a = c2 + normal * halfW;
    cv::Point2f p1b = c1 - normal * halfW;
    cv::Point2f p2b = c2 - normal * halfW;

    cv::line(img, p1a, p2a, color, static_cast<int>(thickness), cv::LINE_AA);
    cv::line(img, p1b, p2b, color, static_cast<int>(thickness), cv::LINE_AA);

    // Arcos nas extremidades
    float startAng1 = (angleDeg + 90.0f);
    float endAng1 = (angleDeg + 270.0f);
    cv::ellipse(img, c1, cv::Size(cvRound(halfW), cvRound(halfW)), 
                0.0, startAng1, endAng1, color, static_cast<int>(thickness), cv::LINE_AA);

    float startAng2 = (angleDeg - 90.0f);
    float endAng2 = (angleDeg + 90.0f);
    cv::ellipse(img, c2, cv::Size(cvRound(halfW), cvRound(halfW)), 
                0.0, startAng2, endAng2, color, static_cast<int>(thickness), cv::LINE_AA);
}

void drawCenterLines(cv::Mat &img, cv::Point2f center, float radiusPx) {
    const float scale = annotationScale(img);
    const cv::Scalar &color = DrawColors::kCenterLine;
    int thickness = scaledThickness(scale, 1);

    float ext = radiusPx + 8.0f * scale;

    // Linhas de centro (traço-ponto longo/curto)
    // Horizontal
    float x_start = center.x - ext;
    float x_end = center.x + ext;
    float y = center.y;

    float dashLen = 12.0f * scale;
    float dotLen = 3.0f * scale;
    float gapLen = 4.0f * scale;

    float x = x_start;
    bool longDash = true;
    while (x < x_end) {
        float segLen = longDash ? dashLen : dotLen;
        float xe = std::min(x + segLen, x_end);
        cv::line(img, cv::Point2f(x, y), cv::Point2f(xe, y), color, thickness,
                 cv::LINE_AA);
        x = xe + gapLen;
        longDash = !longDash;
    }

    // Vertical
    float y_start = center.y - ext;
    float y_end = center.y + ext;
    float xc = center.x;

    float yy = y_start;
    longDash = true;
    while (yy < y_end) {
        float segLen = longDash ? dashLen : dotLen;
        float ye = std::min(yy + segLen, y_end);
        cv::line(img, cv::Point2f(xc, yy), cv::Point2f(xc, ye), color,
                 thickness, cv::LINE_AA);
        yy = ye + gapLen;
        longDash = !longDash;
    }
}

void drawTechnicalFrame(cv::Mat &img, float mmPerPx, int edgeCount,
                        int holeCount, int arcCount) {
    const float scale = annotationScale(img);
    const cv::Scalar &borderColor = DrawColors::kFrameBorder;
    const cv::Scalar &textColor = DrawColors::kFrameText;

    const int w = img.cols;
    const int h = img.rows;
    const int margin = static_cast<int>(12.0f * scale);

    // Moldura dupla
    cv::rectangle(img, cv::Point(margin, margin),
                  cv::Point(w - margin, h - margin), borderColor,
                  scaledThickness(scale, 2), cv::LINE_AA);
    cv::rectangle(img, cv::Point(margin + 3, margin + 3),
                  cv::Point(w - margin - 3, h - margin - 3), borderColor,
                  scaledThickness(scale, 1), cv::LINE_AA);

    // Info box no canto inferior direito
    const int boxW = static_cast<int>(260.0f * scale);
    const int boxH = static_cast<int>(80.0f * scale);
    const int boxX = w - margin - boxW - 4;
    const int boxY = h - margin - boxH - 4;

    cv::rectangle(img, cv::Point(boxX, boxY),
                  cv::Point(boxX + boxW, boxY + boxH),
                  DrawColors::kTextBgAlpha, cv::FILLED);
    cv::rectangle(img, cv::Point(boxX, boxY),
                  cv::Point(boxX + boxW, boxY + boxH), borderColor,
                  scaledThickness(scale, 1), cv::LINE_AA);

    // Linha divisória horizontal
    const int divY = boxY + static_cast<int>(28.0f * scale);
    cv::line(img, cv::Point(boxX, divY), cv::Point(boxX + boxW, divY),
             borderColor, 1, cv::LINE_AA);

    double titleFont = 0.45 * scale;
    double infoFont = 0.35 * scale;
    int titleThick = scaledThickness(scale, 2);
    int infoThick = scaledThickness(scale, 1);

    // Título
    cv::putText(img, "INSPECAO DIMENSIONAL",
                cv::Point2f(static_cast<float>(boxX + 8),
                            static_cast<float>(boxY + 20 * scale)),
                cv::FONT_HERSHEY_SIMPLEX, titleFont,
                cv::Scalar(30, 30, 30), titleThick, cv::LINE_AA);

    // Escala
    char scaleTxt[64];
    snprintf(scaleTxt, sizeof(scaleTxt), "Escala: %.4f mm/px", mmPerPx);
    cv::putText(img, scaleTxt,
                cv::Point2f(static_cast<float>(boxX + 8),
                            static_cast<float>(divY + 18 * scale)),
                cv::FONT_HERSHEY_SIMPLEX, infoFont, textColor, infoThick,
                cv::LINE_AA);

    // Contagens
    char countTxt[128];
    snprintf(countTxt, sizeof(countTxt), "Arestas: %d | Furos: %d | Arcos: %d",
             edgeCount, holeCount, arcCount);
    cv::putText(img, countTxt,
                cv::Point2f(static_cast<float>(boxX + 8),
                            static_cast<float>(divY + 38 * scale)),
                cv::FONT_HERSHEY_SIMPLEX, infoFont, textColor, infoThick,
                cv::LINE_AA);
}

void drawReferenceGrid(cv::Mat &img, float mmPerPx) {
    if (mmPerPx <= 0.0f) return;

    const cv::Scalar &gridColor = DrawColors::kGridLine;
    const float gridSpacingMm = 10.0f; // Grid a cada 10mm
    const float gridSpacingPx = gridSpacingMm / mmPerPx;

    if (gridSpacingPx < 15.0f) return; // Não desenhar se for muito fino

    const int w = img.cols;
    const int h = img.rows;

    // Linhas verticais
    for (float x = gridSpacingPx; x < static_cast<float>(w);
         x += gridSpacingPx) {
        cv::line(img, cv::Point(cvRound(x), 0), cv::Point(cvRound(x), h - 1),
                 gridColor, 1, cv::LINE_AA);
    }

    // Linhas horizontais
    for (float y = gridSpacingPx; y < static_cast<float>(h);
         y += gridSpacingPx) {
        cv::line(img, cv::Point(0, cvRound(y)), cv::Point(w - 1, cvRound(y)),
                 gridColor, 1, cv::LINE_AA);
    }
}
