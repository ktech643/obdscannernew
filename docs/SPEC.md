# TORQUE OBD2 PRO — FLUTTER HYBRID BUILD SPECIFICATION

**Reference target:** `Torque OBD2 Pro - Car Check Tool` — App Store ID `6753583019` (v1.0.2)
**Build approach:** Flutter 3.29+ / Dart 3.7+, single codebase, iOS + Android, with native platform-channel modules where Flutter can't reach
**Prepared for:** K Tech Clans (Muzaffar Ali)
**Supersedes:** the native-Swift parity spec.

---

# PART 0 — WHAT CHANGES WHEN YOU GO FLUTTER

## 0.1 The one thing that makes Flutter the right call

**Android supports Bluetooth Classic SPP. iOS does not.**

On iOS, the cheap $8 ELM327 adapters everyone already owns are **permanently unusable** — Apple exposes no SPP API outside MFi. That single fact generates the majority of 1★ reviews across the iOS OBD2 category. On Android those same adapters work over RFCOMM. For Pakistan, India and the Gulf the SPP clone is the dominant adapter by an enormous margin, and Play is the dominant channel. **Android is the bigger commercial opportunity, and Flutter is how you get there without a second team.**

| Transport | iOS | Android | Notes |
|---|---|---|---|
| Bluetooth LE | ✅ `flutter_reactive_ble` | ✅ `flutter_reactive_ble` | Shared Dart |
| Bluetooth Classic (SPP) | ❌ impossible | ✅ **custom Kotlin channel** | The Android unlock |
| Wi-Fi (TCP) | ✅ `dart:io Socket` | ✅ `dart:io Socket` | Fully shared |
| USB OTG | ❌ | ✅ optional phase 3 | `usb_serial`, niche |
| MFi | ⚠️ Swift channel, phase 3 | n/a | Only if you join MFi |

## 0.2 What you give up

| Cost | Detail | Mitigation |
|---|---|---|
| Bundle size parity is dead | Target is 5.8 MB. Flutter floor ~16–18 MB iOS, ~9–13 MB Android per-device. | Accept it. Apply every lever in §1.5. |
| BLE timing control is coarser | Every notification crosses a platform channel. | §1.4 keeps it under control. 8–10 Hz measured on good adapters. |
| Two stores, two reviews | Play Data Safety, Android 14 FGS types, DSA trader verification. | §8, §11. |
| Plugin risk | The BLE plugin is one maintainer away from a problem — and this happened: `flutter_blue_plus` went commercial mid-build. | Wrapped behind `ObdTransport` (§3.1). The swap cost one file. |
| 60 fps at 10 Hz | Naïve `setState` at grid level janks on mid-range Android. | Leaf-level rebuilds only. §1.4, §B.5. Non-negotiable. |

## 0.3 Parity constraints carried over

| Attribute | Target | This build |
|---|---|---|
| Min OS | iOS 16.1 | iOS 13.0; gate Live Activity features to 16.1 |
| — | n/a | **Android 8.0 / API 26** min, target API 35 |
| Category | Productivity | iOS Productivity; **Play: Auto & Vehicles** (§11.4) |
| Languages | English only | EN at v1, `intl` + ARB from day one. Urdu/Arabic RTL phase 2. |
| Privacy | "Data Not Collected" | Achievable with discipline — §8.3 |
| IAP | Weekly $4.99 / Monthly $9.99 / Lifetime $49.99 | RevenueCat both stores — §7 |
| Feature surface | BT connect · read codes · live data · maintenance log | Unchanged. Four pillars. |

---

# PART 1 — STACK & ARCHITECTURE

## 1.1 Dependencies

```yaml
environment:
  sdk: ">=3.7.0 <4.0.0"
  flutter: ">=3.29.0"

dependencies:
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1
  go_router: ^14.6.0
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0
  flutter_reactive_ble: ^5.5.0      # BLE both platforms — see note below
  drift: ^2.23.0
  sqlite3_flutter_libs: ^0.5.26
  path_provider: ^2.1.5
  permission_handler: ^11.3.1
  device_info_plus: ^11.2.0
  package_info_plus: ^8.1.2
  connectivity_plus: ^6.1.0
  flutter_foreground_task: ^8.17.0
  purchases_flutter: ^8.4.0         # RevenueCat
  fl_chart: ^0.69.2                 # NOT Syncfusion
  flutter_svg: ^2.0.16
  flutter_local_notifications: ^18.0.1
  timezone: ^0.10.0
  share_plus: ^10.1.3
  pdf: ^3.11.1
  printing: ^5.13.4
  csv: ^6.0.0
  image_picker: ^1.1.2
  intl: ^0.19.0

dev_dependencies:
  build_runner, freezed, json_serializable, riverpod_generator,
  drift_dev, custom_lint, riverpod_lint, flutter_lints, mocktail
```

**Explicitly rejected:** `flutter_bluetooth_serial` (abandoned, broken on Android 12+ permissions), Syncfusion charts (bundle size), Firebase anything (breaks the privacy label), `isar` (maintenance uncertain), `get`.

> **`flutter_blue_plus` — rejected during Phase 2 (Sep 2026).** From 2.1.0 it requires a paid commercial license for for-profit use, and from 2.3.5 it makes a network call at build time reporting the package name. Both conflict with this product: it is commercial, and AC-14 forbids outbound traffic. `flutter_reactive_ble` (BSD-3, Philips Hue) was swapped in behind the `ObdTransport` abstraction — one file, as §0.2 predicted.

## 1.2 Project structure

```
lib/
├── main.dart · app.dart
├── core/            di · router · theme · i18n · platform · util
├── transport/       obd_transport · ble · spp · wifi · mock · registry
├── protocol/        ★ PURE DART, zero Flutter imports
│                    elm_session · protocol_negotiator · response_parser
│                    pid_registry · pid_scheduler · dtc_decoder
│                    isotp_reassembler · readiness_decoder · vin_reader
├── data/            db (Drift) · repo · assets loaders
├── domain/          freezed models · health score
├── features/        onboarding connect dashboard diagnostics
│                    garage reports paywall settings demo
└── design_system/
android/app/src/main/kotlin/…  SppPlugin.kt · ObdForegroundService.kt
ios/Runner/                     MfiPlugin.swift (phase 3)
assets/  db/dtc.sqlite.gz · data/pids.json · data/adapters.json
         data/wmi.json · traces/*.obdtrace · fonts/Barlow*
```

**Rule: `lib/protocol/` must import nothing from `package:flutter`.** Pure Dart, unit-testable on the VM in milliseconds, zero device dependency. This is what lets you build and test the hardest 70% of the app before touching a car.

## 1.3 Hybrid boundary — what stays native

| Module | Platform | Why | Size |
|---|---|---|---|
| `SppPlugin.kt` | Android | No maintained SPP package. `BluetoothSocket` over RFCOMM, read loop on a dedicated thread, `EventChannel` to Dart. | ~220 lines |
| `ObdForegroundService.kt` | Android | Android 14 requires a typed FGS (`connectedDevice`). | ~90 lines |
| `MfiPlugin.swift` | iOS, phase 3 | `ExternalAccessory` has no Flutter binding. | ~150 lines |
| OEM battery-optimisation intents | Android | Vendor autostart screens. | ~60 lines |

## 1.4 ★ Concurrency & rendering model

```
UI isolate
  GaugeGrid (const, never rebuilds)
    └─ GaugeTile × 6  ← RepaintBoundary each
         └─ ValueListenableBuilder<PidSample?>
              └─ Text  ← ONLY this rebuilds, at 10 Hz
PidBus — Map<String, ValueNotifier<PidSample?>>
ElmSession — serial queue, ONE outstanding command, framed on '>' (0x3E)
Transport — flutter_reactive_ble / SPP channel / Socket

Separate isolates: trip CSV flush (5 s) · chart downsampling (>2,000 pts) · PDF
```

**Three hard rendering rules:**
1. **Never put live PID data in a Riverpod `StateNotifier` that widgets `watch`.** 10 Hz × 6 tiles = 60 tree rebuilds/sec and dropped frames on mid-range Android.
2. **`RepaintBoundary` around every gauge tile.**
3. **`const` everything above the value.** Only the numeral and the bar marker are dynamic.

Riverpod owns everything that isn't a live sample: connection state, vehicle selection, DTC lists, entitlement, settings.

### The command queue

```dart
Future<ElmResponse> send(String cmd, {Duration? timeout}) { … }
void _pump() {
  if (_active != null || _queue.isEmpty) return;   // ★ strict serialisation
  _active = _queue.removeFirst();
  _transport.write(utf8.encode('${_active!.cmd}\r'));
  _timeoutTimer = Timer(_active!.timeout, _onTimeout);
}
void _onBytes(List<int> chunk) {
  _rx.write(...);
  if (chunk.contains(0x3E)) _complete();           // ★ frame on '>', never '\r'
}
```

There is no pipelining in ELM327. Every clone disaster traces back to violating this.

## 1.5 Bundle size discipline

```bash
flutter build appbundle --release --obfuscate \
  --split-debug-info=build/symbols --tree-shake-icons
flutter build ipa --release --obfuscate \
  --split-debug-info=build/symbols --tree-shake-icons
```

| Lever | Saving |
|---|---|
| App Bundle, ABI + density splits | ~35% Android delivery |
| `--tree-shake-icons` | 1–2 MB |
| Barlow + Barlow Semi Condensed only, 2 weights, Latin subset | ~600 KB vs full family |
| `dtc.sqlite` gzipped, inflated on first run | ~1.1 MB |
| No Syncfusion / Firebase / Lottie | ~15 MB avoided |

**Realistic outcome:** iOS ~17 MB, Android ~11 MB delivered.

---

# PART 2 — INFORMATION ARCHITECTURE

```
Launch → Splash (≤900 ms, no network)
  ├─ [first run] Onboarding (5) → Compatibility Gate → Shell
  └─ [returning] Shell + background auto-reconnect

Shell: CONNECT · DASHBOARD · DIAGNOSTICS · GARAGE · SETTINGS
  ᴬ = Android only   ᴾ = Pro only
  Connect:     Scan · Paired · Wi-Fi · SPPᴬ · Info · Demo · Troubleshooter
  Dashboard:   Gauge grid (editable) · Layouts · Trip meter · Record · Full graph
  Diagnostics: Scan · DTC detail · Clear (guarded) · Freeze · Readiness ·
               Mode 06ᴾ · Health Score
  Garage:      Vehicles · Service log · Reminders · Fuel log · Notes · Docs · Reports
  Settings:    Units · Adapter · Polling · Backgroundᴬ · Data & privacy ·
               Export · Diagnostics log · Restore · Legal
```

**Deep links** (`go_router`): `/connect`, `/connect/troubleshoot`, `/dashboard`, `/dashboard/graph/:pid`, `/diagnostics`, `/diagnostics/dtc/:code` (shareable), `/garage/vehicle/:id`, `/garage/service/new`, `/paywall?trigger=:t`, `/demo`. Scheme `torqueobd://` + App/Universal Links on `torque.ktechclans.com`.

## 2.1 Connection banner — global, every tab

| State | Message | Semantic |
|---|---|---|
| `disconnected` | "Not connected — tap to connect" | neutral |
| `scanning` | "Searching for adapters…" | info |
| `connecting` | "Connecting to {name}…" | info |
| `handshaking` | "Setting up — step {n} of 7" | info |
| `connected` | hidden (hairline + protocol on Connect only) | pass |
| `degraded` | "Weak link — some data may be missing" | caution |
| `ignitionOff` | "Turn the ignition to ON" | caution |
| `lost` | "Connection lost — reconnecting ({n})" | fault |
| `unsupported` | "This adapter isn't supported on {platform}" | fault |
| `bgLimited` ᴬ | "Background updates are restricted on this phone" | caution |

The banner **pushes** content, never overlays it.

---

# PART 3 — TRANSPORT LAYER

## 3.1 The abstraction

```dart
abstract interface class ObdTransport {
  TransportKind get kind;
  String get id;                              // stable fingerprint
  String get displayName;
  Stream<TransportState> get state;
  Stream<List<int>> get inbound;
  Future<void> connect({Duration timeout});
  Future<void> write(List<int> bytes);        // must chunk internally
  Future<void> disconnect();
  int get maxWriteLength;
  TransportCapabilities get capabilities;
}
enum TransportKind { ble, spp, wifi, mfi, mock }
```

Everything above this line is platform-agnostic Dart. Everything below is swappable.

## 3.2 BLE (`flutter_reactive_ble`) — GATT profile matrix, probe in order, first match wins

| Profile | Service | Write char | Notify char | Adapters |
|---|---|---|---|---|
| A | `FFF0` | `FFF2` (WWR) | `FFF1` | Most generics, Vgate |
| B | `FFE0` | `FFE1` | `FFE1` | HM-10 clones, same char both ways |
| C | `18F0` | `2AF1` | `2AF0` | Vgate iCar Pro, LELink |
| D | `6E400001-B5A3-F393-E0A9-E50E24DCCA9E` | `…0002` | `…0003` | Nordic UART |
| E | `E7810A71-73AE-499D-8C15-FAA9AEF0C3F2` | `BEF8D6C9-…` | same | OBDLink CX |

**Generic fallback:** enumerate all services; pick any pair where one char has `notify` and one has `write`/`writeWithoutResponse`; probe `ATI`. If the reply contains `ELM` or `OBD`, accept and cache the fingerprint.

### Platform differences

```dart
if (Platform.isAndroid) {
  await device.requestMtu(247);              // → 244-byte payloads
  await Future.delayed(const Duration(milliseconds: 200));
}
final mtu = device.mtuNow - 3;
```

| Concern | iOS | Android |
|---|---|---|
| MTU | Auto up to 185. `requestMtu` throws. | Must call `requestMtu(247)`. Default 20 until you do. |
| Scan filtering | Service-UUID filter drops adapters | **Scan with no filter on both**, filter by name in Dart |
| Background scan | Not permitted; connection can be held | Permitted, low-power scanMode |
| Write type | `writeWithoutResponse` fire-and-forget | GATT allows one outstanding op — `await` every write |
| Reconnect | `autoConnect` unsupported | `autoConnect: true` works, battery-cheap |
| Device identity | Opaque per-app UUID | MAC address |

**Scan name filter (both platforms):** `OBD, OBDII, ELM, ELM327, VLINK, V-LINK, VGATE, ICAR, VEEPEAK, KONNWEI, OBDLINK, LELINK, CARISTA, ANCEL, VIECAR, IOS-VLINK, SCAN, AUTOPHIX, THINKDIAG, NEXAS`. Always render an unfiltered "Other devices" section, collapsed.

## 3.3 Wi-Fi

Default `192.168.0.10:35000`; probe `192.168.4.1:35000`, `192.168.0.10:23`, `192.168.1.5:35000`. 5 s hard timeout, `tcpNoDelay`.

- **iOS:** the AP kills internet; iOS may auto-switch back. Warn: "Turn off Auto-Join for your home network while you use the adapter." `NSLocalNetworkUsageDescription` required.
- **Android:** may route data over cellular while Wi-Fi carries the adapter. On API 29+ may need `bindProcessToNetwork`.

## 3.4 ★ Android Bluetooth Classic SPP

```kotlin
// MethodChannel "ktc.torque/spp": listPaired, connect(address), write, disconnect, isSupported
// EventChannel  "ktc.torque/spp_stream": ByteArray chunks + {"event":"disconnected"}
private val SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
```

1. `cancelDiscovery()` before **every** connect. Skipping this is the #1 cause of `IOException: read failed`.
2. Try `createRfcommSocketToServiceRecord(SPP_UUID)`; on `IOException` retry once with the reflection socket on channel 1.
3. Read loop on a **dedicated Thread**, not a coroutine.
4. Emit raw `ByteArray` only — zero parsing in Kotlin.
5. Handle `ACTION_ACL_DISCONNECTED` — the read loop won't always throw.

**Discovery:** SPP adapters must be paired in Android Settings first. Do not attempt in-app pairing. Show paired devices + "Pair a new adapter" → `ACTION_BLUETOOTH_SETTINGS` with a 3-step card ("The PIN is usually 1234 or 0000").

### 3.4.1 As built (Phase 3, 2026-09-05) — decisions that are not obvious from the rules

Files: `android/app/src/main/kotlin/com/torque/torque_obd2/SppPlugin.kt`, `lib/transport/spp_transport.dart`, `test/transport/spp_transport_test.dart` (26 tests against a scripted native side). Two adversarial review rounds (5 lenses × 3 refuters) drove the design below.

