import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/tokens.dart';

/// Lucide icons drawn as SVG at stroke-width 1.5.
///
/// The design system calls for Lucide specifically at a 1.5 stroke — an icon
/// font would bake in Lucide's heavier 2.0 default, so the paths are rendered
/// as vectors instead and the weight stays true across every size.
class Lu {
  Lu._();

  // Path data is Lucide's own, on the standard 24×24 grid.
  static const plug =
      '<path d="M12 22v-5"/><path d="M9 8V2"/><path d="M15 8V2"/>'
      '<path d="M18 8v5a4 4 0 0 1-4 4h-4a4 4 0 0 1-4-4V8z"/>';
  static const gauge =
      '<path d="m12 14 4-4"/><path d="M3.34 19a10 10 0 1 1 17.32 0"/>';
  static const activity = '<path d="M22 12h-4l-3 9L9 3l-3 9H2"/>';
  static const car =
      '<path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.4 2.9A3.7 3.7 0 0 0 2 12v4c0 .6.4 1 1 1h2"/>'
      '<circle cx="7" cy="17" r="2"/><path d="M9 17h6"/><circle cx="17" cy="17" r="2"/>';
  static const sliders =
      '<path d="M21 4h-7"/><path d="M10 4H3"/><path d="M21 12h-9"/><path d="M8 12H3"/>'
      '<path d="M21 20h-5"/><path d="M12 20H3"/><path d="M14 2v4"/><path d="M8 10v4"/><path d="M16 18v4"/>';

  static const check = '<path d="M20 6 9 17l-5-5"/>';
  static const x = '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>';
  static const plus = '<path d="M12 5v14"/><path d="M5 12h14"/>';
  static const minus = '<path d="M5 12h14"/>';
  static const chevronRight = '<path d="m9 18 6-6-6-6"/>';
  static const chevronLeft = '<path d="m15 18-6-6 6-6"/>';
  static const chevronDown = '<path d="m6 9 6 6 6-6"/>';
  static const chevronUp = '<path d="m18 15-6-6-6 6"/>';
  static const arrowLeft = '<path d="m12 19-7-7 7-7"/><path d="M19 12H5"/>';
  static const arrowRight = '<path d="M5 12h14"/><path d="m12 5 7 7-7 7"/>';

  static const triangleAlert =
      '<path d="m21.73 18-8-14a2 2 0 0 0-3.46 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3"/>'
      '<path d="M12 9v4"/><path d="M12 17h.01"/>';
  static const circleAlert =
      '<circle cx="12" cy="12" r="10"/><path d="M12 8v4"/><path d="M12 16h.01"/>';
  static const circleCheck =
      '<circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/>';
  static const circleX =
      '<circle cx="12" cy="12" r="10"/><path d="m15 9-6 6"/><path d="m9 9 6 6"/>';
  static const info =
      '<circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/>';
  static const circleDashed =
      '<circle cx="12" cy="12" r="10" stroke-dasharray="3 3"/>';

