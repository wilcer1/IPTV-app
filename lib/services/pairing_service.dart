import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../models/xtream_credentials.dart';

// Lets an already-signed-in device ("sender") hand its Xtream credentials to
// a fresh one ("receiver", typically a TV) over the local network, so the
// receiver never has to have its host/username/password typed in via a
// remote control. Threat model: a trusted home LAN, not a hostile network —
// there is no backend, so an attacker who can already sniff and inject
// traffic on the same LAN is out of scope.
//
// Wire protocol, once the sender has discovered the receiver:
//   1. receiver -> sender: {"nonce": <base64, 16 random bytes>}
//   2. sender -> receiver: {"proof": <base64 HMAC-SHA256(key, nonce)>}
//   3. receiver checks the proof against its own copy of the code. On
//      mismatch it just closes the socket (no error detail, to avoid
//      helping an online guesser). On match: {"proofOk": true}
//   4. sender -> receiver: {"nonce": <base64 AES-GCM nonce>,
//                           "cipherText": <base64>, "mac": <base64>}
//      — the encrypted JSON-encoded credentials.
//   5. receiver decrypts, tries to authenticate against the Xtream API, and
//      replies {"status": "ok"} or {"status": "error", "message": ...}.
// Each line is newline-delimited JSON (TCP is a byte stream, not messages).
//
// The key for both the HMAC proof and the AES-GCM payload is
// SHA-256(normalized code) — nothing code-derived is ever put on the wire
// unencrypted, so passively sniffing the UDP discovery broadcast reveals
// nothing that can be brute-forced offline.

const _discoveryPort = 47601;
const _magic = 'iptv-app-pair-v1';
const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I

class PairingException implements Exception {
  final String message;
  PairingException(this.message);

  @override
  String toString() => message;
}

String generatePairingCode({int length = 8}) {
  final random = Random.secure();
  return List.generate(
    length,
    (_) => _codeAlphabet[random.nextInt(_codeAlphabet.length)],
  ).join();
}

String _normalizeCode(String code) {
  return code.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}

Future<SecretKey> _deriveKey(String code) async {
  final digest = await Sha256().hash(utf8.encode(_normalizeCode(code)));
  return SecretKey(digest.bytes);
}

bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

class _LineSocket {
  final Socket socket;
  final _buffer = BytesBuilder();
  // Broadcast because readJson() below calls .stream.first on every read —
  // a plain single-subscription controller can only ever be listened to
  // once, so the second readJson() call in any exchange would throw "Stream
  // has already been listened to." Safe here since the protocol is strict
  // ping-pong (write, then immediately await the next line) with no gap
  // where a line could arrive before something is listening for it.
  final _lines = StreamController<String>.broadcast();
  late final StreamSubscription<List<int>> _sub;

  _LineSocket(this.socket) {
    _sub = socket.listen(
      (chunk) {
        _buffer.add(chunk);
        var bytes = _buffer.toBytes();
        var newlineIndex = bytes.indexOf(10);
        while (newlineIndex != -1) {
          final line = utf8.decode(bytes.sublist(0, newlineIndex));
          _lines.add(line);
          bytes = bytes.sublist(newlineIndex + 1);
          newlineIndex = bytes.indexOf(10);
        }
        _buffer.clear();
        _buffer.add(bytes);
      },
      onDone: () => _lines.close(),
      onError: (Object e) => _lines.close(),
      cancelOnError: true,
    );
  }

  void writeJson(Map<String, dynamic> message) {
    socket.add(utf8.encode('${jsonEncode(message)}\n'));
  }

  Future<Map<String, dynamic>> readJson({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final line = await _lines.stream.first.timeout(timeout);
    return jsonDecode(line) as Map<String, dynamic>;
  }

  Future<void> close() async {
    await _sub.cancel();
    await _lines.close();
    await socket.close();
  }
}

/// Runs on the device that doesn't have credentials yet (e.g. a TV). Shows a
/// code, then waits for a sender on the LAN to hand over credentials.
class PairingReceiver {
  ServerSocket? _server;
  RawDatagramSocket? _udp;
  Timer? _announceTimer;
  bool _disposed = false;

  Future<XtreamCredentials> listen(
    String code, {
    Duration timeout = const Duration(minutes: 3),
  }) async {
    final key = await _deriveKey(code);
    final normalized = _normalizeCode(code);

    _server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    _udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _discoveryPort, reuseAddress: true);
    _udp!.broadcastEnabled = true;

    // The global limited-broadcast address (255.255.255.255) isn't reliably
    // forwarded between Wi-Fi and Ethernet by every router (mesh systems and
    // ones with AP/client isolation are especially prone to dropping it), so
    // also send a subnet-directed broadcast (e.g. 192.168.1.255) for every
    // local interface — that address tends to survive where the global one
    // doesn't.
    final targets = await _broadcastTargets();

    final completer = Completer<XtreamCredentials>();

    final subscription = _server!.listen((socket) {
      _handleConnection(socket, normalized, key).then((creds) {
        if (creds != null && !completer.isCompleted) {
          completer.complete(creds);
        }
      });
    });

