import 'dart:io';

import 'dart:math';

import 'package:crypto/crypto.dart' as crypto; // Alias crypto package to avoid conflict

import 'package:flutter/foundation.dart';

import 'package:bip39/bip39.dart' as bip39;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:convert/convert.dart';

import 'package:pointycastle/export.dart';

import 'dart:typed_data'; // Import for Uint8List



class WalletSecurity {

  static const int _maxFailedAttempts = 3;

  static const Duration _lockoutDuration = Duration(minutes: 5);

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();



// Keys for secure storage

  static const String _mnemonicStorageKey = 'encrypted_mnemonic';

  static const String _ivStorageKey = 'encryption_iv'; // For AES CBC mode



// Anti-debugging

  static bool get isDebugMode {

    bool inDebugMode = false;

    assert(inDebugMode = true);

    return inDebugMode;

  }



// Root/Jailbreak detection

  static Future<bool> isDeviceCompromised() async {

// Check if the device is rooted (Android) or jailbroken (iOS)

    if (Platform.isAndroid) {

      return await _checkAndroidRoot();

    } else if (Platform.isIOS) {

      return await _checkIOSJailbreak();

    }

    return false;

  }



// Android Root Detection

  static Future<bool> _checkAndroidRoot() async {

    try {

      final suPaths = [

        '/system/app/Superuser.apk',

        '/sbin/su',

        '/system/bin/su',

        '/system/xbin/su',

        '/data/local/xbin/su',

        '/data/local/bin/su',

        '/system/sd/xbin/su',

        '/system/bin/failsafe/su',

        '/data/local/su',

        '/vendor/bin/su',

        '/system/sbin/su',

      ];



      for (final path in suPaths) {

        if (await File(path).exists()) {

          debugPrint('Android Root detected: Found su binary at $path');

          return true;

        }

      }



      final busyboxPaths = [

        '/system/bin/busybox',

        '/system/xbin/busybox',

        '/sbin/busybox',

        '/vendor/bin/busybox',

      ];

      for (final path in busyboxPaths) {

        if (await File(path).exists()) {

          debugPrint('Android Root detected: Found BusyBox at $path');

          return true;

        }

      }



      final buildTags = await _getSystemProperty('ro.build.tags');

      if (buildTags != null && buildTags.contains('test-keys')) {

        debugPrint('Android Root detected: Found test-keys in build tags.');

        return true;

      }



      final selinuxEnforcing = await _getSystemProperty('ro.boot.selinux');

      if (selinuxEnforcing != null && selinuxEnforcing.contains('permissive')) {

        debugPrint('Android Root detected: SELinux is permissive.');

      }



      return false;

    } catch (e) {

      debugPrint('Error during Android root check: $e');

      return false;

    }

  }



  static Future<String?> _getSystemProperty(String propertyName) async {

    return null; // Placeholder: Requires native code to implement

  }



// iOS Jailbreak Detection

  static Future<bool> _checkIOSJailbreak() async {

    try {

      final jailbreakPaths = [

        '/Applications/Cydia.app',

        '/Library/MobileSubstrate/MobileSubstrate.dylib',

        '/bin/bash',

        '/usr/sbin/sshd',

        '/etc/apt',

        '/private/var/lib/apt/',

        '/var/lib/cydia',

        '/private/var/mobile/Library/Preferences/com.saurik.Cydia.plist',

        '/usr/bin/ssh',

        '/private/etc/apt',

      ];



      for (final path in jailbreakPaths) {

        if (await File(path).exists()) {

          debugPrint('iOS Jailbreak detected: Found file at $path');

          return true;

        }

      }



      final suspiciousWritablePaths = [

        '/private/var/cache/apt/',

        '/private/var/log/',

        '/bin/',

        '/etc/',

        '/usr/local/bin/',

      ];



      for (final path in suspiciousWritablePaths) {

        try {

          final testFile = File('$path/jailbreak_test_file_${DateTime.now().microsecondsSinceEpoch}.tmp');

          await testFile.writeAsString('test');

          await testFile.delete();

          debugPrint('iOS Jailbreak detected: Suspicious writable path at $path');

          return true;

        } catch (e) {

          continue;

        }

      }



      return false;

    } catch (e) {

      debugPrint('Error during iOS jailbreak check: $e');

      return false;

    }

  }





// Memory protection

  static void clearSensitiveMemory(List<int> data) {

    if (data.isEmpty) return;

    final random = Random.secure();

    for (int i = 0; i < data.length; i++) {

      data[i] = random.nextInt(256);

    }

  }



// Secure random generation

  static Uint8List generateSecureRandom(int length) {

    final random = Random.secure();

    return Uint8List.fromList(List.generate(length, (index) => random.nextInt(256)));

  }



// Anti-tampering hash (Illustrative)

  static String calculateAppHash() {

    return crypto.sha256.convert('viper_wallet_v1.0_stable_release'.codeUnits).toString();

  }



// Secure storage validation

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

      debugPrint('Secure storage validation failed: Read value mismatch.');

      return false;

    } catch (e) {

      debugPrint('Secure storage validation failed: Exception during access: $e');

      return false;

    }

  }



// Network security

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

    return allowedDomains.any((domain) => url.contains(domain));

  }



// Transaction validation

  static bool validateTransaction(Map<String, dynamic> transaction) {

    return transaction.containsKey('instructions') &&

        transaction.containsKey('recentBlockhash') &&

        transaction['instructions'] is List &&

        (transaction['instructions'] as List).isNotEmpty;

  }



