import 'package:solana/solana.dart';

class RpcService {
  static final List<String> _endpoints = [
    'https://api.mainnet-beta.solana.com',
    /*'https://solana-mainnet.g.alchemy.com/v2/demo',
    'https://rpc.ankr.com/solana',
    'https://solana-api.projectserum.com',
    'https://mainnet.solana-rpc.com',
    'https://solana.public-rpc.com',
    'https://api.metaplex.solana.com',*/
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

        final client = RpcClient(endpoint);
        final result = await operation(client);

        // Başarılı olursa bu endpointi kaydet
        _currentEndpointIndex = endpointIndex;
        _client = client;

        print('✅ RPC başarılı: $endpoint');
        return result;
      } catch (e) {
        print('❌ RPC hatası ($endpoint): $e');

        // Son endpoint ise hata fırlat
        if (i == _endpoints.length - 1) {
          throw Exception('Tüm RPC endpointleri başarısız oldu: $e');
        }

        // Değilse bir sonraki endpoint ile devam et
        continue;
      }
    }

    throw Exception('Tüm RPC endpointleri başarısız oldu');
  }

  static Future<bool> isConnected() async {
    try {
      await client.getHealth();
      return true;
    } catch (e) {
      return false;
    }
  }
}
