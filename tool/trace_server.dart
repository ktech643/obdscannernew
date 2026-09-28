// Development only: a recorded car on a Wi-Fi ELM327's socket.
//
//     dart run tool/trace_server.dart [trace] [port] [--drive]
//     flutter run --dart-define=TORQUE_DEV_WIFI=127.0.0.1:35000
//
// Replays a `.obdtrace` (default: assets/traces/trip_drive_can.obdtrace)
// on 127.0.0.1, so the app on the iOS simulator can make a real connection
// — handshake, identity, gauges, a trip recorded to disk and resumed —
// with no car and no adapter. Demo Mode cannot stand in for this: it never
// records against the real garage.
//
// Parked (the default): every reading holds where the recording ends —
// here a car idling at 0 km/h — so the whole app can be used, editing
// included (§8.4 locks editing while the car moves).
//
// --drive: the recording's drive plays at its recorded pace, on a loop.
// Every reply is the one the car gave at that moment of the drive, so RPM,
// speed, load and fuel always belong together. An earlier version replayed
// each command's replies per request instead: readings from different
// moments mixed, and the gauges leapt about (RPM 760, 1717, 1545 within a
// second).
//
// Nothing here ships: the app offers this endpoint only in a debug build
// given the define.
import 'dart:async';
import 'dart:io';

import 'package:torque_obd2/transport/obd_trace.dart';

Future<void> main(List<String> args) async {
  final drive = args.contains('--drive');
  final positional = [
    for (final a in args)
      if (!a.startsWith('--')) a,
  ];
  final path = positional.isNotEmpty
      ? positional[0]
      : 'assets/traces/trip_drive_can.obdtrace';
  final port = positional.length > 1 ? int.parse(positional[1]) : 35000;
  final timeline = _timeline(ObdTrace.parse(File(path).readAsStringSync()));

  // The drive is the stretch in which Speed was asked for.
  final speed = timeline['010D'];
  final start = speed == null ? 0 : speed.first.at;
  final span = speed == null ? 1 : speed.last.at - start + 1;

  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln(
    'Replaying $path on 127.0.0.1:$port — '
    '${drive ? 'driving, ${(span / 1000).toStringAsFixed(0)} s on a loop' : 'parked'}',
  );

  await for (final socket in server) {
    stdout.writeln('Connected: ${socket.remotePort}');
    // Every connection starts the drive from the top, as a car would after
    // the key is turned.
    final clock = Stopwatch()..start();
    var pending = '';
    var closed = false;
    // A reply still queued when the app goes away fails on the socket's
    // done future, not at the add: that is an ordinary disconnect.
    unawaited(
      socket.done
          .then<void>((_) {}, onError: (Object _) {})
          .whenComplete(() => closed = true),
    );
    String replyTo(String command) {
      final said = timeline[ObdTrace.normalise(command)];
      if (said == null || said.isEmpty) return 'NO DATA\r\r>';
      if (said.length == 1) return said.single.reply;
      if (!drive) return said.last.reply;
      final at = start + clock.elapsedMilliseconds % span;
      var reply = said.first.reply;
      for (final r in said) {
        if (r.at > at) break;
        reply = r.reply;
      }
      return reply;
    }

    socket.listen(
      (bytes) {
        pending += String.fromCharCodes(bytes);
        while (true) {
          final end = pending.indexOf('\r');
          if (end < 0) break;
          final command = pending.substring(0, end).trim();
          pending = pending.substring(end + 1);
          if (command.isEmpty) continue;
          final reply = replyTo(command);
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

/// Every command's replies with the moment each was heard, in order.
Map<String, List<({int at, String reply})>> _timeline(ObdTrace trace) {
  final out = <String, List<({int at, String reply})>>{};
  final events = trace.events;
  for (var i = 0; i + 1 < events.length; i++) {
    final ask = events[i], answer = events[i + 1];
    if (!ask.isRequest || answer.isRequest) continue;
    out.putIfAbsent(ObdTrace.normalise(ask.payload), () => []).add((
      at: answer.offset.inMilliseconds,
      reply: answer.payload,
    ));
  }
  return out;
}
