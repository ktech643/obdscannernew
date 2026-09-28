// Development only: a recorded car on a Wi-Fi ELM327's socket.
//
//     dart run tool/trace_server.dart [trace] [port]
//     flutter run --dart-define=TORQUE_DEV_WIFI=127.0.0.1:35000
//
// Replays a `.obdtrace` (default: assets/traces/trip_drive_can.obdtrace)
// on 127.0.0.1, so the app on the iOS simulator can make a real connection
// — handshake, identity, gauges, a trip recorded to disk and resumed —
// with no car and no adapter. Demo Mode cannot stand in for this: it never
// records against the real garage.
//
// Each command's recorded replies are played in order and then again from
// the first, so a drive that lasts a minute in the recording keeps going:
// every value sent is one the car really sent. Nothing here ships — the
// app offers this endpoint only in a debug build given the define.
import 'dart:async';
import 'dart:io';

import 'package:torque_obd2/transport/obd_trace.dart';

Future<void> main(List<String> args) async {
  final path = args.isNotEmpty
      ? args[0]
      : 'assets/traces/trip_drive_can.obdtrace';
  final port = args.length > 1 ? int.parse(args[1]) : 35000;
  final trace = ObdTrace.parse(File(path).readAsStringSync());
  final replies = trace.repliesByCommand;
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('Replaying $path on 127.0.0.1:$port');

  await for (final socket in server) {
    stdout.writeln('Connected: ${socket.remotePort}');
    // Every connection starts the drive from the top, as a car would after
    // the key is turned.
    final sent = <String, int>{};
    var pending = '';
    var closed = false;
    // A reply still queued when the app goes away fails on the socket's
    // done future, not at the add: that is an ordinary disconnect.
    unawaited(
      socket.done
          .then<void>((_) {}, onError: (Object _) {})
          .whenComplete(() => closed = true),
    );
    socket.listen(
      (bytes) {
        pending += String.fromCharCodes(bytes);
        while (true) {
          final end = pending.indexOf('\r');
          if (end < 0) break;
          final command = pending.substring(0, end).trim();
          pending = pending.substring(end + 1);
          if (command.isEmpty) continue;
          final key = ObdTrace.normalise(command);
          final options = replies[key];
          final n = sent[key] = (sent[key] ?? -1) + 1;
          final reply = options == null || options.isEmpty
              ? 'NO DATA\r\r>'
              : options[n % options.length];
          // A clone's round trip, roughly: the session paces itself on it.
          Timer(const Duration(milliseconds: 40), () {
            if (closed) return;
            try {
              socket.add(reply.codeUnits);
            } catch (_) {
              // The app went away mid-reply.
            }
          });
        }
      },
      onDone: () {
        closed = true;
        stdout.writeln('Disconnected: ${socket.remotePort}');
      },
      onError: (Object e) => stdout.writeln('Socket error: $e'),
      cancelOnError: true,
    );
  }
}
