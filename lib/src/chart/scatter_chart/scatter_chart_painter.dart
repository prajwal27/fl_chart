import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:fl_chart/src/chart/base/axis_chart/axis_chart_painter.dart';
import 'package:fl_chart/src/chart/base/base_chart/base_chart_painter.dart';
import 'package:fl_chart/src/utils/canvas_wrapper.dart';
import 'package:flutter/material.dart';

import '../../utils/utils.dart';
import 'scatter_chart_data.dart';

/// Paints [ScatterChartData] in the canvas, it can be used in a [CustomPainter]
class ScatterChartPainter extends AxisChartPainter<ScatterChartData> {
  /// [_spotsPaint] is responsible to draw scatter spots
  late Paint _spotsPaint, _bgTouchTooltipPaint;

  /// Paints [dataList] into canvas, it is the animating [ScatterChartData],
  /// [targetData] is the animation's target and remains the same
  /// during animation, then we should use it  when we need to show
  /// tooltips or something like that, because [dataList] is changing constantly.
  ///
  /// [textScale] used for scaling texts inside the chart,
  /// parent can use [MediaQuery.textScaleFactor] to respect
  /// the system's font size.
  ScatterChartPainter() : super() {
    _spotsPaint = Paint()..style = PaintingStyle.fill;

    _bgTouchTooltipPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;
  }

  /// Paints [ScatterChartData] into the provided canvas.
  @override
  void paint(BuildContext context, CanvasWrapper canvasWrapper,
      PaintHolder<ScatterChartData> holder) {
    super.paint(context, canvasWrapper, holder);
    drawSpots(context, canvasWrapper, holder);
    drawTouchTooltips(context, canvasWrapper, holder);
  }

