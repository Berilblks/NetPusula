import 'package:flutter/material.dart';

abstract final class BrandColors {
  static const navy = Color(0xFF1E1B4B);
  static const purple = Color(0xFF7C3AED);
  static const lavender = Color(0xFFA78BFA);
  static const pink = Color(0xFFF472B6);
  static const coral = Color(0xFFFCA5A5);
  static const background = Color(0xFFF8F7FC);
  static const surface = Color(0xFFFFFFFF);
  static const secondaryText = Color(0xFF77759A);
  // Slightly darker than the reference's secondary text for small text on white.
  static const readableSecondary = Color(0xFF686583);
  static const darkBackground = Color(0xFF121025);
  static const darkSurface = Color(0xFF211E38);
  static const darkText = Color(0xFFF4F0FF);
  static const darkSecondary = Color(0xFFC6BDDE);
  static const headerEnd = Color(0xFF44238A);
  static const header = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy, headerEnd],
  );
  static const compass = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lavender, purple, pink],
  );
}

abstract final class AppSpace {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 24.0, xxl = 32.0;
  static const page = EdgeInsets.fromLTRB(lg, lg, lg, xxl);
  static const card = EdgeInsets.all(lg);
  static const contentWidth = 720.0;
  static const formWidth = 480.0;
}

abstract final class AppRadius {
  static const control = 12.0, card = 20.0;
  static const cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(card)),
  );
}
