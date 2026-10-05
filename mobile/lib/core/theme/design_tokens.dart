import 'package:flutter/material.dart';

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