  static const clock =
      '<circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>';
  static const bluetooth = '<path d="m7 7 10 10-5 5V2l5 5L7 17"/>';
  static const wifi =
      '<path d="M12 20h.01"/><path d="M2 8.82a15 15 0 0 1 20 0"/>'
      '<path d="M5 12.859a10 10 0 0 1 14 0"/><path d="M8.5 16.429a5 5 0 0 1 7 0"/>';
  static const search =
      '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>';
  static const settings = sliders;
  static const trash =
      '<path d="M3 6h18"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/>'
      '<path d="M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>';
  static const share =
      '<path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8"/>'
      '<polyline points="16 6 12 2 8 6"/><path d="M12 2v13"/>';
  static const copy =
      '<rect width="14" height="14" x="8" y="8" rx="2" ry="2"/>'
      '<path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/>';
  static const download =
      '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>'
      '<polyline points="7 10 12 15 17 10"/><path d="M12 15V3"/>';
  static const lock =
      '<rect width="18" height="11" x="3" y="11" rx="2" ry="2"/>'
      '<path d="M7 11V7a5 5 0 0 1 10 0v4"/>';
  static const user =
      '<path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>';
  static const mail =
      '<rect width="20" height="16" x="2" y="4" rx="2"/>'
      '<path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/>';
  static const camera =
      '<path d="M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3z"/>'
      '<circle cx="12" cy="13" r="3"/>';
  static const calendar =
      '<path d="M8 2v4"/><path d="M16 2v4"/>'
      '<rect width="18" height="18" x="3" y="4" rx="2"/><path d="M3 10h18"/>';
  static const fuel =
      '<line x1="3" x2="15" y1="22" y2="22"/><line x1="4" x2="14" y1="9" y2="9"/>'
      '<path d="M14 22V4a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v18"/>'
      '<path d="M14 13h2a2 2 0 0 1 2 2v2a2 2 0 0 0 2 2a2 2 0 0 0 2-2V9.83a2 2 0 0 0-.59-1.42L18 5"/>';
  static const wrench =
      '<path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/>';
  static const bell =
      '<path d="M10.268 21a2 2 0 0 0 3.464 0"/>'
      '<path d="M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326"/>';
  static const fileText =
      '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/>'
      '<path d="M14 2v4a2 2 0 0 0 2 2h4"/><path d="M10 9H8"/><path d="M16 13H8"/><path d="M16 17H8"/>';
  static const shield =
      '<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/>';
  static const refresh =
      '<path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/>'
      '<path d="M21 3v5h-5"/>'
      '<path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"/><path d="M8 16H3v5"/>';
  static const play = '<polygon points="6 3 20 12 6 21 6 3"/>';
  static const square = '<rect width="16" height="16" x="4" y="4" rx="1"/>';
  static const thermometer =
      '<path d="M14 4v10.54a4 4 0 1 1-4 0V4a2 2 0 0 1 4 0Z"/>';
  static const battery =
      '<rect width="16" height="10" x="2" y="7" rx="2" ry="2"/><line x1="22" x2="22" y1="11" y2="13"/>';
  static const smartphone =
      '<rect width="14" height="20" x="5" y="2" rx="2" ry="2"/><path d="M12 18h.01"/>';
  static const externalLink =
      '<path d="M15 3h6v6"/><path d="M10 14 21 3"/>'
      '<path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/>';
  static const grip =
      '<circle cx="9" cy="6" r="1"/><circle cx="9" cy="12" r="1"/><circle cx="9" cy="18" r="1"/>'
      '<circle cx="15" cy="6" r="1"/><circle cx="15" cy="12" r="1"/><circle cx="15" cy="18" r="1"/>';
  static const filter =
      '<polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3"/>';
  static const eye =
      '<path d="M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0"/>'
      '<circle cx="12" cy="12" r="3"/>';
  static const apple =
      '<path d="M12 20.94c1.5 0 2.75 1.06 4 1.06 3 0 6-8 6-12.22A4.91 4.91 0 0 0 17 5c-2.22 0-4 1.44-5 2-1-.56-2.78-2-5-2a4.9 4.9 0 0 0-5 4.78C2 14 5 22 8 22c1.25 0 2.5-1.06 4-1.06Z"/>'
      '<path d="M10 2c1 .5 2 2 2 5"/>';
  static const zap =
      '<path d="M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z"/>';
  static const image =
      '<rect width="18" height="18" x="3" y="3" rx="2" ry="2"/>'
      '<circle cx="9" cy="9" r="2"/><path d="m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21"/>';
  static const cloud =
      '<path d="M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z"/>';
}

/// Renders one of the [Lu] path strings at a given size and colour.
class Icn extends StatelessWidget {
  const Icn(
    this.path, {
    super.key,
    this.size = 20,
    this.color = T.text,
    this.strokeWidth = 1.5,
  });

  final String path;
  final double size;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final hex =
        '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final svg =
        '<svg xmlns="http://www.w3.org/2000/svg" width="$size" height="$size" '
        'viewBox="0 0 24 24" fill="none" stroke="$hex" stroke-width="$strokeWidth" '
        'stroke-linecap="round" stroke-linejoin="round">$path</svg>';
    return SvgPicture.string(
      svg,
      width: size,
      height: size,
      // The colour is already baked into the stroke; opacity is applied by the
      // caller so stale tiles fade the glyph with their value.
    );
  }
}