  @visibleForTesting
  void drawSpots(
    BuildContext context,
    CanvasWrapper canvasWrapper,
    PaintHolder<ScatterChartData> holder,
  ) {
    final data = holder.data;
    final viewSize = canvasWrapper.size;
    final clip = data.clipData;
    final border = data.borderData.show ? data.borderData.border : null;

    if (data.clipData.any) {
      canvasWrapper.saveLayer(
        Rect.fromLTRB(
          0,
          0,
          canvasWrapper.size.width,
          canvasWrapper.size.height,
        ),
        Paint(),
      );

      var left = 0.0;
      var top = 0.0;
      var right = viewSize.width;
      var bottom = viewSize.height;

      if (clip.left) {
        final borderWidth = border?.left.width ?? 0;
        left = borderWidth / 2;
      }
      if (clip.top) {
        final borderWidth = border?.top.width ?? 0;
        top = borderWidth / 2;
      }
      if (clip.right) {
        final borderWidth = border?.right.width ?? 0;
        right = viewSize.width - (borderWidth / 2);
      }
      if (clip.bottom) {
        final borderWidth = border?.bottom.width ?? 0;
        bottom = viewSize.height - (borderWidth / 2);
      }

      canvasWrapper.clipRect(Rect.fromLTRB(left, top, right, bottom));
    }

    final List<ScatterSpot> sortedSpots = data.scatterSpots.toList()
      ..sort((ScatterSpot a, ScatterSpot b) => b.radius.compareTo(a.radius));

    for (final scatterSpot in sortedSpots) {
      if (!scatterSpot.show) {
        continue;
      }
      final pixelX = getPixelX(scatterSpot.x, viewSize, holder);
      final pixelY = getPixelY(scatterSpot.y, viewSize, holder);

      _spotsPaint.color = scatterSpot.color;

      canvasWrapper.drawCircle(
        Offset(pixelX, pixelY),
        scatterSpot.radius,
        _spotsPaint,
      );
    }
    //print('original length: ${data.scatterSpots.length}');
    if (data.scatterLabelSettings.showLabel) {
      final List<TextPainter> labelPainters = [];
      Map<TextPainter, ScatterSpot> mapSpot = {};

      for (int i = 0; i < data.scatterSpots.length; i++) {
        final ScatterSpot scatterSpot = data.scatterSpots[i];
        final int spotIndex = i;

        String label =
            data.scatterLabelSettings.getLabelFunction(spotIndex, scatterSpot);

        if (label.isEmpty || !scatterSpot.show) {
          continue;
        }

        final span = TextSpan(
          text: label,
          style: Utils().getThemeAwareTextStyle(
            context,
            data.scatterLabelSettings.getLabelTextStyleFunction(
              spotIndex,
              scatterSpot,
            ),
          ),
        );

        final tp = TextPainter(
          text: span,
          textAlign: TextAlign.center,
          textDirection: holder.data.scatterLabelSettings.textDirection,
          textScaleFactor: holder.textScale,
        );

        tp.layout(maxWidth: viewSize.width);

        labelPainters.add(tp);

        mapSpot[tp] = scatterSpot;
      }

      labelPainters
          .sort((TextPainter a, TextPainter b) => (b.width - a.width).floor());

      List<Rect> listOfRects = [];
      Paint labelPointingPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.black45
        ..strokeWidth = 1;

      //print('new length: ${labelPainters.length}');

      List<Offset> alreadyPlacedLabels = [];
      String stock = "DISCA";
      for (int i = 0; i < labelPainters.length; i++) {
        TextPainter tp = labelPainters[i];
        ScatterSpot currentSpot = mapSpot[tp]!;

        final pixelX = getPixelX(currentSpot.x, viewSize, holder);
        final pixelY = getPixelY(currentSpot.y, viewSize, holder);
        final currentSpotOffset = Offset(pixelX, pixelY);
        //double newPixelY;

        /// To ensure the label is centered horizontally with respect to the spot.
        //double newPixelX = pixelX - tp.width / 2;

        if (tp.text?.toPlainText() == stock) {
          print('chart size: ${viewSize}');
          print('Spot - ${tp.text?.toPlainText()}: ${currentSpot.toString()}');
          print('${currentSpotOffset.toString()}');
        }

        // get list of 9 or less possible positions
        List<Offset> possibleNineCandidates = [];

        // if the label can fit inside the spot, then consider the original position aas a candidate
        if ((currentSpot.radius > tp.height * 2 &&
            currentSpot.radius > tp.width * 2)) {
          if (tp.text?.toPlainText() == stock) {
            print('can fit ${tp.size}');
          }

          possibleNineCandidates.add(currentSpotOffset);
        }

        double incrementalStep = tp.size.longestSide;

        for (int i = 0; i < 8; i++) {
          double radianValue = ((pi / 180) * (45 * i));
          bool foundCandidate = false;
          bool isCrossingChartBoundary = false;
          double currentIncrementalStep = currentSpot.radius +
              (cos(radianValue).abs() * tp.width / 2) +
              (sin(radianValue).abs() * tp.height / 2);
          Offset possibleOffset = currentSpotOffset;

          while (!foundCandidate && !isCrossingChartBoundary) {
            possibleOffset = currentSpotOffset +
                Offset.fromDirection(radianValue, currentIncrementalStep);

            // if is crossing chart, then stop going in this direction
            if (possibleOffset.dx - tp.width / 2 < 0 ||
                possibleOffset.dx + tp.width / 2 > viewSize.width ||
                possibleOffset.dy - tp.height / 2 < 0 ||
                possibleOffset.dy + tp.height / 2 > viewSize.height) {
              isCrossingChartBoundary = true;
              break;
            }

            // check if it's breaking any constraint like, intersecting with other labels.
            //
            // subtracting to make sure (possibleX, possibleY) are in the center of the rect.
            Rect possibleLabelRect = Rect.fromLTWH(
                possibleOffset.dx - tp.width / 2,
                possibleOffset.dy - tp.height / 2,
                tp.width,
                tp.height);

            if (isTouchingWithOtherRects(possibleLabelRect, listOfRects)) {
              // if the label rect is touching other existing labels, then continue searching
              // by moving further away from the original point in the same direction.

              // increase the increment step
              currentIncrementalStep += incrementalStep;
            } else {
              // if the label rect does not touch existing labels, then break the loop
              // and add the offset to the possible list of 8 candidates.
              foundCandidate = true;
              possibleNineCandidates.add(possibleOffset);

              // if (tp.text?.toPlainText() == stock) {
              //   print(
              //       'Found in ${45 * i} direction at (${possibleOffset.toString()})');
              //   canvasWrapper.drawCircle(
              //     possibleOffset,
              //     3,
              //     _spotsPaint,
              //   );
              // }
            }
          }
        }

        double minScore = double.infinity;
        Offset finalOffset = Offset(pixelX, pixelY);
        double k1 = 2, k2 = 10, k3 = 1;
        for (int i = 0; i < possibleNineCandidates.length; i++) {
          Offset candidateOffset = possibleNineCandidates[i];

          double distanceFromOtherLabels = 0;
          double avgDistanceFromOtherLabelsRelativeToWidth = 0;

          double measureOfClosenessToSpotRelativeToWidth = 0;
          double distanceFromOtherSpots = 0;

          if (alreadyPlacedLabels.isNotEmpty) {
            for (Offset labelOffset in alreadyPlacedLabels) {
              distanceFromOtherLabels +=
                  k1 * ((candidateOffset - labelOffset).distance);
            }

            // varies between 0 and 1
            avgDistanceFromOtherLabelsRelativeToWidth =
                distanceFromOtherLabels /
                    (alreadyPlacedLabels.length * viewSize.width);
          }

          measureOfClosenessToSpotRelativeToWidth = k2 *
              (((candidateOffset - currentSpotOffset).distance -
                      currentSpot.radius) /
                  viewSize.width);

          for (ScatterSpot spot in mapSpot.values) {
            if (spot != currentSpot) {
              Offset spotOffset = Offset(getPixelX(spot.x, viewSize, holder),
                  getPixelY(spot.y, viewSize, holder));

              distanceFromOtherSpots +=
                  k3 * ((candidateOffset - spotOffset).distance - spot.radius);
            }
          }

          double avgDistanceFromOtherSpotsRelativeToWidth =
              distanceFromOtherSpots / ((mapSpot.length - 1) * viewSize.width);

          double score = -1 * avgDistanceFromOtherLabelsRelativeToWidth +
              measureOfClosenessToSpotRelativeToWidth -
              avgDistanceFromOtherSpotsRelativeToWidth;

          if (tp.text?.toPlainText() == stock) {
            print(
                'Score for ${candidateOffset.toString()} : $score -- minScore:$minScore');
          }

          // find the position with the least score.
          if (score < minScore) {
            minScore = score;
            finalOffset = candidateOffset;
          }
        }
        if (tp.text?.toPlainText() == stock) {
          print('Final position: ${finalOffset.toString()}');
        }
        //print('spotPos: (${currentSpotOffset.dx},${currentSpotOffset.dy}) , labelPos - (${finalOffset.dx},${finalOffset.dy})');

        alreadyPlacedLabels.add(finalOffset);

        double newPixelX = finalOffset.dx - tp.width / 2;
        double newPixelY = finalOffset.dy - tp.height / 2;

        //double centerChartY = viewSize.height / 2;
        // /// if the spot is in the lower half of the chart, then draw the label either in the center or above the spot,
        // /// if the spot is in upper half of the chart, then draw the label either in the center or below the spot.
        // if (pixelY > centerChartY) {
        //   /// if either the height or the width of the spot is greater than the radius of the spot, then draw the label above the bubble,
        //   /// else draw the label inside the bubble.
        //   var off = (scatterSpot.radius * 1.5 < tp.height ||
        //           scatterSpot.radius * 1.5 < tp.width)
        //       ? scatterSpot.radius + tp.height
        //       : tp.height / 2;
        //
        //   newPixelY = pixelY - off;
        //
        //   print(
        //       'Spot(${scatterSpot.x},${scatterSpot.y}): ${pixelY},${newPixelY} -- tp.width: ${tp.width}, tp.height: ${tp.height}');
        //
        //   Rect originalRect =
        //       Rect.fromLTWH(newPixelX, newPixelY, tp.width, tp.height);
        //   if (!isTouchingWithOtherRects(originalRect, listOfRects)) {
        //     // not touching with other rects, so good.
        //   } else {
        //     double testY = pixelY - scatterSpot.radius - tp.height;
        //     bool searching = true;
        //
        //     while (searching && testY > 0) {
        //       Rect testRect =
        //           Rect.fromLTWH(newPixelX, testY, tp.width, tp.height);
        //       if (isTouchingWithOtherRects(testRect, listOfRects)) {
        //         testY = testY - tp.height;
        //       } else {
        //         searching = false;
        //         newPixelY = testY;
        //       }
        //     }
        //
        //     if (!searching) {
        //       double intersectionCircleY = pixelY - scatterSpot.radius;
        //       double intersectionLabelY = newPixelY + tp.height;
        //       canvasWrapper.drawLine(
        //         Offset(pixelX, intersectionLabelY),
        //         Offset(pixelX, intersectionCircleY),
        //         labelPointingPaint,
        //       );
        //     }
        //   }
        // } else {
        //   /// if either the height or the width of the spot is greater than the radius of the spot, then draw the label below the bubble,
        //   /// else draw the label inside the bubble.
        //   var off = (scatterSpot.radius * 1.5 < tp.height ||
        //           scatterSpot.radius * 1.5 < tp.width)
        //       ? scatterSpot.radius
        //       : -tp.height / 2;
        //   newPixelY = pixelY + off;
        //
        //   Rect originalRect =
        //       Rect.fromLTWH(newPixelX, newPixelY, tp.width, tp.height);
        //   if (!isTouchingWithOtherRects(originalRect, listOfRects)) {
        //     // not touching with other rects, so good.
        //   } else {
        //     double testY = pixelY + scatterSpot.radius;
        //     bool searching = true;
        //
        //     while (searching && testY < viewSize.height) {
        //       Rect testRect =
        //           Rect.fromLTWH(newPixelX, testY, tp.width, tp.height);
        //       if (isTouchingWithOtherRects(testRect, listOfRects)) {
        //         testY = testY + tp.height;
        //       } else {
        //         searching = false;
        //         newPixelY = testY;
        //       }
        //     }
        //
        //     if (!searching) {
        //       double intersectionCircleY = pixelY + scatterSpot.radius;
        //       double intersectionLabelY = newPixelY;
        //       canvasWrapper.drawLine(
        //         Offset(pixelX, intersectionLabelY),
        //         Offset(pixelX, intersectionCircleY),
        //         labelPointingPaint,
        //       );
        //     }
        //   }
        // }

        listOfRects
            .add(Rect.fromLTWH(newPixelX, newPixelY, tp.width, tp.height));

        canvasWrapper.drawText(
          tp,
          Offset(newPixelX, newPixelY),
        );
      }
    }

    if (data.clipData.any) {
      canvasWrapper.restore();
    }
  }

