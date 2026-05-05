#ifndef DRAWING_UTILS_H
#define DRAWING_UTILS_H

#include <opencv2/opencv.hpp>
#include <string>

// ===== Paleta de Cores — Desenho Técnico Industrial =====
namespace DrawColors {
// Cotas lineares (azul petróleo)
const cv::Scalar kDimLine(140, 80, 10);    // BGR — azul escuro
const cv::Scalar kDimText(180, 60, 0);     // BGR — azul texto
// Raios e diâmetros (verde esmeralda)
const cv::Scalar kRadiusLine(60, 140, 30); // BGR — verde
const cv::Scalar kRadiusText(40, 130, 20); // BGR — verde texto
// Ângulos (laranja/âmbar)
const cv::Scalar kAngleLine(20, 120, 220); // BGR — laranja
const cv::Scalar kAngleText(10, 100, 200); // BGR — laranja texto
// Contorno da peça
const cv::Scalar kOutlineStraight(30, 30, 30);  // preto forte
const cv::Scalar kOutlineArc(160, 80, 20);      // azul para arcos
// Furos
const cv::Scalar kHoleOutline(100, 100, 100);    // cinza médio
const cv::Scalar kCenterLine(180, 180, 180);     // cinza claro
// Moldura
const cv::Scalar kFrameBorder(60, 60, 60);
const cv::Scalar kFrameText(80, 80, 80);
const cv::Scalar kGridLine(235, 235, 235);       // cinza muito claro
// Fundo do texto
const cv::Scalar kTextBg(255, 255, 255);
const cv::Scalar kTextBgAlpha(245, 248, 252);    // quase branco
} // namespace DrawColors

// Cota linear com extensões, setas e texto
void drawDimensionLine(cv::Mat &img, cv::Point2f p1, cv::Point2f p2,
                       float realValue, int offsetDirection);

// Cota angular com arco e texto
void drawAngleDimension(cv::Mat &img, cv::Point2f center, cv::Point2f p1,
                        cv::Point2f p2, float angleDeg);

// Cota de raio para arcos/semicírculos (R...)
void drawCircleDimension(cv::Mat &img, cv::Point2f center, float radiusPx,
                         float radiusMm);

// Cota de diâmetro para furos completos (Ø...)
void drawDiameterDimension(cv::Mat &img, cv::Point2f center, float radiusPx,
                           float diameterMm);

// Cota de slot/pílula (largura x comprimento)
void drawSlotDimension(cv::Mat &img, cv::Point2f center, float widthMm,
                       float lengthMm, float angleDeg);

// Marcação visual (contorno) do slot
void drawSlotContour(cv::Mat &img, cv::Point2f center, float widthPx,
                     float lengthPx, float angleDeg);

// Linhas de centro (traço-ponto) para furos e slots
void drawCenterLines(cv::Mat &img, cv::Point2f center, float radiusPx);

// Gerenciador simples para evitar sobreposição de anotações
class LabelManager {
public:
    static LabelManager& getInstance() {
        static LabelManager instance;
        return instance;
    }
    void clear() { occupied.clear(); piece_polygons.clear(); }
    void addRect(const cv::Rect& r) { occupied.push_back(r); }
    void addPiecePolygon(const std::vector<cv::Point>& poly) { piece_polygons.push_back(poly); }
    
    bool overlaps(const cv::Rect& r) const {
        // Verifica sobreposição com outros labels
        for (const auto& o : occupied) {
            if ((o & r).area() > 0) return true;
        }
        // Verifica sobreposição com a própria peça
        for (const auto& p : piece_polygons) {
            // Verifica se algum canto do retângulo está dentro da peça
            cv::Point corners[4] = { 
                {r.x, r.y}, {r.x + r.width, r.y}, 
                {r.x, r.y + r.height}, {r.x + r.width, r.y + r.height} 
            };
            for (int i = 0; i < 4; ++i) {
                if (cv::pointPolygonTest(p, corners[i], false) >= 0) return true;
            }
        }
        return false;
    }
    // Tenta encontrar uma posição próxima sem sobreposição
    cv::Point2f getClearPos(cv::Point2f preferred, cv::Size sz, float pad);

private:
    LabelManager() = default;
    std::vector<cv::Rect> occupied;
    std::vector<std::vector<cv::Point>> piece_polygons;
};

// Moldura de desenho técnico com informações
void drawTechnicalFrame(cv::Mat &img, float mmPerPx, int edgeCount,
                        int holeCount, int arcCount);

// Grid de referência sutil
void drawReferenceGrid(cv::Mat &img, float mmPerPx);

#endif // DRAWING_UTILS_H
