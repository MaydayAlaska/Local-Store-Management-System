import 'package:flutter/material.dart';

abstract interface class AppUiStyle {
  String get id;
  String get label;

  ThemeData lightTheme();
  ThemeData darkTheme();
}
