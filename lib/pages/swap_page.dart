import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'dart:ui';
import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:solana/dto.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import 'package:cryptography/cryptography.dart';
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

  TokenInfo _selectedFromTokenInfo = TokenInfo( // Default to SOL
    address: 'So11111111111111111111111111111111111111112',
    name: 'Solana',
    symbol: 'SOL',
    decimals: 9,
    verified: true,
  );
  TokenInfo? _toToken;

  bool _isLoading = false;
  bool _isLoadingQuote = false;
  bool _isLoadingBalances = false;
  bool _isAddingToken = false;
  bool _showAddTokenDialog = false;
  bool _showFromTokenSelectionDialog = false;

  double _exchangeRate = 0.0;
  double _priceImpact = 0.0;
  double _minimumReceived = 0;
  double _networkFee = 0.0;
  double _solBalance = 0.0;

  Map<String, double> _tokenBalances = {};
  List<TokenInfo> _allTokens = [];
  List<TokenInfo> _walletTokens = [];

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

  final List<Map<String, dynamic>> _rpcEndpoints = [
    {
      'url': 'https://mainnet.helius-rpc.com/?api-key=',
      'name': 'Solana Labs',
      'maxTxSize': 1232,
    },
    {
      'url': 'https://api.mainnet-beta.solana.com',
      'name': 'Mainnet Beta RPC',
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

  final List<Map<String, dynamic>> _popularTokens = [
    {
      'symbol': 'USDC',
      'name': 'USD Coin',
      'address': 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
      'decimals': 6,
      'verified': true,
    },
    {
      'symbol': 'SOL',
      'name': 'Solana',
      'address': 'So11111111111111111111111111111111111111112',
      'decimals': 9,
      'verified': true,
    },
    {
      'symbol': 'USDT',
      'name': 'Tether USD',
      'address': 'Es9vMFrzaCERmJfrF4H2cpdgY9SwaJrHwmuqaAccgqgE',
      'decimals': 6,
      'verified': true,
    },
    {
      'symbol': 'BONK',
      'name': 'Bonk',
      'address': 'DezX86zR7PnHcQxJDRrM2DMd1Qh13b2S2s2d2d2d2d2d',
      'decimals': 5,
      'verified': false,
    },
  ];


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
    _loadAllTokens();
    _loadTokenBalances();
    _loadSolBalance();
    _logWalletInfo();
  }

  void _logWalletInfo() {
    debugPrint('🔑 Current Wallet Address: ${widget.wallet.address}');
    debugPrint('🔑 Wallet Public Key: ${widget.wallet.publicKey}');
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

  Future<void> _loadAllTokens() async {
    try {
      debugPrint('🔍 Loading token list...');

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

        debugPrint('✅ ${_allTokens.length} tokens loaded');
      }
    } catch (e) {
      debugPrint('❌ Token list loading error: $e');

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
                      child: Text('OK'.tr()),
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
                      child: Text('OK'.tr()),
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


  Future<Map<String, dynamic>> _getTokenMetadata(String mintAddress) async {
    final token = _allTokens.firstWhere(
          (t) => t.address == mintAddress,
      orElse: () => TokenInfo(
        address: mintAddress,
        name: 'Unknown Token',
        symbol: mintAddress.substring(0, 6),
        decimals: 0,
        verified: false,
      ),
    );
    return {
      'name': token.name,
      'symbol': token.symbol,
      'logoURI': token.logoURI,
      'verified': token.verified,
      'decimals': token.decimals,
    };
  }


  Future<List<Map<String, dynamic>>> fetchTokenBalancesFromHelius(String walletAddress) async {
    const apiKey = '';
    final url = Uri.parse('https://mainnet.helius-rpc.com/?api-key=$apiKey');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "jsonrpc": "2.0",
        "id": "1",
        "method": "getAssetsByOwner",
        "params": {
          "ownerAddress": walletAddress,
          "page": 1,
          "limit": 100,
          "displayOptions": {
            "showFungible": true,
            "showZeroBalance": false,
            "showNativeBalance": false,
          }
        }
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> items = data['result']['items'] ?? [];
      List<Map<String, dynamic>> tokens = [];

      for (var item in items) {
        if (item['token_info'] != null && item['token_info']['balance'] != null) {
          final mint = item['id'];
          final balance = (item['token_info']['balance'] as num).toDouble();
          final decimals = item['token_info']['decimals'] ?? 0;
          final uiAmount = balance / (pow(10, decimals));

          if (uiAmount > 0) {
            final tokenInfo = await _getTokenMetadata(mint);
            tokens.add({
              'mint': mint,
              'balance': uiAmount,
              'decimals': decimals,
              'name': tokenInfo['name'] ?? 'Unknown Token',
              'symbol': tokenInfo['symbol'] ?? mint.substring(0, 6),
              'logoURI': tokenInfo['logoURI'],
              'verified': tokenInfo['verified'] ?? false,
            });
          }
        }
      }
      return tokens;
    } else {
      throw Exception('Helius API error: ${response.statusCode}');
    }
  }

  Future<void> _loadTokenBalances() async {
    if (!mounted) return;

    setState(() => _isLoadingBalances = true);
    _tokenBalances.clear();
    _walletTokens.clear();

    try {
      debugPrint('🔍 Loading wallet balances for: ${widget.wallet.address}');
      final fetchedTokens = await fetchTokenBalancesFromHelius(widget.wallet.address);

      if (mounted) {
        setState(() {
          for (var tokenData in fetchedTokens) {
            final tokenInfo = TokenInfo(
              address: tokenData['mint'],
              name: tokenData['name'],
              symbol: tokenData['symbol'],
              decimals: tokenData['decimals'],
              logoURI: tokenData['logoURI'],
              verified: tokenData['verified'],
            );
            _tokenBalances[tokenInfo.symbol] = tokenData['balance'];
            _walletTokens.add(tokenInfo);
          }


          if (!_walletTokens.any((token) => token.symbol == 'SOL')) {
            _walletTokens.insert(0, _predefinedTokens['SOL']!);

          }


          if (_walletTokens.isNotEmpty) {
            _selectedFromTokenInfo = _walletTokens.firstWhere(
                  (token) => token.symbol == 'SOL',
              orElse: () => _walletTokens.first,
            );
          }
        });
        debugPrint('✅ Wallet balances loaded: $_tokenBalances');
      }
    } catch (e) {
      debugPrint('❌ Balance loading error: $e');
      if (mounted) {
        _showErrorDialog('Balance Error', 'Could not load wallet balances. Please try again.\n$e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingBalances = false);
      }
    }
  }


  Future<void> _loadSolBalance() async {
    if (!mounted) return;

    try {
      print('🔍 Loading SOL balance for wallet: ${widget.wallet.address}');

      final client = SolanaClient(
        rpcUrl: Uri.parse('https://mainnet.helius-rpc.com/?api-key='),
        websocketUrl: Uri.parse('wss://api.mainnet-beta.solana.com'),
      );

      final balance = await client.rpcClient.getBalance(widget.wallet.address);

      print('💰 Raw SOL balance response: $balance');


      const int lamportsPerSol = 1000000000;
      final balanceInSol = balance.value / lamportsPerSol;

      print('💰 Balance in SOL: $balanceInSol');

      if (mounted) {
        setState(() {
          _solBalance = balanceInSol;
          _tokenBalances['SOL'] = _solBalance;
        });
      }
    } catch (e) {
      print('❌ SOL Balance loading error: $e');
      if (mounted) {
        setState(() {
          _solBalance = 0.0;
          _tokenBalances['SOL'] = 0.0;
        });
      }

    }
  }


  void _onAmountChanged() {
    _quoteRefreshTimer?.cancel();

    if (_fromAmountController.text.isNotEmpty &&
        _fromAmountController.text != '0' &&
        _toToken != null &&
        _selectedFromTokenInfo.address != _toToken!.address
    ) {
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


    if (_selectedFromTokenInfo.address == token.address) {
      _showErrorDialog(
        'Invalid Selection',
        'You cannot select the same token for both sending and receiving.',
      );
      return;
    }

    setState(() {
      _toToken = token;
      _showAddTokenDialog = false;
    });

    _showSuccessDialog(
      'Token Added'.tr(),
      '${token.name} (${token.symbol}) successfully added and selected.',
    );
  }

  Future<List<TokenInfo>> fetchRaydiumTokens() async {
    final response = await http.get(Uri.parse('https://api.raydium.io/pairs'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final pairs = data['data'] as List<dynamic>;
      final tokens = <TokenInfo>{};

      for (final pair in pairs) {
        tokens.add(TokenInfo(
          address: pair['baseMint'],
          symbol: pair['baseSymbol'],
          name: pair['baseSymbol'],
          decimals: int.tryParse(pair['baseDecimals'].toString()) ?? 0,
          verified: true,
        ));
        tokens.add(TokenInfo(
          address: pair['quoteMint'],
          symbol: pair['quoteSymbol'],
          name: pair['quoteSymbol'],
          decimals: int.tryParse(pair['quoteDecimals'].toString()) ?? 0,
          verified: true,
        ));
      }

      return tokens.toList();
    } else {
      throw Exception('Raydium token listesi alınamadı');
    }
  }


  Future<void> _addTokenByAddress() async {
    final address = _contractAddressController.text.trim();

    if (address.isEmpty) {
      _showErrorDialog('Missing Information', 'Please enter the token contract address.'.tr());
      return;
    }

    if (!_isValidSolanaAddress(address)) {
      _showErrorDialog(
        'Invalid Address'.tr(),
        'The address you entered is not a valid Solana token address. Please check.'.tr(),
      );
      return;
    }

    setState(() => _isAddingToken = true);

    try {
      debugPrint('🔍 Searching for token: $address');

      TokenInfo? foundToken;


      for (final token in _allTokens) {
        if (token.address.toLowerCase() == address.toLowerCase()) {
          foundToken = token;
          debugPrint('✅ Token found in list: ${token.name}');
          break;
        }
      }


      if (foundToken == null) {
        debugPrint('🔍 Getting token information from Jupiter API...');
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
                name: tokenData['name'] ?? 'Unknown Token',
                symbol: tokenData['symbol'] ?? 'UNKNOWN',
                decimals: tokenData['decimals'] ?? 6,
                logoURI: tokenData['logoURI'],
                verified: (tokenData['tags'] as List?)?.contains('verified') ?? false,
              );

              debugPrint('✅ Token information received from Jupiter API: ${foundToken.name}');
              break;
            } else if (response.statusCode == 404) {
              debugPrint('Token not found in Jupiter API');
              break;
            } else if (attempt < 3) {
              await Future.delayed(Duration(seconds: attempt * 2));
            }
          } catch (e) {
            debugPrint('❌ Jupiter API attempt $attempt failed: $e');
            if (attempt < 3) {
              await Future.delayed(Duration(seconds: attempt));
            }
          }
        }
      }

      if (foundToken == null) {
        debugPrint('🔍 Trying to get token info from Pump.fun APIs...');
        final pumpApis = [
          'https://pumpapi.altlabs.dev/v1/tokens/$address',
          'https://pumpapi.me/api/v1/token/$address',
        ];

        for (final url in pumpApis) {
          try {
            final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
            if (response.statusCode == 200) {
              final data = json.decode(response.body);

              foundToken = TokenInfo(
                address: address,
                name: data['name'] ?? 'Pump.fun Token',
                symbol: data['symbol'] ?? address.substring(0, 4).toUpperCase(),
                decimals: int.tryParse(data['decimals'].toString()) ?? 6,
                logoURI: data['image'] ?? null,
                verified: false,
              );

              debugPrint('✅ Token found via Pump.fun API: ${foundToken.name}');
              break;
            } else {
              debugPrint('Pump.fun API responded with status ${response.statusCode}');
            }
          } catch (e) {
            debugPrint('❌ Pump.fun API error: $e');
          }
        }
      }


      if (foundToken == null) {
        debugPrint('🔍 Checking token from RPC...');

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
                  decimals: 6,
                  verified: false,
                );

                debugPrint('✅ Basic token information received from RPC');
                break;
              }
            }
          } catch (e) {
            debugPrint('❌ RPC error from ${endpoint['name']}: $e');
            continue;
          }
        }
      }


      if (foundToken != null && _selectedFromTokenInfo.address == foundToken.address) {
        _showErrorDialog(
          'Invalid Selection',
          'You cannot select the same token for both sending and receiving.',
        );
        setState(() => _isAddingToken = false);
        return;
      }

      if (foundToken != null && mounted) {
        setState(() {
          _toToken = foundToken;
          _showAddTokenDialog = false;
          _contractAddressController.clear();

          _fromAmountController.clear();
          _toAmountController.clear();
          _currentQuote = null;
          _exchangeRate = 0.0;
          _priceImpact = 0.0;
          _minimumReceived = 0.0;
        });

        _showSuccessDialog(
          'Token Successfully Added'.tr(),
          '${foundToken.name} (${foundToken.symbol}) has been successfully added.\n\n'
              'Address: ${address.substring(0, 8)}...${address.substring(address.length - 8)}\n'
              'Verified: ${foundToken.verified ? 'Yes' : 'No'}',
        );

      } else {
        throw Exception('Token not found or invalid address');
      }

    } catch (e) {
      debugPrint('❌ Token addition error: $e');
      if (mounted) {
        _showErrorDialog(
          'Could Not Add Token',
          'An error occurred while adding the token:\n${e.toString()}\n\n'
              'Please check the token address and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingToken = false);
      }
    }
  }



  Future<void> _getQuote() async {
    if (_isLoadingQuote || !mounted || _toToken == null || _selectedFromTokenInfo == null) return;

    if (_selectedFromTokenInfo.address == _toToken!.address) {
      debugPrint('🚫 Attempted to get quote for same input and output mints. Aborting.');
      setState(() {
        _toAmountController.text = '';
        _exchangeRate = 0.0;
        _currentQuote = null;
        _priceImpact = 0.0;
        _minimumReceived = 0.0;
      });
      _showErrorDialog('Invalid Swap', 'Cannot swap a token for itself.');
      return;
    }

    setState(() => _isLoadingQuote = true);

    try {
      final fromAmount = double.parse(_fromAmountController.text);
      final fromToken = _selectedFromTokenInfo;
      final amountInSmallestUnit = (fromAmount * pow(10, fromToken.decimals)).toInt();

      debugPrint('🔍 Getting quote...');
      debugPrint('From: ${fromToken.symbol} (${fromToken.address})');
      debugPrint('To: ${_toToken!.symbol} (${_toToken!.address})');
      debugPrint('Amount: $amountInSmallestUnit');

      Map<String, dynamic>? quoteData;


      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          debugPrint('🔍 Jupiter quote API attempt: $attempt/3');

          final uri = Uri.parse('https://quote-api.jup.ag/v6/quote').replace(
            queryParameters: {
              'inputMint': fromToken.address,
              'outputMint': _toToken!.address,
              'amount': amountInSmallestUnit.toString(),
              'slippageBps': '50',
              'onlyDirectRoutes': 'false',
              'swapMode': 'ExactIn',
              'maxAccounts': '64',
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
              throw Exception('Jupiter API Error: ${quoteData['error']}');
            }

            if (quoteData['outAmount'] != null) {
              debugPrint('✅ Quote successfully received');
              break;
            } else {
              throw Exception('outAmount not found in Quote response');
            }
          } else if (quoteResponse.statusCode == 400) {
            final errorBody = quoteResponse.body;
            debugPrint('❌ Bad Request: $errorBody');
            throw Exception('Invalid token pair or amount');
          } else if (quoteResponse.statusCode == 429) {

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
          debugPrint('❌ Jupiter quote attempt $attempt failed: $e');
          if (attempt == 3) {
            rethrow;
          }
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }

      if (quoteData == null) {
        throw Exception('Price quote could not be retrieved - all attempts failed');
      }

      if (quoteData['outAmount'] != null && mounted) {
        final outputAmount = double.parse(quoteData['outAmount']) / pow(10, _toToken!.decimals);

        setState(() {
          _currentQuote = quoteData;
          _toAmountController.text = outputAmount.toStringAsFixed(8);
          _exchangeRate = outputAmount / fromAmount;
          _priceImpact = double.tryParse(quoteData!['priceImpactPct']?.toString() ?? '0') ?? 0.0;
          _minimumReceived = outputAmount * 0.995;
          _networkFee = 0.000005;
        });

        debugPrint('✅ Quote successfully processed');
        debugPrint('📈 Exchange Rate: $_exchangeRate');
        debugPrint('💥 Price Impact: $_priceImpact%');
        debugPrint('📤 Output Amount: $outputAmount');
      } else {
        throw Exception('Invalid quote response'); //
      }
    } catch (e) {
      debugPrint('❌ Quote fetch error: $e');
      if (mounted) {
        String errorMessage = 'Error while getting price information:\n${e.toString()}'; //

        if (e.toString().contains('Invalid token pair')) { //
          errorMessage = 'Price information is not available for this token pair. Try a different token.'; //
        } else if (e.toString().contains('timeout')) {
          errorMessage = 'Connection timed out. Please try again.'; //
        }

        _showErrorDialog('Could Not Get Price Information', errorMessage); //
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
    if (_selectedFromTokenInfo == null || _toToken == null) {
      return;
    }

    if (_selectedFromTokenInfo.address == _toToken!.address) {
      _showErrorDialog('Invalid Swap', 'Cannot swap a token for itself.');
      return;
    }

    setState(() {
      final tempFromTokenInfo = _selectedFromTokenInfo;
      final tempToTokenInfo = _toToken;

      _selectedFromTokenInfo = tempToTokenInfo!;
      _toToken = tempFromTokenInfo;

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

  Future<void> _executeSwap() async {
    if (!mounted || _fromAmountController.text.isEmpty) {
      _showErrorDialog('Missing Information', 'Please enter a valid amount.'); //
      return;
    }

    final fromAmount = double.tryParse(_fromAmountController.text);
    if (fromAmount == null || fromAmount <= 0) {
      _showErrorDialog('Invalid Amount', 'Please enter a valid amount.'); //
      return;
    }

    final availableBalance = _tokenBalances[_selectedFromTokenInfo.symbol] ?? 0.0;
    if (fromAmount > availableBalance) {
      _showErrorDialog(
        'Insufficient Balance'.tr(), //
        'The amount you entered exceeds your current balance.\n\n' //
            'Available balance: ${availableBalance.toStringAsFixed(6)} ${_selectedFromTokenInfo.symbol}\n'
            'Entered amount: ${fromAmount.toStringAsFixed(6)} ${_selectedFromTokenInfo.symbol}', //
      );
      return;
    }

    if (_currentQuote == null) {
      setState(() => _isLoadingQuote = true);
      try {
        await _getQuote();
      } catch (e) {
        setState(() => _isLoadingQuote = false);
        _showErrorDialog('Quote Error', 'Could not get a price quote. Please try again.');
        return;
      } finally {
        setState(() => _isLoadingQuote = false);
      }
      if (_currentQuote == null) {
        _showErrorDialog('Quote Error', 'Failed to get a price quote. Cannot proceed with swap.');
        return;
      }
    }

    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      debugPrint('🚀 Starting swap operation...'.tr()); //

      final result = await _executeSwapTransaction();

      if (result['success'] && mounted) {
        _lastTransactionSignature = result['signature'];

        _showSuccessDialog(
          'Swap Successful!'.tr(), //
          'Token swap completed successfully.\n\n' //
              'Transaction ID: ${result['signature'].substring(0, 16)}...\n\n'
              'Your balance will be updated in a few seconds.', //
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
        await _loadSolBalance();

        HapticFeedback.heavyImpact();
      } else {
        throw Exception(result['error'] ?? 'Unknown error occurred'); //
      }
    } catch (e) {
      debugPrint('❌ Swap transaction error: $e'); //
      if (mounted) {
        _showErrorDialog(
          'Swap Error', //
          'An error occurred during token swap:\n${e.toString()}\n\n' //
              'Please try again.', //
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

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
              'asLegacyTransaction': false,
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
        throw Exception('Swap transaction could not be retrieved'); //
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
      throw Exception('Signing error: $e'); //
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
        throw lastError ?? Exception('All RPC endpoints failed'); //
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
                      Text(
                        'Swap Confirmation'.tr(),
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
                        Text(
                          'Transaction Details'.tr(),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow('Sending:', '${_fromAmountController.text} ${_selectedFromTokenInfo.symbol}'), //
                        _buildDetailRow('Receiving:', '${_toAmountController.text} ${_toToken?.symbol}'), //
                        _buildDetailRow('Minimum Received:', '${_minimumReceived.toStringAsFixed(6)} ${_toToken?.symbol}'), //
                        _buildDetailRow(
                          'Price Impact:', //
                          '${_priceImpact.toStringAsFixed(2)}%',
                          valueColor: priceImpactColor,
                        ),
                        _buildDetailRow('Network Fee:', '~${_networkFee.toStringAsFixed(6)} SOL'), //
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
                        Expanded(
                          child: Text(
                            'This transaction is irreversible. Are you sure you want to proceed?'.tr(),
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
                          child:  Text('Cancel'.tr()),
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
                          child:  Text('Swap'.tr()),
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
        !_isLoading &&
        !_isLoadingQuote &&
        _toToken != null &&
        _selectedFromTokenInfo != null &&
        _selectedFromTokenInfo.address != _toToken!.address;
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
              Text(
                'Add Token'.tr(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
                Text(
                  'Add Custom Token'.tr(),
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
                    labelText: 'Token Contract Address'.tr(),
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: 'Ex: EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v', //
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
                  child:  Text('Cancel'.tr()),
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
                        :  Text('Add Token'.tr()),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFromTokenSelectionDialog() {
    return _buildGlassContainer(
      width: MediaQuery.of(context).size.width * 0.9,
      height: MediaQuery.of(context).size.height * 0.7,
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
                child: const Icon(Icons.token, color: Colors.orange, size: 28),
              ),
              const SizedBox(width: 12),
              Text(
                'Select Token to Send'.tr(), //
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _isLoadingBalances
              ? const Center(
            child: CircularProgressIndicator(color: Colors.orange),
          )
              : _walletTokens.isEmpty
              ? Expanded(
            child: Center(
              child: Text(
                'No tokens found in your wallet.'.tr(),
                style: TextStyle(color: Colors.white70),
              ),
            ),
          )
              : Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _walletTokens.length,
              itemBuilder: (context, index) {
                final token = _walletTokens[index];
                final balance = _tokenBalances[token.symbol] ?? 0.0;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedFromTokenInfo = token;
                      _showFromTokenSelectionDialog = false;
                      _fromAmountController.clear();
                      _toAmountController.clear();
                      _currentQuote = null;
                      _exchangeRate = 0.0;
                      _priceImpact = 0.0;
                      _minimumReceived = 0.0;


                      if (_selectedFromTokenInfo.symbol != 'SOL') {
                        _toToken = _predefinedTokens['SOL'];
                      } else {
                        _toToken = null;
                      }
                    });
                    HapticFeedback.lightImpact();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: _buildGlassContainer(
                      color: Colors.white,
                      opacity: 0.05,
                      borderRadius: 12,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: Row(
                        children: [

                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: token.logoURI != null && token.logoURI!.isNotEmpty
                                ? ClipOval(
                              child: Image.network(
                                token.logoURI!,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Icon(Icons.token, color: Colors.white70),
                              ),
                            )
                                : Icon(Icons.token, color: Colors.white70),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      token.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
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
                                        token.symbol,
                                        style: const TextStyle(
                                          color: Colors.orange,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (token.verified)
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
                                Text(
                                  'Balance: ${balance.toStringAsFixed(6)}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_selectedFromTokenInfo.address == token.address)
                            const Icon(Icons.check_circle, color: Colors.green, size: 24),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _showFromTokenSelectionDialog = false;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Close'.tr()),
            ),
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
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF000000),
                const Color(0xFF1A1A1A),
                const Color(0xFF2D1810),
                const Color(0xFF1A1A1A),
              ],
            ),
          ),
          child: Stack(
            children: [

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


              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
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
                        Text(
                          'Token Swap'.tr(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            _loadTokenBalances();
                            _loadSolBalance();
                          },
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
              ),


              Padding(
                padding: const EdgeInsets.only(top: 80.0),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Column(
                    children: [
                      _buildGlassContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'You send'.tr(),
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Spacer(),
                                GestureDetector(
                                  onTap: () {
                                    final balance = _tokenBalances[_selectedFromTokenInfo.symbol] ?? 0.0;
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
                                    child: Text(
                                      'MAX'.tr(),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 15,),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _showFromTokenSelectionDialog = true;
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
                                  'Balance: ${(_tokenBalances[_selectedFromTokenInfo.symbol] ?? 0.0).toStringAsFixed(6)} ${_selectedFromTokenInfo.symbol}', // Updated
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
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _showFromTokenSelectionDialog = true;
                                    });
                                    HapticFeedback.lightImpact();
                                  },
                                  child: Container(
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
                                    child: _selectedFromTokenInfo.logoURI != null && _selectedFromTokenInfo.logoURI!.isNotEmpty
                                        ? ClipOval(
                                      child: Image.network(
                                        _selectedFromTokenInfo.logoURI!,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.token, color: Colors.white, size: 24),
                                      ),
                                    )
                                        : const Icon(Icons.token, color: Colors.white, size: 24),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            _selectedFromTokenInfo.name,
                                            style: TextStyle(
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
                                              _selectedFromTokenInfo.symbol,
                                              style: const TextStyle(
                                                color: Colors.orange,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (_selectedFromTokenInfo.verified)
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

                      const SizedBox(height: 5),

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

                      const SizedBox(height: 5),


                      _buildGlassContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'You receive (estimated)'.tr(),
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
                            const SizedBox(height: 5),
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
                                  child: _toToken != null && _toToken!.logoURI != null && _toToken!.logoURI!.isNotEmpty
                                      ? ClipOval(
                                    child: Image.network(
                                      _toToken!.logoURI!,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Icon(Icons.token, color: Colors.white70),
                                    ),
                                  )
                                      : Icon(
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
                                      Text(
                                        'Select Token'.tr(),
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Click the + button above'.tr(),
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
                                    Text(
                                      'Calculating price...'.tr(),
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
                                  Text(
                                    'Transaction Details'.tr(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildDetailRow('Exchange Rate:', '1 ${_selectedFromTokenInfo.symbol} = ${_exchangeRate.toStringAsFixed(8)} ${_toToken!.symbol}'),
                              _buildDetailRow(
                                'Price Impact:',
                                '${_priceImpact.toStringAsFixed(2)}%',
                                valueColor: _priceImpact > 5.0 ? Colors.red :
                                _priceImpact > 2.0 ? Colors.orange : Colors.green,
                              ),
                              _buildDetailRow('Minimum Received:', '${_minimumReceived.toStringAsFixed(8)} ${_toToken!.symbol}'),
                              _buildDetailRow('Estimated Network Fee:', '~${_networkFee.toStringAsFixed(6)} SOL'),
                            ],
                          ),
                        ),

                      const SizedBox(height: 24),

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
                              } else if (_selectedFromTokenInfo == null) {
                                setState(() {
                                  _showFromTokenSelectionDialog = true;
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
                              _canSwap() ? 'SWAP'.tr() :
                              _toToken == null ? 'SELECT RECEIVE TOKEN'.tr() :
                              _selectedFromTokenInfo == null ? 'SELECT SEND TOKEN'.tr() : 'ENTER AMOUNT'.tr(), // Updated
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Security Notice'.tr(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'This swap will be performed on the Solana mainnet using the Jupiter aggregator. Always verify token contract addresses and be aware of price impact. Transactions are irreversible.'.tr(), // Translated
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

              // Select From Token dialog overlay
              if (_showFromTokenSelectionDialog)
                Container(
                  color: Colors.black.withOpacity(0.8),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Center(
                      child: _buildFromTokenSelectionDialog(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class TokenInfo {
  final String address;
  final String name;
  final String symbol;
  final int decimals;
  final String? logoURI;
  final bool verified;

  TokenInfo({
    required this.address,
    required this.name,
    required this.symbol,
    required this.decimals,
    this.logoURI,
    this.verified = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is TokenInfo &&
              runtimeType == other.runtimeType &&
              address == other.address;

  @override
  int get hashCode => address.hashCode;
}