// wallet_security.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart' as crypto; // App hash için eklendi

class WalletSecurity {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // Güvenli depolama anahtarları
  static const String _mnemonicStorageKey = 'mnemonic_key';
  static const String _passwordStorageKey = 'password_key';

  static bool get isDebugMode {
    bool inDebugMode = false;
    assert(inDebugMode = true);
    return inDebugMode;
  }

  static Future<bool> isDeviceCompromised() async {
    // Mobil için root/jailbreak kontrolleri burada yapılabilir.
    // Web için bu kontrol genellikle anlamsızdır veya farklı şekilde ele alınır.
    if (kIsWeb) {
      debugPrint('Cihazın ele geçirilme kontrolleri (root/jailbreak) web ortamları için geçerli değildir ve yapılamaz.');
      return false;
    }
    // Gerçek bir uygulamada burada platforma özel kontroller eklenebilir.
    return false;
  }

  static void clearSensitiveMemory(List<int> data) {
    // Belleği temizlemek, özellikle özel anahtarlar veya mnemonic gibi hassas veriler için önemlidir.
    // Ancak Dart'ın çöp toplama mekanizması nedeniyle, bu yalnızca bir best practice'tir
    // ve garantili bir temizlik sağlamaz. FlutterSecureStorage, verileri işletim sistemi düzeyinde korur.
    if (data.isEmpty) return;
    for (int i = 0; i < data.length; i++) {
      data[i] = 0;
    }
  }

  // Güvenli rastgele veri üretimi - bip39 için zaten yerleşik.
  // Başka amaçlar için gerekirse burada implementasyon yapılabilir.
  static Future<Uint8List> generateSecureRandom(int length) async {
    // Web için kriptografik olarak güvenli rastgele sayılar
    // window.crypto.getRandomValues aracılığıyla implemente edilmelidir.
    // Bu sadece bir yer tutucudur.
    if (kIsWeb) {
      debugPrint('UYARI: Web için secureRandom yer tutucu kullanılıyor. Üretimde window.crypto.getRandomValues ile değiştirin.');
      return Uint8List.fromList(List<int>.generate(length, (i) => 0)); // Kriptografik olarak güvenli DEĞİL
    } else {
      // Mobil/Masaüstü için platforma özgü güvenli rastgele sayı üreteci kullanın
      // (örneğin, dart:math SecureRandom veya platform çağrıları).
      // Bu örnek için basit bir Uint8List döndürüyoruz.
      return Uint8List(length);
    }
  }

  static String calculateAppHash() {
    // Uygulama bütünlüğü kontrolü için örnek bir hash.
    // Gerçek bir uygulamada, bu hash'in derleme zamanında oluşturulması ve
    // uygulama ikilisiyle eşleştiğinden emin olunması gerekir.
    return crypto.sha256.convert('viper_wallet_v1.0_stable_release'.codeUnits).toString();
  }

  static Future<bool> validateSecureStorage() async {
    try {
      const String testKey = '_wallet_security_test_key';
      const String testValue = 'secure_storage_check';

      await _secureStorage.write(key: testKey, value: testValue);
      final String? readValue = await _secureStorage.read(key: testKey);
      await _secureStorage.delete(key: testKey);

      if (readValue == testValue) {
        return true;
      }
      debugPrint('Güvenli depolama doğrulaması başarısız: Okunan değer uyuşmuyor.');
      return false;
    } catch (e) {
      debugPrint('Güvenli depolama doğrulaması başarısız: Erişim sırasında istisna: $e');
      return false;
    }
  }

  static bool isSecureConnection(String url) {
    if (!url.startsWith('https://')) {
      return false;
    }
    final allowedDomains = [
      'api.mainnet-beta.solana.com',
      'api.devnet.solana.com',
      'api.testnet.solana.com',
      'quote-api.jup.ag',
    ];
    // URL'nin izin verilen domainlerden birini içerip içermediğini kontrol edin.
    return allowedDomains.any((domain) => url.contains(domain));
  }

  static bool validateTransaction(Map<String, dynamic> transaction) {
    // İşlem yapısını temel düzeyde doğrula
    return transaction.containsKey('instructions') &&
        transaction.containsKey('recentBlockhash') &&
        transaction['instructions'] is List &&
        (transaction['instructions'] as List).isNotEmpty;
  }

  static void protectPrivateKey() {
    // Özel anahtar koruması için yer tutucu.
    // Mobil platformlarda anahtarlık/anahtar deposu hizmetleri (örneğin Android Keystore, iOS Keychain)
    // veya donanım güvenlik modülleri (HSM) kullanılmalıdır.
    // Web'de, özel anahtarların tarayıcı depolamasında kalıcı olarak saklanmasından kaçınılmalıdır.
    debugPrint('Özel anahtar koruma çağrıldı. Gerçek uygulamada platforma özgü güvenli depolama mekanizmaları kullanılmalıdır.');
  }

  static Future<bool> validateEnvironment() async {
    if (isDebugMode && kReleaseMode == false) {
      debugPrint('Uyarı: Uygulama hata ayıklama modunda çalışıyor. Güvenlik kontrolleri atlanabilir veya farklı davranabilir.');
    }

    // Cihazın ele geçirilip geçirilmediğini kontrol et (yalnızca mobil için daha anlamlı)
    if (!kIsWeb && await isDeviceCompromised()) {
      debugPrint('KRİTİK: Cihaz ele geçirilmiş görünüyor (rooted/jailbroken). Güvenlik riskleri mevcut.');
      return false;
    }

    // Güvenli depolamanın çalışıp çalışmadığını kontrol et
    if (!await validateSecureStorage()) {
      debugPrint('KRİTİK: Güvenli depolama doğrulaması başarısız oldu. Veri bütünlüğü risk altında olabilir.');
      return false;
    }

    debugPrint('Ortam güvenlik doğrulaması geçti.');
    return true;
  }

  // Mnemonic İşlemleri
  static String generateMnemonic() {
    return bip39.generateMnemonic();
  }

  static bool validateMnemonic(String mnemonic) {
    if (mnemonic.isEmpty) {
      return false;
    }
    return bip39.validateMnemonic(mnemonic.trim());
  }

  static Future<void> saveMnemonic(String mnemonic) async {
    await _secureStorage.write(key: _mnemonicStorageKey, value: mnemonic);
  }

  static Future<String?> getMnemonic() async {
    return await _secureStorage.read(key: _mnemonicStorageKey);
  }

  // Şifre İşlemleri
  static Future<void> savePassword(String password) async {
    await _secureStorage.write(key: _passwordStorageKey, value: password);
  }

  static Future<String?> getPassword() async {
    return await _secureStorage.read(key: _passwordStorageKey);
  }

  // Cüzdan Verilerini Silme
  static Future<void> deleteMnemonic() async {
    await _secureStorage.delete(key: _mnemonicStorageKey);
  }

  static Future<void> deletePassword() async {
    await _secureStorage.delete(key: _passwordStorageKey);
  }

  static Future<void> deleteWalletData() async {
    await _secureStorage.delete(key: _mnemonicStorageKey);
    await _secureStorage.delete(key: _passwordStorageKey);
  }

  static Future<bool> hasWallet() async {
    return await _secureStorage.containsKey(key: _mnemonicStorageKey);
  }
}