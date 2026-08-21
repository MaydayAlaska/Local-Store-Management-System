import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

typedef InstanceActivationHandler = FutureOr<void> Function();

class SingleInstanceGuard {
  SingleInstanceGuard._(
    this._server,
    this._instanceKey,
    this._onActivate,
  ) {
    _subscription = _server.listen(_handleClient);
  }

  static final Set<SingleInstanceGuard> _activeGuards = <SingleInstanceGuard>{};

  static const int _candidateCount = 6;
  static const int _minimumPort = 49152;
  static const int _maximumPort = 65535;
  static const Duration _connectTimeout = Duration(milliseconds: 250);
  static const Duration _responseTimeout = Duration(milliseconds: 500);
  static const String _protocol = 'LSMS_SINGLE_INSTANCE_V2';

  final ServerSocket _server;
  final String _instanceKey;
  final InstanceActivationHandler? _onActivate;
  late final StreamSubscription<Socket> _subscription;
  bool _closed = false;

  static Future<SingleInstanceGuard?> tryAcquire(
    String dataDirectory, {
    InstanceActivationHandler? onActivate,
  }) async {
    final instanceKey = _instanceKeyFor(dataDirectory);

    for (final port in _candidatePorts(instanceKey)) {
      try {
        final server = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          port,
          shared: false,
        );
        final guard = SingleInstanceGuard._(
          server,
          instanceKey,
          onActivate,
        );
        _activeGuards.add(guard);
        return guard;
      } on SocketException {
        if (await _activateExistingInstance(port, instanceKey)) {
          return null;
        }
      }
    }

    throw StateError(
      'Impossibile riservare il canale locale usato per garantire '
      "un'unica istanza dell'applicazione.",
    );
  }

  static Iterable<int> _candidatePorts(String instanceKey) sync* {
    final seed = int.parse(instanceKey, radix: 16);
    final availableSpan =
        (_maximumPort - _minimumPort + 1) - _candidateCount;
    final firstPort = _minimumPort + (seed % availableSpan);
    for (var offset = 0; offset < _candidateCount; offset++) {
      yield firstPort + offset;
    }
  }

  static String _instanceKeyFor(String dataDirectory) {
    var normalized = p.normalize(p.absolute(dataDirectory));
    if (Platform.isWindows) {
      normalized = normalized.toLowerCase();
    }

    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(normalized)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static Future<bool> _activateExistingInstance(
    int port,
    String instanceKey,
  ) async {
    for (var attempt = 0; attempt < 4; attempt++) {
      Socket? socket;
      try {
        socket = await Socket.connect(
          InternetAddress.loopbackIPv4,
          port,
          timeout: _connectTimeout,
        );
        final response = socket
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .first
            .timeout(_responseTimeout);

        socket.writeln('$_protocol ACTIVATE $instanceKey');
        await socket.flush();

        if (await response == '$_protocol OK $instanceKey') {
          return true;
        }
        return false;
      } on SocketException {
        // La porta può essere stata occupata da un altro processo proprio
        // durante l'avvio. Riproviamo brevemente prima di considerarla estranea.
      } on TimeoutException {
        return false;
      } finally {
        socket?.destroy();
      }

      await Future<void>.delayed(const Duration(milliseconds: 75));
    }
    return false;
  }

  void _handleClient(Socket socket) {
    unawaited(_handleClientAsync(socket));
  }

  Future<void> _handleClientAsync(Socket socket) async {
    try {
      final request = await socket
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(_responseTimeout);

      if (request != '$_protocol ACTIVATE $_instanceKey') {
        return;
      }

      socket.writeln('$_protocol OK $_instanceKey');
      await socket.flush();

      final handler = _onActivate;
      if (handler != null) {
        try {
          await handler();
        } catch (_) {
          // L'istanza primaria resta valida anche se il focus della finestra
          // non è disponibile in questo preciso momento.
        }
      }
    } on SocketException {
      // Connessione locale interrotta: nessuna azione necessaria.
    } on TimeoutException {
      // Richiesta incompleta/non appartenente all'applicazione.
    } finally {
      socket.destroy();
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _activeGuards.remove(this);
    await _subscription.cancel();
    await _server.close();
  }
}