- **Error codes** (native → `SppFailure`): `unsupported`, `off`, `permission`, `unpaired` → `notPaired`, `argument` → `badAddress`, `io`, `state`. `listPaired` returns `off` when Bluetooth is disabled — `bondedDevices` is empty whenever the adapter isn't `STATE_ON`, so without this "off" looks like "nothing paired". `connect` refuses a device whose `bondState != BOND_BONDED` with `unpaired`, because a secure RFCOMM connect to an unbonded device makes the OS pop its pairing dialog — the in-app pairing this spec forbids.
- **Rule 5 needs `RECEIVER_EXPORTED` on API 33+.** `ACTION_ACL_DISCONNECTED` is sent by the Bluetooth stack process (uid 1002), not `system_server`; a `RECEIVER_NOT_EXPORTED` receiver only accepts root/system senders and the broadcast is dropped with an "Exported Denial". The action is a `<protected-broadcast>`, so exporting adds no spoofing surface. Filtered to the connected address.
- **One `Link` per connection** (socket, streams, own `alive` flag, receiver). A stale read thread can only close its own link; nothing ever `join`s a thread. Disconnect is synchronous on the platform thread: closing the socket is what unblocks a parked `connect()`/`read()`.
- **Generation + `pending` socket.** Every connect *and* disconnect bumps a generation on the platform thread, in call order. The socket a connect is blocked on is parked in `pending`; `abort()` closes it, and a newer connect closes the one it supersedes rather than queueing 12–30 s behind it. A connect that finds the generation moved throws its socket away. The link is published and its ACL receiver registered in one critical section so an abort can't leave a receiver registered forever.
- **Dart holds exactly one `EventChannel` subscription, shared across instances.** Flutter keeps one message handler per channel name; cancelling a second overlapping `receiveBroadcastStream()` subscription silently removes the first's handler. Native has one link anyway, so the subscription is static, routed to the current *owner* instance; connecting a second `SppTransport` evicts the first (it sees `disconnected`, and its own `disconnect()` touches nothing native).
- **Dart timeout tells native to stop** (only if still the current attempt), or a late native success would leave an open socket nobody listens to. Addresses are upper-cased on both sides — `getRemoteDevice` rejects lower-case hex.
- **Build:** `flutter_reactive_ble` 5.x pins `compileSdk 33` while its androidx dependencies require 34+; `android/build.gradle.kts` lifts every library plugin to 36. Behavioural APIs (`minSdk`/`targetSdk`) are untouched.
- **Deferred to Phase 7:** `SppPlugin` is Activity-scoped (created/disposed with the engine). The foreground service will need the link to be Application-scoped.

## 3.5 `MockTransport` and the trace format

```
# torque.obdtrace v1
# vehicle: 2014 Honda Civic 1.8 petrol
# adapter: Vgate iCar Pro BLE 4.0
# protocol: 6 (ISO 15765-4 CAN 11/500)
T+0000  > ATZ
T+0983  < ELM327 v1.5\r\r>
T+1031  > 0100
T+1210  < SEARCHING...\r41 00 BE 3F A8 13\r\r>
```

Replays with original inter-message timing (×N for CI). Gives: the whole protocol layer unit-tested with no device and no car · deterministic CI · a support workflow (user emails a trace, you replay it) · Demo Mode driven by the same code path.

**Ship ≥20 traces:** clean CAN · slow ISO 9141-2 · KWP 5-baud · clone echoing after `ATE0` · `BUFFER FULL` under load · 12-DTC multi-frame · pending + permanent · diesel readiness · EV with 4 PIDs · `LV RESET` mid-session · two-ECU interleaved · adapter rejecting `ATH1`.

---

# PART 4 — PROTOCOL ENGINE (pure Dart)

## 4.1 Handshake — 7 steps, shown as progress

| # | Command | Expected | On failure |
|---|---|---|---|
| 1 | `ATZ` | `ELM327 v?.?` within 3 s | Escalating pre-write delay 250/500/1000 ms, then `ATWS`, then `adapterUnresponsive` |
| 2 | `ATE0` | `OK` | Tolerate; set `echoActive`, strip echoed command in parser |
| 3 | `ATL0` | `OK` | Ignore; normalise line endings |
| 4 | `ATS0` | `OK` | Ignore; strip all whitespace |
| 5 | `ATH1` | `OK` | If `?`, `headersUnavailable = true`, disable multi-ECU, continue |
| 6 | `ATSP0` | `OK` | Fall to the explicit ladder |
| 7 | `0100` | `41 00 xx xx xx xx` | The real connectivity test — see §4.4 |

Then non-blocking: `ATRV` (voltage), `ATDPN` (protocol number, cache), `ATI`/`AT@1` (fingerprint), `ATAT1` (adaptive timing, skip on rejection).

**Framing:** send `"$cmd\r"`, read until `0x3E`. Never split on `\r`. Timeouts: 5 s for `ATZ`/`0100`, 1.2 s steady-state, 15 s on a K-line ladder entry.

## 4.2 Protocol ladder

```
ATSP6  ISO 15765-4 CAN 11-bit 500k   ← 99% of 2008+
ATSP7  CAN 29-bit 500k
ATSP8  CAN 11-bit 250k
ATSP9  CAN 29-bit 250k
ATSP5  ISO 14230-4 KWP fast init
ATSP4  ISO 14230-4 KWP 5-baud        (allow 10 s)
ATSP3  ISO 9141-2                    (allow 10 s)
ATSP1  SAE J1850 PWM (Ford)
ATSP2  SAE J1850 VPW (GM)
```

Probe `0100` after each. **Cache the winner keyed on `vin ?? vehicleId`** — cuts reconnect from ~20 s to ~3 s, the single biggest perceived-speed win.

## 4.3 PID registry — formula, unit, hard physical bounds

| PID | Name | Formula | Unit | Bounds | Priority |
|---|---|---|---|---|---|
| `0104` | Engine load | `A*100/255` | % | 0–100 | high |
| `0105` | Coolant temp | `A-40` | °C | −40–215 | high |
| `0106/07` | STFT/LTFT bank 1 | `(A-128)*100/128` | % | −100–99.2 | med |
| `0108/09` | STFT/LTFT bank 2 | same | % | −100–99.2 | low |
| `010B` | Intake manifold pressure | `A` | kPa | 0–255 | med |
| `010C` | **Engine RPM** | `((A*256)+B)/4` | rpm | 0–16383 | **critical** |
| `010D` | **Vehicle speed** | `A` | km/h | 0–255 | **critical** |
| `010E` | Timing advance | `(A/2)-64` | ° | −64–63.5 | low |
| `010F` | Intake air temp | `A-40` | °C | −40–215 | med |
| `0110` | MAF rate | `((A*256)+B)/100` | g/s | 0–655.35 | high |
| `0111` | Throttle position | `A*100/255` | % | 0–100 | high |
| `011F` | Run time since start | `(A*256)+B` | s | 0–65535 | low |
| `0121` | Distance with MIL on | `(A*256)+B` | km | 0–65535 | med |
| `012F` | Fuel level | `A*100/255` | % | 0–100 | med |
| `0130` | Warm-ups since clear | `A` | count | 0–255 | low |
| `0131` | Distance since clear | `(A*256)+B` | km | 0–65535 | med |
| `0133` | Barometric pressure | `A` | kPa | 0–255 | low |
| `013C` | Catalyst temp B1S1 | `((A*256)+B)/10-40` | °C | −40–6513.5 | low |
| `0142` | **Module voltage** | `((A*256)+B)/1000` | V | 0–65.535 | **high** |
| `0143` | Absolute load | `((A*256)+B)*100/255` | % | 0–25700 | low |
| `0144` | Lambda | `((A*256)+B)/32768` | λ | 0–2 | med |
| `0146` | Ambient air temp | `A-40` | °C | −40–215 | low |
| `014D` | Time with MIL on | `(A*256)+B` | min | 0–65535 | med |
| `014E` | Time since clear | `(A*256)+B` | min | 0–65535 | med |
| `0151` | Fuel type | enum | — | — | once |
| `015C` | Engine oil temp | `A-40` | °C | −40–210 | med |
| `015E` | Fuel rate | `((A*256)+B)/20` | L/h | 0–3212.75 | med |
| `0161-63` | Torque demand/actual/reference | `A-125` / `((A*256)+B)` | % / N·m | — | low |

**Supported-PID discovery is mandatory.** Query `0100`, `0120`, `0140`, `0160`, unpack the 32-bit bitmasks, never poll outside the discovered set.

### Derived metrics — always labelled "Estimated"

| Metric | Source | Caveat |
|---|---|---|
| Instant economy | `015E`, else `(MAF×3600)/(14.7×820×speed)×100` | MAF path assumes stoichiometric petrol |
| Trip fuel used | ∫ fuel rate dt | |
| 0–100 km/h | `010D` at max rate | ±0.4 s; "for fun, not benchmarking" |
| Boost | `010B − 0133` | Forced induction only |
| Power | `(torque × rpm)/9549` from `0162`+`0163` | **Only if both PIDs supported.** Never show MAF-derived horsepower. |

## 4.4 Response failure taxonomy

| Raw response | Code | User-facing | Recovery |
|---|---|---|---|
| `NO DATA` | `noData` | silent for one PID | Drop the PID after 3 consecutive |
| `?` | `badCommand` | silent | Skip; flag limited command set |
| `SEARCHING...` | `searching` | "Finding your car's protocol…" | Extend timeout to 10 s, **do not retry** |
| `UNABLE TO CONNECT` | `noEcu` | "Can't reach your car's computer" | → troubleshooter |
| `BUS INIT: ERROR` | `busInit` | "Couldn't start a session with your car" | Retry once, then step the ladder |
| `CAN ERROR` | `canError` | "Communication error" | `ATWS`, re-negotiate |
| `BUS BUSY` | `busBusy` | silent | Back off 500 ms, retry ×2 |
| `BUFFER FULL` | `bufferFull` | silent | **Halve the poll rate**, `ATWS`, ramp +10% every 30 s |
| `STOPPED` | `stopped` | silent | Retry once |
| `LV RESET` | `lowVoltage` | "Adapter lost power — check it's seated firmly" | Full re-handshake |
| `ERR{xx}` | `internalError` | "Adapter error" | `ATZ`, full re-handshake |
| timeout / empty | `timeout` | reconnect ladder | |
| garbled hex, odd length | `malformed` | silent | Discard. >20% in 10 s → `degraded` |

**Clone quirks:** echo persists after `ATE0` (strip a leading token equal to the sent command) · `SEARCHING...` prepended to the first real response (strip it) · spaces despite `ATS0` (remove all whitespace) · multiple ECUs concatenated without headers (if `headersUnavailable`, accept the first well-formed frame only) · fake "v2.1" chips reject `ATCRA`/`ATFCSH`/`ATCAF0`/Mode 06 (feature-probe, cache per fingerprint) · some need 300–1000 ms of silence after `ATZ`.

## 4.5 Adaptive scheduler

```
Tiers:  critical (RPM, speed)                  every cycle
        high (load, coolant, throttle, MAF, voltage)  every 2nd
        medium                                 every 5th
        low                                    every 20th
        once-per-session (VIN, fuel type, supported PIDs)

Budget: rolling p95 RTT over 20 samples; target cycle 100 ms (10 Hz)
        maxPidsPerCycle = floor(budget / p95Rtt)
        p95 > 250 ms → 5 Hz + "Slow adapter detected"
        p95 > 600 ms → 2 Hz + degraded banner
        BUFFER FULL  → halve immediately

Only poll PIDs whose tile is currently visible.
App backgrounded with no active recording → stop polling entirely.
```

**Multi-PID batching:** probe `010C0D11` once on CAN. Parses cleanly → enable for the session (~3× throughput). `NO DATA`/malformed → disable permanently for that vehicle.

## 4.6 DTC decoding

Mode `03` (stored), `07` (pending), `0A` (permanent). Two bytes per code:

```
byte1 bits 7-6 → letter  00=P 01=C 10=B 11=U
byte1 bits 5-4 → first digit (0-3)
byte1 bits 3-0 → second digit (hex)
byte2 bits 7-4 → third digit
byte2 bits 3-0 → fourth digit
0x0000 → padding, skip
```

**ISO-TP multi-frame reassembly is mandatory.** >3 DTCs arrive as `10 LL …` (first frame) then `21`, `22`, … Most cheap apps skip this and show only the first three.

**Dictionary:** `dtc.sqlite` FTS5 — `code`, `title`, `description`, `severity`, `system`, `common_causes`, `is_manufacturer_specific`. P1xxx/P3xxx render as *"Manufacturer-specific code — meaning varies by make."* **Never fabricate a definition.**

## 4.7 Readiness, VIN

**Mode 01 PID 01:** byte A bit 7 = MIL, bits 6-0 = DTC count. Byte B bit 3 selects spark (0) vs compression (1). Three states: Complete / Not complete / Not supported. Emissions verdict carries a "rules vary by state and country" caveat.

**Mode 09 PID 02 (VIN):** multi-frame ISO-TP, 17 ASCII. Validate the ISO 3779 check digit (position 9). Reject any VIN containing I, O or Q — the standard forbids them, so their presence means a corrupt read. Decode WMI locally. **Never call a cloud VIN API.**

---

# PART 5 — SCREENS

## 5.1 Onboarding — 5 screens

| # | Screen | Content |
|---|---|---|
| 1 | What this does | Phone → adapter → car. |
| 2 | **You need an adapter** ★ | **Platform-branched.** iOS: "must be Bluetooth LE or Wi-Fi — the cheap Bluetooth ones sold for Android won't work on iPhone." Android: "Almost any ELM327 works — Bluetooth, BLE, or Wi-Fi." |
| 3 | Add your car | Nickname, make/model/year, odometer. All skippable. |
| 4 | Permissions primer | Platform-branched soft-ask. Android: explain why API ≤30 demands Location. No system dialog here. |
| 5 | Safety | Non-skippable acknowledgement. |

No paywall in onboarding.

## 5.2 Connect

Current connection card · Nearby BLE (RSSI-sorted, "Known good" badges) · **Paired Bluetooth** ᴬ · Wi-Fi (host/port, Test) · Other devices (collapsed) · "Can't find your adapter?" · **"Try it without an adapter"** → Demo Mode.

**Compatibility gate** after a 15 s scan with zero results — platform-branched. iOS names the Classic-BT impossibility. Android points at Settings pairing with the PIN hint.

## 5.3 Dashboard — hero

2×3 editable gauge grid + trip strip. Tile types: numeric, arc, sparkline, bar. Long-press → edit: drag reorder, tap to change PID, swipe to remove. Layouts save per vehicle. Free 6 tiles/1 layout; Pro unlimited + named layouts.

- **Staleness:** >2× expected interval → 40% + clock glyph; >5 s → `—`.
- **Bounds rejection** at the parser, never in the widget tree.
- **`null` vs `0`:** zero is a value. `double?` throughout, no sentinels.
- **Keep awake** while foreground **and** connected.
- **Recording:** trip CSV flushed every 5 s from a background isolate. Free 2 min / last 3 trips.
- **Backgrounding:** iOS `bluetooth-central` at 0.5 Hz for active recordings only. Android `connectedDevice` FGS.

## 5.4 Diagnostics

Scan runs Mode 03 → 07 → 0A → 01/PID01 → 02, with a real per-step label.

| MIL | Codes | Header |
|---|---|---|
| off | 0 | "No problems found" (pass) |
| off | pending only | "1 pending code — being monitored" (caution) |
| on | ≥1 | "Check Engine light is on — 2 codes" (fault) |

Every DTC detail ends with: *"A code points to a symptom, not always the cause. A mechanic's diagnosis may differ."*

**Clear codes — two-step guarded.** The sheet states, uncollapsed: turns off the light · erases freeze-frame data · **resets readiness monitors, car will likely fail an emissions test until driven 50–100 miles** · does not fix the fault. Write a `DtcSnapshot` **before** Mode 04 and say so. **Always re-read Mode 03 after** and report the truth. Hard-gate on speed = 0.

**Health Score** 0–100, **always with its full breakdown**: −25 per confirmed DTC (severity-weighted), −20 permanent, −15 MIL on, −10 pending, −10 low battery, −8 coolant out of band, −8 fuel trims beyond ±10%, −5 per overdue reminder, −3 per incomplete monitor.

## 5.5 Garage

Vehicles · Maintenance log · Reminders (local notifications only) · Fuel log (economy **between full fill-ups only**) · Reports (PDF/CSV, local isolate, `share_plus`).

**Service intervals:** oil 10,000 km/6 mo · tyre rotation 10,000 · air filter 20,000 · cabin filter 15,000 · brake pads 40,000 · brake fluid 24 mo · coolant 60,000 · transmission 60,000 · plugs 40,000/100,000 · battery 48 mo · timing belt 100,000 (critical) · inspection 12 mo · repair · custom.

