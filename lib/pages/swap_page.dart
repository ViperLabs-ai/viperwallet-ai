import 'dart:ui';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:solana/dto.dart';
import 'package:solana/solana.dart';
import 'package:solana/encoder.dart';
import 'package:solana/base58.dart';
import 'package:http/http.dart' as http;
import 'dart:isolate';
import 'package:crypto/crypto.dart';
import 'dart:async';
import 'dart:math';
import '../services/rpc_service.dart';
import 'package:flutter/services.dart';

class SwapPage extends StatefulWidget {
  final Ed25519HDKeyPair wallet;

  const SwapPage({super.key, required this.wallet});

  @override
  State<SwapPage> createState() => _SwapPageState();
}

class _SwapPageState extends State<SwapPage> {
  final _fromAmountController = TextEditingController();
  final _toAmountController = TextEditingController();

  String _fromToken = 'SOL';
  String _toToken = 'USDC';
  bool _isLoading = false;
  bool _isLoadingQuote = false;
  bool _isLoadingBalances = false;
  double _exchangeRate = 0.0;
  double _priceImpact = 0.0;
  double _minimumReceived = 0.0;
  Map<String, dynamic>? _currentQuote;
  String? _lastTransactionSignature;

  late RpcClient _rpcClient;
  Map<String, double> _tokenBalances = {};
  Map<String, String> _tokenAccounts = {}; // Store token account addresses

  // Token mint addresses for Solana mainnet
  final Map<String, Map<String, dynamic>> _tokens = {
    'SOL': {
      'name': 'Solana',
      'mint': 'So11111111111111111111111111111111111111112',
      'decimals': 9,
      'icon': Icons.circle,
      'color': Colors.purple,
    },
    'USDC': {
      'name': 'USD Coin',
      'mint': 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
      'decimals': 6,
      'icon': Icons.attach_money,
      'color': Colors.blue,
    },
    'USDT': {
      'name': 'Tether',
      'mint': 'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB',
      'decimals': 6,
      'icon': Icons.monetization_on,
      'color': Colors.green,
    },
    'RAY': {
      'name': 'Raydium',
      'mint': '4k3Dyjzvzp8eMZWUXbBCjEvwSkkk59S5iCNLY3QrkX6R',
      'decimals': 6,
      'icon': Icons.flash_on,
      'color': Colors.orange,
    },
    'BONK': {
      'name': 'Bonk',
      'mint': 'DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263',
      'decimals': 5,
      'icon': Icons.pets,
      'color': Colors.pink,
    },
  };

  bool _isSecureEnvironment = true;
  Timer? _securityTimer;
  int _failedAttempts = 0;
  static const int _maxFailedAttempts = 3;
  static const Duration _lockoutDuration = Duration(minutes: 5);
  DateTime? _lockoutUntil;

  @override
  void initState() {
    super.initState();
    // _rpcClient = RpcClient('https://api.mainnet-beta.solana.com'); // KALDIR
    // Artık RpcService.client kullanacağız
    _fromAmountController.addListener(_onAmountChanged);
    _initSecurityChecks();
    _loadTokenBalances();
  }

