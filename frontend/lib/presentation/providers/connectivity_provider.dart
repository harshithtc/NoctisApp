import 'dart:async';
import 'dart:io' show InternetAddress;
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Connectivity provider:
/// - compatibility with connectivity_plus 6.x (list-based onConnectivityChanged)
/// - optional internet reachability probing via DNS
/// - debounced state updates to minimize rebuilds
/// - broadcast stream for external listeners
class ConnectivityProvider with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;
  ConnectivityResult _lastResult = ConnectivityResult.none;

  Timer? _debounceTimer;
  Duration debounce = const Duration(milliseconds: 250);

  bool probeInternet = true;
  Duration probeTimeout = const Duration(seconds: 2);

  final _statusController = StreamController<bool>.broadcast();

  bool get isOnline => _isOnline;
  ConnectivityResult get connectionType => _lastResult;
  Stream<bool> get statusStream => _statusController.stream;

  ConnectivityProvider({
    bool? probeInternet,
    Duration? probeTimeout,
    Duration? debounce,
  }) {
    if (probeInternet != null) this.probeInternet = probeInternet;
    if (probeTimeout != null) this.probeTimeout = probeTimeout;
    if (debounce != null) this.debounce = debounce;

    _initConnectivity();

    // connectivity_plus 6.x emits List<ConnectivityResult>
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final result = _pickResult(results);
      _onConnectivityChanged(result);
    });
  }

  // Initialize by checking current connectivity and normalizing to a list shape.
  Future<void> _initConnectivity() async {
    try {
      final initial = await _connectivity.checkConnectivity();
      final results = _asResults(initial);
      final result = _pickResult(results);
      await _updateFromResult(result);
    } catch (_) {
      _emit(false);
    }
  }

  // Debounced handler receiving a single normalized result.
  void _onConnectivityChanged(ConnectivityResult result) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () async {
      await _updateFromResult(result);
    });
  }

  // Core updater: sets last result, performs optional reachability probe, emits state.
  Future<void> _updateFromResult(ConnectivityResult result) async {
    _lastResult = result;

    if (result == ConnectivityResult.none) {
      _emit(false);
      return;
    }

    if (kIsWeb || !probeInternet) {
      _emit(true);
      return;
    }

    final reachable = await _isInternetReachable(timeout: probeTimeout);
    _emit(reachable);
  }

  // Convert any value to a List<ConnectivityResult> without type checks that trigger lints.
  List<ConnectivityResult> _asResults(Object value) {
    if (value is List<ConnectivityResult>) return value;
    if (value is ConnectivityResult) return <ConnectivityResult>[value];
    return const <ConnectivityResult>[ConnectivityResult.none];
  }

  // Determine a representative connectivity status from a list.
  ConnectivityResult _pickResult(List<ConnectivityResult> results) {
    if (results.isEmpty) return ConnectivityResult.none;
    // Prefer real networks first
    if (results.contains(ConnectivityResult.wifi)) return ConnectivityResult.wifi;
    if (results.contains(ConnectivityResult.ethernet)) return ConnectivityResult.ethernet;
    if (results.contains(ConnectivityResult.mobile)) return ConnectivityResult.mobile;
    if (results.contains(ConnectivityResult.vpn)) return ConnectivityResult.vpn;
    if (results.contains(ConnectivityResult.bluetooth)) return ConnectivityResult.bluetooth;
    // Fallback to the last reported item
    return results.last;
  }

  // DNS probe using InternetAddress.lookup; respects timeout
  Future<bool> _isInternetReachable({Duration timeout = const Duration(seconds: 2)}) async {
    try {
      final res = await InternetAddress.lookup('one.one.one.one').timeout(timeout); // Cloudflare DNS
      if (res.isNotEmpty && res.first.rawAddress.isNotEmpty) return true;

      final res2 = await InternetAddress.lookup('dns.google').timeout(timeout);
      return res2.isNotEmpty && res2.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // Manual recheck trigger (e.g., pull-to-refresh connectivity)
  Future<void> recheck() async {
    final current = await _connectivity.checkConnectivity();
    final result = _pickResult(_asResults(current));
    await _updateFromResult(result);
  }

  void _emit(bool online) {
    if (_isOnline == online) return;
    _isOnline = online;
    if (!_statusController.isClosed) {
      _statusController.add(_isOnline);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _subscription?.cancel();
    _statusController.close();
    super.dispose();
  }
}
