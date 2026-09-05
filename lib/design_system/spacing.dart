import 'package:flutter/widgets.dart';

/// SPEC Part B.3 — space, radius, targets, motion.

class Space {
  Space._();
  static const x4 = 4.0;
  static const x8 = 8.0;
  static const x12 = 12.0;
  static const x16 = 16.0;
  static const x24 = 24.0;
  static const x32 = 32.0;
  static const x48 = 48.0;

  /// Screen edge inset.
  static const gutter = 20.0;
}

class Radii {
  Radii._();
  static const tile = 16.0;

  /// Sheets: top corners only.
  static const sheet = 24.0;
  static const button = 12.0;
  static const chip = 8.0;
  static const input = 10.0;

  /// List rows are square. Always.
  static const row = 0.0;
}

class Targets {
  Targets._();

  /// 48×48, not 44 — a parked car, one hand, sometimes dirty.
  static const min = 48.0;
}

/// "In a diagnostic tool, animation latency is a correctness bug."
///
/// Every duration goes through [of], which returns zero when the platform
/// asks for reduced motion. The live numeric value never animates at all.
class Motion {
  Motion._();

  /// Direct swap. Not a tween, not a fade, not a count-up.
  static const value = Duration.zero;
  static const rangeBar = Duration(milliseconds: 120);
  static const stalenessDecay = Duration(milliseconds: 400);
  static const tilePress = Duration(milliseconds: 80);
  static const sheet = Duration(milliseconds: 280);

  /// One pulse when a fault appears. Never loops.
  static const faultPulse = Duration(milliseconds: 200);

  /// A generic layout change (a banner pushing content).
  static const layout = Duration(milliseconds: 200);

  static const easeOut = Curves.easeOut;

  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.maybeDisableAnimationsOf(context) == true ? Duration.zero : d;

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) == true;
}
