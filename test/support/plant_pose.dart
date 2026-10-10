import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_garden/src/garden/growing_plant.dart';
import 'package:pomodoro_garden/src/garden/plant_painter.dart';

/// How far through §5.3's bloom the timer screen's plant is: 0 before it, 1
/// once it has run.
///
/// Read off the painter rather than the pixels, for the reason
/// `test/garden/growing_plant_test.dart` gives — it is a number, and the tests
/// that ask about it through the real app want the number.
double bloomOnScreen(WidgetTester tester) => (tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byType(GrowingPlant),
            matching: find.byType(CustomPaint),
          ),
        )
        .painter! as PlantPainter)
    .bloom;