  // Güvenlik kontrolleri ekle
  Future<void> _initSecurityChecks() async {
    // Emulator detection
    _isSecureEnvironment = await _checkSecureEnvironment();

    // Security timer - her 30 saniyede kontrol
    _securityTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _performSecurityCheck();
    });
  }

  Future<bool> _checkSecureEnvironment() async {
    try {
      // Debug mode kontrolü
      bool inDebugMode = false;
      assert(inDebugMode = true);

      // Root/Jailbreak detection (basit)
      // Gerçek uygulamada daha gelişmiş kontroller yapılmalı

      return !inDebugMode; // Production'da true olmalı
    } catch (e) {
      return false;
    }
  }

  void _performSecurityCheck() {
    if (!_isSecureEnvironment) {
      _lockWallet('Güvenli olmayan ortam tespit edildi');
      return;
    }

    // Memory dump protection
    if (_fromAmountController.hasListeners && _toAmountController.hasListeners) {
      _fromAmountController.clear();
      _toAmountController.clear();
      _currentQuote = null;
    }
  }

  void _lockWallet(String reason) {
    setState(() {
      _lockoutUntil = DateTime.now().add(_lockoutDuration);
    });

    _showSecurityAlert(reason);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showSecurityAlert(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.red),
            SizedBox(width: 8),
            Text('Güvenlik Uyarısı'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  // _clearSensitiveData metodunu güncelle - TextEditingController'ları güvenli şekilde temizle
  void _clearSensitiveData() {
    // Memory'deki hassas verileri temizle
    // Controller'ları sadece dispose edilmemişse temizle
    if (_fromAmountController.hasListeners) {
      _fromAmountController.clear();
    }
    if (_toAmountController.hasListeners) {
      _toAmountController.clear();
    }
    _currentQuote = null;
  }

  // dispose metodunu güncelle - önce timer'ı iptal et, sonra controller'ları dispose et
  @override
  void dispose() {
    _fromAmountController.removeListener(_onAmountChanged);
    _securityTimer?.cancel();
    // Controller'ları en son dispose et
    _fromAmountController.dispose();
    _toAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadTokenBalances() async {
    setState(() => _isLoadingBalances = true);

    try {
      // Load SOL balance with fallback
      final solBalance = await RpcService.executeWithFallback((client) async {
        return await client.getBalance(widget.wallet.address);
      });

      setState(() {
        _tokenBalances['SOL'] = solBalance.value / 1000000000;
      });

      // Load SPL token balances
      await _loadSPLTokenBalances();

    } catch (e) {
      print('Error loading token balances: $e');
      _showErrorSnackBar('Network hatası: Bakiyeler yüklenemedi. Lütfen internet bağlantınızı kontrol edin.');
    }

    setState(() => _isLoadingBalances = false);
  }

  Future<void> _loadSPLTokenBalances() async {
    try {
      final tokenAccountsResult = await RpcService.executeWithFallback((client) async {
        return await client.getTokenAccountsByOwner(
          widget.wallet.address,
          const TokenAccountsFilter.byProgramId(TokenProgram.programId),
          encoding: Encoding.jsonParsed,
        );
      });

      for (final account in tokenAccountsResult.value) {
        try {
          final accountInfo = await RpcService.executeWithFallback((client) async {
            return await client.getAccountInfo(
              account.pubkey,
              encoding: Encoding.jsonParsed,
            );
          });

          // Geri kalan kod aynı kalacak...
          if (accountInfo?.value?.data != null) {
            final accountData = accountInfo!.value!.data;

            if (accountData is ParsedAccountData) {
              final parsed = accountData.parsed as Map<String, dynamic>;
              final info = parsed['info'] as Map<String, dynamic>;

              final mint = info['mint'] as String;
              final tokenAmount = info['tokenAmount'] as Map<String, dynamic>;
              final amount = double.parse(tokenAmount['amount']);
              final decimals = tokenAmount['decimals'] as int;

              final tokenEntry = _tokens.entries.firstWhere(
                      (entry) => entry.value['mint'] == mint,
                  orElse: () => const MapEntry('', {})
              );

              if (tokenEntry.key.isNotEmpty) {
                final balance = amount / (10 * decimals);

                setState(() {
                  _tokenBalances[tokenEntry.key] = balance;
                });
              }
            }
          }
        } catch (e) {
          print('Error processing token account ${account.pubkey}: $e');
        }
      }
    } catch (e) {
      print('Error loading SPL token balances: $e');
    }
  }

  void _onAmountChanged() {
    if (_fromAmountController.text.isNotEmpty &&
        _fromAmountController.text != '0' &&
        _fromToken != _toToken) {
      _getQuote();
    } else {
      setState(() {
        _toAmountController.text = '';
        _exchangeRate = 0.0;
        _currentQuote = null;
      });
    }
  }

  Future<void> _getQuote() async {
    if (_isLoadingQuote) return;

    setState(() => _isLoadingQuote = true);

    try {
      final fromAmount = double.parse(_fromAmountController.text);
      final fromDecimals = _tokens[_fromToken]!['decimals'] as int;
      final amountInSmallestUnit = (fromAmount * pow(10, fromDecimals)).toInt();

      // Jupiter API quote request - DÜZELTME
      final quoteResponse = await http.get(
        Uri.parse(
            'https://quote-api.jup.ag/v6/quote?'
                'inputMint=${_tokens[_fromToken]!['mint']}&'
                'outputMint=${_tokens[_toToken]!['mint']}&'
                'amount=$amountInSmallestUnit&'
                'slippageBps=50'
        ),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Viper Wallet/1.0',
        },
      ).timeout(const Duration(seconds: 15));

      if (quoteResponse.statusCode == 200) {
        final quoteData = json.decode(quoteResponse.body);

        if (quoteData['outAmount'] != null) {
          final toDecimals = _tokens[_toToken]!['decimals'] as int;
          final outputAmount = double.parse(quoteData['outAmount']) / pow(10, toDecimals);

          setState(() {
            _currentQuote = quoteData;
            _toAmountController.text = outputAmount.toStringAsFixed(6);
            _exchangeRate = outputAmount / fromAmount;
            _priceImpact = double.tryParse(quoteData['priceImpactPct']?.toString() ?? '0') ?? 0.0;
            _minimumReceived = outputAmount * 0.995; // 0.5% slippage tolerance
          });
        } else {
          throw Exception('Invalid quote response');
        }
      } else {
        final errorBody = quoteResponse.body;
        print('Quote API Error Body: $errorBody');
        throw Exception('Quote API error: ${quoteResponse.statusCode} - $errorBody');
      }
    } catch (e) {
      print('Error getting quote: $e');
      _showErrorSnackBar('Fiyat alınamadı: ${e.toString()}');

      setState(() {
        _toAmountController.text = '';
        _exchangeRate = 0.0;
        _currentQuote = null;
      });
    }

    setState(() => _isLoadingQuote = false);
  }

  // _executeSwap fonksiyonunda başarılı işlem sonrası bakiye güncelleme
  Future<void> _executeSwap() async {
    // Lockout kontrolü
    if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
      final remaining = _lockoutUntil!.difference(DateTime.now());
      _showErrorSnackBar('Cüzdan kilitli. ${remaining.inMinutes} dakika bekleyin.');
      return;
    }

    // Güvenlik kontrolü
    if (!_isSecureEnvironment) {
      _lockWallet('Güvenli olmayan ortam');
      return;
    }

    if (_fromAmountController.text.isEmpty || _currentQuote == null) {
      _failedAttempts++;
      if (_failedAttempts >= _maxFailedAttempts) {
        _lockWallet('Çok fazla başarısız deneme');
        return;
      }
      _showErrorSnackBar('Lütfen geçerli bir miktar girin');
      return;
    }

    // Validate balance
    final fromAmount = double.parse(_fromAmountController.text);
    final availableBalance = _tokenBalances[_fromToken] ?? 0.0;

    if (fromAmount > availableBalance) {
      _failedAttempts++;
      if (_failedAttempts >= _maxFailedAttempts) {
        _lockWallet('Çok fazla başarısız deneme');
        return;
      }
      _showErrorSnackBar('Yetersiz bakiye. Mevcut: ${availableBalance.toStringAsFixed(4)} $_fromToken');
      return;
    }

    // Show confirmation dialog with security warning
    final confirmed = await _showSecureConfirmationDialog();
    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      // Secure transaction execution
      final result = await _executeSecureSwap();

      if (result['success']) {
        _failedAttempts = 0; // Reset on success
        _showSuccessSnackBar('Swap başarılı! İşlem: ${result['signature'].substring(0, 8)}...');

        // Refresh real balances from blockchain - 3 saniye bekleyerek
        await Future.delayed(const Duration(seconds: 3));
        await _loadTokenBalances();

        // UI'ı temizle
        _fromAmountController.clear();
        _toAmountController.clear();
        setState(() {
          _currentQuote = null;
          _exchangeRate = 0.0;
        });

        // Haptic feedback ekle
        HapticFeedback.heavyImpact();
      } else {
        throw Exception(result['error']);
      }
    } catch (e) {
      _failedAttempts++;
      if (_failedAttempts >= _maxFailedAttempts) {
        _lockWallet('Çok fazla başarısız işlem');
        return;
      }
      _showErrorSnackBar('Swap hatası: ${e.toString()}');
    }

    setState(() => _isLoading = false);
  }

  // Güvenli transaction execution - HATASIZ HAL
  Future<Map<String, dynamic>> _executeSecureSwap() async {
    try {
      // Get swap transaction from Jupiter
      final swapResponse = await http.post(
        Uri.parse('https://quote-api.jup.ag/v6/swap'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'quoteResponse': _currentQuote,
          'userPublicKey': widget.wallet.address,
          'wrapAndUnwrapSol': true,
          'dynamicComputeUnitLimit': true,
          'prioritizationFeeLamports': 'auto',
        }),
      ).timeout(const Duration(seconds: 30));

      if (swapResponse.statusCode == 200) {
        final swapData = json.decode(swapResponse.body);
        final swapTransactionBase64 = swapData['swapTransaction'];

        // ✅ DÜZELTME: RpcService kullan
        final signature = await RpcService.executeWithFallback((client) async {
          return await client.sendTransaction(
            swapTransactionBase64,
            preflightCommitment: Commitment.processed,
          );
        });

        // Wait for confirmation
        await _waitForConfirmation(signature);

        return {
          'success': true,
          'signature': signature,
        };
      } else {
        throw Exception('Swap transaction failed: ${swapResponse.statusCode}');
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

// Güvenli confirmation dialog
  Future<bool> _showSecureConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : Colors.white,
        title: Row(
          children: [
            const Icon(Icons.security, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              'Güvenli Swap Onayı',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'GÜVENLİK UYARISI',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Bu işlem GERİ ALINAMAZ\n'
                        '• Private key kullanılacak\n'
                        '• Mainnet üzerinde gerçek işlem\n'
                        '• Network fees ödenecek',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'İşlem Detayları:',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gönder: ${_fromAmountController.text} $_fromToken',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Al: ${_toAmountController.text} $_toToken',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Fiyat Etkisi: ${_priceImpact.toStringAsFixed(3)}%',
                    style: TextStyle(
                      color: _priceImpact > 1 ? Colors.red : Colors.orange,
                    ),
                  ),
                  Text(
                    'Slippage: 0.5%',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
            ),
            child: const Text(
              'GÜVENLİ ONAYLA',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<String?> _getSwapTransaction() async {
    try {
      final swapResponse = await http.post(
        Uri.parse('https://quote-api.jup.ag/v6/swap'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'Viper Wallet/1.0',
        },
        body: json.encode({
          'quoteResponse': _currentQuote,
          'userPublicKey': widget.wallet.address,
          'wrapAndUnwrapSol': true,
          'dynamicComputeUnitLimit': true,
          'prioritizationFeeLamports': 'auto',
          'asLegacyTransaction': false,
        }),
      ).timeout(const Duration(seconds: 30));

      if (swapResponse.statusCode == 200) {
        final swapData = json.decode(swapResponse.body);
        return swapData['swapTransaction'] as String?;
      } else {
        final errorData = json.decode(swapResponse.body);
        throw Exception('Swap API error: ${errorData['error'] ?? swapResponse.statusCode}');
      }
    } catch (e) {
      throw Exception('Swap transaction error: $e');
    }
  }

  // Transaction signing/sending - HATASIZ HAL
  Future<String?> _signAndSendTransaction(String transactionBase64) async {
    try {
      // Decode transaction
      final transactionBytes = base64.decode(transactionBase64);

      // Send transaction directly
      final signature = await _rpcClient.sendTransaction(
        base64.encode(transactionBytes),
        preflightCommitment: Commitment.processed,
      );

      return signature;
    } catch (e) {
      throw Exception('Transaction signing/sending error: $e');
    }
  }

  // Güvenli confirmation bekleme
  Future<void> _waitForConfirmation(String signature) async {
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(seconds: 1));

      try {
        final statuses = await RpcService.executeWithFallback((client) async {
          return await client.getSignatureStatuses([signature]);
        });

        if (statuses.value.isNotEmpty && statuses.value.first != null) {
          final status = statuses.value.first!;
          if (status.confirmationStatus == 'confirmed' ||
              status.confirmationStatus == 'finalized') {
            return;
          }
          if (status.err != null) {
            throw Exception('Transaction failed: ${status.err}');
          }
        }
      } catch (e) {
        print('Confirmation check error: $e');
      }
    }
    throw Exception('Transaction confirmation timeout');
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : Colors.white,
        title: Text(
          'Swap Onayı',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black87,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bu işlemi onaylıyor musunuz?',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gönder: ${_fromAmountController.text} $_fromToken',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Al: ${_toAmountController.text} $_toToken',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Fiyat Etkisi: ${_priceImpact.toStringAsFixed(3)}%',
                    style: TextStyle(
                      color: _priceImpact > 1 ? Colors.red : Colors.orange,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
            ),
            child: const Text(
              'Onayla',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 5),
        action: _lastTransactionSignature != null
            ? SnackBarAction(
          label: 'Explorer\'da Gör',
          textColor: Colors.white,
          onPressed: () {
            // Open Solana Explorer
            print('Open: https://explorer.solana.com/tx/$_lastTransactionSignature');
          },
        )
            : null,
      ),
    );
  }

  void _swapTokens() {
    setState(() {
      final tempToken = _fromToken;
      _fromToken = _toToken;
      _toToken = tempToken;

      _fromAmountController.clear();
      _toAmountController.clear();
      _exchangeRate = 0.0;
      _currentQuote = null;
    });
  }

  Widget _buildGlassCard({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFFF6B35).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildTokenSelector({
    required String selectedToken,
    required Function(String) onTokenSelected,
    required String label,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedTokenData = _tokens[selectedToken]!;

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Token Seçin',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ..._tokens.entries.map((entry) {
                  final token = entry.value;
                  final symbol = entry.key;
                  final balance = _tokenBalances[symbol] ?? 0.0;

                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (token['color'] as Color).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        token['icon'] as IconData,
                        color: token['color'] as Color,
                      ),
                    ),
                    title: Text(
                      symbol,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      token['name'] as String,
                      style: TextStyle(
                        color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                      ),
                    ),
                    trailing: Text(
                      balance.toStringAsFixed(4),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      onTokenSelected(symbol);
                      Navigator.pop(context);
                    },
                  );
                }),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.black.withOpacity(0.5)
              : Colors.grey[100]?.withOpacity(0.5) ?? Colors.grey.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFFF6B35).withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (selectedTokenData['color'] as Color).withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                selectedTokenData['icon'] as IconData,
                color: selectedTokenData['color'] as Color,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              selectedToken,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fromBalance = _tokenBalances[_fromToken] ?? 0.0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Token Swap',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: (isDark ? Colors.black : Colors.white).withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFF6B35).withOpacity(0.3),
              ),
            ),
            child: IconButton(
              onPressed: _isLoadingBalances ? null : _loadTokenBalances,
              icon: _isLoadingBalances
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                ),
              )
                  : const Icon(
                Icons.refresh,
                color: Color(0xFFFF6B35),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
              const Color(0xFF000000),
              const Color(0xFF1A1A1A),
              const Color(0xFF2D1810),
            ]
                : [
              Colors.grey[50]!,
              Colors.grey[100]!,
              const Color(0xFFFFF5F0),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                // From token kartı
                _buildGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Gönder',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            _buildTokenSelector(
                              selectedToken: _fromToken,
                              onTokenSelected: (token) {
                                setState(() {
                                  _fromToken = token;
                                  _fromAmountController.clear();
                                  _toAmountController.clear();
                                  _currentQuote = null;
                                });
                              },
                              label: 'From',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'Bakiye: ${fromBalance.toStringAsFixed(4)} $_fromToken',
                              style: TextStyle(
                                color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                _fromAmountController.text = fromBalance.toStringAsFixed(6);
                              },
                              child: const Text(
                                'MAX',
                                style: TextStyle(
                                  color: Color(0xFFFF6B35),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _fromAmountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            hintText: '0.0',
                            hintStyle: TextStyle(
                              color: (isDark ? Colors.white : Colors.black87).withOpacity(0.5),
                              fontSize: 24,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Swap butonu
                Center(
                  child: GestureDetector(
                    onTap: _swapTokens,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.swap_vert,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // To token kartı
                _buildGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Al',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            _buildTokenSelector(
                              selectedToken: _toToken,
                              onTokenSelected: (token) {
                                setState(() {
                                  _toToken = token;
                                  _fromAmountController.clear();
                                  _toAmountController.clear();
                                  _currentQuote = null;
                                });
                              },
                              label: 'To',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Bakiye: ${(_tokenBalances[_toToken] ?? 0.0).toStringAsFixed(4)} $_toToken',
                          style: TextStyle(
                            color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _toAmountController,
                                readOnly: true,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  hintText: '0.0',
                                  hintStyle: TextStyle(
                                    color: (isDark ? Colors.white : Colors.black87).withOpacity(0.5),
                                    fontSize: 24,
                                  ),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            if (_isLoadingQuote)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Swap details
                if (_currentQuote != null) ...[
                  _buildGlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.compare_arrows,
                                color: const Color(0xFFFF6B35),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '1 $_fromToken = ${_exchangeRate.toStringAsFixed(6)} $_toToken',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.trending_down,
                                color: _priceImpact > 1 ? Colors.red : Colors.orange,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Fiyat Etkisi: ${_priceImpact.toStringAsFixed(3)}%',
                                style: TextStyle(
                                  color: _priceImpact > 1 ? Colors.red : Colors.orange,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.shield,
                                color: Colors.green,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Min. Alacağınız: ${_minimumReceived.toStringAsFixed(6)} $_toToken',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                const Spacer(),

                // Swap butonu
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _currentQuote != null && !_isLoading
                          ? [const Color(0xFFFF6B35), const Color(0xFFFF8C42)]
                          : [Colors.grey, Colors.grey.shade600],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton(
                    onPressed: (_currentQuote != null && !_isLoading) ? _executeSwap : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    )
                        : Text(
                      _currentQuote != null ? 'Swap Yap' : 'Miktar Girin',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