**Every default interval displays "Check your owner's manual — intervals vary by vehicle."**

## 5.6 Settings

Units (independent toggles) · Polling rate · Keep screen on · Haptics · Adapter prefs · **Background & battery** ᴬ · Notifications · Data & privacy · Export JSON · Delete all data · Diagnostics log · Restore · Manage subscription · Support · Legal.

---

# PART 6 — DATA MODEL (Drift)

`Vehicles` (id, nickname, vin, make, model, year, fuelType, odometerKm, odometerUpdatedAt, plate, photoPath, cachedProtocol, supportedPidsJson, supportsBatching, isPrimary, createdAt) · `ServiceRecords` (+ vehicleId FK cascade, type, title ≤200, date, odometerKm, cost, currencyCode, vendor, notes ≤5000, attachmentPathsJson, linkedDtcsJson) · `Reminders` · `FuelEntries` · `DtcSnapshots` · `TripSessions` (samplesFilePath — CSV on disk, never in the DB).

**Storage:** attachments and trip CSVs in `getApplicationDocumentsDirectory()`, never blobs. Trip logs capped 30 days / 200 MB, LRU. Migrations with a schema-version test per step.

**Sync:** no cloud sync at v1. Full JSON export/import instead — preserves the zero-server posture.

### 6.1 As built (Phase 4, 2026-09-05) — decisions that are not obvious from the table list

Files: `lib/data/db/{tables,app_database,open}.dart`, `lib/data/repositories/{vehicle,service,dtc,trip}_repository.dart`, `lib/data/backup/backup_codec.dart`, `lib/data/{clock,ids}.dart`; 59 tests in `test/data/`. Drift 2.34 with `drift_flutter`; generated code and `drift_schemas/` are committed. Two adversarial review rounds (16 + 11 confirmed findings) drove the design below.

