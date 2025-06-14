import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:solana/dto.dart';
import 'package:solana/solana.dart';
import '../services/rpc_service.dart';

class SwapPage extends StatefulWidget {
  final Ed25519HDKeyPair wallet;

  const SwapPage({super.key, required this.wallet});

  @override
  State<SwapPage> createState() => _SwapPageState();
}

class _SwapPageState extends State<SwapPage> {
  final _fromAmountController = TextEditingController();
  final _toAmountController = TextEditingController();
  final _contractAddressController = TextEditingController();

  String _fromToken = 'SOL';
  String? _toTokenMint;
  String? _toTokenSymbol = "Token";
  int _toTokenDecimals = 0;
  IconData? _toTokenIcon;
  Color? _toTokenColor;

  bool _isLoading = false;
  bool _isLoadingQuote = false;
  bool _isLoadingBalances = false;
  bool _isAddingToken = false;

  double _exchangeRate = 0.0;
  double _priceImpact = 0.0;
  double _minimumReceived = 0.0;

  Map<String, double> _tokenBalances = {};
  final Map<String, Map<String, dynamic>> _tokens = {
    'SOL': {
      'name': 'Solana',
      'mint': 'So11111111111111111111111111111111111111112',
      'decimals': 9,
      'icon': Icons.circle,
      'color': Colors.purple,
    },
  };

  bool _isSecureEnvironment = true;
  Timer? _securityTimer;
  int _failedAttempts = 0;
  static const int _maxFailedAttempts = 3;
  static const Duration _lockoutDuration = Duration(minutes: 5);
  DateTime? _lockoutUntil;

  String? _lastTransactionSignature;
  Map<String, dynamic>? _currentQuote;

  @override
  void initState() {
    super.initState();
    _fromAmountController.addListener(_onAmountChanged);
    _initSecurityChecks();
    _loadTokenBalances();
  }

