import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The text field whose label is [label].
Finder textFieldLabelled(String label) => find.widgetWithText(TextField, label);

/// Whether the field labelled [label] accepts input.
bool isFieldEnabled(WidgetTester tester, String label) =>
    tester.widget<TextField>(textFieldLabelled(label)).enabled ?? true;