- **Ids are random 128-bit strings, never autoincrement**, so rows keep their identity across export/import. Enums are stored by **name** (append, never reorder). Dates are ISO-8601 **UTC** text (`build.yaml` + `clock.dart`): text `ORDER BY` is only chronological when every row uses the same offset, and §9.7 says store UTC. Repositories normalise every DateTime they write; readers get UTC instants back. *Dart's `DateTime ==` also compares the UTC flag — compare instants with `isAtSameMomentAs`.*
- **Length limits are real SQL `CHECK`s** (`title` 1–200, `notes` ≤5000, `currencyCode` = 3). Drift's `withLength` alone is Dart-side validation only; raw SQL would bypass it.
- **`PRAGMA foreign_keys = ON` in `beforeOpen`** — SQLite defaults it off, and every cascade depends on it. The test asserts the pragma, not just "something threw".
- **Duplicate VINs are allowed** (§9.8), so `byVin` returns a list, primary first; `primary()` never throws; `reconcilePrimary()` restores the one-primary invariant after deletes and imports (a merge keeps the device's own primary even if the backup unflags it). `setPrimary` with a stale id rolls back rather than leave zero primaries. Whole-row `update()`/`updateRecord()` normalise dates to UTC like every other write — the date-picker edit path is the one that would otherwise store a local offset.
- **DTC clear (§9.5):** `beginClear()` writes the `beforeClear` snapshot with `clearOutcome = pending` and must be awaited before Mode 04; `completeClear()` writes the `afterClear` re-read, links both ways, and settles `cleared` / `codesReturned`; `failClear()` for `refused`/`unknown`. `unreconciledClears()` on every launch finds a clear the app died in the middle of — tested across a real close-and-reopen.
- **Trip files:** the only path ever resolved is exactly `trips/<32-hex>.csv`; anything else (the database file, an attachment, `..`) is refused, and an imported trip row is accepted only with the path the app produces for its own id — a backup is someone else's data. The row is inserted before the file is created. `reconcileFiles()` at launch deletes orphan CSVs and zeroes `fileBytes` on rows whose file is gone; `deleteAllFiles()` is the file half of "Delete all data" (`wipe()` is only the row half). Retention: 30 days by `startedAt`, then 200 MB by `lastOpenedAt` (LRU); a recording trip is never touched; one failed delete doesn't stop the pass.
- **Backup (`BackupCodec`):** one JSON document, all tables, files by path only. Import runs in one transaction; a row that doesn't parse or fails a CHECK is skipped and counted, never fatal — including the case where Drift's Dart-side length check (UTF-16 units) passes but SQLite's `LENGTH()` (code points) refuses; a merge overwrites a known id in full, nulls included; `replace: true` refuses a document without a vehicle list before wiping, and rolls the wipe back if none of its vehicles could be read. Every timestamp encoding (ISO string or epoch integer) is read back as a UTC instant.
- **Fuel economy** is computed between full fills only, partials folded in, walked in odometer order (date-picker entries share a midnight timestamp). A km-recurring reminder completed without a reading rolls from the vehicle's odometer, else its own target, else is simply completed — never a silent no-op.
- **Schema test:** v1 opens a *fresh* database so `onCreate` runs and is diffed against the dump; starting at v1 and validating at v1 only compares the dump with itself. Each future version adds a step. `tool/schema.sh` re-dumps and regenerates the verifier.
- **Free-tier caps (§7.2)** are answerable from `count()`/`recordCount()`/`recent(limit:)` but enforced by the entitlement layer (Phase 8), not here.
- **Not built here:** attachment/photo path handling (Phase 6 UI), the bundled DTC-definition database (`assets/db/dtc.sqlite.gz` needs a licensed, verified source — never fabricate definitions), and wiring the existing Provider UI to these repositories (Phase 6).

---

# PART 7 — MONETISATION

| Entitlement | iOS product | Android product | Price |
|---|---|---|---|
| Weekly | `torque_pro_weekly` | base plan `weekly` | $4.99, optional 3-day trial |
| Monthly | `torque_pro_monthly` | base plan `monthly` | $9.99 |
| Lifetime | `torque_pro_lifetime` | one-time INAPP | $49.99 |

RevenueCat (`purchases_flutter`) for one entitlement check across both stores.

> **Privacy note:** RevenueCat transmits an anonymous app user ID and purchase data. You **cannot** claim "Data Not Collected" on iOS, and must declare "Purchases" and "Identifiers" on Play. See §8.3.

## 7.2 Free vs Pro

| Capability | Free | Pro |
|---|---|---|
| Connect (all transports) | ✅ | ✅ |
| Read DTCs stored + pending | ✅ | ✅ |
| **Clear DTCs** | ✅ | ✅ |
| DTC descriptions | Generic SAE | + manufacturer-specific + ranked causes |
| Live gauges | 6 tiles, 1 layout | Unlimited, named layouts |
| Graph window | 60 s | 30 min |
| Recording | 2 min, last 3 trips | Unlimited |
| Freeze frame, readiness | ✅ | ✅ |
| Mode 06, permanent codes | ❌ | ✅ |
| Health Score | Score only | + breakdown + trend |
| Vehicles | 1 | Unlimited |
| Maintenance entries | 10 | Unlimited |
| PDF/CSV export | ❌ | ✅ |

**Hard rule: reading and clearing codes stays free on both stores.**

## 7.3 Paywall triggers

Contextual only, never on launch: 7th gauge tile · Mode 06 · permanent codes · export · 2nd vehicle · recording past 2 min · 11th maintenance entry.

## 7.4 Pricing recommendation

Weekly $4.99 annualises to $259; monthly priced above 2× weekly exists to make weekly look cheap. Recommended instead: **weekly $4.99 (3-day trial) / annual $29.99 / lifetime $49.99**, plus **regional pricing** on Play for PK/IN/EG/NG.

## 7.5 Edge cases

App killed mid-purchase (RevenueCat reconciles; register the listener in `main()` before `runApp`) · pending purchase ("Waiting for approval", do not grant, do not error) · refund (downgrade, never delete data) · Family Sharing (grant identically) · billing retry/grace (keep Pro, non-blocking banner) · restore on a new device with no account · offline launch (7-day cached grace, then degrade with an explanation) · sandbox renews in minutes · **user subscribes then finds their car is an EV** (proactive refund card).

---

# PART 8 — PERMISSIONS, PRIVACY, SAFETY

## 8.1 Android permission matrix

```xml
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
                 android:usesPermissionFlags="neverForLocation" tools:targetApi="s" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE" />
<service android:name=".ObdForegroundService"
         android:foregroundServiceType="connectedDevice" android:exported="false" />
```

**API ≤30 also needs location *services* switched on system-wide**, not just the permission, or `startScan` silently returns nothing. Detect and prompt with `ACTION_LOCATION_SOURCE_SETTINGS`. A silent empty scan list is the most confusing failure in the Android build.

## 8.2 iOS permissions

`NSBluetoothAlwaysUsageDescription` · `NSLocalNetworkUsageDescription` · `NSPhotoLibraryUsageDescription` · `UIBackgroundModes: bluetooth-central`. **Do not request location on iOS.**

## 8.3 ★ The privacy decision

| Component | Collects? | Verdict |
|---|---|---|
| `flutter_blue_plus`, `drift`, `fl_chart`, `permission_handler`, `share_plus`, `pdf` | No | Safe |
| `device_info_plus`, `package_info_plus` | Local read only | Safe |
| **`purchases_flutter` (RevenueCat)** | **Yes** — anon ID + purchase events | Breaks "Data Not Collected" |
| `in_app_purchase` (official) | Store-only | **Preserves the label** |
| Firebase / Sentry / Crashlytics | Yes | Breaks it |

**Option A** — `in_app_purchase`, zero collection, ship blind. **Option B** — RevenueCat, declare "Purchases" + "Identifiers".
**Recommendation: Option B, and nothing beyond it.** No analytics SDK, no crash reporter. Then say so in the listing: *"No analytics. No tracking. No account. Your car's data never leaves your phone."*

Verify with a proxy before every release (AC-14).

## 8.4 Safety and legal

1. Driving warning at onboarding and first Dashboard session each day. Tile editing disabled above 5 km/h; display stays live.
2. "Not a substitute for professional diagnosis" on every DTC detail.
3. Emissions-test warning before clearing, uncollapsible.
4. **Read-only plus Mode 04 only.** No actuator tests, no ECU writes, no module coding.
5. Parasitic draw note in Settings.

---

# PART 9 — EDGE CASE MATRIX

## 9.1 Adapter discovery

| Scenario | Required behaviour |
|---|---|
| First BLE scan finds nothing in 15 s | Platform-branched Compatibility Gate. Never "try again" without explaining why. |
| Adapter advertises no name | Sort "Other devices" by RSSI desc, live bars, hint: "Move closer to your car." |
| **Android API ≤30, location services off** | `startScan` returns nothing, no error, no callback. **Detect and prompt before scanning.** |
| Android `BLUETOOTH_SCAN` denied | Distinguish `denied` (re-ask with rationale) from `permanentlyDenied` (deep-link to settings). |
| iOS Bluetooth off vs unauthorised | Branch on `adapterState`. Never a spinner in either. |
| Android SPP adapter not paired | Paired list + "Pair a new adapter" → `ACTION_BLUETOOTH_SETTINGS`, PIN hint. |
| Two adapters in range | On first handshake with a new fingerprint, show identity + voltage, ask "Is this your car?" once. |
| Fake "v2.1" firmware | Never trust the version string. Feature-probe once, cache per fingerprint, degrade silently, one "Limited adapter" chip. |

## 9.2 Connection lifecycle

| Scenario | Required behaviour |
|---|---|
| Engine cranking | Reconnect ladder 0.5/1/2/4/8 s, then every 15 s for 2 min, then a manual button. Re-scan by **fingerprint**, not the plugin's device identifier. |
| Ignition switched off | If `ATRV` answers but `0100` returns `UNABLE TO CONNECT` → ignition-off. "Turn the ignition to ON", not an error. |
| Adapter unplugged mid-session | Callback may never fire. **Watchdog:** 3 consecutive timeouts → force disconnect, enter the ladder. |
| Two apps fighting for the adapter | >30% malformed in 10 s → disconnect: "Another app may be using this adapter." |
| Android Bluetooth toggled off | Tear down cleanly, persist the trip, show the enable prompt. |
| iOS backgrounded 10+ min | Flush the trip CSV every 5 s. On relaunch mark `.interrupted`, offer "Resume trip?" |
| **Flutter hot restart** | Native connection survives while Dart state resets → phantom "already connected". On init, reconcile `FlutterBluePlus.connectedDevices`. Ship this — it also fixes real process restarts. |

## 9.3 Background execution — the Android battleground

| Scenario | Required behaviour |
|---|---|
| Android 14+ untyped FGS | Crashes with `MissingForegroundServiceTypeException`. Declare `connectedDevice` **and** hold the permission. |
| Doze | BLE callbacks throttle. Timestamp every sample; never assume a fixed interval. |
| **OEM battery killers** ★ | Xiaomi/MIUI, Oppo/Realme, Vivo, Huawei, Samsung, OnePlus, Tecno/Infinix — all kill FGS aggressively and **dominate PK/IN**. Detect the manufacturer, show a one-time "Your {brand} phone may stop background recording. [Fix this]" → vendor autostart intent + per-brand walkthrough. Fall back to `dontkillmyapp.com/{brand}`. |
| Notification permission denied (33+) | Block background recording and explain why. |
| iOS `bluetooth-central` | Drop to 0.5 Hz, active recordings only. 10 Hz in background gets the app killed. |
| **Flutter background isolate calling a plugin** | Throws. `BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken)`, or keep plugin calls on the root isolate and use isolates for pure computation only. |

## 9.4 Live data streaming

| Scenario | Required behaviour |
|---|---|
| Throughput below 2 Hz sustained | Degraded banner + tap-through: "Your adapter is responding slowly. This is normal for budget adapters." Never a silent slideshow. |
| **UI at 10 Hz on mid-range Android** | Leaf `ValueListenableBuilder` + `RepaintBoundary` per tile + `const` chrome. **Profile on a ₨25,000 phone, not a flagship.** |
| A PID stops responding | 3 consecutive `NO DATA` → drop from scheduler, tile becomes "Not available" — visually distinct from a live zero. |
| Corrupt frame → absurd value | Hard bounds per PID. Out-of-bounds never reaches the widget tree. |
| Legitimate zero | `double?` throughout. Zero is a value; `null` is absence. |
| RPM 0 while speed > 0 | If it persists >2 s, mark both suspect and show staleness. |
| Redline blip between samples | Graph footer: "Sampled at N Hz — brief peaks may be missed." |
| Diesel | Read the compression/spark bit; switch readiness set and default layout. |
| Hybrid | Persistent note: RPM reads 0 in EV mode. |
| **Full EV** | `0100` succeeds but <6 PIDs and no RPM/MAF → honest state, **and block the paywall from it.** |
| `fl_chart` with 18,000 points | Downsample in an isolate (LTTB) to ≤600 before rendering; full series stays on disk. |

## 9.5 DTC read and clear

No codes → positive empty state with timestamp and readiness summary · 12 codes → **ISO-TP reassembly mandatory** · P1xxx → never fabricate · clear succeeds but code returns → always re-read and say so · ECU refuses while running → suggest engine off, ignition ON · clearing before an emissions test → uncollapsible warning · clearing while driving → hard-gate on speed = 0 · app killed mid-clear → snapshot written **before** Mode 04, reconcile on relaunch.

## 9.6 VIN

VIN unsupported pre-2008 → never block vehicle creation · check digit fails → re-read once, then store flagged `vinUnverified`, don't decode · contains I/O/Q → corrupt, discard · truncated by a clone → length check, 8 chars is not a VIN · two vehicles one adapter → compare VIN on connect, prompt on mismatch before recording.

## 9.7 Flutter and platform edge cases

Android 15 edge-to-edge (`SafeArea` + `viewPadding`, test both nav modes) · Android 15 16 KB page size (verify custom `.so`) · predictive back (`enableOnBackInvokedCallback`, `PopScope` not `WillPopScope`) · `AppLifecycleState.hidden` treated as `paused` · low-RAM (trim in-memory samples to 2,000) · Impeller on Mali-G52-class GPUs · display cutout · portrait lock except the full graph · text scale 2.0 · comma-decimal locales (`NumberFormat`, never `toStringAsFixed` interpolation) · RTL phase 2 (numerals stay LTR) · storage full · DST/clock change (monotonic `Stopwatch`, store UTC).

## 9.8 Hostile input

10 KB garbage → 4 KB read cap, discard, `ATWS` · no `>` ever → timeout, queue never deadlocks · non-ASCII → filter to `[0-9A-Fa-f\r\n> ]` · odd-length hex → discard · short response → discard, count malformed · 200-char BLE name → truncate to 40, never in a file path · 10,000-char note → cap 5,000 with a counter · odometer 999,999,999 → validate 0–2,000,000 km · future service date → allow, exclude from rollups · negative fuel cost → inline error · duplicate VIN → warn, allow.

---

# PART 10 — QA & TEST STRATEGY

## 10.1 Hardware rig (~$260)

Vgate iCar Pro BLE 4.0 ($30, reference good) · generic $10 BLE clone (reference bad) · **Classic-Bluetooth SPP ELM327 ($8 — Android's key path)** · Veepeak Wi-Fi ($30) · ECUsim 2000 or Freematics emulator ($150–200) · vehicles: ≥1 CAN 2010+, ≥1 K-line 1999–2005, ≥1 diesel.

## 10.2 Device matrix

iOS: iPhone SE 2 (layout floor, iOS 16), iPhone 15 · Android flagship: Pixel 7/8 · **Android mid-range OEM skin ★: Redmi Note (MIUI), Samsung A-series (One UI), Infinix/Tecno (HiOS) — this is your actual user in PK/IN/MENA** · Android old: any API 26–29.

## 10.3 Testing pyramid

```
Unit (Dart VM, no device, <5 s) ─── 70%
  ResponseParser · DtcDecoder incl. 12-code ISO-TP · ReadinessDecoder both
  branches · PID formulas + bounds · VIN check digit, I/O/Q, truncation
  · ElmSession serialisation invariant · PidScheduler BUFFER FULL backoff
Integration (MockTransport replay) ── 20%   all 20 traces end to end
Golden / widget ───────────────────── 7%    GaugeTile 5 states, AX sizes
Manual on hardware ───────────────── 3%    cranking brown-out, ignition-off,
                                            OEM battery kill, real range loss
```

## 10.4 In-app diagnostics log

Last 500 protocol events (timestamp, direction, raw, parsed, latency). Copy · Share `.txt` · Clear. VIN masked to `WVW••••••••••1234` unless the user opts in. **This is your entire support infrastructure.**

## 10.5 Acceptance criteria

| ID | Criterion |
|---|---|
| AC-01 | Cold start to interactive ≤ 1200 ms on a Redmi Note-class device |
| AC-02 | BLE scan surfaces a Vgate iCar Pro within 3 s, both platforms |
| AC-03 | Android SPP connect to a paired classic adapter ≤ 4 s |
| AC-04 | Handshake to first live RPM ≤ 6 s CAN, ≤ 20 s ISO 9141-2 |
| AC-05 | Sustained ≥ 5 Hz on 4 PIDs with the reference adapter |
| AC-06 | **≥ 55 fps on the Dashboard at 10 Hz on mid-range Android** |
| AC-07 | All 12 stored DTCs displayed from the multi-frame trace |
| AC-08 | Every §4.4 response handled with no crash and no stuck spinner |
| AC-09 | App kill mid-recording loses ≤ 5 s of samples |
| AC-10 | Adapter unplugged → reconnect banner within 4 s |
| AC-11 | Zero PID polling backgrounded with no active recording |
| AC-12 | Android 14 FGS starts with `connectedDevice` type, no crash |
| AC-13 | VoiceOver + TalkBack read every tile with value, unit, freshness |
| AC-14 | **Proxy check: no outbound traffic except the store and RevenueCat** |
| AC-15 | Memory ≤ 180 MB during a 30-minute recording |
| AC-16 | Text scale 2.0: no truncation or clipping on any screen |
| AC-17 | Restore purchases recovers Lifetime on a fresh install, both stores |
| AC-18 | Delivered size ≤ 18 MB iOS, ≤ 13 MB Android per-device |

---

# PART 11 — STORE REVIEW RISK REGISTER

## 11.1 Both stores

1. ★ **The reviewer has no adapter and no car.** Ship **Demo Mode** from Connect ("Try it without an adapter"), replaying a canned trace with watermarked data. Document it in both stores' review notes. **The single highest-value thing for approval.**
2. Screenshots must be real captures from Demo Mode or a vehicle.
3. Never claim to diagnose or guarantee.
4. Driving warning + editing disabled above 5 km/h.

## 11.2 App Store

2.1 non-functional without hardware → Demo Mode · 3.1.1 gating a safety feature → reading/clearing stays free · 3.1.2 weekly ladder → full disclosure, visible dismiss from frame one · 2.5.4 `bluetooth-central` → justify in notes · 5.1.1 label mismatch → proxy check · 2.3.7 keyword stuffing → keep the subtitle human.

## 11.3 Google Play

**Data Safety form** must match behaviour exactly · **Foreground service declaration (Aug 2024+)** needs a written justification **and a demo video** for `connectedDevice` — budget a week · `BLUETOOTH_SCAN` always with `neverForLocation` · **DSA trader verification** (reuse the K Tech Clans one) · target API 35 from day one · subscriptions use base plans + offers.

## 11.4 Store metadata

| Field | iOS | Android |
|---|---|---|
| Category | Productivity | **Auto & Vehicles** — better ASO fit, less competition |
| Name | Torque OBD2 Pro — Car Check | Same |
| Subtitle | "Live data and maintenance log" | "Read fault codes, watch live engine data, track every service" |

---

# PART B — UI/UX DESIGN

## B.1 Brief

A phone app that reads diagnostic data from a car through an OBD2 adapter. **Who:** car owners and DIY mechanics, not professional technicians — someone whose check-engine light came on yesterday who wants to know how worried to be before booking a garage. **Where:** a parked car, often at night, one-handed, phone at arm's length, sometimes with dirty hands. **The job:** turn an opaque amber light into a decision. **Register:** reassuring competence — a calm mechanic who explains things, not a hacking terminal.

## B.2 Direction

**Rejected:** near-black canvas + acid-green accent + circular gradient gauges (what all 200 competitors look like, signals "for hackers"). **Rejected:** circular gauges as default (70% decoration, and they still don't answer *is this number normal?*).

**The direction: backlit instrument glass, with ISO 2575 as the semantic system.**

1. **The colour system is the diagnostic system.** ISO 2575 is already installed in every driver's head: red stop, amber caution, green working, blue information. Colour is never decorative. If nothing is wrong, the screen is monochrome.
2. **Numerals first, range second.** A large numeral with a thin bar beneath showing where the value sits in its normal operating band. "89 °C" means nothing; "89 °C, mid-band, normal" answers the question.

**Spend the boldness in one place: the Dashboard readouts.** Lists, forms, Garage and Settings stay quiet and dense.

## B.3 Tokens

```dart
class TorqueTokens extends ThemeExtension<TorqueTokens> {
  final Color surfaceDeep;    // #0A1418  canvas
  final Color surfaceRaised;  // #10202A  tiles, sheets
  final Color surfacePanel;   // #17303C  inputs, selected, tile headers
  final Color hairline;       // #22404E  1px rules
  final Color inkPrimary;     // #EAF3F6
  final Color inkSecondary;   // #93AFBB
  final Color inkTertiary;    // #5B7885
  final Color tellRed;        // #FF4A45  fault, MIL on
  final Color tellAmber;      // #FFB020  caution  ← brand accent
  final Color tellGreen;      // #33D17A  pass, in range
  final Color tellBlue;       // #4FC3F7  informational, recording
}
```

**Amber `#FFB020` is the brand accent** — the hue of the check-engine lamp. Primary action and caution only, nowhere else.

**Monochrome-when-healthy:** no faults ⇒ no colour beyond one green tick.

### Type — Barlow, two widths

```
readoutXl   64 / 0.94 / w600 / -1.5   primary gauge value
readoutLg   40 / 1.00 / w600 / -1.0
readoutMd   28 / 1.07 / w600 / -0.5
titleLg     26 / 1.23 / w600 / -0.3
titleMd     19 / 1.32 / w600 /  0     section headings, DTC codes
body        16 / 1.50 / w400 /  0
label       14 / 1.29 / w500 /  0
unit        13 / 1.23 / w500 / +0.4
gaugeLabel  12 / 1.17 / w600 / +1.0   UPPERCASE — tile PID names ONLY
meta        12 / 1.33 / w400 /  0
```

Uppercase appears in exactly one place: the PID name on a gauge tile. **Numerals are always tabular** (`FontFeature.tabularFigures()`).

### Space, radius, elevation

Space 4·8·12·16·24·32·48, gutter 20 · radius: tile 16, sheet 24 top, button 12, chip 8, input 10, **list row 0** · **no `BoxShadow` anywhere** — depth from surface value plus a 1px top-edge white @6% highlight · **touch targets 48×48**, not 44.

### Motion

**In a diagnostic tool, animation latency is a correctness bug.**

| Element | Duration |
|---|---|
| Live numeric value | **0 ms.** Direct swap. |
| Range bar fill | 120 ms easeOut |
| Staleness decay | 400 ms fade to 40% + desaturate ★ |
| Tile press | 80 ms scale 0.98 |
| Sheet present | 280 ms spring |
| Tab change | none |
| Fault appears | one 200 ms amber edge pulse, **never loops** |

Respect `MediaQuery.disableAnimations`.

## B.4 Adaptive strategy

One visual language, two chromes. Adapt: nav bar, tab bar, back gesture, sheets, switches, date pickers, haptics, alerts, loading indicators, overscroll. Wrap in `Adaptive*` widgets in `design_system/` — **feature code never branches on platform**.

## B.5 Core widgets

`GaugeTile` (RepaintBoundary → radius 16 surfaceRaised, 1px top-edge white @6%, const chrome, `ValueListenableBuilder` around **only** the numeral and marker; variants numeric/arc/sparkline/bar; states live·stale·unavailable·unsupported·outOfRange) · `RangeBar` (CustomPaint 4px, bands at 22%, 2×10 marker, animate marker only) · `ConnectionBanner` (44px, **pushes** content) · `TelltaleChip` (radius 8, h24, 15% fill) · `DtcRow` (radius 0, 72px min, 3px severity bar) · `PrimaryButton` (radius 12, h56, amber, **width never changes when loading**) · `DestructiveButton` (red outline, fills solid only at step 2) · `StepProgress` · `EmptyStateView` · `ValueList`.

## B.6 Six states, every screen

**Loading** skeletons matching final geometry, named step over 3 s · **Empty** what's absent, why, one action · **Partial** ★ show what arrived, mark the rest "Not available" with a reason — **the normal state in OBD2** · **Stale** dimmed, desaturated, clock glyph · **Error** names what happened and what to do · **Offline** the app is fully functional offline; **never show a network-error state**.

## B.8 Accessibility floor

Contrast ≥4.5:1 text, ≥3:1 bars and chips · **never encode state in colour alone** — every semantic colour ships with a glyph and a word · text scale 2.0, grid reflows 2-up → 1-up · `Semantics` per tile as **one** node with value, unit, range position, freshness · `liveRegion` only on threshold crossings, never per sample · respect `disableAnimations` and `highContrast` · 48×48 targets · test VoiceOver **and** TalkBack.

## B.9 Icon

Deep `#0A1418` ground, one geometric mark combining the OBD2 connector trapezoid with a rising diagnostic line in `#FFB020`. Legible at 29pt and as a 48dp Android adaptive foreground inside the 66dp safe circle. No text, no wrench, no car silhouette, no gloss.

---

## B.10 As built (Phase 5, 2026-09-05) — decisions that are not obvious from B.1–B.9

Files: `lib/design_system/` (`tokens`, `typography`, `spacing`, `theme`, `surfaces`, `adaptive`, `widgets/*`, barrel `design_system.dart`), `lib/domain/pid_sample.dart` (`PidSample`, `GaugeSpec`, `PidBus`, `DashboardClock`), `tool/icon.py` (B.9). 72 tests and 20 goldens in `test/design_system/`; `test/flutter_test_config.dart` loads Barlow and the Material icon font so goldens render real glyphs. The existing `lib/screens` + `lib/widgets` (the earlier Industry design) are untouched; Phase 6 rebuilds the screens on this.

- **`GaugeTile` rendering model (hard rule 3).** `RepaintBoundary` → const chrome (label, unit, frame) → `ValueListenableBuilder<GaugeState>` (rebuilds only on a state *change*) → `ListenableBuilder` over the sample **and** the state (the numeral, unit, marker, and the variant graphic). The readout listens to state too because the shared clock can move a tile from stale to unavailable with no new sample, and the numeral must become `—` the moment it does — a test caught that. Staleness is derived, never stored: `stateFor(spec, sample, now)` gives live / stale (>2× interval) / unavailable (>5 s or null) / unsupported / outOfRange.
- **One `DashboardClock` for the whole dashboard**, ticked by the scheduler, not a timer per tile. Decay is 400 ms opacity to 40% plus a luma-preserving desaturation matrix; both collapse to 0 ms under `disableAnimations`.
- **Semantics:** one node per tile, built inside the readout (so it carries the current value) with the chrome excluded; `liveRegion` is set exactly once when the state crosses into or out of `outOfRange`, consumed by the next build — never per sample.
- **`RangeBar`** paints its track and band once in their own `RepaintBoundary`; only the 2×10 marker moves, via `TweenAnimationBuilder` retargeting at 120 ms easeOut. The sparkline variant scales to the normal band widened by half its width on each side, not the physical range — coolant wandering 84–91 °C on a 0–150 axis is a flat line and says nothing.
- **`PrimaryButton` keeps its width while loading** by leaving the label in the layout at opacity 0 and stacking the indicator on top. `DestructiveButton` is two-step with a 4 s auto-disarm timer, cancelled on dispose.
- **`ConnectionBanner`** is 44 px and is laid out by `BannerHost` *above* the content, so it pushes rather than covers; the child's top moves by exactly 44 (tested).
- **`DtcRow`** needs `IntrinsicHeight` around its stretched row or the severity bar forces infinite height — the same trap the Industry UI hit.
- **B.4:** every platform decision is in `adaptive.dart` and reads `PlatformInfo` through `AdaptiveScope` (tests inject `FakePlatform`); nothing else in `lib/design_system/` mentions a platform. Tab change is `Duration.zero` on both chromes.
- **B.8 is tested against the actual tokens:** primary and secondary ink ≥ 4.5:1 on all three surfaces, every telltale ≥ 3:1 on the tile and canvas, dark-on-amber ≥ 4.5:1. Tertiary ink is for chrome and secondary text only.
- **Type:** condensed Barlow for readouts and titles, regular for everything else; tabular figures on every style; uppercase produced by the tile itself for the PID label and nowhere else.
- **Icon (B.9):** generated, not drawn by hand — `tool/icon.py` renders the trapezoid-and-rising-line mark at 4× and downsamples into all 19 iOS sizes, the five legacy mipmaps, and an adaptive foreground at 52/108 of the canvas inside the 66 dp safe circle over a `#0A1418` colour background.
- **Round-2 review (22 findings, all applied):** every button, the banner action, the DTC row and a tappable tile carry their tap action *on the Semantics node* — a `GestureDetector` under `ExcludeSemantics` is invisible to TalkBack and VoiceOver. The tile is one node: its header is excluded and the readout node carries `button`/`onTap`. Only the *readout* dims when stale; the header word ("3 s ago" with the clock glyph) stays at full strength, because the word explaining the dimming must be the most legible thing on the tile, and *unavailable* is not dimmed at all (the dash is the state). Desaturation is a colour choice (amber drops to ink) rather than a `ColorFilter`, so no layer and no re-inflation on the transition. The clock is **required**; an optional one meant a tile with no samples never decayed. Numerals, button labels, chip words, DTC status and list values scale down or wrap at text scale 2.0 instead of overflowing (tested at 1.5 and 2.0 in 2-up widths). Chrome is monochrome — tabs, switches, spinners, progress and the current handshake step are ink; amber is the primary button, the banner action and caution only. "Caution" is a word in `meta`, not a second uppercase site. A `TorqueTokens.highContrast` set answers `MediaQuery.highContrast` (brighter inks, visible rules, stronger tints, a lighter dim). iOS icons are exported without an alpha channel (App Store Connect rejects one); the Android adaptive foreground fills the 66 dp safe circle.
- **Not built here:** the six-state *screens* (B.6 is a rule for Phase 6; the building blocks — `Skeleton`, `GaugeTileSkeleton`, `EmptyStateView`, `ValueRow(null, reason:)`, the banner — are); haptics beyond the three verbs; the fault-appears 200 ms edge pulse (belongs to the dashboard grid, Phase 6).

## B.11 The session layer (Phase 6, slice 1 — 2026-09-07)

`lib/session/` is the piece that makes everything built in Phases 1–5
actually talk to a car. Until now the protocol engine, the transports and
the design system all existed and were tested, but nothing drove them: the
screens still ran on the older Provider/Industry stack with a faked
handshake.

- **`ObdSession`** owns the running conversation: transport → `ElmSession`
  → handshake → supported-PID discovery → poll loop → `PidBus`. It is a
  `ChangeNotifier` for *connection* state only, which changes rarely; live
  values never pass through it (hard rule 3). Hard rule 2 needs no work
  here — `ElmSession` keeps one command outstanding, so the loop can await
  freely without ever pipelining.
- **Every async step is generation-checked.** `connect` and `disconnect`
  bump a counter; a loop belonging to a superseded connection stops the
  moment it resumes. A second `connect` while the first is in flight is a
  supported operation, not a race.
- **The handshake now hands back its own `0100` payload.** That probe *is*
  the first support bitmask, so discovery no longer re-asks it: one fewer
  round trip on every connect. This was found by replay — a recorded
  session contains exactly one `0100`, because a real session only asks
  once, and the second ask timed out against the recorded 1.8 s
  SEARCHING latency.
- **Latency feedback must never undo a `BUFFER FULL` backoff.** The
  scheduler's `recordP95Rtt` sets the rate back to 10 Hz on any fast cycle,
  which erased the halving one line after it happened. After an overflow
  the only way up is `relax()`, which ramps over several cycles.
  `bufferOverflows` is counted for the §10.4 diagnostics log.
- **§9.5 is enforced here, not in the UI.** `clearDtcs` reads the codes,
  writes the `beforeClear` snapshot, sends Mode 04, then *always* re-reads
  and settles the snapshot to `cleared` or `codesReturned`. A refusal is
  recorded too. The UI cannot skip a step because it never sees them.
- **Hard rule 9** is a property of the loop: `setBackgrounded(true)` stops
  it unless `setRecording(true)`.
- **Three new fixtures.** `clear_ok`, `clear_returns` and
  `buffer_full_poll`. Mode 04 appeared in none of the twenty Phase 2
  recordings — the one place the app *writes* to the car had nothing to
  replay against — and `BUFFER FULL` had only ever been recorded against a
  batched request this build never sends.

### B.11.1 What the review changed

An adversarial pass over the first cut confirmed 29 findings. The ones that
mattered, and what they say about the fixtures:

- **★ Headers were never stripped.** The handshake sends `ATH1`, so on any
  real adapter every reply is prefixed with a CAN header — three hex
  characters on 11-bit CAN. Three is odd, so byte-pairing shifts by a
  nibble and *every* decode silently returns empty: no supported PIDs, a
  blank dashboard, no codes on a car with a lit lamp, no VIN. Every test
  passed, because nineteen of the twenty Phase 2 fixtures answer `ATH1`
  with `OK` and then emit header-less frames — something that cannot happen
  on real hardware. The width is now *measured*, not assumed: the `0100`
  probe is the one reply whose shape is known in advance, so each candidate
  width is tried against it once at connect. That also survives the clones
  that quietly ignore `ATH1`. New fixture: `headers_can`.
- **★ Two states wedged the poll loop permanently.** After `LV RESET` the
  re-handshake tried to restart the loop from inside it, where the
  `_looping` guard made the restart a no-op; and `ignitionOff` fell outside
  `isLive`, so the loop exited and its own recovery branch became
  unreachable. Both now continue in the same loop, and `ignitionOff` keeps
  a slow one-PID probe running — the only way the session notices the key
  coming back. New fixtures: `lv_reset_recovers`, `ignition_wakes`.
- **★ The reconnect ladder collapsed to one rung**, because it checked the
  generation counter that its own `connect` call increments. It has its own
  token now, and 0.5/1/2/4/8 s all run.
- **★ `clearDtcs` could claim "cleared" when the verifying re-read failed.**
  `readDtcs` returned an empty list both for "the car has no codes" and for
  "we could not ask". It now reports `failedModes`, and a clear whose
  re-read is untrustworthy returns `interrupted` with the snapshot left
  `pending` for relaunch. A Mode 04 *negative response* (`7F 04 22`, engine
  running) is well-formed hex and parsed as success — it was reported as
  "the code came straight back". A link drop during Mode 04 was recorded as
  a refusal, which defeats the whole point of writing the snapshot first.
  New fixtures: `clear_refused`, `clear_interrupted`, `clear_unverified`.
- **The clock is now independent of the poll loop.** It was ticked only
  inside the loop, so a hung link froze every tile at its last value —
  stale rendering as live, which hard rule 4 exists to prevent.
- Also: `connect` failure paths no longer leak the transport, `ElmSession`
  and state subscription; the watchdog is 3 consecutive timeouts, not 5,
  per §9.2; `busInitError`/`busBusy`/`badCommand` are handled rather than
  silently swallowed; the `BUFFER FULL` ramp is time-gated to §4.4's 30 s
  rather than running every cycle; a transient error on one support query
  no longer writes off every PID above it; and `_onLinkLost` is idempotent,
  so a BLE stack emitting `disconnected` then `failed` starts one ladder.

Three tests were replaced for asserting nothing: one compared `0 == 0`, and
one asserted `expect(ok, isA<bool>())`.

## B.12 The Dashboard (Phase 6, slice 2 — 2026-09-09)

`lib/features/dashboard/dashboard_screen.dart` is the first screen on the
Part B system, and the first anywhere in the app fed by real decoded data
rather than a fixture: its tiles read `ObdSession.bus`, so what is on
screen is what the protocol engine took off the wire.

- **The grid decides what is asked for.** Only PIDs with a tile are handed
  to `setVisible`, so removing a tile stops costing a round trip at once.
- **Nothing rebuilds at 10 Hz.** The screen listens to the *session*, which
  changes state rarely; each tile listens to its own notifier and repaints
  alone. One shared clock drives decay.
- **`lib/features/session_banner.dart`** reproduces the §2.1 table
  literally, so no screen invents its own wording. A healthy link shows no
  banner at all.
- **The six states are real, not decoration.** Loading is a skeleton grid
  matching the final geometry; Error names the failure and offers one
  action; Partial keeps an unsupported tile in place saying "Not supported"
  rather than leaving a hole; Stale and Unavailable are the tile's own
  states; Offline never appears, because the app has nothing to be offline
  from.

**Testing note.** The widget tests drive a real `ObdSession` replaying a
recorded car. Three traps cost time and are worth knowing: inside
`testWidgets` the clock is fake, so (a) awaiting anything the session does
deadlocks rather than fails — drive it by pumping and observing; (b) real
file I/O never completes, so fixtures must be read in `setUpAll`; and (c)
the poll loop's own delay outlives the test body unless the session is shut
down and pumped dry first.

## B.13 Connect (Phase 6, slice 3 — 2026-09-10)

`lib/features/connect/connect_screen.dart` plus
`lib/session/adapter_discovery.dart`. The screen finds adapters, connects
to one, and names each of the seven handshake steps while it happens.

- **Discovery is an interface.** `RealAdapterDiscovery` reads the BLE scan,
  the Android paired list and the well-known Wi-Fi endpoints;
  `FakeAdapterDiscovery` scripts a result set. The screen cannot tell them
  apart, which is what makes the whole flow testable without a radio — and
  is also what Demo Mode will use.
- **The compatibility list is compiled in and short.** Anything absent is
  `unknown` and gets *no badge*: claiming to have verified an adapter that
  nobody tested would be worse than saying nothing. No lookup leaves the
  device (AC-14).
- **§9.1 in full.** Bluetooth off, permission refused, permission refused
  permanently, the Android ≤30 location trap, and no radio at all each get
  their own message and their own remedy. None of them is a spinner —
  including the case that used to slip through, where the screen kept
  saying "Looking for adapters…" while the radio was off.
- **The compatibility gate** appears only after a full 15 s scan with
  nothing found, and is platform-branched: iOS names the classic-Bluetooth
  impossibility as an Apple platform rule; Android points at Settings
  pairing with the PIN hint.
- **Adapter ids are stable** (`ble:…`, `spp:<MAC>`, `wifi:<host>:<port>`)
  and `buildTransport` turns one back into a transport without scanning, so
  a remembered adapter can be reconnected directly.

Also fixed here: the adapter identity shown on the card was the raw `ATZ`
reply, so it carried the `>` prompt — "ELM327 v1.5 >" on every real
connection. It is cleaned once, at the source.

**Test stability.** The replay suites ran replies at 9 ms against a 12 ms
timeout — a 3 ms margin that any machine load blew through, and two runs in
three failed. `timeScale` is now 0.05, which leaves replay exactly as fast
and gives the deadline 60 ms.

## B.14 Wired into the app (Phase 6, slice 4 — 2026-09-10)

`lib/features/live_tabs.dart` holds the one live `ObdSession` and the
discovery feeding it, and the Connect and Dashboard tabs are now the Part B
screens on the real protocol engine. The other three tabs are still the
older Industry design, so the new theme is applied per-screen rather than
at the app root; it moves to the root once every screen has migrated.

**Demo Mode (§11.1)** is a *recorded session* replayed through the same
transport, engine and session the real thing uses, so a store reviewer with
no car sees what a car produces rather than a mock-up. Nothing in it
invents a number; values hold steady once the recording runs out.

### Three defects that only running it could show

- **★ A tight budget starved PIDs instead of delaying them.** `nextCycle`
  sorted by priority and then truncated to the budget — a stable sort with a
  stable cut, so the same tail fell off *every* cycle and was never asked
  for at all. On the six default tiles with a four-PID budget, Throttle and
  Battery read "No data" permanently on a car answering both. Criticals are
  now never dropped and the rest take turns. (The first attempt at the
  rotation keyed off the cycle counter, which lands on the same offset every
  time, because a high-priority PID is only due on alternate cycles.)
- **★ The compatibility gate was unreachable.** It appears when a scan finds
  nothing, but the Wi-Fi endpoints are offered unconditionally — they do not
  advertise — so the list was never empty. The one affordance that explains
  to an iPhone user why their cheap adapter cannot work would never have
  appeared. It now ignores the unconditional entries.
- The adapter identity carried the ELM prompt (`ELM327 v1.5 >`), fixed in
  §B.13.

**Still to do in Phase 6:** The tab shell itself is still the older one, and
the deferred UI pieces are editing the grid (drag reorder, change PID, swipe
to remove), the full graph screen, and the trip strip. BLE scanning is wired but
unexercised — it needs hardware (§10.1), so on the simulator only the Wi-Fi
endpoints appear.

## B.15 Diagnostics (Phase 6, slice 5 — 2026-09-11)

`lib/features/diagnostics/` — the scan, the codes, the readiness monitors,
the health score and the guarded clear, on the Part B system and the real
session. `DiagnosticsController` holds every decision about what the car
said, so the wording is decided in one place and tested without a widget
tree.

**The scan runs §5.4's order on the wire** — 03, 07, 0A, then the Mode 01
summary, then the VIN — and the label names the command in flight.
`ObdSession.readDtcs` was reordered to match and now reports each step, so
the progress the user reads is the conversation rather than a decoration.

**The headline table is reproduced literally**, plus the rows it does not
cover, because real cars produce all of them: the light on with nothing
stored, codes with the light off, and the light not reported at all. The
count is of **distinct** codes — one fault can sit in two lists, and
counting it twice overstates what is wrong with the car.

**Hard rule 7 has a home: `lib/data/dtc_dictionary.dart`.** The bundled
`dtc.sqlite` still needs a licensed source (§6.1), so the app ships on
`EmptyDtcDictionary` and every code renders through `DtcText`, which says
only what SAE J2012 defines *structurally* — the system letter, and whether
the second digit makes the code manufacturer-specific. An unknown generic
code is named as unknown. Nothing describes a fault it did not look up.

**The clear is guarded twice over.** The sheet states all four
consequences uncollapsed — a disclosure triangle is how you hide the
emissions reset while claiming you didn't — then the speed gate, then
`DestructiveButton`'s two taps. The gate **reads the car** rather than the
bus: a stale zero from a stop sign ten seconds ago is exactly the reading
that must not open it (hard rule 4), and a speed it could not read is not
permission. A pending `beforeClear` row on disk surfaces as "a clear was
never verified" with an offer to settle it from the car.

### Things building it found

- **★ A permanent code surviving Mode 04 was reported as "the code came
  straight back".** `clearDtcs` judged the outcome on `after.all`, so the
  one kind of code that is *supposed* to survive a clear turned a clean
  result into a live-fault warning. It now judges on stored and pending,
  and the sheet names the code that stayed.
- **★ Connect handed the user on at every notification, not on the edge.**
  Found by running it: tapping "Scan now" bounced to the Dashboard,
  because a scan flips the session between connected and degraded and
  `_onSession` called `onConnected` each time. Any tab, mid-task.
- The demo recording answered 03 and 07 but not 0A or 0902, so Demo Mode's
  own scan would have reported itself incomplete. `clean_can.obdtrace` now
  answers the whole scan, as the car it is recorded from does.
- The Drift database is opened in `main()` and provided at the root. It
  has been built since Phase 4 but nothing was using it; §9.5's
  reconciliation has to be answerable on the first frame. Snapshots still
  need a vehicle, and until the Garage names one the sheet says the
  history is not being kept rather than quietly keeping none.

**Deferred with the Garage:** the −5 per overdue reminder is an input the
health score takes and nothing yet supplies, and freeze-frame capture
(§4.5) is not read before a clear — the sheet says the data is erased, it
does not offer to keep it.

### What the adversarial review found (2026-09-12)

Six lenses looked for defects, three independent refuters tried to kill
each finding, and what survived was real. Every one now has a test that
fails without its fix.

- **★ The screen denied the codes listed directly under it.** Making
  `cleared` mean "no stored and no pending" was right, and the sheet was
  updated for it — the *screen's* outcome line was not, so it read "the
  re-read came back empty" with the surviving permanent code one row
  below. The same class of misreport this slice set out to fix, left in
  the second widget.
- **★ `reconcile()` swapped the codes and left the old score beside them.**
  Three call sites each had to do the same four things — install the
  result, load definitions, stamp the time, recompute the score — and one
  of them did three. There is now one `_install` path, which is the actual
  fix; the drift was the defect.
- **★ The clear sheet overflowed at text scale 2.0.** Both progress lines
  were a bare `Text` in a `Row` with no `Expanded`, so they ran off the
  edge instead of wrapping — 155 px at 320 pt, which is an iPhone with
  Display Zoom on. Every other row in the file wrapped correctly; these
  two were missed.
- **★ A pushed route does not inherit the theme of the screen that pushed
  it.** It is a *sibling*, so the code-detail page opened with the old
  light Industry nav bar sitting on the Part B body. `Backlit` is now a
  design-system widget and any pushable screen carries its own ground.
  The existing tests could not catch this because they mount the screen
  under their own `MaterialApp(theme: torqueTheme())`, which the app does
  not.
- **A finished clear's verdict survived every later scan.** `_lastClear`
  was never reset, so "codes cleared" stood above a fresh reading it said
  nothing about.
- **A scan outliving its link could merge two conversations.** Five round
  trips is long enough for a drop and a reconnect to land inside one.
  Every step is now pinned to the generation it started on and reports the
  modes as unanswered instead — which is what they are. `readPidOnce` is
  pinned too, so a late reply cannot put another car's number on a tile.

The `truthfulness` lens died to repeated agent stalls and was re-run
separately.

# PART C — BUILD ORDER

```
Phase 1  Protocol engine, PURE DART, no Flutter imports. Tests FIRST.   ✅ done
Phase 2  Transport: ObdTransport + MockTransport, then BLE, then Wi-Fi.   ✅ done
Phase 3  Android SPP native module.   ✅ done 2026-09-05 — see §3.4.1
Phase 4  Persistence — Drift, migrations with a schema test per step.   ✅ done 2026-09-05 — see §6.1
Phase 5  Design system — Part B before any screen. Goldens.   ✅ done 2026-09-05 — see §B.10
Phase 6  Screens: Connect, Dashboard, Diagnostics, Garage, Settings, Onboarding.
         ◐ slice 1 done 2026-09-07 — the session layer, see §B.11
         ◐ slice 2 done 2026-09-09 — the Dashboard, see §B.12
         ◐ slice 3 done 2026-09-10 — Connect + discovery, see §B.13
         ◐ slice 4 done 2026-09-10 — wired into the app + Demo Mode, see §B.14
         ◐ slice 5 done 2026-09-11 — Diagnostics + the clear, see §B.15
         ◐ slice 6 done 2026-09-12 — Garage + §9.6 identity, see §B.16
         ◐ slice 7 done 2026-09-13 — connection settings wired, see §B.17
         ◐ slice 8 done 2026-09-17 — Settings + diagnostics log on Part B, see §B.18
         ◐ slice 9 done 2026-09-17 — Onboarding on Part B, see §B.19
         ◐ review of slices 8/9 + slice 6 re-run, 2026-09-24 — five clusters fixed, see §B.20
         ◐ slice 10 done 2026-09-24 — the unit toggles reach the gauges, see §B.21
         ◐ slice 11 done 2026-09-24 — the freeze frame (Mode 02) on the scan and before the clear, see §B.22
         ◐ slice 12 done 2026-09-24 — the tab shell on Part B, see §B.23
         ◐ slice 13 done 2026-09-24 — the paywall on Part B; the account flow and the ad code deleted, see §B.24
         ◐ slice 14 done 2026-09-24 — Data & privacy on Part B; no Industry sub-screen remains, see §B.25
         ◐ review of slices 10–14, 2026-09-25 — 22 confirmed, all fixed, see §B.26
         ◐ slice 15 done 2026-09-25 — the Garage's maintenance log, reminders and fuel log, see §B.27
Phase 7  Android FGS, OEM battery helper, permission matrix.   ✅ built before Phase 6, on the Provider stack
Phase 8  Monetisation — RevenueCat, all §7.5 cases.   ✅ built before Phase 6, on the Provider stack
Phase 9  Demo Mode. Required for store review, not optional.   ✅ rebuilt on the real session in slice 4 (§11.1, §B.14)
```

## B.16 Garage (Phase 6, slice 6 — 2026-09-12)

The vehicles, on the Part B system and the Drift repositories, with the one
thing every other record needs: a `vehicleId`.

**What was built.** `lib/features/garage/`: `GarageController` (the list,
exactly one primary, delete that takes the trip *files* with it because the
row cascade cannot reach disk), `GarageScreen` (the primary as a card,
the others as rows, the free-tier gate on a second vehicle), the
`VehicleFormScreen` (§9.8 for everything typed — name ≤ 40, year bounded,
odometer 0–2,000,000 km with comma-decimal parsing, VIN refused with the
reason or allowed flagged), `DtcHistoryScreen` (every §9.5 snapshot as what
it was), and `Distance` — kilometres on disk, the user's unit on screen,
nothing else converts. The Drift repositories for services and trips are now
provided at the root, and `main()` resolves the documents directory for trip
files.

**§9.6 — two vehicles, one adapter.** `resolveIdentity` is a pure function
of (what the car said, the primary, the garage) with five outcomes: no VIN
(pre-2008; the primary stands, nothing blocks), the primary's own, *attached*
(the primary had none on record — not a mismatch), *another vehicle's* (prompt,
named), and *unknown* (prompt; offered as a new vehicle with the VIN filled
in). `GarageController.onConnected` runs on the live edge only, re-reads once
on a failed check digit, and on the two prompting outcomes leaves the verdict
*pending*. While it is pending `LiveSession` sets the diagnostics vehicle to
null, so a scan in that window is not recorded under the wrong car — which is
what "prompt before recording" means in code. `IdentityPromptHost` sits above
the tab stack and asks with a sheet that cannot be swiped away, because there
is no safe default to fall back to. The §4.2 connection cache (protocol,
supported PIDs) is written on the vehicle only once the car's identity is
settled.

**Two fixtures, both on a real CAN wire with headers:** `vin_reread` (the last
character arrives as `7` — one dropped bit — and the second read is clean) and
`vin_corrupt` (every read the same; stored flagged, compared as read, never
decoded). Both derived from `headers_can`.

**The health score's −5 per overdue reminder** now has a source. The Garage
counts reminders past their date or their odometer (paused and completed
excluded), and Diagnostics asks it at scan time. When there is no vehicle to
ask about, the input is `null` — a *gap* in the breakdown ("Service reminders
— no vehicle selected"), not a zero. The same rule as every other input.

**Waiting for the first read.** A connect can land before the garage's first
row does, and judging a VIN against an empty list would call every car a
stranger. `onConnected` awaits `GarageController.ready` — a test connects
first and constructs the controller second to prove it.

**Deferred to their own slices:** the maintenance log, reminders, fuel log
(economy between full fill-ups only), trip recordings and reports. The
screen has a `GarageLinks` slot for each and offers none until they exist;
the older Industry versions of those screens are not linked, because a light
Industry page under a Part B card is the wrong thing to ship for the sake of
a row. Vehicle photos and the free-tier cap on *records* (§7.2) also wait.

**What the tests found before the app ran.** The identity sheet handed off
to the vehicle form and the host, seeing the question still open, put the
sheet straight back up *on top of the form*. The host now owns the whole
hand-off inside one guard. And "Switch to The Civic" left the last verdict
saying *other*, so the card never showed the car as connected; answering now
settles the verdict.

**What running it found that the tests had not.**
- The card said a VIN "failed its check digit **twice**" — the re-read story
  for a VIN read from the car, shown for one that was typed. The card
  cannot tell which, so it no longer claims a re-read.
- "Petrol" twice: the subtitle fell back to the fuel when make, model and
  year were empty, and the list has a Fuel row. No subtitle now.
- The §9.6 sheet's "Add it as a new vehicle" walked round the one-vehicle
  free plan that the garage's own button enforces. Same door, same lock:
  on the free plan the sheet names Pro and offers only the other answer.
- **"0 scans" after a scan.** The count was memoised on (vehicle, odometer,
  list length) and the Garage never leaves the tab stack, so it showed the
  number it read on first build for ever. The controller now watches the
  snapshot and reminder streams for the primary and bumps a `revision`;
  the screen re-reads when it moves. The subscriptions live on the
  controller, not the widget, because drift schedules a `Timer.run` on
  cancel and a widget-lifetime cancel fails `testWidgets`' pending-timer
  invariant — which is how the first attempt at this fix broke a passing
  test.

## B.17 Connection settings, wired (2026-09-13)

§5.6 lists Polling rate, Auto-reconnect and Haptics as things the user can
set. `SettingsProvider` has stored the first two since the app was built —
but nothing downstream ever read them. A toggle that changes a preference
and nothing else is worse than no toggle: it tells the user something
happened.

**What was built.**
- `ObdSession.autoReconnect` (`lib/session/obd_session.dart`) — a plain
  `bool`, default `true`. `_onLinkLost` checks it: off, a dropped link tears
  down like a deliberate disconnect (tiles decay, the loop stops) and is
  reported as `'Connection lost'` rather than silently retried; on, the
  existing §9.2 ladder runs exactly as before.
- `PidScheduler.maxHz` (`lib/protocol/pid_scheduler.dart`) — a ceiling the
  adaptive rate never rises above, applied at every place the rate can
  climb (`recordP95Rtt`, `relax`, `reset`) and at every place it can fall
  (`onBufferFull`), so a user who chose "4 Hz" still sees the adapter drop
  to 2 Hz and say so on a slow link — the ceiling caps the *rate*, it does
  not disable the *adaptation*. Null (Auto) is the default and means no
  ceiling beyond what the protocol itself allows (10 Hz).
- `AdaptiveHaptics.enabled` (`lib/design_system/adaptive.dart`) — a static
  switch every haptic call already goes through. §5.6 lists a Haptics
  toggle; no such preference exists yet in `SettingsProvider`; and the
  Settings screen itself is still the old Industry stack (Phase 6 slice 7,
  not yet built). Wiring a real toggle to a screen that does not exist yet
  would be inventing a UI. The switch is built, defaults to the app's
  existing always-on behaviour, and is one line for that future slice to
  connect.
- `ProtocolLog` (`lib/protocol/protocol_log.dart`) — SPEC §10.4, "the last
  500 protocol events... this is your entire support infrastructure." A
  capped ring of real commands and replies, fed from inside `ElmSession`
  (the one place both the write and the read already pass through), so
  nothing upstream can forget to log something. `ElmSession.describe`
  turns a reply into the value it decoded to (`ObdSession._describeReply`
  supplies this — a PID's value, a VIN, or the status word for a failure);
  never a guess, and a reply this cannot decode gets no description at
  all. `render()` masks the VIN by default, in **both** the plain text and
  its hex encoding: a Mode 09 reply carries the VIN as hex-encoded ASCII
  split across ISO-TP frames, and a naive string-replace on the decoded
  VIN would miss it there. `LiveSession.log` is now real and accumulating;
  the visible screen is still the old one showing nine years of fake
  static rows (`lib/screens/settings/diagnostics_log_screen.dart`) — that
  rewrite is Settings' own slice, not this one.

**The bridge.** None of the above widgets know `SettingsProvider` exists —
the session layer has no Provider dependency, by design. `LiveSettingsSync`
(`lib/features/live_tabs.dart`) is a small `StatelessWidget` that watches
both `LiveSession` and `SettingsProvider` and calls
`LiveSession.applySettings` on every rebuild; the calls are idempotent
field writes, so re-applying an unchanged value costs nothing. It wraps the
tab stack in `app.dart` next to `LiveIdentityPrompt`, so a change made on
the Settings tab reaches the session on the very next frame no matter which
tab is open.

**Deferred, honestly:** the Haptics preference and its UI; rewiring the old
diagnostics-log screen to `LiveSession.log`; Adapter prefs, Background &
battery, Notifications, Data & privacy, Export/Delete/Restore, Manage
subscription, Support and Legal — all of §5.6 not named above. Settings and
Onboarding remain the one screen pair still fully on the Industry/Provider
stack; this slice only made sure the two preferences that already existed
were not silently inert.

546 tests, analyzer clean.

**What the adversarial review found (2026-09-13).** A focused review of
just this slice — three lenses, three refuters each — confirmed three real
defects, none caught by the tests above.

- ★ **Blocker.** `maskVinIn`'s hex masking computed a run's reveal/mask
  pattern from *where in the VIN* it sat, then did a global text-replace
  per window. Two different positions can hex-encode to the identical
  byte run — any VIN with a repeated ≥3-character substring does this
  whenever one copy sits next to the disclosed prefix or suffix and
  another sits entirely in the masked interior — and a text-replace
  cannot tell which physical occurrence it is looking at. On a fragmented
  reply (a K-line frame can carry as few as three VIN characters between
  its headers) whichever window ran first stamped its answer onto both,
  and real interior digits survived in the rendered log. Fixed by
  resolving every distinct hex-byte run's answer once, before touching any
  text: if two positions that produce the same bytes disagree, the run is
  masked in full rather than guessed at.
- **Major.** The poll loop's BUFFER FULL backoff cleared on
  `_scheduler.targetHz >= 10` literally. Under any ceiling below 10 the
  rate can never reach literal 10 again, so a single transient overflow
  left the backoff latched — and `maxPidsPerCycle` frozen at half its
  normal value — for the rest of the connection, even though the rate
  itself correctly climbed back to the user's ceiling. Fixed with
  `PidScheduler.hasRecovered`, which compares against the ceiling that
  actually applies rather than a hardcoded top.
- **Minor.** Turning Auto-reconnect off while the §9.2 ladder was already
  running changed nothing — the setting was only ever read at the moment
  the link dropped. The ladder now checks it at both ends of every rung's
  wait, so a mid-ladder toggle stops it within one rung rather than the
  full remaining 0.5–8 s sequence.

551 tests, analyzer clean.

## B.18 Settings screen, on Part B (Phase 6, slice 8 — 2026-09-17)

`lib/features/settings/settings_screen.dart` replaces the last Industry/Provider
screen still in the tab shell. The connection settings wired in slice 7 now have
a UI that reads them back, and the diagnostics log is no longer nine years of
fake static rows.

**What was built.**
- A new `SettingsScreen` under `lib/features/settings/` using the Part B design
  system: `RaisedSurface`-style sections, `_LinkRow`, `_SwitchRow`, and sheet
  radio rows. Units and polling rate open honest sheets instead of segmented
  controls that hide options.
- `Haptics` preference added to `SettingsProvider` (`Keys.haptics`) and wired
  through `LiveSettingsSync` to `AdaptiveHaptics.enabled`. It defaults to on,
  preserving existing behaviour, and is now one toggle away from off.
- `DiagnosticsLogScreen` on the real `ProtocolLog` from `LiveSession.log`. It
  renders commands and replies as they happened, masks the VIN in both plain
  and hex form when `SettingsProvider.maskVin` is true and a primary vehicle
  VIN is known, copies the rendered log to the clipboard, and clears with a
  two-step destructive confirmation.
- `LiveSettingsTab` wraps the new screen in `_Backlit` like the other Part B
  tabs, and `app.dart` now uses it as the fifth tab. The old
  `lib/screens/settings/settings_screen.dart` and its fake diagnostics log are
  deleted.

**Deferred to their own slices:** the paywall, account and privacy sub-screens
are still the older Industry screens. They still work, but they are the next
pieces to move. Demo Mode remains reachable from Connect (§11.1); it no longer
lives in Settings.

**What the tests cover.** `test/features/settings/settings_screen_test.dart`
proves the title, sections, unit sheet, haptics toggle and diagnostics-log
navigation. `test/features/settings/diagnostics_log_screen_test.dart` covers
empty state, command/reply rendering, VIN masking, clear and clipboard copy.
`test/features/live_settings_sync_test.dart` adds the haptics wiring case.

561 tests, analyzer clean.

## B.19 Onboarding on Part B (Phase 6, slice 9 — 2026-09-17)

`lib/features/onboarding/onboarding_flow.dart` replaces the last main screen
still on the Industry/Provider stack. The four frames — what Torque does, the
adapter explainer, add your car, and the non-skippable safety acknowledgement —
are rebuilt on the Part B design system and wrapped in `Backlit`.

**What was built.**
- A new `OnboardingFlow` under `lib/features/onboarding/` using `Backlit`,
  `_Page`, `PrimaryButton`, `GhostButton`, `RaisedSurface`, and the design
  system's typography and spacing tokens.
- The adapter explainer keeps its platform branch: Android sees one "Works"
  cell, iPhone sees "Works" (Bluetooth LE / Wi-Fi) and "Can't work"
  (Bluetooth Classic) side by side, with the note that Classic is an Apple
  platform rule.
- The add-car screen now actually creates the primary vehicle through
  `VehicleRepository.create` when a nickname is entered. Make, model, year and
  odometer are optional; the unit toggle sets the odometer conversion. The
  "I'll do this later" button advances without creating a vehicle.
- The safety screen is non-skippable, disables the "Agree and continue" button
  until the checkbox is checked, and calls `OnboardingProvider.finish()` to
  flip `onboardingComplete`.
- `app.dart` now uses the new `OnboardingFlow`; the old
  `lib/screens/onboarding/onboarding_flow.dart` is deleted.

**Deferred to their own slices:** the bundled adapter compatibility list that
"Help me pick one" would open; the paywall, account and privacy sub-screens;
and the tab shell itself.

**What the tests cover.** `test/features/onboarding/onboarding_test.dart`
proves the four screens advance correctly, Skip finishes (★ that was the bug —
Skip must stop at the safety step; corrected 2026-09-24, see §B.20), the iOS adapter
limits are shown, the add-car form creates a primary vehicle, and the safety
acknowledgement gate works. `test/widget_test.dart` was updated to
`pumpAndSettle` through the new screen transition.

566 tests, analyzer clean.

## B.20 Adversarial review of slices 8/9, with slice 6 re-run (2026-09-24)

A review of the Settings, diagnostics-log and Onboarding slices, plus a re-run
of the Garage review now that the §9.6 identity logic is live — lenses find,
three refuters each, only a unanimous survivor counts — confirmed 23 findings,
which reduced to five clusters. All five are fixed; every fix's ★ regression
test was seen failing with its bug put back before it was trusted.

- **Garage identity (`af1e851`).** Demo Mode's connect ran the §9.6 identity
  judgement against the real garage: the recording's VIN was attached to the
  user's VIN-less car, the recording's protocol cached on it, and a demo scan
  or clear filed under their vehicle (blocker). Demo never asks now and never
  records (`NotRecording.demo`). `attached` was judged before `other`, so a
  VIN-less primary took a VIN another garage row already owned; the verdict
  outlived the link, a primary change and a late VIN read; the edit form saved
  a stale whole row over the controller's fresher one. Fixed by the
  `resolveIdentity` order, a per-connection epoch, `onDisconnected`,
  `_reconsider` on primary change, and `VehicleRepository.updateDetails` — a
  partial update that never touches `isPrimary`, `createdAt` or the connection
  cache.
- **Diagnostics log (`b39f7aa`).** The log masked only the garage primary's
  VIN, captured when the screen opened: an empty garage, a friend's car, the
  previous car still in the ring and a clone's corrupt first read (sixteen
  real characters) all showed in full, the decoded column was never masked,
  and there was no opt-in and no Share `.txt` (blocker). `ObdSession` now
  notes every VIN it decodes — pre-validation candidates included — into
  `ProtocolLog.knownVins`; both columns are masked from that set;
  `maskVinsIn` resolves every VIN's hex runs in one settled map; the screen
  carries the §10.4 "Include the VIN" opt-in and shares a `.txt` through
  `share_plus`.
- **Data & privacy (`2ef989f`).** "Delete all data" cleared SharedPreferences
  and nothing else — every row, every trip CSV and every provider's in-memory
  state survived behind a sheet that said all of it was erased (blocker).
  `EraseEverything` closes the link, wipes every table, deletes every trip
  file, clears the preferences except the Pro cache (a purchase belongs to
  the store account), empties the log, and then `TorqueApp` rebuilds the
  whole provider tree from the emptied storage by keying `MultiProvider` on a
  generation counter; a failing step stops there and the sheet says so.
  Export shared a hard-coded sample car; it now shares `BackupCodec`'s export
  of the database as a `.json` file, VINs whole, in the format import reads.
  The copy disclosed ad requests, iCloud sync and a personalised-ads switch —
  none of which exist — and said nothing about the store and RevenueCat, the
  one thing that does leave the phone (§8.3, AC-14); rewritten to what the
  code does. `EntitlementProvider` unregisters its RevenueCat listener on
  dispose, so the rebuilt tree leaves none behind.
- **Onboarding (`e002cc3`).** Skip called `finish()`, so three taps reached
  the Dashboard without the §8.4 warning — and a test asserted exactly that
  (blocker). Skip stops at the safety step; only "Agree and continue"
  finishes. The odometer was parsed with every comma stripped (`142380,5` →
  1,423,805), had no bound, and a long entry stored Infinity that the Garage
  card's `round()` threw on; it now uses `Distance.parse` (which refuses
  Infinity and NaN) with the Garage form's own limits, shows errors under the
  fields, and `Distance.display` shows the dash for a non-finite reading.
  Every save created a vehicle — a relaunch before the safety step, or a
  double tap, made a second, non-primary car past the §7.2 limit with no
  paywall; the form now prefills from and updates the existing primary, one
  save at a time. The safety checkbox's tap action sits on its Semantics node
  (a `GestureDetector` under `ExcludeSemantics` is invisible to VoiceOver and
  TalkBack); the page pads itself by the keyboard's height and a tap outside a
  field dismisses it; the copy no longer assumes an iPhone.
- **Keep screen on (`5171234`).** The preference was read by nothing.
  `ScreenWake` (`lib/platform/`, channel `ktc.torque/screen`, one method
  `setKeepAwake(bool)`): iOS sets the idle timer from the app delegate,
  Android sets `FLAG_KEEP_SCREEN_ON` on the activity window. `LiveSession`
  holds the screen only while the setting is on *and* the link is live, and
  lets go on disconnect, on the setting turning off, and on dispose; the
  platform hears only a change of answer. The Android side is written to
  `BackgroundPlugin`'s shape but was not built here (disk); the iOS build
  compiles and the app launches on the simulator.

Also fixed on the way: a flaky BUFFER FULL recovery test whose fixture
replied in 10 ms — faster than any ELM327 — so replay collapsed its RTTs to
zero and the recovery path never ran (`5a54995`); and light status-bar icons
on the Part B ground via `AnnotatedRegion` in `Backlit` (`d61ecbd`).

**Refuted or deferred, named.** Distance and temperature units still did not
reach the Dashboard gauges — the §B.17 deferral — until §B.21, the same day. The LV RESET
re-prompt is spec-consistent. "Help me pick one" still opens the coming-soon
alert (§B.19). The Industry paywall and account screens under `lib/screens/`
remain reachable from Settings and still read the old providers.

**Verification review of the fixes (same day, workflow wf_800096c7).**
Five lenses, three refuters each, over `2ef989f`, `e002cc3` and `5171234`:
23 findings, 12 survived all three refuters — six distinct defects, fixed in
the commit that follows this note, every ★ test revert-proven.

- *Blocker.* `share_plus` stages a data-backed `XFile` under the temporary
  directory and never deletes it: after Export and then "Delete all data" a
  full-VIN copy of the database was still in the sandbox, and the
  diagnostics-log share left the same. `ShareFile` (`lib/core/`) now writes
  under one app-owned directory, shares by path, deletes the file when the
  sheet returns, and `EraseEverything` sweeps the temporary directory.
- *Major.* On iPad the sheet is a popover that needs an anchor; without one
  share_plus throws, and the toast blamed the data. The row's box is the
  anchor, and a sheet failure now says it was the sheet.
- *Major.* The onboarding form hard-coded its unit to km: a relaunch showed
  a miles user their kilometres under "km", overwrote their preference on
  the way out, and tapping "mi" relabelled the figure (×1.609 stored). The
  unit is seeded from Settings; a toggle converts the figure; only an
  *edited* odometer is written (the Garage form's rule), so an untouched
  prefill keeps its exact value and date; the prefill fills only empty
  fields.
- *Minor.* `AdaptiveHaptics.enabled` survived the restart (the erase resets
  it); the delete sheet could be dismissed mid-erase (`PopScope` while
  busy); two tests certified less than they claimed (the prefill fixture
  had no make, model or odometer; the export test seeded the non-default
  VIN mask).
- *Refuted, and why.* "Free with ads" / "Remove ads" in Settings and the
  Account "Sign in" row contradict the privacy screen's "No ads … no
  account" — real, but they are the Industry paywall and account
  sub-screens §B.19 defers, and they are the next slice rather than left as
  they are. `wipe()` leaves freed SQLite pages readable with a hex editor on
  an unlocked device — real, judged outside the app's threat model; `PRAGMA
  secure_delete` is the one-line follow-up if that changes. `ScreenWake`
  assumes the platform starts released — wrong only across a Dart-only hot
  restart. The safety primer's "no location access" is false on Android
  8–11, where BLE scanning needs the location permission — copy to fix with
  the Android permission matrix.

**Lessons recorded** (also in the project memory). A bare `tester.pump()`
flushes microtasks only; the `Timer.run` drift schedules when a stream is
cancelled needs a pump *with a duration*, and `db.close()` in a tearDown
waits on that timer forever after a failed test — cap the close. A fixture
that cannot happen in the field certifies the bug it hides: at replay speed
100 any recorded latency under ~100 ms becomes a 0 ms RTT.

609 tests, analyzer clean.

## B.21 The unit toggles reach the gauges (Phase 6, slice 10 — 2026-09-24)

The §5.6 unit toggles had been stored since the app was built and read by
the Garage alone: the Dashboard showed °C and km/h whatever the user chose —
the deferral §B.17 named and every review since re-flagged.

**Where the conversion lives.** `GaugeSpec` (`lib/domain/pid_sample.dart`)
gained `UnitScale`, an affine map (°C → °F is ×1.8 + 32, km → mi is
×0.621371), and a `display` field. A spec's `unit`, `min`, `max` and normal
band are in the unit *shown*; `format`, `position` and `inRange` take the
raw sample and apply `display` first. `GaugeCatalog.specFor(distance:,
temperature:)` is the one place a spec is converted (`displayedAs`), and
only for the registry units `°C`, `km/h` and `km`. The samples on the
`PidBus` stay metric; the scheduler, the bus and the tile never learn the
unit changed — hard rule 3 is untouched. Because the map is affine, a
reading sits at the same place on the bar, the arc and the caution band in
either unit, which is the property the tests pin. The sparkline converts
its raw history points against the converted axis.

**Wiring.** `LiveDashboardTab` watches `SettingsProvider` and hands both
units to `DashboardScreen`, which passes them to the catalogue per build; a
toggle in Settings rebuilds the six specs and nothing else. The clear-codes
gate's "moving at N km/h" quotes the speed in the user's unit too
(`LiveDiagnosticsTab` → `DiagnosticsScreen(distance:)` → `ClearCodesSheet`).

**Not converted, on purpose:** pressure (kPa), flow (g/s, L/h), voltage and
percentages — §5.6 offers only distance and temperature. The Garage's
`Distance` helper is unchanged; it and `UnitScale.kmToMiles` share one
factor.

**Tests.** `test/domain/gauge_spec_units_test.dart` (the scale, the
position/band/caution invariance, the catalogue's three conversions and its
refusals), two ★ tests in `dashboard_test.dart` (°F and mph on the tiles
from metric samples; a live toggle), `live_dashboard_tab_test.dart` (the
Settings → tab wiring, the part that was missing), and an mph case for the
clear gate. Each ★ test was seen failing with its piece of the wiring
removed. 624 tests, analyzer clean.

## B.22 The freeze frame — Mode 02 on the scan and before the clear (Phase 6, slice 11 — 2026-09-24)

§5.4 lists Mode 02 as the last step of the scan, and the clear sheet has
always warned that Mode 04 "erases freeze-frame data"; nothing read it.
The freeze frame is the readings the ECU stored the moment it set its first
code — the mechanic's first question, *what was the engine doing when this
happened?* — and a clear is the one thing that destroys it.

**Protocol.** `lib/protocol/freeze_frame.dart`, pure Dart: `FreezeFrame`
(the code, the frame number, values keyed by the registry's Mode 01 ids, in
metric like a live sample) and `FreezeFrameDecoder`. A Mode 02 reply is a
Mode 01 reply with the frame number wedged in before the data — `42 <pid>
<frame> <data…>` — and a decoder that forgot that byte would read every
value one byte off and usually still land inside the PID's physical bounds:
the wrong number, confidently. `decodeValue` steps over it and hands the
registry a Mode 01-shaped payload, so the formula and bounds are the tiles'
own. `decodeDtc` reads `42 02 <frame> A B` (`00 00` is "no frame");
`decodeSupportMask` reads the Mode 02 mask; `pidsToRead` orders the PIDs a
mechanic reads (RPM, speed, coolant, load, throttle, MAP, IAT, MAF, the two
trims, voltage, run time, fuel, timing), filtered by the car's mask — or the
first eight when the ECU has no Mode 02 mask, each `NO DATA` costing one
round trip and nothing else.

**Session.** `ObdSession.readFreezeFrame()` — one PID per request (Mode 02
batching is not universal), bounded to `maxPids` + 2 round trips, null on
no frame, `NO DATA` or a replaced link. `clearDtcs` reads it after the
pre-clear Mode 03 and **before Mode 04**, and stores it in the `beforeClear`
snapshot: hard rule 8's snapshot now holds the one thing the clear
destroys.

**Data.** Schema v2: `DtcSnapshots.freezeFrameJson`, nullable; the
migration is one `addColumn`; `drift_schemas/drift_schema_v2.json` is
dumped and `test/data/schema_migration_test.dart` validates a fresh
database at v2 and a v1 device migrating to v2. `DtcSnapshotRow.freezeFrame`
reads it back tolerantly.

**Diagnostics.** The scan gained the §5.4 step "Reading the freeze frame",
after the readiness read and only when the reading has a code — a clean car
is not asked a dozen questions it answers `NO DATA` to. The frame is
recorded in the scan snapshot, shown in a "Freeze frame" section between
the codes and the monitors in the user's units through
`GaugeCatalog.specFor(distance:, temperature:)` (the same specs as the
tiles, so the number here and on a tile agree), and dropped when a reading
with no codes replaces the one it belonged to — a clear, a reconcile —
because the car has erased it and the snapshot keeps the copy. The history
row says "freeze frame at P0301"; the clear sheet's consequence now says
Torque keeps a copy.

**Traces.** `dtc_scan_can` gained the Mode 02 exchanges for P0301 — an idle
misfire while warming up: 750 rpm, 0 km/h, 50 °C, lean trims — with the
car's own mask; `clear_ok` gained the same frame but answers `NO DATA` to
the Mode 02 mask, so the fallback eight are exercised. Every other trace
answers `NO DATA` to Mode 02 through the mock, which reads as "no frame".

**Tests.** `test/protocol/freeze_frame_test.dart` (★ the frame byte is
stepped over — read as data, 750 rpm becomes 2.75), `test/session/
freeze_frame_session_test.dart` (★ the frame off the recording; ★ it is in
the `beforeClear` row and every Mode 02 command precedes `04` in what went
over the wire; the after row has none; a round trip through the row), the
★ v1 → v2 schema step, and three Diagnostics widget tests (★ the section;
the units; a clean car). Each ★ test was seen failing with its piece
removed. 648 tests, analyzer clean.

## B.23 The tab shell on Part B (Phase 6, slice 12 — 2026-09-24)

The last piece of Industry chrome sat under every rebuilt screen: the light
`AppTabBar`, a light strip under the status bar and the home indicator, and
the debug `DevPanel` strip, all drawn on the root `Material(color: T.bg)`.

`AppShell` (`lib/app.dart`) now uses the design system's `AdaptiveTabBar`
— `CupertinoTabBar` on iOS, `NavigationBar` on Android, tab change
`Duration.zero` on both — on the Part B ground, which runs under the
status bar and the home indicator so the screens sit on one dark surface.
The status-bar icons are claimed light at the shell, where the box under
them is (the lesson of `d61ecbd`: `AnnotatedRegion` covers only its own
box). `Backlit` wraps only the chrome: a route pushed inside a tab keeps
the root theme, which the remaining Industry sub-screens (paywall,
account) are drawn against, so nothing they render changed. The five
tabs are named once, in `AppShell.tabs`.

The `DevPanel` is deleted, not hidden: every control on it drove the old
`ConnectionProvider`/`DashboardProvider` stack, which none of the Part B
tabs read — a debug strip whose buttons did nothing visible was worse
than none. Demo Mode is what reaches every state without hardware now
(§11.1, §B.14).

**Tests.** `test/app_shell_test.dart`: the shell opens on the Dashboard
with the Part B bar and no Industry chrome, claims the status bar light,
and switches tabs without an animation while keeping the others alive
(offstage in the `IndexedStack`). 651 tests, analyzer clean.

## B.24 The paywall on Part B; no account, no ads (Phase 6, slice 13 — 2026-09-24)

The verification review in §B.20 refuted, as a named deferral, that the
Settings rows "Free with ads" / "Remove ads" and "Account › Sign in"
contradicted the privacy screen. They did, and they contradicted the spec:
§7.2's free tier is limit-based and names no ads, the code has never had an
ad SDK, and §8.3 says "No account" — the Industry account flow signed
anyone in as a hard-coded stranger. This slice replaces the one and deletes
the other.

**The paywall** (`lib/features/pro/paywall_screen.dart`, `openProPaywall`).
§7.2 row for row, with the hard rule stated above the table in words —
"Reading and clearing codes: free on both stores, always." The plans are
`EntitlementProvider`'s: the store's prices when RevenueCat is configured,
the spec's fallback prices when not; weekly (with the 3-day trial),
monthly, lifetime — the products §7.1 defines. §7.4's *recommendation* of
an annual plan in place of monthly is a product decision that has not been
taken; the paywall sells what the config defines and nothing it does not.
§7.5's outcomes are each told as they happened: success grants and says so,
pending is neither granted nor an error, cancelled is nothing, failed says
nothing was charged. Restore says when there was nothing to restore. Pro
users see the table and "Manage subscription". The legal line names the
one thing that does leave the phone — the store and RevenueCat, an
anonymous ID and the purchase — consistent with the privacy screen.

**Where it opens** (§7.3, contextual only): Settings › "Go Pro"; the
Garage's "Add a vehicle" alert on the free plan now offers "See Pro" beside
"Not now"; the §9.6 identity sheet's locked second-vehicle answer offers it
too, without closing the question. `LiveGarageTab` and `LiveIdentityPrompt`
pass `onUpgrade`; nothing in `lib/features/garage/` imports the paywall.

**Deleted, not restyled.** `AccountProvider`, `AccountStatus`, the account
preference keys, and `lib/screens/account/`; the Industry paywall and
`ad_screens.dart`; `AdState`, `AdBanner`, and every ad method on
`EntitlementProvider` (`canShowBanner`, `rewardedOffered`,
`continueFreeWithAds`, …); `lib/screens/system/system_screens.dart` (its
sync-conflict screen read the account) and the Industry
`lib/screens/dashboard/dashboard_screen.dart` (unreachable since §B.14; it
drew the banner). Settings has no Account section; its subscription rows
say "Torque Free — 6 gauges · 1 vehicle · 2-minute recordings" or "Torque
Pro — Unlimited gauges, vehicles and recording". The one Industry
sub-screen left is Data & privacy.

**Tests.** `test/features/pro/paywall_screen_test.dart` (★ §7.2 with
nothing about ads or an app account; the three plans at the provider's
prices; choosing a plan; ★ buying grants Pro; not now; restore with nothing
behind it; already Pro; text scale 2.0 at 320 pt); two ★ door tests in
`garage_test.dart` (the alert and the identity answer call `onUpgrade`);
the settings test's sections without Account; the ad-placement tests are
gone with the code. Each ★ test seen failing with its piece removed. 667
tests, analyzer clean.

## B.25 Data & privacy on Part B — no Industry sub-screen remains (Phase 6, slice 14 — 2026-09-24)

The last screen a Part B tab pushed from the Industry stack.
`lib/features/settings/privacy_screen.dart` replaces
`lib/screens/settings/privacy_screen.dart`, word for word in its claims
(§B.20 fixed the words; this slice only moves them onto the design system):
`Backlit`, `AdaptiveTopBar`, and the rows Settings itself is made of, lifted
into `settings_rows.dart` as `SettingsSection` and `SettingsLinkRow` (which
gained a subtitle line and a destructive tone) so the two screens cannot
drift apart.

"Delete all data" is now a design-system sheet: the consequences named in
the amber tell, then a **two-step `DestructiveButton`** (B.5: arm, then
"Tap again to delete everything"), a Cancel, and no backdrop dismissal —
the sheet is `dismissible: false`, and `PopScope` refuses Android back
while the erase runs, for the reason §B.20 gave. Failures are alerts on the
screen underneath, not toasts: Part B has no toast, and the Industry one is
gone with its screen.

What is left under `lib/screens/` is unreachable reference code for the
Garage sub-screens and the old dashboard's grid editing (§B.14's "still to
do"); nothing in `lib/features/` or `lib/app.dart` imports it.

**Tests.** The privacy tests in `erase_everything_test.dart` run unchanged
in what they assert — export contents, the claims on screen, the sheet that
cannot be dismissed while erasing — with the two-tap confirmation. That
sheet has two independent guards, the route's `dismissible: false` and the
`PopScope` while busy, and either alone satisfies the test: removing one
still passes, removing both fails, which is what was run to prove it. 667
tests, analyzer clean.

## B.26 Adversarial review of slices 10–14 (2026-09-25)

Six lenses (units, freeze frame, shell, paywall, privacy, test quality),
three refuters each, over `62aad70`…`2bb652d`: 32 findings, 22 survived all
three refuters — about nineteen distinct defects after duplicates, two of them
blockers. All are fixed, in five commits; every ★ test was seen failing with
its fix removed (the harness keeps the file in memory and restores it — a
shell loop that did not word-split restored nothing once).

- **Freeze frame (`9048222`).** *Blocker:* a link that dropped during the
  pre-clear frame read made `readFreezeFrame` return null — the same as "no
  frame" — and `clearDtcs` went on to write the snapshot without it and send
  Mode 04 through the ElmSession it had captured, which, disposed, still wrote
  to the transport the ladder had just reused: the car erased the frame, on a
  conversation the clear was not part of. `clearDtcs` now checks the link after
  every await; a disposed ElmSession writes nothing. The screens said a copy was
  kept when nothing is recorded; they now say so only when
  `DiagnosticsController.recording`, and a history snapshot opens its frame
  (`FreezeFrameView`). A frame lives only while its own code is stored or
  pending. Every Mode 02 mask is walked, so fuel and module voltage are read.
  §B.22's "hard rule 8's snapshot now holds the one thing the clear destroys"
  is true from this commit, not the one it was written for.
- **Units (`73033c6`).** The health breakdown's coolant line is said in the
  user's unit; a reading that rounds to zero prints "0", never "-0".
- **Shell (`d97f1d0`).** Back used `pop` and a re-tapped tab `popUntil`, both
  deaf to a route's PopScope, so the Delete-all sheet could be taken away mid-
  erase; back now uses `maybePop`, the re-tap stops at a route that refuses,
  and the sheet opens on the root navigator. Back at a tab root goes to the
  Dashboard, then out. Tab labels no longer grow with text size (CupertinoTabBar
  overflowed at 2.0; even Android's own 1.3 wraps at 390 pt) and are Barlow on
  iOS; EmptyStateView scrolls when it is a screen's body. Backlit answers high
  contrast itself. §B.23's "a route pushed inside a tab keeps the root theme"
  was false — every tab is under LiveIdentityPrompt's Backlit — and its test
  asserted nothing that could fail; both corrected.
- **Paywall (`ef3c111`).** *Blocker:* Android could not buy — one
  `getProducts` call (subscriptions only, so no lifetime) and plain-id matching
  against Play's `{subscription}:{basePlan}`. Both categories are asked for and
  matched by prefix (`RevenueCatService.planFor`, pure and tested). Plans reload
  when the paywall opens or a buy finds no product, and the paywall says when
  its prices are not the store's. The "3-day free trial" is claimed only when
  the store offers one to this user. The identity sheet follows the entitlement
  live. §B.24's table was not "row for row"; it is now the spec's thirteen.
- **Rows, onboarding, iPad (`655515d`).** Tapless rows are statements, not
  disabled controls (VoiceOver read the privacy facts as "dimmed", at 3.97:1);
  the three private row widgets became the design system's `ListRow`. An edited
  odometer survives a unit toggle. The iPad share anchor is clipped to the
  screen.

**Refuted, and what was still done.** A multi-ECU car whose ECU without a
frame answers 0202 first (not shown reachable); Mode 02 masks in the fixture
naming PIDs it never answers (fixture only); an offline grace that never
expires (the configured SDK does not return null there); several test-quality
notes that named no user-visible defect. One refuted as a blocker was still
true and was fixed as copy: the phone's own backup to iCloud or Google holds
the app's data, so "stored on this device and nowhere else" and "nothing is
deleted anywhere else" now name it.

**Not testable here, named.** That `plans()` really asks both product
categories needs a configured store key; the id matching it feeds is tested.

725 tests, analyzer clean.

## B.27 The Garage's logs — maintenance, reminders, fuel (Phase 6, slice 15 — 2026-09-25)

§B.16 gave the Garage a `GarageLinks` slot for each log and offered none. Three
now exist, each over the Drift stream for the primary vehicle, opened from the
Garage tab with the user's distance unit, currency and plan (`LiveGarageTab`
reads the providers; the screens take plain values).

**Maintenance log** (`maintenance_screen.dart`). Records newest first; the
form takes the kind, what was done (1–200, the table's own limit), a date no
later than today, the odometer (`Distance.parse`, 0–2,000,000 km, the vehicle
form's bound), a cost (`Money.parse`: comma or point decimals, a sanity bound),
where, and notes (≤ 5,000). An edit writes the row as it is on disk with only
the form's fields changed, so linked codes and attachments survive. A reading
higher than the car's is the newest reading there is and moves the vehicle's
odometer — which reminders due by distance are judged against. §7.2's ten
records on the free plan: the eleventh is a §7.3 door (the alert's "See Pro"),
and the ten already there stay readable, editable and deletable (§7.5).

**Reminders** (`reminders_screen.dart`). The thirteen §5.5 intervals as
presets (`ServicePreset`; "plugs 40,000/100,000" is two, copper and long-life;
the timing belt is critical), each with "Check your owner's manual — intervals
vary by vehicle." on the picker and on the form. From a preset the next due
date is today plus the interval and the next reading the car's plus the
interval, both editable; a reminder needs something to be due by, or it is
refused with the reason. Months are stored as days of an average month, so "6
months" round-trips as 6. The list runs overdue, due soon (a month or 1,000
km), coming up, paused, done — the status always a word, the tone red for an
overdue critical one. Mark as done rolls a repeating reminder forward from
today and the current reading (the repository's rule). `reminderStatus` is the
one overdue rule, now also behind `GarageController.overdueCount`, so the card,
the list and the health score's −5 each cannot disagree.

**Fuel log** (`fuel_log_screen.dart`). §5.5's economy between full fill-ups
only, as a pure `FuelSummary` in the repository (which `economy()` now calls):
a span runs from one full tank to the next, the part fills in between counted
into it; a part fill has no figure of its own and the first full tank has none,
and each row says which. The average is weighted by distance, not by fill-up.
Miles users see both US and UK mpg — the app does not know which gallon they
mean. A reading lower than one already logged is a caution ("fine if this is an
older receipt"), not a refusal. An electric car has no fuel log; a hybrid does.

**Design system.** `ListRow`/`ListSection` (§B.26), `LabelledField`,
`ChoiceChips` and `LabelledDateField` — the three screens and their forms are
built from these alone. `ServiceRepository` gained `updateReminder` and
`updateFuel`.

**Deferred, named.** Local notifications for reminders (§5.5 "local
notifications only") need a notifications plugin and the permission flow;
until then a reminder is shown, not pinged. Attachments and receipts on a
record, linking a record to a code from the Diagnostics screen, trip
recordings and reports (the last two slots stay empty). The vehicle form still
has its own private field widget; moving it onto `LabelledField` is mechanical
and left for the next Garage slice.

**Tests.** `test/features/garage/service_intervals_test.dart` (the rule, the
presets, money, economy), `garage_logs_test.dart` (each screen and form on a
real in-memory database), `live_garage_tab_test.dart` (the wiring, the
currency, the electric car). Each ★ test seen failing with its piece removed.
728 tests, analyzer clean.

**On the simulator** (iPhone 17 Pro, iOS; a vehicle, an Oil reminder from the
preset, a service record, two full tanks). Everything computed what it should
— the preset's 152,380 km and 27 Mar 2027, the record moving the car to
150,100 and the reminder to "Due in 2,280 km", 6.3 L/100 km over 600 km — and
four things only a screen showed were fixed:

- **`ListRow` put a value mid-row.** `Expanded(title)` beside `Flexible(value)`
  split the row in two, so "0 scans ›" and "None overdue ›" sat in the middle
  and a reminder's subtitle wrapped in half the width. The value now takes its
  own width, up to 45% of *the row* (a `LayoutBuilder`, not the screen — a
  sheet can be narrower), and the title the rest.
- **`ValueList` put a value beside its label.** Two `Flexible`s each held half
  the row and both packed left: "Petrol" sat just after "Fuel", and a VIN or
  "ISO 15765-4 CAN 11-bit 500k" beside a short label wrapped mid-word in half
  the width it had. The label keeps its own width up to half the row; the
  value takes the rest, flush right. The `value_list` and `connect_connected`
  goldens had recorded the old layout and are regenerated — a golden taken of
  a bug certifies it.
- **The date sat 4 pt left of the fields above it.** A filled `TextField`
  adds 4 inside its `contentPadding` (Flutter's `_kInputExtraPadding`); the
  date box had the same 12 and no such gap. It is 16 now, and the test
  compares the two rendered insets rather than either number.
- **The fill-up's reading hint was an example, "142380".** Grey, in a
  required field, below a car that read 150,100, it looked like a reading the
  app believed. It is the car's reading now ("Now 150,100"), from the garage
  rather than the screen's copy of the vehicle, as the reminder form does.

Not changed, for a decision: a logged "Oil and filter" service does not mark
the Oil reminder done — §5.5 does not link the two, and matching them by title
would be a guess. Golden-diff images (`**/failures/*.png`, four committed in
slice 3) are ignored now. 734 tests, analyzer clean.

## B.28 Adversarial review of slice 15 (2026-09-25)

Seven lenses (maintenance, reminders, fuel, design system, wiring, data, test
quality), three refuters each, over `eb55bdf`…`defe0cb`: 38 findings, 25
survived all three — fifteen distinct defects after duplicates. The run was cut
short by a session limit once and resumed from its journal. Two more came from
the first, interrupted run and were proven by a failing test instead of the
refuters: a preset's interval edited on the form left the first due point at
the default, and a 240-month interval saved a date past the picker's range.
Every ★ test was seen failing with its fix removed (33 reverts; the four about
dates under `TZ=America/New_York` or `Europe/London`, where they show), and the
suite passes in four zones (Karachi, New York, London, Auckland).

- **Open screens held stale values.** *Blocker:* `_links` read the plan once;
  a user who bought Pro through the maintenance log's own §7.3 door met the
  cap again on the same screen. The unit and currency were read once too, and
  each log re-read `garage.primary` whenever it rebuilt, so it could become
  another car's while a form already open still wrote to the first. The links
  now take the vehicle their row was tapped for (`VehicleScreenBuilder`) and
  read the providers in the route's own context. A form keeps the unit it
  opened with — what is typed in it is in that unit.
- **Dates are calendar days.** A date with no time was stored as an instant
  (local midnight), so a reminder was overdue from 00:00 on its own due date
  (and cost the health score its −5 that day), "today" was said the day
  before, every countdown was a day short, a preset added across a DST change
  was due a day early, and every date read back a day early once the phone
  moved west. New dates are UTC midnight of the day (`calendarDay`); `dayOf`
  reads either kind — a row written before as local midnight still reads as
  the day picked — and `addDays`/`daysBetween` count on the calendar.
  `reminderStatus` compares days: due today is due soon ("Due today"), overdue
  from the day after. A completed reminder rolls forward by calendar days.
  `pickDay` wraps the adaptive picker, which now widens its range to include
  the date it opens on.
- **Reminders.** A km-only interval on a car with no reading was saved with
  nothing to be due by and could never be due — nine presets, the critical
  timing belt among them; it is refused with the reason, and "Next due at"
  says it is needed. A reminder due by both distance and date always gave the
  distance ("Due soon in 8,000 km" when the date was ten days off); due soon
  now names the trigger that is close, coming up names both. Editing a done
  reminder's due point or interval sets it again — kept as done, the edit was
  saved and could never show. A new reminder's first due point follows its
  interval until the user sets it. The Garage card's overdue count was keyed on
  nothing that changes with the day; it is keyed on the day too, and re-read
  on resume and on return from a log.
- **Fuel.** A part fill and the full tank after it, at one reading on one day,
  sorted by insertion — newest first — and the full tank's span got the wrong
  litres (1.0 L/100 km for 7.0); a part fill now sorts first. A second full
  tank at the same reading is a top-up whose litres go forward, not away. Each
  entry has a `FuelSpanRole`, so a part fill before the first full tank says it
  is not counted instead of claiming it is.
- **Numbers as typed.** `Money.parse` read `1.234,56` as 1.23456 and saved it
  without an error; `Distance.parse` read `142.380,5` as 142.38. Both go
  through `parseTypedNumber`: with both marks the last is the decimal point;
  one mark more than once groups (lakh grouping `1,23,456` included); one mark
  before exactly three digits groups for money and readings and is a decimal
  point for litres, which a pump shows to three places. An edit that leaves a
  field untouched saves the stored value, not its rounding: 150,000 km shown as
  93,206 mi came back as 150,000.5 km, moved the car and stamped it as read
  today.
- **Currency.** Every install started in pounds and no screen offered another.
  Settings has a Currency row (ten currencies: the stores' three and those of
  §10.2's markets); the default is the phone's region, from our own table —
  `intl` gives `en_PK` dollars and `ar_AE` Egyptian pounds.
- **Accessibility.** Two `LabelledField`s side by side merged their labels into
  one static node and left each field named by its hint; each field is one
  merged node now. A toned `ListRow` value draws its glyph (hard rule 11). A
  date field said its label twice. A field near its `maxLength` shows its count
  (§9.8 "with a counter") rather than cutting a pasted note without a word.

**Refuted, and done anyway.** A reading far above the car's (a typo of
1,501,000) moves the car's odometer for good — §B.27 allows it, and the vehicle
form can set it back — so it is now a caution past 50,000 km. The empty date
field's "No date" was tertiary on the panel (2.93:1); it is the hint ink the
text fields use. A higher reading from an old receipt is stamped with the
receipt's day, not now (`GarageController.noteReading`, shared by both forms).

**Refuted, not changed.** The owner's-manual line is on the preset picker and
the form a preset opens, not on a later edit of it (§5.5 is about the default
interval shown). The test-quality findings (single-span economy tests, a
currency test that checked a field, the preset test's "and nothing it does
not") described tests that could miss a future bug in code that is right.

**For a decision, not a defect.** §7.2's ten free records are counted per
vehicle; the free plan has one vehicle, so the two readings differ only for a
garage that was Pro and lapsed (two refuters of three called it policy). A
logged service still does not mark its reminder done (§B.27).

## HARD RULES

1. `lib/protocol/` imports nothing from `package:flutter`. Ever.
2. Exactly one outstanding ELM327 command at a time. No pipelining.
3. Live PID data **never** goes through a Riverpod provider that widgets watch. One `ValueNotifier` per PID, `ValueListenableBuilder` around the smallest subtree, `RepaintBoundary` per tile, `const` chrome.
4. Never render a stale value as if it were live. Staleness is a visual state.
5. `double?` everywhere. Zero is a value; null is absence. No sentinels.
6. Reject out-of-physical-bounds samples at the parser, before the UI.
7. Never fabricate a DTC definition. Unknown codes say they are unknown.
8. Always write a `DtcSnapshot` before Mode 04, and always re-read after.
9. Never poll while backgrounded unless a trip recording is active.
10. Reading and clearing DTCs are free features on both stores.
11. Colour never carries meaning alone — always pair with a glyph and a word.
12. Every `Platform.isIOS`/`isAndroid` branch lives in `design_system/` or `core/platform/`.
