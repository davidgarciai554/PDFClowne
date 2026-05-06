#pragma once

namespace PDFClowne::Heuristics {

constexpr double TEXT_ROTATION_EDITABLE_MAX_DEGREES = 5.0;

constexpr double LINE_BASELINE_TOL_RATIO = 0.3;
constexpr double BLOCK_FONT_SIZE_RATIO_MIN = 0.9;
constexpr double BLOCK_FONT_SIZE_RATIO_MAX = 1.1;
constexpr double BLOCK_COLOR_DISTANCE_MAX = 30.0;
constexpr double BLOCK_LEADING_RATIO_MIN = 0.9;
constexpr double BLOCK_LEADING_RATIO_MAX = 1.8;
constexpr double BLOCK_HORIZ_OVERLAP_MIN = 0.5;
constexpr double BLOCK_INDENT_MAX_RATIO = 2.0;
constexpr double ALIGNMENT_TOLERANCE_RATIO = 0.5;

} // namespace PDFClowne::Heuristics
