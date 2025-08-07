import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:solana/solana.dart';

class SwapRpcService {
  static final List<String> _endpoints = [
    'https://api.mainnet-beta.solana.com',
    'https://solana-api.projectserum.com',
    'https://rpc.ankr.com/solana',
  ];

  static int _currentEndpointIndex = 0;
  static RpcClient? _client;
  static final Map<String, DateTime> _endpointFailures = {};
  static const Duration _failureCooldown = Duration(minutes: 1);

  static RpcClient get client {
    _client ??= RpcClient(_endpoints[_currentEndpointIndex]);
    return _client!;
  }

  static Future<T> executeWithFallback<T>(
      Future<T> Function(RpcClient client) operation, {
        int maxRetries = 3,
        Duration timeout = const Duration(seconds: 15),
      }) async {
    Exception? lastException;

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      for (int i = 0; i < _endpoints.length; i++) {
        final endpointIndex = (_currentEndpointIndex + i) % _endpoints.length;
        final endpoint = _endpoints[endpointIndex];

        if (!_isEndpointAvailable(endpoint)) continue;

        try {
          final client = RpcClient(endpoint);
          final result = await operation(client).timeout(timeout);

          _currentEndpointIndex = endpointIndex;
          _client = client;
          return result;
        } catch (e) {
          lastException = e is Exception ? e : Exception(e.toString());
          _markEndpointFailed(endpoint);
          continue;
        }
      }

      if (attempt < maxRetries - 1) {
        await Future.delayed(Duration(milliseconds: 1000 * pow(2, attempt).toInt()));
        _endpointFailures.clear();
      }
    }

    throw lastException ?? Exception('Tüm RPC endpointleri başarısız oldu');
  }

  static bool _isEndpointAvailable(String endpoint) {
    final lastFailure = _endpointFailures[endpoint];
    if (lastFailure == null) return true;
    return DateTime.now().difference(lastFailure) > _failureCooldown;
  }

  static void _markEndpointFailed(String endpoint) {
    _endpointFailures[endpoint] = DateTime.now();
  }
}