  Future<void> _initSecurityChecks() async {
    _isSecureEnvironment = await _checkSecureEnvironment();
    _securityTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _performSecurityCheck();
    });
  }

  Future<bool> _checkSecureEnvironment() async {
    try {
      bool inDebugMode = false;
      assert(inDebugMode = true);
      return !inDebugMode;
    } catch (_) {
      return false;
    }
  }

  void _performSecurityCheck() {
    if (!_isSecureEnvironment) {
      _lockWallet('Güvenli olmayan ortam tespit edildi');
      return;
    }
    if (_fromAmountController.hasListeners && _toAmountController.hasListeners) {
      _fromAmountController.clear();
      _toAmountController.clear();
      _currentQuote = null;
      setState(() {});
    }
  }

  void _lockWallet(String reason) {
    setState(() {
      _lockoutUntil = DateTime.now().add(_lockoutDuration);
      _failedAttempts = 0;
      _currentQuote = null;
      _toTokenMint = null;
      _toTokenSymbol = "Token";
      _toTokenDecimals = 0;
      _toTokenIcon = null;
      _toTokenColor = null;
    });
    _clearSensitiveData();
    _showSecurityAlert(reason);
    //Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _clearSensitiveData() {
    if (_fromAmountController.hasListeners) _fromAmountController.clear();
    if (_toAmountController.hasListeners) _toAmountController.clear();
    _currentQuote = null;
    setState(() {});
  }

  @override
  void dispose() {
    _fromAmountController.removeListener(_onAmountChanged);
    _securityTimer?.cancel();
    _fromAmountController.dispose();
    _toAmountController.dispose();
    _contractAddressController.dispose();
    super.dispose();
  }

  Future<void> _loadTokenBalances() async {
    setState(() => _isLoadingBalances = true);
    try {
      final solBalance = await RpcService.executeWithFallback(
              (client) => client.getBalance(widget.wallet.address));
      setState(() {
        _tokenBalances['SOL'] = solBalance.value / 1000000000;
      });
    } catch (e) {
      print('Bakiyeler yüklenirken hata: $e');
      _showErrorSnackBar(
          'Ağ hatası: Bakiyeler yüklenemedi. Lütfen internet bağlantınızı kontrol edin.');
    }
    setState(() => _isLoadingBalances = false);
  }

  void _onAmountChanged() {
    if (_fromAmountController.text.isNotEmpty &&
        _fromAmountController.text != '0' &&
        _toTokenMint != null &&
        _toTokenMint!.isNotEmpty) {
      _getQuote();
    } else {
      setState(() {
        _toAmountController.text = '';
        _exchangeRate = 0.0;
        _currentQuote = null;
      });
    }
  }

  bool _isValidSolanaAddress(String address) {
    final base58regex = RegExp(r'^[1-9A-HJ-NP-Za-km-z]{32,44}$');
    final trimmed = address.trim();
    if (trimmed.length < 32 || trimmed.length > 44) return false;
    return base58regex.hasMatch(trimmed);
  }

  Future<void> _fetchTokenMetadataByMint(String mintAddress) async {
    setState(() => _isAddingToken = true);
    try {
      // Jupiter API Token list endpoint
      final jupiterTokenListUri = Uri.parse('https://cache.jup.ag/tokens');
      final response = await http.get(jupiterTokenListUri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> tokensList = json.decode(response.body);
        final foundToken = tokensList.firstWhere(
              (token) => (token['address'] as String).toLowerCase() == mintAddress.toLowerCase(),
          orElse: () => null,
        );
        if (foundToken != null) {
          final name = foundToken['name'] as String? ?? 'Bilinmeyen Token';
          final symbol = foundToken['symbol'] as String? ?? 'UNKNOWN';
          final decimals = foundToken['decimals'] as int? ?? 0;
          Color iconColor = Colors.deepOrange;
          IconData icon = Icons.token;

          setState(() {
            _toTokenMint = mintAddress;
            _toTokenSymbol = symbol;
            _toTokenDecimals = decimals;
            _toTokenIcon = icon;
            _toTokenColor = iconColor;
          });

          if (!_tokens.containsKey(symbol)) {
            _tokens[symbol] = {
              'name': name,
              'mint': mintAddress,
              'decimals': decimals,
              'icon': icon,
              'color': iconColor,
            };
          }
          setState(() {});
          return;
        } else {
          // Token listed in Jupiter API değilse, belki onchain metadata çekilebilir veya varsayılan değerler atanır
          setState(() {
            _toTokenMint = mintAddress;
            _toTokenSymbol = 'Unknown';
            _toTokenDecimals = 0;
            _toTokenIcon = Icons.token;
            _toTokenColor = Colors.orange;
          });
          return;
        }
      } else {
        _showErrorSnackBar(
            'Token bilgisi alınamadı. Lütfen internet bağlantınızı kontrol edin.');
      }
    } catch (e) {
      print('Token metadata fetch hatası: $e');
      _showErrorSnackBar('Token bilgisi alınırken hata oluştu.');
    } finally {
      setState(() => _isAddingToken = false);
    }
  }

  Future<void> _onAddTokenPressed() async {
    final contract = _contractAddressController.text.trim();
    if (contract.isEmpty) {
      _showErrorSnackBar('Lütfen token contract adresi girin.');
      return;
    }
    if (!_isValidSolanaAddress(contract)) {
      _showErrorSnackBar(
          'Geçersiz token contract adresi. Lütfen Solana token mint adresi giriniz.');
      return;
    }
    await _fetchTokenMetadataByMint(contract);
    if (_toTokenMint != null && _toTokenMint == contract) {
      _contractAddressController.clear();
      _showSuccessSnackBar('Token başarıyla eklendi: $_toTokenSymbol');
      if (_fromAmountController.text.isNotEmpty &&
          _fromAmountController.text != '0') {
        _getQuote();
      }
    }
  }

  Future<void> _getQuote() async {
    if (_isLoadingQuote) return;
    if (_toTokenMint == null || _toTokenMint!.isEmpty) {
      _showErrorSnackBar('Lütfen hedef token contract adresini ekleyin.');
      return;
    }
    setState(() => _isLoadingQuote = true);

    try {
      final fromAmount = double.parse(_fromAmountController.text);
      final fromDecimals = _tokens[_fromToken]!['decimals'] as int;
      final amountInSmallestUnit = (fromAmount * pow(10, fromDecimals)).toInt();

      final quoteResponse = await http.get(
        Uri.parse(
          'https://quote-api.jup.ag/v6/quote?'
              'inputMint=${_tokens[_fromToken]!['mint']}&'
              'outputMint=$_toTokenMint&'
              'amount=$amountInSmallestUnit&'
              'slippageBps=50',
        ),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Viper Wallet/1.0',
        },
      ).timeout(const Duration(seconds: 15));

      if (quoteResponse.statusCode == 200) {
        final quoteData = json.decode(quoteResponse.body);
        if (quoteData['outAmount'] != null) {
          final toDecimals = _toTokenDecimals;
          final outputAmount =
              double.parse(quoteData['outAmount']) / pow(10, toDecimals);

          setState(() {
            _currentQuote = quoteData;
            _toAmountController.text = outputAmount.toStringAsFixed(6);
            _exchangeRate = outputAmount / fromAmount;
            _priceImpact =
                double.tryParse(quoteData['priceImpactPct']?.toString() ?? '0') ??
                    0.0;
            _minimumReceived = outputAmount * 0.995;
          });
        } else {
          throw Exception('Geçersiz fiyat teklifi alınamadı.');
        }
      } else {
        final errorBody = quoteResponse.body;
        print('Quote API Hata Detayı: $errorBody');
        throw Exception(
            'Quote API hatası: ${quoteResponse.statusCode} - $errorBody');
      }
    } catch (e) {
      print('Fiyat teklifi alınırken hata: $e');
      _showErrorSnackBar('Fiyat alınamadı: ${e.toString()}');
      setState(() {
        _toAmountController.text = '';
        _exchangeRate = 0.0;
        _currentQuote = null;
      });
    }
    setState(() => _isLoadingQuote = false);
  }

  Future<void> _executeSwap() async {
    if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
      final remaining = _lockoutUntil!.difference(DateTime.now());
      _showErrorSnackBar(
          'Cüzdan kilitli. Lütfen ${remaining.inMinutes} dakika bekleyin.');
      return;
    }
    if (!_isSecureEnvironment) {
      _lockWallet('Güvenli olmayan ortam tespit edildi');
      return;
    }
    if (_fromAmountController.text.isEmpty || _currentQuote == null) {
      _failedAttempts++;
      if (_failedAttempts >= _maxFailedAttempts) {
        _lockWallet('Çok fazla başarısız deneme');
        return;
      }
      _showErrorSnackBar('Lütfen geçerli bir miktar girin.');
      return;
    }
    final fromAmount = double.tryParse(_fromAmountController.text);
    if (fromAmount == null) {
      _showErrorSnackBar('Geçersiz miktar girdiniz.');
      return;
    }
    final availableBalance = _tokenBalances[_fromToken] ?? 0.0;
    if (fromAmount > availableBalance) {
      _failedAttempts++;
      if (_failedAttempts >= _maxFailedAttempts) {
        _lockWallet('Çok fazla başarısız deneme');
        return;
      }
      _showErrorSnackBar(
          'Yetersiz bakiye. Mevcut: ${availableBalance.toStringAsFixed(6)} $_fromToken');
      return;
    }

    final confirmed = await _showSecureConfirmationDialog();
    if (!confirmed) return;

    setState(() => _isLoading = true);
    try {
      final result = await _executeSecureSwap();
      if (result['success']) {
        _failedAttempts = 0;
        _lastTransactionSignature = result['signature'];
        _showSuccessSnackBar(
            'Swap başarılı! İşlem ID: ${result['signature'].substring(0, 8)}...');
        await Future.delayed(const Duration(seconds: 2));
        await _loadTokenBalances();
        _fromAmountController.clear();
        _toAmountController.clear();
        setState(() {
          _currentQuote = null;
          _exchangeRate = 0.0;
        });
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

  Future<Map<String, dynamic>> _executeSecureSwap() async {
    try {
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
        final signature = await RpcService.executeWithFallback((client) async {
          return await client.sendTransaction(
            swapTransactionBase64,
            preflightCommitment: Commitment.processed,
          );
        });
        await _waitForConfirmation(signature);
        return {
          'success': true,
          'signature': signature,
        };
      } else {
        throw Exception('Swap işlemi başarısız oldu: ${swapResponse.statusCode}');
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

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
            throw Exception('İşlem başarısız oldu: ${status.err}');
          }
        }
      } catch (e) {
        print('İşlem onayı kontrolü hatası: $e');
      }
    }
    throw Exception('İşlem onayı zaman aşımı');
  }

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
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                  SizedBox(height: 8),
                  Text(
                    '• Bu işlem GERİ ALINAMAZ\n'
                        '• Private key kullanılacak\n'
                        '• Mainnet üzerinde gerçek işlem\n'
                        '• Network ücretleri ödenecek',
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
                    'Al: ${_toAmountController.text.isNotEmpty ? _toAmountController.text : '0'} ${_toTokenSymbol ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Fiyat Etkisi: ${_priceImpact.toStringAsFixed(3)}%',
                    style: TextStyle(
                        color: _priceImpact > 1 ? Colors.red : Colors.orange),
                  ),
                  const Text('Slippage: 0.5%'),
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
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ) ??
        false;
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
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
    if (!mounted) return;
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
            final url =
                'https://explorer.solana.com/tx/$_lastTransactionSignature';
            print('Explorer Link: $url');
          },
        )
            : null,
      ),
    );
  }

  Widget _buildContractAddressInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _contractAddressController,
              decoration: InputDecoration(
                hintText: 'Hedef token contract adresi girin',
                hintStyle: TextStyle(
                  color: (isDark ? Colors.white : Colors.black54).withOpacity(0.5),
                ),
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.grey.shade200,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 48,
            height: 48,
            child: ElevatedButton(
              onPressed: _isAddingToken ? null : _onAddTokenPressed,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                backgroundColor: const Color(0xFFFF6B35),
                padding: EdgeInsets.zero,
              ),
              child: _isAddingToken
                  ? const SizedBox(
                width: 20,
                height: 20,
                child:
                CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Icon(Icons.add, color: Colors.white),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isDark ? Colors.white12 : Colors.white.withOpacity(0.4),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black54 : Colors.grey.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: isDark ? Colors.white24 : Colors.white70),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: child,
        ),
      ),
    );
  }

  Widget _buildTokenSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_toTokenMint == null || _toTokenMint!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(_toTokenIcon ?? Icons.token, color: _toTokenColor ?? Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _toTokenSymbol ?? 'Bilinmeyen Token',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black54),
            onPressed: () {
              setState(() {
                _toTokenMint = null;
                _toTokenSymbol = "Token";
                _toTokenDecimals = 0;
                _toTokenIcon = null;
                _toTokenColor = null;
                _toAmountController.clear();
                _currentQuote = null;
                _exchangeRate = 0.0;
              });
            },
          ),
        ],
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
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: (isDark ? Colors.black : Colors.white).withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.3)),
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
                  : const Icon(Icons.refresh, color: Color(0xFFFF6B35)),
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
                ? const [Color(0xFF000000), Color(0xFF1A1A1A), Color(0xFF2D1810)]
                : [Colors.grey.shade50, Colors.grey.shade100, const Color(0xFFFFF5F0)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildContractAddressInput(),
                const SizedBox(height: 20),
                _buildGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Gönder (Sadece SOL)',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                _fromAmountController.text =
                                    fromBalance.toStringAsFixed(6);
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
                        Text(
                          'Bakiye: ${fromBalance.toStringAsFixed(6)} $_fromToken',
                          style: TextStyle(
                            color:
                            (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _fromAmountController,
                          keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 26,
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
                const SizedBox(height: 20),
                if (_toTokenMint != null && _toTokenMint!.isNotEmpty)
                  _buildTokenSelector(),
                const SizedBox(height: 16),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _currentQuote != null && !_isLoading
                          ? const [Color(0xFFFF6B35), Color(0xFFFF8C42)]
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
                      _currentQuote != null ? 'Swap Yap' : 'Miktar Girin ve Token Ekle',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_currentQuote != null)
                  _buildGlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.compare_arrows,
                                color: const Color(0xFFFF6B35),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '1 $_fromToken = ${_exchangeRate.toStringAsFixed(6)} ${_toTokenSymbol ?? 'Token'}',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (_isLoadingQuote)
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                    AlwaysStoppedAnimation(Colors.orange.shade300),
                                  ),
                                )
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
                                'Min. Alacağınız: ${_minimumReceived.toStringAsFixed(6)} ${_toTokenSymbol ?? ''}',
                                style: const TextStyle(
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
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
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
}
