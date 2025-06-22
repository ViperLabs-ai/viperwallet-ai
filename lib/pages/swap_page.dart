import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:solana/dto.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import 'package:cryptography/cryptography.dart';
import '../services/swap_rpc_service.dart';
import '../widgets/glass_card.dart';
import '../models/token_info.dart';

class SwapPage extends StatefulWidget {
  final Ed25519HDKeyPair wallet;

  const SwapPage({super.key, required this.wallet});

  @override
  State<SwapPage> createState() => _SwapPageState();
}

class _SwapPageState extends State<SwapPage> with TickerProviderStateMixin {
  final _fromAmountController = TextEditingController();
  final _toAmountController = TextEditingController();
  final _contractAddressController = TextEditingController();

  String _fromToken = 'SOL';
  TokenInfo? _toToken;

  bool _isLoading = false;
  bool _isLoadingQuote = false;
  bool _isLoadingBalances = false;
  bool _isAddingToken = false;
  bool _showAddTokenDialog = false;

  double _exchangeRate = 0.0;
  double _priceImpact = 0.0;
  double _minimumReceived = 0.0;
  double _networkFee = 0.0;

  Map<String, double> _tokenBalances = {};
  List<TokenInfo> _allTokens = []; // Tüm tokenları burada saklayacağız

  final Map<String, TokenInfo> _predefinedTokens = {
    'SOL': TokenInfo(
      address: 'So11111111111111111111111111111111111111112',
      name: 'Solana',
      symbol: 'SOL',
      decimals: 9,
      verified: true,
    ),
  };

  String? _lastTransactionSignature;
  Map<String, dynamic>? _currentQuote;
  Timer? _quoteRefreshTimer;

  // Güncellenmiş RPC endpoints - daha güvenilir olanlar
  final List<Map<String, dynamic>> _rpcEndpoints = [
    {
      'url': 'https://api.mainnet-beta.solana.com',
      'name': 'Solana Labs',
      'maxTxSize': 1232,
    },
    {
      'url': 'https://rpc.ankr.com/solana',
      'name': 'Ankr',
      'maxTxSize': 1232,
    },
    {
      'url': 'https://solana.public-rpc.com',
      'name': 'Public RPC',
      'maxTxSize': 1232,
    },
  ];

