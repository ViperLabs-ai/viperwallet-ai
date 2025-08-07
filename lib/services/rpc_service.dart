import 'package:solana/solana.dart';

class RpcService {
  static final List<String> _endpoints = [
    'https://mainnet.helius-rpc.com/?api-key=',
  ];

  static int _currentEndpointIndex = 0;
  static RpcClient? _client;

  static RpcClient get client {
    _client ??= RpcClient(_endpoints[_currentEndpointIndex]);
    return _client!;
  }

  static void resetToFirstEndpoint() {
    _currentEndpointIndex = 0;
    _client = RpcClient(_endpoints[_currentEndpointIndex]);
    print('🔄 RPC Endpoint kullanılıyor: ${_endpoints[_currentEndpointIndex]}');
  }

  static Future<T> executeWithFallback<T>(
      Future<T> Function(RpcClient client) operation,
      ) async {
    for (int i = 0; i < _endpoints.length; i++) {
      final endpointIndex = (_currentEndpointIndex + i) % _endpoints.length;
      final endpoint = _endpoints[endpointIndex];

      try {
        print('🔄 RPC denemesi ${i + 1}/${_endpoints.length}: $endpoint');

        final clientAttempt = RpcClient(endpoint);
        final result = await operation(clientAttempt);


        _currentEndpointIndex = endpointIndex;
        _client = clientAttempt;

        print('✅ RPC başarılı: $endpoint');
        return result;
      } catch (e) {
        print('❌ RPC hatası ($endpoint): $e');

        throw Exception('Tek RPC endpointi de başarısız oldu: $e');
      }
    }


    throw Exception('Beklenmeyen bir hata oluştu ve RPC işlemi tamamlanamadı.');
  }

  static Future<bool> isConnected() async {
    try {
      await client.getHealth();
      return true;
    } catch (e) {
      print('❌ Bağlantı testi başarısız: $e');
      return false;
    }
  }
}