  bool isTouchingWithOtherRects(Rect toBePlotted, List<Rect> listOfRects) {
    for (Rect rect in listOfRects) {
      if (!(toBePlotted.bottom <= rect.top || toBePlotted.top >= rect.bottom)) {
        // vertically the two rects are intersecting or inside one another.
        // checking if horizontally they intersect.

        if (!(toBePlotted.right < rect.left || toBePlotted.left > rect.right)) {
          return true;
        }
      }
    }
    return false;
  }

  @visibleForTesting
  void drawTouchTooltips(BuildContext context, CanvasWrapper canvasWrapper,
      PaintHolder<ScatterChartData> holder) {
    final targetData = holder.targetData;
    for (var i = 0; i < targetData.scatterSpots.length; i++) {
      if (!targetData.showingTooltipIndicators.contains(i)) {
        continue;
      }

      final scatterSpot = targetData.scatterSpots[i];
      drawTouchTooltip(
        context,
        canvasWrapper,
        targetData.scatterTouchData.touchTooltipData,
        scatterSpot,
        holder,
      );
    }
  }

  @visibleForTesting
  void drawTouchTooltip(
      BuildContext context,
      CanvasWrapper canvasWrapper,
      ScatterTouchTooltipData tooltipData,
      ScatterSpot showOnSpot,
      PaintHolder<ScatterChartData> holder) {
    final viewSize = canvasWrapper.size;

    final tooltipItem = tooltipData.getTooltipItems(showOnSpot);

    if (tooltipItem == null) {
      return;
    }

    final span = TextSpan(
      style: Utils().getThemeAwareTextStyle(context, tooltipItem.textStyle),
      text: tooltipItem.text,
      children: tooltipItem.children,
    );

    final drawingTextPainter = TextPainter(
        text: span,
        textAlign: tooltipItem.textAlign,
        textDirection: tooltipItem.textDirection,
        textScaleFactor: holder.textScale);
    drawingTextPainter.layout(maxWidth: tooltipData.maxContentWidth);

    final width = drawingTextPainter.width;
    final height = drawingTextPainter.height;

    /// if we have multiple bar lines,
    /// there are more than one FlCandidate on touch area,
    /// we should get the most top FlSpot Offset to draw the tooltip on top of it
    final mostTopOffset = Offset(
      getPixelX(showOnSpot.x, viewSize, holder),
      getPixelY(showOnSpot.y, viewSize, holder),
    );

    final tooltipWidth = width + tooltipData.tooltipPadding.horizontal;
    final tooltipHeight = height + tooltipData.tooltipPadding.vertical;

    /// draw the background rect with rounded radius
    var rect = Rect.fromLTWH(
      mostTopOffset.dx - (tooltipWidth / 2),
      mostTopOffset.dy -
          tooltipHeight -
          showOnSpot.radius -
          tooltipItem.bottomMargin,
      tooltipWidth,
      tooltipHeight,
    );

    if (tooltipData.fitInsideHorizontally) {
      if (rect.left < 0) {
        final shiftAmount = 0 - rect.left;
        rect = Rect.fromLTRB(
          rect.left + shiftAmount,
          rect.top,
          rect.right + shiftAmount,
          rect.bottom,
        );
      }

      if (rect.right > viewSize.width) {
        final shiftAmount = rect.right - viewSize.width;
        rect = Rect.fromLTRB(
          rect.left - shiftAmount,
          rect.top,
          rect.right - shiftAmount,
          rect.bottom,
        );
      }
    }

    if (tooltipData.fitInsideVertically) {
      if (rect.top < 0) {
        final shiftAmount = 0 - rect.top;
        rect = Rect.fromLTRB(
          rect.left,
          rect.top + shiftAmount,
          rect.right,
          rect.bottom + shiftAmount,
        );
      }

      if (rect.bottom > viewSize.height) {
        final shiftAmount = rect.bottom - viewSize.height;
        rect = Rect.fromLTRB(
          rect.left,
          rect.top - shiftAmount,
          rect.right,
          rect.bottom - shiftAmount,
        );
      }
    }

    final radius = Radius.circular(tooltipData.tooltipRoundedRadius);
    final roundedRect = RRect.fromRectAndCorners(rect,
        topLeft: radius,
        topRight: radius,
        bottomLeft: radius,
        bottomRight: radius);
    _bgTouchTooltipPaint.color = tooltipData.tooltipBgColor;

    final rotateAngle = tooltipData.rotateAngle;
    final rectRotationOffset =
        Offset(0, Utils().calculateRotationOffset(rect.size, rotateAngle).dy);
    final rectDrawOffset = Offset(roundedRect.left, roundedRect.top);

    final textRotationOffset =
        Utils().calculateRotationOffset(drawingTextPainter.size, rotateAngle);

    final drawOffset = Offset(
      rect.center.dx - (drawingTextPainter.width / 2),
      rect.topCenter.dy +
          tooltipData.tooltipPadding.top -
          textRotationOffset.dy +
          rectRotationOffset.dy,
    );
    canvasWrapper.drawRotated(
      size: rect.size,
      rotationOffset: rectRotationOffset,
      drawOffset: rectDrawOffset,
      angle: rotateAngle,
      drawCallback: () {
        canvasWrapper.drawRRect(roundedRect, _bgTouchTooltipPaint);
        canvasWrapper.drawText(drawingTextPainter, drawOffset);
      },
    );
  }

  /// Makes a [ScatterTouchedSpot] based on the provided [localPosition]
  ///
  /// Processes [localPosition] and checks
  /// the elements of the chart that are near the offset,
  /// then makes a [ScatterTouchedSpot] from the elements that has been touched.
  ///
  /// Returns null if finds nothing!
  ScatterTouchedSpot? handleTouch(
    Offset localPosition,
    Size viewSize,
    PaintHolder<ScatterChartData> holder,
  ) {
    final data = holder.data;

    for (var i = 0; i < data.scatterSpots.length; i++) {
      final spot = data.scatterSpots[i];

      final spotPixelX = getPixelX(spot.x, viewSize, holder);
      final spotPixelY = getPixelY(spot.y, viewSize, holder);

      final distance =
          (localPosition - Offset(spotPixelX, spotPixelY)).distance;

      if (distance < spot.radius + data.scatterTouchData.touchSpotThreshold) {
        return ScatterTouchedSpot(spot, i);
      }
    }
    return null;
  }
}
