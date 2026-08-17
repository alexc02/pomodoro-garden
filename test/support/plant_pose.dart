import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_garden/src/garden/growing_plant.dart';
import 'package:pip_garden/src/garden/plant_painter.dart';

/// Bloom progress of the timer screen's plant (0 to 1), read off the painter.
double bloomOnScreen(WidgetTester tester) => (tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byType(GrowingPlant),
            matching: find.byType(CustomPaint),
          ),
        )
        .painter! as PlantPainter)
    .bloom;