  // Güncellenmiş ve genişletilmiş popüler tokenlar listesi
  final List<Map<String, dynamic>> _popularTokens = [
    {
      'symbol': 'USDC',
      'name': 'USD Coin',
      'address': 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
      'decimals': 6,
      'verified': true,
    },
    {
      'symbol': 'USDT',
      'name': 'Tether USD',
      'address': 'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB',
      'decimals': 6,
      'verified': true,
    },
    {
      'symbol': 'BONK',
      'name': 'Bonk',
      'address': 'DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263',
      'decimals': 5,
      'verified': true,
    },
    {
      'symbol': 'WIF',
      'name': 'dogwifhat',
      'address': 'EKpQGSJtjMFqKZ9KQanSqYXRcF8fBopzLHYxdM65zcjm',
      'decimals': 6,
      'verified': true,
    },
    {
      'symbol': 'JUP',
      'name': 'Jupiter',
      'address': 'JUPyiwrYJFskUPiHa7hkeR8VUtAeFoSYbKedZNsDvCN',
      'decimals': 6,
      'verified': true,
    },
    {
      'symbol': 'RAY',
      'name': 'Raydium',
      'address': '4k3Dyjzvzp8eMZWUXbBCjEvwSkkk59S5iCNLY3QrkX6R',
      'decimals': 6,
      'verified': true,
    },
    {
      'symbol': 'ORCA',
      'name': 'Orca',
      'address': 'orcaEKTdK7LKz57vaAYr9QeNsVEPfiu6QeMU1kektZE',
      'decimals': 6,
      'verified': true,
    },
    {
      'symbol': 'MNGO',
      'name': 'Mango',
      'address': 'MangoCzJ36AjZyKwVj3VnYU4GTonjfVEnJmvvWaxLac',
      'decimals': 6,
      'verified': true,
    },
  ];

  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _fromAmountController.addListener(_onAmountChanged);
    _loadAllTokens(); // Token listesini yükle
    _loadTokenBalances();
    _logWalletInfo();
  }

  void _logWalletInfo() {
    debugPrint('🔑 Mevcut Cüzdan Adresi: ${widget.wallet.address}');
    debugPrint('🔑 Cüzdan Public Key: ${widget.wallet.publicKey}');
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotateController,
      curve: Curves.easeInOut,
    ));

    _slideController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _fromAmountController.removeListener(_onAmountChanged);
    _quoteRefreshTimer?.cancel();
    _slideController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    _fromAmountController.dispose();
    _toAmountController.dispose();
    _contractAddressController.dispose();
    super.dispose();
  }

  // Tüm tokenları yükle - Jupiter token listesinden
  Future<void> _loadAllTokens() async {
    try {
      debugPrint('🔍 Token listesi yükleniyor...');

      final response = await http.get(
        Uri.parse('https://token.jup.ag/all'),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'SolanaSwapApp/1.0',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> tokensData = json.decode(response.body);

        setState(() {
          _allTokens = tokensData.map((tokenData) => TokenInfo(
            address: tokenData['address'] ?? '',
            name: tokenData['name'] ?? 'Unknown Token',
            symbol: tokenData['symbol'] ?? 'UNKNOWN',
            decimals: tokenData['decimals'] ?? 6,
            logoURI: tokenData['logoURI'],
            verified: (tokenData['tags'] as List?)?.contains('verified') ?? false,
          )).toList();
        });

        debugPrint('✅ ${_allTokens.length} token yüklendi');
      }
    } catch (e) {
      debugPrint('❌ Token listesi yükleme hatası: $e');
      // Hata durumunda popüler tokenları kullan
      setState(() {
        _allTokens = _popularTokens.map((token) => TokenInfo(
          address: token['address'],
          name: token['name'],
          symbol: token['symbol'],
          decimals: token['decimals'],
          verified: token['verified'] ?? false,
        )).toList();
      });
    }
  }

  // Glassmorphism container widget'ı
  Widget _buildGlassContainer({
    required Widget child,
    double? width,
    double? height,
    EdgeInsets? padding,
    Color? color,
    double borderRadius = 20,
    double blur = 20,
    double opacity = 0.1,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.orange.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color?.withOpacity(opacity) ?? Colors.orange.withOpacity(opacity),
                  color?.withOpacity(opacity * 0.7) ?? Colors.deepOrange.withOpacity(opacity * 0.5),
                ],
              ),
            ),
            padding: padding ?? const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
  }

  // Başarı dialog'u göster
  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: Colors.transparent,
            contentPadding: EdgeInsets.zero,
            content: _buildGlassContainer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.check_circle, color: Colors.green, size: 32),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Tamam'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Hata dialog'u göster
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: Colors.transparent,
            contentPadding: EdgeInsets.zero,
            content: _buildGlassContainer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.error, color: Colors.red, size: 32),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Tamam'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadTokenBalances() async {
    if (!mounted) return;

    setState(() => _isLoadingBalances = true);

    try {
      debugPrint('🔍 Cüzdan bakiyesi yükleniyor: ${widget.wallet.address}');

      for (final endpoint in _rpcEndpoints) {
        try {
          final response = await http.post(
            Uri.parse(endpoint['url']),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'jsonrpc': '2.0',
              'id': 1,
              'method': 'getBalance',
              'params': [widget.wallet.address],
            }),
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['result'] != null) {
              final balance = data['result']['value'] / 1000000000.0;
              debugPrint('💰 Bakiye yüklendi ${endpoint['name']}: $balance SOL');

              if (mounted) {
                setState(() {
                  _tokenBalances['SOL'] = balance;
                });
              }
              break;
            }
          }
        } catch (e) {
          debugPrint('❌ Bakiye hatası ${endpoint['name']}: $e');
          continue;
        }
      }
    } catch (e) {
      debugPrint('❌ Bakiye yükleme hatası: $e');
      if (mounted) {
        _showErrorDialog('Bakiye Hatası', 'Cüzdan bakiyesi yüklenemedi. Lütfen tekrar deneyin.');
      }
    }

    if (mounted) {
      setState(() => _isLoadingBalances = false);
    }
  }

  void _onAmountChanged() {
    _quoteRefreshTimer?.cancel();

    if (_fromAmountController.text.isNotEmpty &&
        _fromAmountController.text != '0' &&
        _toToken != null) {
      _quoteRefreshTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) {
          _getQuote();
        }
      });
    } else {
      setState(() {
        _toAmountController.text = '';
        _exchangeRate = 0.0;
        _currentQuote = null;
        _priceImpact = 0.0;
        _minimumReceived = 0.0;
      });
    }
  }

  bool _isValidSolanaAddress(String address) {
    try {
      final base58regex = RegExp(r'^[1-9A-HJ-NP-Za-km-z]{32,44}$');
      final trimmed = address.trim();
      if (trimmed.length < 32 || trimmed.length > 44) return false;
      return base58regex.hasMatch(trimmed);
    } catch (e) {
      return false;
    }
  }

  Future<void> _addPopularToken(Map<String, dynamic> tokenData) async {
    final token = TokenInfo(
      address: tokenData['address']!,
      name: tokenData['name']!,
      symbol: tokenData['symbol']!,
      decimals: tokenData['decimals'] ?? 6,
      verified: tokenData['verified'] ?? true,
    );

    setState(() {
      _toToken = token;
      _showAddTokenDialog = false;
    });

    _showSuccessDialog(
      'Token Eklendi',
      '${token.name} (${token.symbol}) başarıyla eklendi ve seçildi.',
    );

    if (_fromAmountController.text.isNotEmpty && _fromAmountController.text != '0') {
      _getQuote();
    }
  }

  // GELİŞTİRİLMİŞ TOKEN EKLEME FONKSİYONU
  Future<void> _addTokenByAddress() async {
    final address = _contractAddressController.text.trim();

    if (address.isEmpty) {
      _showErrorDialog('Eksik Bilgi', 'Lütfen token contract adresini girin.');
      return;
    }

    if (!_isValidSolanaAddress(address)) {
      _showErrorDialog(
        'Geçersiz Adres',
        'Girdiğiniz adres geçerli bir Solana token adresi değil. Lütfen kontrol edin.',
      );
      return;
    }

    setState(() => _isAddingToken = true);

    try {
      debugPrint('🔍 Token aranıyor: $address');

      TokenInfo? foundToken;

      // 1. Önce yüklenen token listesinde ara
      for (final token in _allTokens) {
        if (token.address.toLowerCase() == address.toLowerCase()) {
          foundToken = token;
          debugPrint('✅ Token listede bulundu: ${token.name}');
          break;
        }
      }

      // 2. Listede bulunamazsa Jupiter API'den ara
      if (foundToken == null) {
        debugPrint('🔍 Jupiter API\'den token bilgileri alınıyor...');

        for (int attempt = 1; attempt <= 3; attempt++) {
          try {
            final response = await http.get(
              Uri.parse('https://tokens.jup.ag/token/$address'),
              headers: {
                'Accept': 'application/json',
                'User-Agent': 'SolanaSwapApp/1.0',
                'Cache-Control': 'no-cache'
              },
            ).timeout(const Duration(seconds: 15));

            debugPrint('Jupiter API Response Status: ${response.statusCode}');

            if (response.statusCode == 200) {
              final tokenData = json.decode(response.body);

              foundToken = TokenInfo(
                address: tokenData['address'] ?? address,
                name: tokenData['name'] ?? 'Bilinmeyen Token',
                symbol: tokenData['symbol'] ?? 'UNKNOWN',
                decimals: tokenData['decimals'] ?? 6,
                logoURI: tokenData['logoURI'],
                verified: (tokenData['tags'] as List?)?.contains('verified') ?? false,
              );

              debugPrint('✅ Jupiter API\'den token bilgileri alındı: ${foundToken.name}');
              break;
            } else if (response.statusCode == 404) {
              debugPrint('Token Jupiter API\'de bulunamadı');
              break;
            } else if (attempt < 3) {
              await Future.delayed(Duration(seconds: attempt * 2));
            }
          } catch (e) {
            debugPrint('❌ Jupiter API denemesi $attempt başarısız: $e');
            if (attempt < 3) {
              await Future.delayed(Duration(seconds: attempt));
            }
          }
        }
      }

      // 3. Hala bulunamazsa RPC'den temel bilgileri al
      if (foundToken == null) {
        debugPrint('🔍 RPC\'den token kontrol ediliyor...');

        for (final endpoint in _rpcEndpoints) {
          try {
            final response = await http.post(
              Uri.parse(endpoint['url']),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'jsonrpc': '2.0',
                'id': 1,
                'method': 'getAccountInfo',
                'params': [
                  address,
                  {'encoding': 'base64'}
                ],
              }),
            ).timeout(const Duration(seconds: 10));

            if (response.statusCode == 200) {
              final data = json.decode(response.body);
              if (data['result']?['value'] != null) {
                final shortName = 'Token ${address.substring(0, 6)}...${address.substring(address.length - 4)}';
                final shortSymbol = address.substring(0, 6).toUpperCase();

                foundToken = TokenInfo(
                  address: address,
                  name: shortName,
                  symbol: shortSymbol,
                  decimals: 6, // Varsayılan
                  verified: false,
                );

                debugPrint('✅ RPC\'den temel token bilgileri alındı');
                break;
              }
            }
          } catch (e) {
            debugPrint('❌ RPC hatası ${endpoint['name']}: $e');
            continue;
          }
        }
      }

      if (foundToken != null && mounted) {
        setState(() {
          _toToken = foundToken;
          _showAddTokenDialog = false;
          _contractAddressController.clear();
        });

        _showSuccessDialog(
          'Token Başarıyla Eklendi',
          '${foundToken.name} (${foundToken.symbol}) başarıyla eklendi.\n\n'
              'Adres: ${address.substring(0, 8)}...${address.substring(address.length - 8)}\n'
              'Onaylanmış: ${foundToken.verified ? 'Evet' : 'Hayır'}',
        );

        // Fiyat teklifi al
        if (_fromAmountController.text.isNotEmpty && _fromAmountController.text != '0') {
          await Future.delayed(const Duration(milliseconds: 500));
          _getQuote();
        }
      } else {
        throw Exception('Token bulunamadı veya geçersiz adres');
      }

    } catch (e) {
      debugPrint('❌ Token ekleme hatası: $e');
      if (mounted) {
        _showErrorDialog(
          'Token Eklenemedi',
          'Token eklenirken bir hata oluştu:\n${e.toString()}\n\n'
              'Lütfen token adresini kontrol edin ve tekrar deneyin.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingToken = false);
      }
    }
  }

  // GELİŞTİRİLMİŞ QUOTE ALMA FONKSİYONU
  Future<void> _getQuote() async {
    if (_isLoadingQuote || !mounted || _toToken == null) return;

    setState(() => _isLoadingQuote = true);

    try {
      final fromAmount = double.parse(_fromAmountController.text);
      final fromToken = _predefinedTokens[_fromToken]!;
      final amountInSmallestUnit = (fromAmount * pow(10, fromToken.decimals)).toInt();

      debugPrint('🔍 Quote alınıyor...');
      debugPrint('From: ${fromToken.symbol} (${fromToken.address})');
      debugPrint('To: ${_toToken!.symbol} (${_toToken!.address})');
      debugPrint('Amount: $amountInSmallestUnit');

      Map<String, dynamic>? quoteData;

      // Jupiter Quote API ile fiyat teklifi al
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          debugPrint('🔍 Jupiter quote API denemesi: $attempt/3');

          final uri = Uri.parse('https://quote-api.jup.ag/v6/quote').replace(
            queryParameters: {
              'inputMint': fromToken.address,
              'outputMint': _toToken!.address,
              'amount': amountInSmallestUnit.toString(),
              'slippageBps': '50',
              'onlyDirectRoutes': 'false', // Tüm rotaları dene
              'swapMode': 'ExactIn',
              'maxAccounts': '20',
            },
          );

          debugPrint('Quote URL: $uri');

          final quoteResponse = await http.get(
            uri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'SolanaSwapApp/1.0',
              'Cache-Control': 'no-cache',
            },
          ).timeout(const Duration(seconds: 20));

          debugPrint('📊 Jupiter Quote Response Status: ${quoteResponse.statusCode}');

          if (quoteResponse.statusCode == 200) {
            final responseBody = quoteResponse.body;
            debugPrint('Quote Response Body: ${responseBody.length > 100 ? responseBody.substring(0, 100) + '...' : responseBody}...');

            quoteData = json.decode(responseBody);

            if (quoteData!['error'] != null) {
              throw Exception('Jupiter API Hatası: ${quoteData['error']}');
            }

            if (quoteData['outAmount'] != null) {
              debugPrint('✅ Quote başarıyla alındı');
              break;
            } else {
              throw Exception('Quote response\'da outAmount bulunamadı');
            }
          } else if (quoteResponse.statusCode == 400) {
            final errorBody = quoteResponse.body;
            debugPrint('❌ Bad Request: $errorBody');
            throw Exception('Geçersiz token çifti veya miktar');
          } else if (quoteResponse.statusCode == 429) {
            // Rate limit - bekle ve tekrar dene
            if (attempt < 3) {
              await Future.delayed(Duration(seconds: attempt * 3));
              continue;
            }
          } else {
            debugPrint('❌ HTTP Error: ${quoteResponse.statusCode} - ${quoteResponse.body}');
            if (attempt < 3) {
              await Future.delayed(Duration(seconds: attempt * 2));
              continue;
            }
          }
        } catch (e) {
          debugPrint('❌ Jupiter quote denemesi $attempt başarısız: $e');
          if (attempt == 3) {
            rethrow;
          }
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }

      if (quoteData == null) {
        throw Exception('Fiyat teklifi alınamadı - tüm denemeler başarısız');
      }

      if (quoteData['outAmount'] != null && mounted) {
        final outputAmount = double.parse(quoteData['outAmount']) / pow(10, _toToken!.decimals);

        setState(() {
          _currentQuote = quoteData;
          _toAmountController.text = outputAmount.toStringAsFixed(8);
          _exchangeRate = outputAmount / fromAmount;
          _priceImpact = double.tryParse(quoteData!['priceImpactPct']?.toString() ?? '0') ?? 0.0;
          _minimumReceived = outputAmount * 0.995; // %0.5 slippage
          _networkFee = 0.000005;
        });

        debugPrint('✅ Quote başarıyla işlendi');
        debugPrint('📈 Exchange Rate: $_exchangeRate');
        debugPrint('💥 Price Impact: $_priceImpact%');
        debugPrint('📤 Output Amount: $outputAmount');
      } else {
        throw Exception('Geçersiz quote response');
      }
    } catch (e) {
      debugPrint('❌ Quote fetch error: $e');
      if (mounted) {
        String errorMessage = 'Fiyat bilgisi alınırken hata oluştu:\n${e.toString()}';

        // Daha spesifik hata mesajları
        if (e.toString().contains('Geçersiz token çifti')) {
          errorMessage = 'Bu token çifti için fiyat bilgisi mevcut değil. Farklı bir token deneyin.';
        } else if (e.toString().contains('timeout')) {
          errorMessage = 'Bağlantı zaman aşımına uğradı. Lütfen tekrar deneyin.';
        }

        _showErrorDialog('Fiyat Bilgisi Alınamadı', errorMessage);

        setState(() {
          _toAmountController.text = '';
          _exchangeRate = 0.0;
          _currentQuote = null;
          _priceImpact = 0.0;
          _minimumReceived = 0.0;
        });
      }
    }

    if (mounted) {
      setState(() => _isLoadingQuote = false);
    }
  }

  Future<void> _swapTokens() async {
    if (_fromToken == 'SOL' && _toToken != null) {
      return;
    } else if (_toToken != null) {
      setState(() {
        final tempToken = _toToken;
        _toToken = TokenInfo(
          address: _predefinedTokens[_fromToken]!.address,
          name: _predefinedTokens[_fromToken]!.name,
          symbol: _predefinedTokens[_fromToken]!.symbol,
          decimals: _predefinedTokens[_fromToken]!.decimals,
          verified: _predefinedTokens[_fromToken]!.verified,
        );
        _fromToken = tempToken!.symbol;

        final tempAmount = _fromAmountController.text;
        _fromAmountController.text = _toAmountController.text;
        _toAmountController.text = tempAmount;

        _currentQuote = null;
        _exchangeRate = 0.0;
        _priceImpact = 0.0;
        _minimumReceived = 0.0;
      });

      _rotateController.forward().then((_) {
        _rotateController.reset();
      });

      if (_fromAmountController.text.isNotEmpty && _fromAmountController.text != '0') {
        await Future.delayed(const Duration(milliseconds: 500));
        _getQuote();
      }

      HapticFeedback.lightImpact();
    }
  }

  Future<void> _executeSwap() async {
    if (!mounted || _fromAmountController.text.isEmpty || _currentQuote == null) {
      _showErrorDialog('Eksik Bilgi', 'Lütfen geçerli bir miktar girin.');
      return;
    }

    final fromAmount = double.tryParse(_fromAmountController.text);
    if (fromAmount == null || fromAmount <= 0) {
      _showErrorDialog('Geçersiz Miktar', 'Lütfen geçerli bir miktar girin.');
      return;
    }

    final availableBalance = _tokenBalances[_fromToken] ?? 0.0;
    if (fromAmount > availableBalance) {
      _showErrorDialog(
        'Yetersiz Bakiye',
        'Girdiğiniz miktar mevcut bakiyenizden fazla.\n\n'
            'Mevcut bakiye: ${availableBalance.toStringAsFixed(6)} $_fromToken\n'
            'Girilen miktar: ${fromAmount.toStringAsFixed(6)} $_fromToken',
      );
      return;
    }

    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      debugPrint('🚀 Swap işlemi başlıyor...');

      final result = await _executeSwapTransaction();

      if (result['success'] && mounted) {
        _lastTransactionSignature = result['signature'];

        _showSuccessDialog(
          'Swap Başarılı!',
          'Token takası başarıyla tamamlandı.\n\n'
              'İşlem ID: ${result['signature'].substring(0, 16)}...\n\n'
              'Bakiyeniz birkaç saniye içinde güncellenecek.',
        );

        _fromAmountController.clear();
        _toAmountController.clear();
        setState(() {
          _currentQuote = null;
          _exchangeRate = 0.0;
          _priceImpact = 0.0;
          _minimumReceived = 0.0;
        });

        await Future.delayed(const Duration(seconds: 3));
        await _loadTokenBalances();

        HapticFeedback.heavyImpact();
      } else {
        throw Exception(result['error'] ?? 'Bilinmeyen hata oluştu');
      }
    } catch (e) {
      debugPrint('❌ Swap işlem hatası: $e');
      if (mounted) {
        _showErrorDialog(
          'Swap Hatası',
          'Token takası sırasında hata oluştu:\n${e.toString()}\n\n'
              'Lütfen tekrar deneyin.',
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // Diğer methodlar aynı kalacak - transaction execution vb.
  Future<Map<String, dynamic>> _executeSwapTransaction() async {
    try {
      Map<String, dynamic>? swapData;

      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          final swapResponse = await http.post(
            Uri.parse('https://quote-api.jup.ag/v6/swap'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'User-Agent': 'SolanaSwapApp/1.0',
            },
            body: json.encode({
              'quoteResponse': _currentQuote,
              'userPublicKey': widget.wallet.address,
              'wrapAndUnwrapSol': true,
              'dynamicComputeUnitLimit': true,
              'prioritizationFeeLamports': 1000,
              'asLegacyTransaction': true,
            }),
          ).timeout(const Duration(seconds: 30));

          if (swapResponse.statusCode == 200) {
            swapData = json.decode(swapResponse.body);
            if (swapData!['error'] == null) break;
          }

          if (attempt < 3) {
            await Future.delayed(Duration(seconds: attempt * 2));
          }
        } catch (e) {
          if (attempt == 3) rethrow;
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }

      if (swapData == null || swapData['swapTransaction'] == null) {
        throw Exception('Swap transaction alınamadı');
      }

      final signedTransactionBase64 = await _signTransactionCorrect(swapData['swapTransaction']);
      final result = await _sendSignedTransaction(signedTransactionBase64);

      return result;
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<String> _signTransactionCorrect(String unsignedTransactionBase64) async {
    try {
      final transactionBytes = base64.decode(unsignedTransactionBase64);
      int messageStart = 1;
      final numSignatures = transactionBytes[0];
      messageStart += numSignatures * 64;
      final messageBytes = transactionBytes.sublist(messageStart);
      final signature = await widget.wallet.sign(messageBytes);

      final signedTransactionBytes = <int>[];
      signedTransactionBytes.add(1);
      signedTransactionBytes.addAll(signature.bytes);
      signedTransactionBytes.addAll(messageBytes);

      return base64.encode(signedTransactionBytes);
    } catch (e) {
      throw Exception('İmzalama hatası: $e');
    }
  }

  Future<Map<String, dynamic>> _sendSignedTransaction(String signedTransactionBase64) async {
    try {
      String? signature;
      Exception? lastError;

      for (final endpoint in _rpcEndpoints) {
        try {
          final response = await http.post(
            Uri.parse(endpoint['url']),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({
              'jsonrpc': '2.0',
              'id': DateTime.now().millisecondsSinceEpoch,
              'method': 'sendTransaction',
              'params': [
                signedTransactionBase64,
                {
                  'encoding': 'base64',
                  'preflightCommitment': 'processed',
                  'maxRetries': 2,
                  'skipPreflight': false,
                }
              ],
            }),
          ).timeout(const Duration(seconds: 20));

          if (response.statusCode == 200) {
            final responseData = json.decode(response.body);
            if (responseData['error'] == null) {
              signature = responseData['result'];
              if (signature != null && signature.isNotEmpty) break;
            }
          }
        } catch (e) {
          lastError = e is Exception ? e : Exception(e.toString());
          continue;
        }
      }

      if (signature == null || signature.isEmpty) {
        throw lastError ?? Exception('Tüm RPC endpoint\'leri başarısız');
      }

      return {
        'success': true,
        'signature': signature,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<bool> _showConfirmationDialog() async {
    final priceImpactColor = _priceImpact > 5.0 ? Colors.red :
    _priceImpact > 2.0 ? Colors.orange : Colors.green;

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          content: _buildGlassContainer(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.swap_horiz, color: Colors.orange, size: 32),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Swap Onayı',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildGlassContainer(
                    color: Colors.white,
                    opacity: 0.05,
                    borderRadius: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'İşlem Detayları',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow('Gönderilecek:', '${_fromAmountController.text} $_fromToken'),
                        _buildDetailRow('Alınacak:', '${_toAmountController.text} ${_toToken?.symbol}'),
                        _buildDetailRow('Minimum Alınacak:', '${_minimumReceived.toStringAsFixed(6)} ${_toToken?.symbol}'),
                        _buildDetailRow(
                          'Fiyat Etkisi:',
                          '${_priceImpact.toStringAsFixed(2)}%',
                          valueColor: priceImpactColor,
                        ),
                        _buildDetailRow('Ağ Ücreti:', '~${_networkFee.toStringAsFixed(6)} SOL'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Bu işlem geri alınamaz. Devam etmek istediğinizden emin misiniz?',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                          ),
                          child: const Text('İptal Et'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Swap Yap'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ) ?? false;
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  bool _canSwap() {
    return _fromAmountController.text.isNotEmpty &&
        _currentQuote != null &&
        !_isLoading &&
        !_isLoadingQuote &&
        _toToken != null;
  }

  Widget _buildAddTokenDialog() {
    return _buildGlassContainer(
      width: MediaQuery.of(context).size.width * 0.9,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_circle, color: Colors.orange, size: 28),
              ),
              const SizedBox(width: 12),
              const Text(
                'Token Ekle',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Popular tokens section
          _buildGlassContainer(
            color: Colors.white,
            opacity: 0.05,
            borderRadius: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Popüler Tokenlar',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _popularTokens.map((token) =>
                      GestureDetector(
                        onTap: () => _addPopularToken(token),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                token['symbol']!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                token['name']!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Custom token section
          _buildGlassContainer(
            color: Colors.white,
            opacity: 0.05,
            borderRadius: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Özel Token Ekle',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _contractAddressController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Token Contract Adresi',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: 'Örn: EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.orange.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.orange),
                    ),
                    prefixIcon: const Icon(Icons.link, color: Colors.orange),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _showAddTokenDialog = false;
                      _contractAddressController.clear();
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('İptal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange, Colors.deepOrange],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: _isAddingToken ? null : _addTokenByAddress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isAddingToken
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Text('Token Ekle'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 2.0,
            colors: [
              Colors.orange.withOpacity(0.3),
              Colors.deepOrange.withOpacity(0.2),
              const Color(0xFF0A0A0A),
              Colors.black,
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Background blur effect
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.orange.withOpacity(0.1),
                    Colors.deepOrange.withOpacity(0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            // AppBar
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Token Swap',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _loadTokenBalances,
                      child: AnimatedBuilder(
                        animation: _isLoadingBalances ? _pulseController : kAlwaysCompleteAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _isLoadingBalances ? _pulseAnimation.value : 1.0,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange.withOpacity(0.3)),
                              ),
                              child: const Icon(Icons.refresh, color: Colors.orange),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Main content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 80, 16, 5),
                child: Column(
                  children: [
                    // From section
                    _buildGlassContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Gönderilecek',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  final balance = _tokenBalances[_fromToken] ?? 0.0;
                                  if (balance > 0) {
                                    _fromAmountController.text = balance.toString();
                                    HapticFeedback.lightImpact();
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.orange, Colors.deepOrange],
                                    ),
                                    borderRadius: BorderRadius.circular(25),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.orange.withOpacity(0.2),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    'MAX',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                _isLoadingBalances ? Icons.hourglass_empty : Icons.account_balance_wallet,
                                color: Colors.white70,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Bakiye: ${(_tokenBalances[_fromToken] ?? 0.0).toStringAsFixed(6)} SOL',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.purple, Colors.deepPurple],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.purple.withOpacity(0.3),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.circle, color: Colors.white, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Solana',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    TextField(
                                      controller: _fromAmountController,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: '0.0',
                                        hintStyle: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 28,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Swap button
                    Center(
                      child: GestureDetector(
                        onTap: _swapTokens,
                        child: AnimatedBuilder(
                          animation: _rotateAnimation,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _rotateAnimation.value * 2 * pi,
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.orange, Colors.deepOrange],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.orange.withOpacity(0.4),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.swap_vert,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // To section
                    _buildGlassContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Alınacak (tahmini)',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _showAddTokenDialog = true;
                                  });
                                  HapticFeedback.lightImpact();
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.orange, Colors.deepOrange],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.orange.withOpacity(0.3),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: _toToken != null ? Colors.green.withOpacity(0.2) : Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _toToken != null ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
                                  ),
                                ),
                                child: Icon(
                                  _toToken != null ? Icons.token : Icons.help_outline,
                                  color: _toToken != null ? Colors.green : Colors.white70,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _toToken == null
                                    ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Token Seçin',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Yukarıdaki + butonuna tıklayın',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                )
                                    : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          _toToken!.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                          ),
                                          child: Text(
                                            _toToken!.symbol,
                                            style: const TextStyle(
                                              color: Colors.orange,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        if (_toToken!.verified)
                                          Container(
                                            margin: const EdgeInsets.only(left: 6),
                                            padding: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.verified,
                                              color: Colors.green,
                                              size: 16,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    TextField(
                                      controller: _toAmountController,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      readOnly: true,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // Quote loading indicator
                          if (_isLoadingQuote)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Fiyat hesaplanıyor...',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Price details section
                    if (_currentQuote != null && _toToken != null)
                      _buildGlassContainer(
                        color: Colors.blue,
                        opacity: 0.05,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'İşlem Detayları',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildDetailRow('Döviz Kuru:', '1 $_fromToken = ${_exchangeRate.toStringAsFixed(8)} ${_toToken!.symbol}'),
                            _buildDetailRow(
                              'Fiyat Etkisi:',
                              '${_priceImpact.toStringAsFixed(2)}%',
                              valueColor: _priceImpact > 5.0 ? Colors.red :
                              _priceImpact > 2.0 ? Colors.orange : Colors.green,
                            ),
                            _buildDetailRow('Minimum Alınacak:', '${_minimumReceived.toStringAsFixed(8)} ${_toToken!.symbol}'),
                            _buildDetailRow('Tahmini Ağ Ücreti:', '~${_networkFee.toStringAsFixed(6)} SOL'),
                          ],
                        ),
                      ),

                    const Spacer(),

                    // Main action button
                    Container(
                      width: double.infinity,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _canSwap() ? Colors.orange.withOpacity(0.3) : Colors.white.withOpacity(0.1),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: _canSwap()
                              ? LinearGradient(
                            colors: [Colors.orange, Colors.deepOrange],
                          )
                              : LinearGradient(
                            colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: ElevatedButton(
                          onPressed: _canSwap() ? _executeSwap : () {
                            if (_toToken == null) {
                              setState(() {
                                _showAddTokenDialog = true;
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                              : Text(
                            _canSwap() ? 'SWAP YAP' :
                            _toToken == null ? 'TOKEN SEÇİN' : 'MİKTAR GİRİN',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Security notice
                    _buildGlassContainer(
                      color: Colors.blue,
                      opacity: 0.05,
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.security,
                              color: Colors.blue,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Güvenlik Bildirimi',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Bu swap Solana mainnet üzerinde Jupiter aggregator kullanılarak gerçekleştirilecek. Token contract adreslerini her zaman doğrulayın ve fiyat etkisine dikkat edin. İşlemler geri alınamaz.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Add token dialog overlay
            if (_showAddTokenDialog)
              Container(
                color: Colors.black.withOpacity(0.8),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Center(
                    child: _buildAddTokenDialog(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}