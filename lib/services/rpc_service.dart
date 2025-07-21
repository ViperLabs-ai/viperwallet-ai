import 'package:solana/solana.dart';

class RpcService {
  // Sadece bu tek endpoint'i kullanmak için listeyi daraltın.
  static final List<String> _endpoints = [
    'https://mainnet.helius-rpc.com/?api-key=774e9e08-9268-49f2-95c0-f1f05666f96e',
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
    // Tek bir endpoint olduğu için döngü tek bir iterasyon yapacaktır.
    // Yine de hata yönetimi ve yeniden deneme mantığı korunmuş olur.
    for (int i = 0; i < _endpoints.length; i++) {
      final endpointIndex = (_currentEndpointIndex + i) % _endpoints.length;
      final endpoint = _endpoints[endpointIndex];

      try {
        print('🔄 RPC denemesi ${i + 1}/${_endpoints.length}: $endpoint');

        // Her denemede yeni bir RpcClient oluşturmak en güvenli yoldur.
        final clientAttempt = RpcClient(endpoint);
        final result = await operation(clientAttempt);

        // Başarılı olursa bu endpointi kaydet (tek endpoint zaten budur)
        _currentEndpointIndex = endpointIndex;
        _client = clientAttempt;

        print('✅ RPC başarılı: $endpoint');
        return result;
      } catch (e) {
        print('❌ RPC hatası ($endpoint): $e');

        // Tek endpoint olduğu için doğrudan hata fırlat.
        // Diğer endpointler olmadığı için devam etme şansı yok.
        throw Exception('Tek RPC endpointi de başarısız oldu: $e');
      }
    }

    // Bu noktaya ulaşılmaz, çünkü hata ya try/catch içinde yakalanır ya da fırlatılır.
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