// Private key protection (Conceptual)

  static void protectPrivateKey() {

    debugPrint('Conceptual private key protection invoked. Requires platform-specific implementation.');

  }



  /// Validates the overall security environment.

  static Future<bool> validateEnvironment() async {

    if (isDebugMode && kReleaseMode == false) {

      debugPrint('Warning: Application running in debug mode. Security checks may be bypassed.');

    }



    final compromised = await isDeviceCompromised();

    if (compromised) {

      debugPrint('CRITICAL: Device appears to be compromised (rooted/jailbroken).');

      return false;

    }



    if (!await validateSecureStorage()) {

      debugPrint('CRITICAL: Secure storage validation failed. Data integrity may be at risk.');

      return false;

    }



    debugPrint('Environment security validation passed.');

    return true;

  }



  /// Generates a new BIP-39 mnemonic phrase.

  static String generateMnemonic() {

    return bip39.generateMnemonic();

  }



  /// Validates a BIP-39 mnemonic phrase.

  static bool validateMnemonic(String mnemonic) {

    if (mnemonic.isEmpty) {

      return false;

    }

    return bip39.validateMnemonic(mnemonic.trim());

  }



// --- NEW: Encryption and Secure Storage for Mnemonic ---



  /// Derives a 256-bit AES key from the given PIN using PBKDF2.

  static Uint8List _deriveKey(String pin, Uint8List salt) {

// Use pointcastle's Hmac, and ensure the key is Uint8List

    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))

      ..init(Pbkdf2Parameters(salt, 10000, 32)); // 10000 iterations, 32 bytes (256 bits) key

    return pbkdf2.process(Uint8List.fromList(pin.codeUnits));

  }



  /// Encrypts data using AES-256-CBC with a derived key and a random IV.

  static Future<String> _encrypt(String data, String pin) async {

    final salt = generateSecureRandom(16); // 16 bytes for PBKDF2 salt

    final key = _deriveKey(pin, salt);

    final iv = generateSecureRandom(16); // 16 bytes for AES IV



    final cipher = BlockCipher("AES/CBC")

      ..init(true, ParametersWithIV(KeyParameter(key), iv));



    final paddedData = _padData(Uint8List.fromList(data.codeUnits));

    final encryptedData = cipher.process(paddedData);



// Store salt and IV along with encrypted data

    final saltHex = hex.encode(salt);

    final ivHex = hex.encode(iv);

    final encryptedHex = hex.encode(encryptedData);



// Store IV separately for decryption

    await _secureStorage.write(key: _ivStorageKey, value: ivHex);



    return '$saltHex:$encryptedHex'; // Combine salt and encrypted data

  }



  /// Decrypts data using AES-256-CBC with a derived key and a stored IV.

  static Future<String> _decrypt(String encryptedDataWithSalt, String pin) async {

    final parts = encryptedDataWithSalt.split(':');

    if (parts.length != 2) {

      throw Exception('Invalid encrypted data format');

    }

    final salt = hex.decode(parts[0]);

    final encryptedData = hex.decode(parts[1]);



    final ivHex = await _secureStorage.read(key: _ivStorageKey);

    if (ivHex == null) {

      throw Exception('Encryption IV not found. Cannot decrypt.');

    }

    final iv = hex.decode(ivHex);



    final key = _deriveKey(pin, Uint8List.fromList(salt)); // Ensure salt is Uint8List



    final cipher = BlockCipher("AES/CBC")

      ..init(false, ParametersWithIV(KeyParameter(key), Uint8List.fromList(iv))); // Ensure iv is Uint8List



    final decryptedData = cipher.process(Uint8List.fromList(encryptedData));

    final unpaddedData = _unpadData(decryptedData);



    return String.fromCharCodes(unpaddedData);

  }



  /// PKCS7 padding for AES

  static Uint8List _padData(Uint8List data) {

    final blockSize = 16; // AES block size

    final padLength = blockSize - (data.length % blockSize);

    final padded = Uint8List(data.length + padLength)

      ..setAll(0, data);

    for (var i = 0; i < padLength; i++) {

      padded[data.length + i] = padLength;

    }

    return padded;

  }



  /// PKCS7 unpadding for AES

  static Uint8List _unpadData(Uint8List paddedData) {

    if (paddedData.isEmpty) return Uint8List(0);

    final padLength = paddedData.last;

    if (padLength == 0 || padLength > paddedData.length) {

// Invalid padding or empty data after unpadding

// Depending on strictness, you might throw an exception here

      return paddedData;

    }

    return paddedData.sublist(0, paddedData.length - padLength);

  }



  /// Saves the mnemonic securely, encrypted with the provided PIN.

  static Future<void> saveEncryptedMnemonic(String mnemonic, String pin) async {

    final encrypted = await _encrypt(mnemonic, pin);

    await _secureStorage.write(key: _mnemonicStorageKey, value: encrypted);

  }



  /// Retrieves and decrypts the mnemonic using the provided PIN.

  /// Returns null if not found or decryption fails.

  static Future<String?> getDecryptedMnemonic(String pin) async {

    final encrypted = await _secureStorage.read(key: _mnemonicStorageKey);

    if (encrypted == null) {

      return null;

    }

    try {

      final decrypted = await _decrypt(encrypted, pin);

// It's good practice to clear the decrypted mnemonic from memory after use

      final List<int> decryptedCodeUnits = List<int>.from(decrypted.codeUnits);

      clearSensitiveMemory(decryptedCodeUnits);

      return decrypted;

    } catch (e) {

      debugPrint('Mnemonic decryption failed: $e');

      return null;

    }

  }



  /// Checks if a wallet (encrypted mnemonic) exists in secure storage.

  static Future<bool> hasWallet() async {

    return await _secureStorage.containsKey(key: _mnemonicStorageKey);

  }



  /// Deletes the stored mnemonic and IV.

  static Future<void> deleteWalletData() async {

    await _secureStorage.delete(key: _mnemonicStorageKey);

    await _secureStorage.delete(key: _ivStorageKey);

  }

}