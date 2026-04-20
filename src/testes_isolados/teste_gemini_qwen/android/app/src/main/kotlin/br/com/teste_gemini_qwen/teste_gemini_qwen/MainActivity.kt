package br.com.teste_gemini_qwen.teste_gemini_qwen

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.opencv.android.OpenCVLoader
import org.opencv.core.Core
import org.opencv.core.Mat
import org.opencv.core.MatOfPoint
import org.opencv.core.MatOfPoint2f
import org.opencv.core.Point
import org.opencv.core.Rect
import org.opencv.core.RotatedRect
import org.opencv.core.Size
import org.opencv.imgcodecs.Imgcodecs
import org.opencv.imgproc.Imgproc
import org.opencv.objdetect.ArucoDetector
import org.opencv.objdetect.DetectorParameters
import org.opencv.objdetect.Objdetect
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "br.com.teste_gemini_qwen/metrology"
        private const val DEFAULT_MARKER_SIZE_MM = 23.0
    }

    private enum class MeasurementMode {
        AUTO,
        OUTER_SPAN,
        HOLE_DIAMETER,
        CENTER_DISTANCE,
        EDGE_TO_HOLE_CENTER,
        SLOT_WIDTH,
    }

    private enum class AxisPreference {
        AUTO,
        HORIZONTAL,
        VERTICAL,
    }

    private data class MarkerDetection(
        val id: Int,
        val corners: List<Point>,
        val center: Point,
    )

    private data class ArucoScale(
        val mmPerPixel: Double,
        val markerCount: Int,
        val quality: Double,
        val rectifiedImage: Mat,
        val debug: String,
    )

    private data class HoleFeature(
        val center: Point,
        val diameterPx: Double,
        val circularity: Double,
    )

    private data class FeatureExtraction(
        val boundingRect: Rect,
        val rotatedRect: RotatedRect,
        val holes: List<HoleFeature>,
        val slotWidthsPx: List<Double>,
        val debug: String,
    )

    private data class MeasurementCandidate(
        val mode: MeasurementMode,
        val label: String,
        val valueMm: Double,
        val confidence: Double,
    )

    private data class MeasurementOutcome(
        val valueMm: Double,
        val confidence: Double,
        val debug: String,
    )

    private data class Segment(
        val p1: Point,
        val p2: Point,
        val length: Double,
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        initializeOpenCv()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "processImage" -> {
                        val imagePath = call.argument<String>("imagePath")
                        if (imagePath.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "imagePath is required", null)
                            return@setMethodCallHandler
                        }

                        val analysisType = call.argument<String>("analysisType") ?: "aruco_2d"
                        val measurementMode = call.argument<String>("measurementMode") ?: "auto"
                        val axisPreference = call.argument<String>("axisPreference") ?: "auto"
                        val targetHint = call.argument<String>("targetHint") ?: ""
                        val requiresAllMarkers = call.argument<Boolean>("requiresAllMarkers") ?: true
                        val expectedValue = dynamicToDouble(call.argument<Any>("expectedValue"))
                        val markerSizeMm = dynamicToDouble(
                            call.argument<Any>("markerSizeMm"),
                            fallback = DEFAULT_MARKER_SIZE_MM,
                        )

                        try {
                            val payload = processImage(
                                imagePath = imagePath,
                                analysisType = analysisType,
                                measurementMode = measurementMode,
                                axisPreference = axisPreference,
                                targetHint = targetHint,
                                requiresAllMarkers = requiresAllMarkers,
                                expectedValue = expectedValue,
                                markerSizeMm = markerSizeMm,
                            )
                            result.success(payload)
                        } catch (exception: Exception) {
                            result.error(
                                "OPENCV_ERROR",
                                exception.message ?: "Unknown OpenCV error",
                                null,
                            )
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun initializeOpenCv() {
        val initialized = try {
            OpenCVLoader.initDebug()
        } catch (_: Throwable) {
            false
        }

        if (!initialized) {
            try {
                System.loadLibrary("opencv_java4")
            } catch (_: UnsatisfiedLinkError) {
                // The method channel will surface an error when processing starts.
            }
        }
    }

    private fun processImage(
        imagePath: String,
        analysisType: String,
        measurementMode: String,
        axisPreference: String,
        targetHint: String,
        requiresAllMarkers: Boolean,
        expectedValue: Double,
        markerSizeMm: Double,
    ): Map<String, Any> {
        val source = loadImageForProcessing(imagePath, maxSidePx = 3200)
        if (source.empty()) {
            throw IllegalArgumentException("Could not load image: $imagePath")
        }

        return when (analysisType) {
            "angle_profile" -> {
                val measuredAngle = measureProfileAngle(source, expectedValue)
                val markerCount = runCatching { detectMarkers(source).size }.getOrDefault(0)

                mapOf(
                    "measuredValue" to measuredAngle,
                    "unit" to "deg",
                    "markerCount" to markerCount,
                    "confidence" to 0.80,
                    "analysisType" to "angle_profile",
                    "debug" to "angle_hough_lines",
                )
            }

            else -> {
                val mode = parseMeasurementMode(measurementMode)
                val axis = parseAxisPreference(axisPreference)
                val scale = detectArucoScale(source, markerSizeMm, requiresAllMarkers)
                val outcome = measureByGeometry2d(
                    normalized = scale.rectifiedImage,
                    mmPerPixel = scale.mmPerPixel,
                    expectedValue = expectedValue,
                    measurementMode = mode,
                    axisPreference = axis,
                    targetHint = targetHint,
                )

                val confidence = (0.55 * scale.quality + 0.45 * outcome.confidence)
                    .coerceIn(0.20, 0.995)

                mapOf(
                    "measuredValue" to outcome.valueMm,
                    "unit" to "mm",
                    "markerCount" to scale.markerCount,
                    "confidence" to confidence,
                    "analysisType" to "aruco_2d",
                    "debug" to "${scale.debug};${outcome.debug}",
                )
            }
        }
    }

    private fun loadImageForProcessing(imagePath: String, maxSidePx: Int): Mat {
        val source = Imgcodecs.imread(imagePath)
        if (source.empty()) {
            return source
        }

        val width = source.cols()
        val height = source.rows()
        val maxSide = max(width, height)
        if (maxSide <= maxSidePx) {
            return source
        }

        val resizeScale = maxSidePx.toDouble() / maxSide.toDouble()
        val resized = Mat()
        Imgproc.resize(
            source,
            resized,
            Size(width * resizeScale, height * resizeScale),
            0.0,
            0.0,
            Imgproc.INTER_AREA,
        )
        source.release()
        return resized
    }

    private fun detectMarkers(source: Mat): List<MarkerDetection> {
        val gray = Mat()
        Imgproc.cvtColor(source, gray, Imgproc.COLOR_BGR2GRAY)

        val dictionary = Objdetect.getPredefinedDictionary(Objdetect.DICT_4X4_50)
        val parameters = DetectorParameters()
        val detector = ArucoDetector(dictionary, parameters)
        val corners = ArrayList<Mat>()
        val ids = Mat()
        detector.detectMarkers(gray, corners, ids)

        if (corners.isEmpty()) {
            return emptyList()
        }

        val markers = mutableListOf<MarkerDetection>()
        for (index in corners.indices) {
            val markerMat = corners[index]
            val points = mutableListOf<Point>()
            for (cornerIndex in 0..3) {
                val point = markerMat.get(0, cornerIndex)
                if (point != null && point.size >= 2) {
                    points += Point(point[0], point[1])
                }
            }

            if (points.size != 4) {
                continue
            }

            val centerX = points.map { it.x }.average()
            val centerY = points.map { it.y }.average()
            val idValues = ids.get(index, 0)
            val markerId = if (idValues != null && idValues.isNotEmpty()) {
                idValues[0].toInt()
            } else {
                -1
            }

            markers += MarkerDetection(
                id = markerId,
                corners = points,
                center = Point(centerX, centerY),
            )
        }

        return markers
    }

    private fun averageMarkerSidePx(corners: List<Point>): Double {
        if (corners.size < 4) {
            return 0.0
        }

        var sideSum = 0.0
        for (index in 0..3) {
            sideSum += distancePx(corners[index], corners[(index + 1) % 4])
        }
        return sideSum / 4.0
    }

    private fun pickBoardMarkers(markers: List<MarkerDetection>, source: Mat): List<MarkerDetection> {
        if (markers.size < 4) {
            throw IllegalStateException("Found ${markers.size} ArUco markers. Need 4 markers visible.")
        }

        val targets = listOf(
            Point(0.0, 0.0),
            Point(source.cols().toDouble(), 0.0),
            Point(source.cols().toDouble(), source.rows().toDouble()),
            Point(0.0, source.rows().toDouble()),
        )

        val selected = mutableListOf<MarkerDetection>()
        val usedIndices = mutableSetOf<Int>()

        for (target in targets) {
            val closest = markers.withIndex()
                .filter { candidate -> candidate.index !in usedIndices }
                .minByOrNull { candidate -> distancePx(candidate.value.center, target) }
                ?: continue

            selected += closest.value
            usedIndices += closest.index
        }

        if (selected.size != 4) {
            throw IllegalStateException("Could not map the 4 board ArUco markers reliably.")
        }

        return selected
    }

    private fun warpPoints(points: List<Point>, homography: Mat): List<Point> {
        if (points.isEmpty()) {
            return emptyList()
        }

        val src = MatOfPoint2f(*points.toTypedArray())
        val dst = MatOfPoint2f()
        Core.perspectiveTransform(src, dst, homography)
        return dst.toArray().toList()
    }

    private fun detectArucoScale(
        source: Mat,
        markerSizeMm: Double,
        requiresAllMarkers: Boolean,
    ): ArucoScale {
        val markers = detectMarkers(source)
        if (markers.isEmpty()) {
            throw IllegalStateException("No ArUco markers were detected.")
        }

        if (markers.size < 4 && requiresAllMarkers) {
            throw IllegalStateException("Found ${markers.size} ArUco markers. Need 4 markers visible.")
        }

        if (markers.size < 4) {
            val sideSamples = markers.map { marker -> averageMarkerSidePx(marker.corners) }
                .filter { side -> side > 0.0 }
            if (sideSamples.isEmpty()) {
                throw IllegalStateException("Could not compute ArUco side length.")
            }
            val sidePx = median(sideSamples)
            val mmPerPixel = markerSizeMm / sidePx
            return ArucoScale(
                mmPerPixel = mmPerPixel,
                markerCount = markers.size,
                quality = 0.35,
                rectifiedImage = source,
                debug = "markers=${markers.size};fallback_scale_only=true;marker_px=$sidePx;mm_per_px=$mmPerPixel",
            )
        }

        val boardMarkers = pickBoardMarkers(markers, source)
        val srcQuad = MatOfPoint2f(
            boardMarkers[0].center,
            boardMarkers[1].center,
            boardMarkers[2].center,
            boardMarkers[3].center,
        )

        val topWidth = distancePx(boardMarkers[0].center, boardMarkers[1].center)
        val bottomWidth = distancePx(boardMarkers[3].center, boardMarkers[2].center)
        val leftHeight = distancePx(boardMarkers[0].center, boardMarkers[3].center)
        val rightHeight = distancePx(boardMarkers[1].center, boardMarkers[2].center)

        val targetWidth = max(topWidth, bottomWidth).coerceIn(400.0, 4000.0)
        val targetHeight = max(leftHeight, rightHeight).coerceIn(400.0, 4000.0)

        val dstQuad = MatOfPoint2f(
            Point(0.0, 0.0),
            Point(targetWidth - 1.0, 0.0),
            Point(targetWidth - 1.0, targetHeight - 1.0),
            Point(0.0, targetHeight - 1.0),
        )

        val homography = Imgproc.getPerspectiveTransform(srcQuad, dstQuad)
        val rectified = Mat()
        Imgproc.warpPerspective(
            source,
            rectified,
            homography,
            Size(targetWidth, targetHeight),
            Imgproc.INTER_CUBIC,
        )

        val warpedMarkerSidesPx = mutableListOf<Double>()
        for (marker in boardMarkers) {
            val warpedCorners = warpPoints(marker.corners, homography)
            if (warpedCorners.size < 4) {
                continue
            }
            warpedMarkerSidesPx += averageMarkerSidePx(warpedCorners)
        }

        if (warpedMarkerSidesPx.isEmpty()) {
            throw IllegalStateException("Could not compute ArUco side length after rectification.")
        }

        val medianSidePx = median(warpedMarkerSidesPx)
        if (medianSidePx <= 0.0) {
            throw IllegalStateException("Invalid ArUco side in pixels.")
        }

        val variation = coefficientOfVariation(warpedMarkerSidesPx)
        if (variation > 0.28) {
            throw IllegalStateException(
                "ArUco geometry unstable (cv=${"%.3f".format(variation)}). Reposition camera and keep all markers flat.",
            )
        }

        val quality = (1.0 - variation).coerceIn(0.25, 0.995)
        val mmPerPixel = markerSizeMm / medianSidePx

        return ArucoScale(
            mmPerPixel = mmPerPixel,
            markerCount = markers.size,
            quality = quality,
            rectifiedImage = rectified,
            debug = "markers=${markers.size};median_marker_px=$medianSidePx;cv=$variation;mm_per_px=$mmPerPixel",
        )
    }

    private fun parseMeasurementMode(raw: String): MeasurementMode {
        return when (raw.trim().lowercase()) {
            "outer_span", "overall_length", "overall_width" -> MeasurementMode.OUTER_SPAN
            "hole_diameter", "diameter" -> MeasurementMode.HOLE_DIAMETER
            "center_distance", "hole_center_distance", "distance_between_centers" -> MeasurementMode.CENTER_DISTANCE
            "edge_to_hole_center", "edge_hole_center" -> MeasurementMode.EDGE_TO_HOLE_CENTER
            "slot_width", "channel_width" -> MeasurementMode.SLOT_WIDTH
            else -> MeasurementMode.AUTO
        }
    }

    private fun parseAxisPreference(raw: String): AxisPreference {
        return when (raw.trim().lowercase()) {
            "x", "horizontal" -> AxisPreference.HORIZONTAL
            "y", "vertical" -> AxisPreference.VERTICAL
            else -> AxisPreference.AUTO
        }
    }

    private fun inferModeFromHint(targetHint: String): MeasurementMode? {
        val normalized = targetHint.lowercase()
        return when {
            normalized.contains("diam") || normalized.contains("furo") -> MeasurementMode.HOLE_DIAMETER
            normalized.contains("centro") || normalized.contains("entre") -> MeasurementMode.CENTER_DISTANCE
            normalized.contains("borda") || normalized.contains("aresta") || normalized.contains("offset") -> MeasurementMode.EDGE_TO_HOLE_CENTER
            normalized.contains("rasgo") || normalized.contains("slot") || normalized.contains("canal") -> MeasurementMode.SLOT_WIDTH
            normalized.contains("comprimento") || normalized.contains("largura") || normalized.contains("altura") -> MeasurementMode.OUTER_SPAN
            else -> null
        }
    }

    private fun extractFeatures(normalized: Mat): FeatureExtraction {
        val gray = Mat()
        Imgproc.cvtColor(normalized, gray, Imgproc.COLOR_BGR2GRAY)
        Imgproc.GaussianBlur(gray, gray, Size(5.0, 5.0), 0.0)

        val binary = Mat()
        Imgproc.threshold(gray, binary, 0.0, 255.0, Imgproc.THRESH_BINARY + Imgproc.THRESH_OTSU)

        val whiteRatio = Core.countNonZero(binary).toDouble() /
            (binary.rows().toDouble() * binary.cols().toDouble())
        if (whiteRatio > 0.55) {
            Core.bitwise_not(binary, binary)
        }

        val kernel = Imgproc.getStructuringElement(Imgproc.MORPH_RECT, Size(3.0, 3.0))
        Imgproc.morphologyEx(binary, binary, Imgproc.MORPH_OPEN, kernel)
        Imgproc.morphologyEx(binary, binary, Imgproc.MORPH_CLOSE, kernel)

        val contours = ArrayList<MatOfPoint>()
        val hierarchy = Mat()
        Imgproc.findContours(
            binary.clone(),
            contours,
            hierarchy,
            Imgproc.RETR_CCOMP,
            Imgproc.CHAIN_APPROX_SIMPLE,
        )

        if (contours.isEmpty()) {
            throw IllegalStateException("No contour found for the part.")
        }

        val imageArea = normalized.cols().toDouble() * normalized.rows().toDouble()
        var primaryIndex = -1
        var largestArea = -1.0

        for (index in contours.indices) {
            val area = Imgproc.contourArea(contours[index])
            if (area < imageArea * 0.01 || area > imageArea * 0.97) {
                continue
            }
            if (area > largestArea) {
                largestArea = area
                primaryIndex = index
            }
        }

        if (primaryIndex < 0) {
            for (index in contours.indices) {
                val area = Imgproc.contourArea(contours[index])
                if (area > largestArea) {
                    largestArea = area
                    primaryIndex = index
                }
            }
        }

        if (primaryIndex < 0) {
            throw IllegalStateException("Could not isolate part contour.")
        }

        val primaryContour = contours[primaryIndex]
        val boundingRect = Imgproc.boundingRect(primaryContour)
        val primary2f = MatOfPoint2f(*primaryContour.toArray())
        val rotatedRect = Imgproc.minAreaRect(primary2f)

        val holes = mutableListOf<HoleFeature>()
        val slotWidthsPx = mutableListOf<Double>()
        if (!hierarchy.empty()) {
            for (index in contours.indices) {
                val entry = hierarchy.get(0, index) ?: continue
                if (entry.size < 4) {
                    continue
                }

                val parentIndex = entry[3].toInt()
                if (parentIndex != primaryIndex) {
                    continue
                }

                val area = Imgproc.contourArea(contours[index])
                if (area < imageArea * 0.0002) {
                    continue
                }

                val contour2f = MatOfPoint2f(*contours[index].toArray())
                val perimeter = Imgproc.arcLength(contour2f, true)
                if (perimeter <= 0.0) {
                    continue
                }

                val circularity = (4.0 * Math.PI * area) / (perimeter * perimeter)
                val center = Point()
                val radius = FloatArray(1)
                Imgproc.minEnclosingCircle(contour2f, center, radius)

                val diameterPx = radius[0].toDouble() * 2.0
                if (diameterPx <= 2.0) {
                    continue
                }

                if (circularity >= 0.70) {
                    holes += HoleFeature(
                        center = center,
                        diameterPx = diameterPx,
                        circularity = circularity,
                    )
                } else {
                    val slotRect = Imgproc.minAreaRect(contour2f)
                    val slotWidthPx = min(slotRect.size.width, slotRect.size.height)
                    if (slotWidthPx > 2.0) {
                        slotWidthsPx += slotWidthPx
                    }
                }
            }
        }

        if (holes.isEmpty()) {
            val circles = Mat()
            Imgproc.HoughCircles(
                gray,
                circles,
                Imgproc.HOUGH_GRADIENT,
                1.2,
                20.0,
                120.0,
                20.0,
                4,
                0,
            )

            for (col in 0 until circles.cols()) {
                val circle = circles.get(0, col) ?: continue
                if (circle.size < 3) {
                    continue
                }

                holes += HoleFeature(
                    center = Point(circle[0], circle[1]),
                    diameterPx = circle[2] * 2.0,
                    circularity = 0.72,
                )
            }
        }

        return FeatureExtraction(
            boundingRect = boundingRect,
            rotatedRect = rotatedRect,
            holes = holes,
            slotWidthsPx = slotWidthsPx,
            debug = "holes=${holes.size};slots=${slotWidthsPx.size};white_ratio=$whiteRatio;part_area=$largestArea",
        )
    }

    private fun buildMeasurementCandidates(
        features: FeatureExtraction,
        mmPerPixel: Double,
        axisPreference: AxisPreference,
    ): List<MeasurementCandidate> {
        val candidates = mutableListOf<MeasurementCandidate>()

        val majorPx = max(features.rotatedRect.size.width, features.rotatedRect.size.height)
        val minorPx = min(features.rotatedRect.size.width, features.rotatedRect.size.height)
        val horizontalPx = features.boundingRect.width.toDouble()
        val verticalPx = features.boundingRect.height.toDouble()

        val horizontalConfidence =
            if (axisPreference == AxisPreference.HORIZONTAL) 0.82 else 0.70
        val verticalConfidence =
            if (axisPreference == AxisPreference.VERTICAL) 0.82 else 0.70

        candidates += MeasurementCandidate(
            mode = MeasurementMode.OUTER_SPAN,
            label = "outer_major",
            valueMm = majorPx * mmPerPixel,
            confidence = 0.78,
        )
        candidates += MeasurementCandidate(
            mode = MeasurementMode.OUTER_SPAN,
            label = "outer_minor",
            valueMm = minorPx * mmPerPixel,
            confidence = 0.73,
        )
        candidates += MeasurementCandidate(
            mode = MeasurementMode.OUTER_SPAN,
            label = "outer_horizontal",
            valueMm = horizontalPx * mmPerPixel,
            confidence = horizontalConfidence,
        )
        candidates += MeasurementCandidate(
            mode = MeasurementMode.OUTER_SPAN,
            label = "outer_vertical",
            valueMm = verticalPx * mmPerPixel,
            confidence = verticalConfidence,
        )

        for ((index, hole) in features.holes.withIndex()) {
            candidates += MeasurementCandidate(
                mode = MeasurementMode.HOLE_DIAMETER,
                label = "hole_diameter_$index",
                valueMm = hole.diameterPx * mmPerPixel,
                confidence = (0.68 + hole.circularity * 0.20).coerceIn(0.45, 0.95),
            )

            val leftPx = hole.center.x - features.boundingRect.x
            val rightPx = features.boundingRect.x + features.boundingRect.width - hole.center.x
            val topPx = hole.center.y - features.boundingRect.y
            val bottomPx = features.boundingRect.y + features.boundingRect.height - hole.center.y

            val edgeDistancePx = when (axisPreference) {
                AxisPreference.HORIZONTAL -> min(leftPx, rightPx)
                AxisPreference.VERTICAL -> min(topPx, bottomPx)
                AxisPreference.AUTO -> min(min(leftPx, rightPx), min(topPx, bottomPx))
            }

            if (edgeDistancePx > 1.0) {
                candidates += MeasurementCandidate(
                    mode = MeasurementMode.EDGE_TO_HOLE_CENTER,
                    label = "edge_to_hole_$index",
                    valueMm = edgeDistancePx * mmPerPixel,
                    confidence = (0.62 + hole.circularity * 0.20).coerceIn(0.40, 0.90),
                )
            }
        }

        for (indexA in features.holes.indices) {
            for (indexB in indexA + 1 until features.holes.size) {
                val a = features.holes[indexA]
                val b = features.holes[indexB]

                val distanceBetweenCentersPx = when (axisPreference) {
                    AxisPreference.HORIZONTAL -> abs(a.center.x - b.center.x)
                    AxisPreference.VERTICAL -> abs(a.center.y - b.center.y)
                    AxisPreference.AUTO -> distancePx(a.center, b.center)
                }

                if (distanceBetweenCentersPx <= 1.0) {
                    continue
                }

                val pairConfidence = min(a.circularity, b.circularity)
                candidates += MeasurementCandidate(
                    mode = MeasurementMode.CENTER_DISTANCE,
                    label = "center_distance_${indexA}_$indexB",
                    valueMm = distanceBetweenCentersPx * mmPerPixel,
                    confidence = (0.62 + pairConfidence * 0.20).coerceIn(0.40, 0.92),
                )
            }
        }

        for ((index, slotWidthPx) in features.slotWidthsPx.withIndex()) {
            candidates += MeasurementCandidate(
                mode = MeasurementMode.SLOT_WIDTH,
                label = "slot_width_$index",
                valueMm = slotWidthPx * mmPerPixel,
                confidence = 0.64,
            )
        }

        return candidates.filter { candidate ->
            candidate.valueMm.isFinite() && candidate.valueMm > 0.0
        }
    }

    private fun pickBestCandidate(
        candidates: List<MeasurementCandidate>,
        expectedValue: Double,
        measurementMode: MeasurementMode,
        targetHint: String,
    ): MeasurementCandidate {
        if (candidates.isEmpty()) {
            throw IllegalStateException("No geometric candidate found for measurement.")
        }

        val filtered = if (measurementMode == MeasurementMode.AUTO) {
            candidates
        } else {
            candidates.filter { it.mode == measurementMode }
        }

        val pool = if (filtered.isNotEmpty()) filtered else candidates
        val preferredFromHint = inferModeFromHint(targetHint)

        var best: MeasurementCandidate? = null
        var bestScore = Double.MAX_VALUE

        for (candidate in pool) {
            var score = if (expectedValue > 0.0) {
                abs(candidate.valueMm - expectedValue)
            } else {
                0.0
            }

            if (preferredFromHint != null && candidate.mode == preferredFromHint) {
                score *= 0.72
            }

            if (measurementMode != MeasurementMode.AUTO && candidate.mode != measurementMode) {
                score *= 1.35
            }

            score -= candidate.confidence * 0.05

            if (score < bestScore) {
                bestScore = score
                best = candidate
            }
        }

        val selected = best ?: throw IllegalStateException("Could not select a measurement candidate.")

        if (expectedValue > 0.0) {
            val hardLimitMm = max(1.20, expectedValue * 0.18)
            val mismatch = abs(selected.valueMm - expectedValue)
            if (mismatch > hardLimitMm) {
                throw IllegalStateException(
                    "No reliable target matched expected dimension ($expectedValue mm). Captured feature mismatch is too high.",
                )
            }
        }

        return selected
    }

    private fun scoreMeasurementConfidence(
        selected: MeasurementCandidate,
        expectedValue: Double,
    ): Double {
        val closeness = if (expectedValue > 0.0) {
            val error = abs(selected.valueMm - expectedValue)
            val toleranceWindow = max(0.60, expectedValue * 0.20)
            (1.0 - (error / toleranceWindow)).coerceIn(0.0, 1.0)
        } else {
            0.55
        }

        return (0.35 + 0.40 * closeness + 0.25 * selected.confidence)
            .coerceIn(0.20, 0.99)
    }

    private fun measureByGeometry2d(
        normalized: Mat,
        mmPerPixel: Double,
        expectedValue: Double,
        measurementMode: MeasurementMode,
        axisPreference: AxisPreference,
        targetHint: String,
    ): MeasurementOutcome {
        val features = extractFeatures(normalized)
        val candidates = buildMeasurementCandidates(features, mmPerPixel, axisPreference)
        val selected = pickBestCandidate(
            candidates = candidates,
            expectedValue = expectedValue,
            measurementMode = measurementMode,
            targetHint = targetHint,
        )

        val confidence = scoreMeasurementConfidence(selected, expectedValue)
        return MeasurementOutcome(
            valueMm = selected.valueMm,
            confidence = confidence,
            debug = "candidate=${selected.label};mode=${selected.mode};${features.debug}",
        )
    }

    private fun measureProfileAngle(source: Mat, expectedAngle: Double): Double {
        val gray = Mat()
        Imgproc.cvtColor(source, gray, Imgproc.COLOR_BGR2GRAY)
        Imgproc.GaussianBlur(gray, gray, Size(5.0, 5.0), 0.0)

        val edges = Mat()
        Imgproc.Canny(gray, edges, 50.0, 150.0)

        val lines = Mat()
        Imgproc.HoughLinesP(edges, lines, 1.0, Math.PI / 180.0, 60, 60.0, 20.0)
        if (lines.rows() < 2) {
            throw IllegalStateException("Not enough lines to estimate bend angle.")
        }

        val segments = mutableListOf<Segment>()
        for (rowIndex in 0 until lines.rows()) {
            val row = lines.get(rowIndex, 0) ?: continue
            if (row.size < 4) {
                continue
            }

            val p1 = Point(row[0], row[1])
            val p2 = Point(row[2], row[3])
            val length = distancePx(p1, p2)
            if (length >= 35.0) {
                segments += Segment(p1, p2, length)
            }
        }

        if (segments.size < 2) {
            throw IllegalStateException("Could not identify enough profile edges.")
        }

        segments.sortByDescending { segment -> segment.length }
        val topSegments = segments.take(12)
        val angleCandidates = mutableListOf<Double>()

        for (indexA in topSegments.indices) {
            for (indexB in indexA + 1 until topSegments.size) {
                val baseAngle = angleBetweenSegments(topSegments[indexA], topSegments[indexB])
                if (baseAngle in 5.0..175.0) {
                    angleCandidates += baseAngle
                }

                val supplementary = 180.0 - baseAngle
                if (supplementary in 5.0..175.0) {
                    angleCandidates += supplementary
                }
            }
        }

        if (angleCandidates.isEmpty()) {
            throw IllegalStateException("No valid angle candidate was found.")
        }

        return if (expectedAngle > 0.0) {
            angleCandidates.minByOrNull { candidate -> abs(candidate - expectedAngle) }
                ?: angleCandidates.first()
        } else {
            angleCandidates.average()
        }
    }

    private fun angleBetweenSegments(first: Segment, second: Segment): Double {
        val firstDx = first.p2.x - first.p1.x
        val firstDy = first.p2.y - first.p1.y
        val secondDx = second.p2.x - second.p1.x
        val secondDy = second.p2.y - second.p1.y

        val firstAngle = Math.toDegrees(Math.atan2(firstDy, firstDx))
        val secondAngle = Math.toDegrees(Math.atan2(secondDy, secondDx))
        var diff = abs(firstAngle - secondAngle)
        while (diff > 180.0) {
            diff -= 180.0
        }
        if (diff > 180.0) {
            diff = 360.0 - diff
        }
        return diff
    }

    private fun median(values: List<Double>): Double {
        if (values.isEmpty()) {
            return 0.0
        }

        val sorted = values.sorted()
        val middle = sorted.size / 2
        return if (sorted.size % 2 == 0) {
            (sorted[middle - 1] + sorted[middle]) / 2.0
        } else {
            sorted[middle]
        }
    }

    private fun coefficientOfVariation(values: List<Double>): Double {
        if (values.isEmpty()) {
            return 1.0
        }

        val avg = values.average()
        if (avg <= 0.0) {
            return 1.0
        }

        val variance = values.map { value ->
            val diff = value - avg
            diff * diff
        }.average()
        return sqrt(variance) / avg
    }

    private fun distancePx(pointA: Point, pointB: Point): Double {
        return hypot(pointA.x - pointB.x, pointA.y - pointB.y)
    }

    private fun dynamicToDouble(value: Any?, fallback: Double = 0.0): Double {
        return when (value) {
            is Number -> value.toDouble()
            is String -> value.replace(',', '.').toDoubleOrNull() ?: fallback
            else -> fallback
        }
    }
}