    _announceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final packet = utf8.encode(jsonEncode({'magic': _magic, 'port': _server!.port}));
      for (final target in targets) {
        try {
          _udp!.send(packet, target, _discoveryPort);
        } catch (_) {
          // Best-effort; some networks briefly reject broadcast sends.
        }
      }
    });

    final timeoutTimer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(PairingException('No device connected in time.'));
      }
    });

    try {
      return await completer.future;
    } finally {
      timeoutTimer.cancel();
      await subscription.cancel();
      await dispose();
    }
  }

  Future<XtreamCredentials?> _handleConnection(
    Socket socket,
    String normalizedCode,
    SecretKey key,
  ) async {
    final line = _LineSocket(socket);
    try {
      final nonce = List<int>.generate(16, (_) => Random.secure().nextInt(256));
      line.writeJson({'nonce': base64Encode(nonce)});

      final proofMessage = await line.readJson();
      final expectedMac = await Hmac.sha256().calculateMac(nonce, secretKey: key);
      final givenProof = base64Decode(proofMessage['proof'] as String);
      if (!_constantTimeEquals(expectedMac.bytes, givenProof)) {
        await line.close();
        return null;
      }
      line.writeJson({'proofOk': true});

      final payload = await line.readJson(timeout: const Duration(seconds: 15));
      final secretBox = SecretBox(
        base64Decode(payload['cipherText'] as String),
        nonce: base64Decode(payload['nonce'] as String),
        mac: Mac(base64Decode(payload['mac'] as String)),
      );
      final plaintext = await AesGcm.with256bits().decrypt(secretBox, secretKey: key);
      final json = jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
      final credentials = XtreamCredentials(
        host: json['host'] as String,
        username: json['username'] as String,
        password: json['password'] as String,
      );

      line.writeJson({'status': 'ok'});
      await line.close();
      return credentials;
    } catch (e) {
      try {
        line.writeJson({'status': 'error', 'message': e.toString()});
      } catch (_) {}
      await line.close();
      return null;
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _announceTimer?.cancel();
    _udp?.close();
    await _server?.close();
  }

  Future<List<InternetAddress>> _broadcastTargets() async {
    final targets = <InternetAddress>{InternetAddress('255.255.255.255')};
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          // Assumes a /24 subnet, true for the overwhelming majority of home
          // routers; not exact for other subnet sizes but a safe extra try.
          final parts = addr.address.split('.');
          if (parts.length == 4) {
            targets.add(InternetAddress('${parts[0]}.${parts[1]}.${parts[2]}.255'));
          }
        }
      }
    } catch (_) {
      // Best-effort; fall back to just the global broadcast address.
    }
    return targets.toList();
  }
}

/// Runs on the device that already has working credentials. Discovers a
/// receiver advertising itself on the LAN and sends it the credentials once
/// both sides have proven they know the same pairing code.
class PairingSender {
  Future<void> send(
    String code,
    XtreamCredentials credentials, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final key = await _deriveKey(code);
    final normalized = _normalizeCode(code);
    if (normalized.isEmpty) {
      throw PairingException('Enter the code shown on the other device.');
    }

    final udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _discoveryPort, reuseAddress: true);
    // On Windows, a socket won't receive broadcast/subnet-broadcast
    // datagrams at all unless SO_BROADCAST is set — confirmed by direct
    // testing, not just a documentation assumption. Unlike typical POSIX
    // behavior (where this flag only gates sending), Windows also gates
    // receiving on it.
    udp.broadcastEnabled = true;
    final tried = <String>{};
    final deadline = DateTime.now().add(timeout);
    StreamSubscription<RawSocketEvent>? sub;

    try {
      final completer = Completer<void>();

      sub = udp.listen((event) async {
        if (event != RawSocketEvent.read) return;
        final datagram = udp.receive();
        if (datagram == null) return;
        Map<String, dynamic> announcement;
        try {
          announcement = jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
        } catch (_) {
          return;
        }
        if (announcement['magic'] != _magic) return;
        final port = announcement['port'] as int?;
        if (port == null) return;

        final candidateKey = '${datagram.address.address}:$port';
        if (!tried.add(candidateKey)) return;

        try {
          await _attempt(datagram.address, port, normalized, key, credentials);
          if (!completer.isCompleted) completer.complete();
        } catch (e) {
          tried.remove(candidateKey);
          if (DateTime.now().isAfter(deadline) && !completer.isCompleted) {
            completer.completeError(e);
          }
        }
      });

      final remaining = deadline.difference(DateTime.now());
      await completer.future.timeout(
        remaining.isNegative ? Duration.zero : remaining,
        onTimeout: () => throw PairingException(
          tried.isEmpty
              ? 'No device found on the network. Make sure both devices are on the same Wi-Fi.'
              : 'Could not pair — check the code and try again.',
        ),
      );
    } finally {
      await sub?.cancel();
      udp.close();
    }
  }

  Future<void> _attempt(
    InternetAddress address,
    int port,
    String normalizedCode,
    SecretKey key,
    XtreamCredentials credentials,
  ) async {
    final socket = await Socket.connect(address, port, timeout: const Duration(seconds: 5));
    final line = _LineSocket(socket);
    try {
      final challenge = await line.readJson();
      final nonce = base64Decode(challenge['nonce'] as String);
      final proof = await Hmac.sha256().calculateMac(nonce, secretKey: key);
      line.writeJson({'proof': base64Encode(proof.bytes)});

      final proofResponse = await line.readJson();
      if (proofResponse['proofOk'] != true) {
        throw PairingException('The other device rejected the code.');
      }

      final plaintext = utf8.encode(jsonEncode({
        'host': credentials.host,
        'username': credentials.username,
        'password': credentials.password,
      }));
      final secretBox = await AesGcm.with256bits().encrypt(plaintext, secretKey: key);
      line.writeJson({
        'nonce': base64Encode(secretBox.nonce),
        'cipherText': base64Encode(secretBox.cipherText),
        'mac': base64Encode(secretBox.mac.bytes),
      });

      final result = await line.readJson(timeout: const Duration(seconds: 15));
      if (result['status'] != 'ok') {
        throw PairingException((result['message'] as String?) ?? 'Pairing failed.');
      }
    } finally {
      await line.close();
    }
  }
}
