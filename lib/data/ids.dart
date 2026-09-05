import 'dart:math';

final _rng = Random.secure();

/// 128 random bits as 32 hex characters. Collision-free for our purposes,
/// sortable by nothing — creation order lives in `createdAt`, not the id.
String newId() {
  final b = StringBuffer();
  for (var i = 0; i < 16; i++) {
    b.write(_rng.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return b.toString();
}
