import 'dart:ui';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solana/dto.dart';
import 'package:solana/solana.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import 'transaction_history_page.dart';
import 'send_page.dart';
import 'receive_page.dart';
import 'swap_page.dart';
import 'nft_page.dart';
import 'charts_page.dart';
import 'settings_page.dart';
import '../providers/app_provider.dart';
import '../services/rpc_service.dart';

class TokenInfo {
  final String mint;
  final String name;
  final String symbol;
  final double balance;
  final int decimals;
  final String? logoUri;
  final double? price;
  final double? change24h;

  TokenInfo({
    required this.mint,
    required this.name,
    required this.symbol,
    required this.balance,
    required this.decimals,
    this.logoUri,
    this.price,
    this.change24h,
  });
}

class DashboardPage extends StatefulWidget {
  final Ed25519HDKeyPair wallet;

  const DashboardPage({super.key, required this.wallet});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  double _solBalance = 0.0;
  bool _isLoading = true;
  bool _showFullAddress = false;

  late AnimationController _refreshController;
  late AnimationController _cardController;
  late AnimationController _pulseController;
  late AnimationController _loadingController;
  late Animation<double> _cardAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  double _solPrice = 180.0;
  double _dailyChange = 0.0;
  double _weeklyChange = 0.0;
  double _monthlyChange = 0.0;
  double _dailyVolume = 2000000000;
  double _marketCap = 85000000000;

  double _walletDailyChange = 0.0;
  double _walletWeeklyChange = 0.0;
  double _walletMonthlyChange = 0.0;

  int _transactionCount = 0;
  bool _isLoadingStats = true;
  List<Map<String, dynamic>> _recentTransactions = [];

  // Token-related variables
  List<TokenInfo> _tokens = [];
  bool _isLoadingTokens = true;
  double _totalPortfolioValue = 0.0;

  String _networkStatus = '';
  bool _isNetworkConnected = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllData();
    });
  }

  void _initializeAnimations() {
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _cardController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _cardAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOutCubic),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.linear),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.elasticOut),
    );

    _cardController.forward();
    _pulseController.repeat(reverse: true);
    _loadingController.repeat();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _cardController.dispose();
    _pulseController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);

    setState(() {
      _isLoading = true;
      _isLoadingStats = true;
      _isLoadingTokens = true;
      _networkStatus = l10n?.connecting ?? 'Connecting...';
    });

    _refreshController.repeat();

    try {
      RpcService.resetToFirstEndpoint();

      await _loadBalance();
      if (!mounted) return;

      await _loadTokens();
      if (!mounted) return;

      await _loadSolPriceData();
      if (!mounted) return;

      await _loadTransactionHistory();
      if (!mounted) return;

      setState(() {
        _isNetworkConnected = true;
        _networkStatus = l10n?.connected ?? 'Connected';
        _retryCount = 0;
      });
    } catch (e) {
      print('❌ Data loading error: $e');

      if (mounted) {
        setState(() {
          _isNetworkConnected = false;
          _networkStatus = l10n?.connectionError ?? 'Connection Error';
          _retryCount++;

          if (_retryCount >= _maxRetries) {
            _networkStatus = l10n?.offlineMode ?? 'Offline Mode';
          }
        });
      }
    }

    _calculateWalletChanges();
    _calculateTotalPortfolioValue();

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isLoadingStats = false;
        _isLoadingTokens = false;
      });
    }

    _refreshController.stop();
    _refreshController.reset();
  }

  Future<void> _loadBalance() async {
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);

    try {
      setState(() {
        _networkStatus = l10n?.loadingBalance ?? 'Loading balance...';
      });

      final response = await RpcService.executeWithFallback<BalanceResult>(
            (client) => client.getBalance(widget.wallet.address),
      );

      if (mounted) {
        setState(() {
          _solBalance = response.value / 1000000000;
          _networkStatus = l10n?.balanceLoaded ?? 'Balance loaded';
        });
      }

    } catch (e) {
      print('❌ Balance loading error: $e');
      if (mounted) {
        setState(() {
          _networkStatus = l10n?.balanceLoadFailed ?? 'Balance error';
        });
      }
      rethrow;
    }
  }

  Future<void> _loadTokens() async {
    if (!mounted) return;

    try {
      setState(() {
        _networkStatus = 'Loading tokens...';
        _isLoadingTokens = true;
      });

      // Basit ve güvenli yaklaşım - popüler token'ları manuel kontrol et
      final knownTokens = [
        {
          'mint': 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
          'name': 'USD Coin',
          'symbol': 'USDC',
          'decimals': 6,
          'logoUri': 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v/logo.png',
        },
        {
          'mint': 'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB',
          'name': 'Tether USD',
          'symbol': 'USDT',
          'decimals': 6,
          'logoUri': 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB/logo.png',
        },
        {
          'mint': 'So11111111111111111111111111111111111111112',
          'name': 'Wrapped SOL',
          'symbol': 'wSOL',
          'decimals': 9,
          'logoUri': 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/So11111111111111111111111111111111111111112/logo.png',
        },
        {
          'mint': 'mSoLzYCxHdYgdzU16g5QSh3i5K3z3KZK7ytfqcJm7So',
          'name': 'Marinade staked SOL',
          'symbol': 'mSOL',
          'decimals': 9,
          'logoUri': 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/mSoLzYCxHdYgdzU16g5QSh3i5K3z3KZK7ytfqcJm7So/logo.png',
        },
        {
          'mint': '7vfCXTUXx5WJV5JADk17DUJ4ksgau7utNKj4b963voxs',
          'name': 'Ethereum (Wormhole)',
          'symbol': 'ETH',
          'decimals': 8,
          'logoUri': 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/7vfCXTUXx5WJV5JADk17DUJ4ksgau7utNKj4b963voxs/logo.png',
        },
      ];

      List<TokenInfo> validTokens = [];

      for (final tokenData in knownTokens) {
        try {
          // Token hesaplarını kontrol et
          final tokenAccounts = await RpcService.executeWithFallback<ProgramAccountsResult>(
                (client) => client.getTokenAccountsByOwner(
              widget.wallet.address,
              TokenAccountsFilter.byMint(tokenData['mint'] as String),
              commitment: Commitment.confirmed,
            ),
          );

          if (tokenAccounts.value.isNotEmpty) {
            // İlk token hesabının balance'ını al
            final tokenAccount = tokenAccounts.value.first;
            final balanceResult = await RpcService.executeWithFallback<TokenAmountResult>(
                  (client) => client.getTokenAccountBalance(
                tokenAccount.pubkey,
                commitment: Commitment.confirmed,
              ),
            );

            // Balance değerini hesapla
            final amount = double.tryParse(balanceResult.value.amount) ?? 0.0;
            final decimals = balanceResult.value.decimals;
            final balance = amount / pow(10, decimals);

            if (balance > 0) {
              // Token metadata'sını al
              final tokenInfo = await _getTokenMetadata(tokenData['mint'] as String);

              validTokens.add(TokenInfo(
                mint: tokenData['mint'] as String,
                name: tokenData['name'] as String,
                symbol: tokenData['symbol'] as String,
                balance: balance,
                decimals: decimals,
                logoUri: tokenData['logoUri'] as String?,
                price: tokenInfo['price'],
                change24h: tokenInfo['change24h'],
              ));
            }
          }
        } catch (e) {
          print('❌ ${tokenData['symbol']} kontrol hatası: $e');
          continue;
        }
      }

      if (mounted) {
        setState(() {
          _tokens = validTokens;
          _networkStatus = validTokens.isEmpty ? 'No tokens found' : 'Tokens loaded';
          _isLoadingTokens = false;
        });
      }

    } catch (e) {
      print('❌ Token yükleme hatası: $e');
      if (mounted) {
        setState(() {
          _tokens = [];
          _networkStatus = 'Token loading failed';
          _isLoadingTokens = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _getTokenMetadata(String mint) async {
    try {
      // CoinGecko'dan fiyat bilgisi almaya çalış
      final priceResponse = await http.get(
        Uri.parse('https://api.coingecko.com/api/v3/simple/token_price/solana?contract_addresses=$mint&vs_currencies=usd&include_24hr_change=true'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (priceResponse.statusCode == 200) {
        final priceData = json.decode(priceResponse.body);
        if (priceData[mint] != null) {
          return {
            'price': priceData[mint]['usd']?.toDouble(),
            'change24h': priceData[mint]['usd_24h_change']?.toDouble(),
          };
        }
      }
    } catch (e) {
      print('❌ Token metadata hatası: $e');
    }

    // Varsayılan değerler
    return {
      'price': null,
      'change24h': null,
    };
  }

  Future<void> _loadSolPriceData() async {
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);

    try {
      setState(() {
        _networkStatus = l10n?.loadingPriceData ?? 'Loading price data...';
      });

      final endpoints = [
        'https://api.coingecko.com/api/v3/simple/price?ids=solana&vs_currencies=usd&include_24hr_change=true&include_7d_change=true&include_30d_change=true&include_24hr_vol=true&include_market_cap=true',
        'https://api.binance.com/api/v3/ticker/24hr?symbol=SOLUSDT',
      ];

      bool success = false;

      for (final endpoint in endpoints) {
        if (!mounted) return;

        try {
          final priceResponse = await http.get(
            Uri.parse(endpoint),
            headers: {
              'User-Agent': 'ViperWallet/1.0',
              'Accept': 'application/json',
            },
          ).timeout(const Duration(seconds: 8));

          if (priceResponse.statusCode == 200 && mounted) {
            if (endpoint.contains('coingecko')) {
              final priceData = json.decode(priceResponse.body);
              setState(() {
                _solPrice = priceData['solana']['usd'].toDouble();
                _dailyChange = priceData['solana']['usd_24h_change']?.toDouble() ?? 0.0;
                _weeklyChange = priceData['solana']['usd_7d_change']?.toDouble() ?? 0.0;
                _monthlyChange = priceData['solana']['usd_30d_change']?.toDouble() ?? 0.0;
                _dailyVolume = priceData['solana']['usd_24h_vol']?.toDouble() ?? 0.0;
                _marketCap = priceData['solana']['usd_market_cap']?.toDouble() ?? 0.0;
                _networkStatus = l10n?.priceDataLoaded ?? 'Price data loaded';
              });
              success = true;
              break;
            }
          }
        } catch (e) {
          print('❌ Price API error ($endpoint): $e');
          continue;
        }
      }

      if (!success) {
        throw Exception('All price APIs failed');
      }

    } catch (e) {
      print('❌ Price loading error: $e');
      if (mounted) {
        setState(() {
          _networkStatus = 'Price data offline';
        });
      }
      rethrow;
    }
  }

  void _calculateWalletChanges() {
    _walletDailyChange = (_solBalance * _solPrice * _dailyChange / 100);
    _walletWeeklyChange = (_solBalance * _solPrice * _weeklyChange / 100);
    _walletMonthlyChange = (_solBalance * _solPrice * _monthlyChange / 100);
  }

  void _calculateTotalPortfolioValue() {
    double totalValue = _solBalance * _solPrice;

    for (final token in _tokens) {
      if (token.price != null) {
        totalValue += token.balance * token.price!;
      }
    }

    _totalPortfolioValue = totalValue;
  }

  Future<void> _loadTransactionHistory() async {
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);

    try {
      setState(() {
        _networkStatus = l10n?.loadingTransactionHistory ?? 'Loading transaction history...';
      });

      final signatures = await RpcService.executeWithFallback<List<TransactionSignatureInformation>>(
            (client) => client.getSignaturesForAddress(widget.wallet.address, limit: 5),
      );

      if (mounted) {
        setState(() {
          _transactionCount = signatures.length;
          _recentTransactions = signatures.map((sig) => {
            'signature': sig.signature,
            'slot': sig.slot,
            'blockTime': sig.blockTime,
            'confirmationStatus': sig.confirmationStatus,
            'err': sig.err,
          }).toList();
          _networkStatus = l10n?.transactionHistoryLoaded ?? 'Transaction history loaded';
        });
      }

    } catch (e) {
      print('❌ Transaction history loading error: $e');
      if (mounted) {
        setState(() {
          _transactionCount = 0;
          _recentTransactions = [];
          _networkStatus = 'Transaction history offline';
        });
      }
      rethrow;
    }
  }

  void _copyAddress() {
    final l10n = AppLocalizations.of(context);

    Clipboard.setData(ClipboardData(text: widget.wallet.address));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(l10n?.addressCopied ?? 'Address copied to clipboard'),
          ],
        ),
        backgroundColor: const Color(0xFFFF6B35),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _formatAddress(String address) {
    if (!_showFullAddress) {
      return '${address.substring(0, 6)}...${address.substring(address.length - 6)}';
    }
    return address;
  }

  String _formatCurrency(double value) {
    if (value.abs() >= 1000000000) {
      return '\$${(value / 1000000000).toStringAsFixed(2)}B';
    } else if (value.abs() >= 1000000) {
      return '\$${(value / 1000000).toStringAsFixed(2)}M';
    } else if (value.abs() >= 1000) {
      return '\$${(value / 1000).toStringAsFixed(2)}K';
    } else {
      return '\$${value.toStringAsFixed(2)}';
    }
  }

  String _formatDate(int? blockTime) {
    if (blockTime == null) return AppLocalizations.of(context)?.unknown ?? 'Unknown';
    final date = DateTime.fromMillisecondsSinceEpoch(blockTime * 1000);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildGlassCard({
    required Widget child,
    Color? borderColor,
    List<Color>? gradientColors,
    double? height,
    EdgeInsets? padding,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            height: height,
            padding: padding,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: borderColor ?? const Color(0xFFFF6B35).withOpacity(0.2),
                width: 1,
              ),
              gradient: gradientColors != null
                  ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors.map((c) => c.withOpacity(0.1)).toList(),
              )
                  : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final l10n = AppLocalizations.of(context);
    final totalValue = _solBalance * _solPrice;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
          ).createShader(bounds),
          child: Text(
            l10n?.appTitle ?? 'Viper Wallet',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (_isNetworkConnected ? Colors.green : Colors.orange).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (_isNetworkConnected ? Colors.green : Colors.orange).withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isNetworkConnected ? Icons.wifi : Icons.wifi_off,
                  color: _isNetworkConnected ? Colors.green : Colors.orange,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _isNetworkConnected ? (l10n?.online ?? 'Online') : (l10n?.offline ?? 'Offline'),
                  style: TextStyle(
                    color: _isNetworkConnected ? Colors.green : Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: (isDark ? Colors.black : Colors.white).withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFF6B35).withOpacity(0.3),
              ),
            ),
            child: IconButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsPage(),
                  ),
                );
              },
              icon: const Icon(
                Icons.settings,
                color: Color(0xFFFF6B35),
              ),
            ),
          ),
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
              onPressed: _isLoading ? null : () {
                HapticFeedback.mediumImpact();
                RpcService.resetToFirstEndpoint();
                _loadAllData();
              },
              icon: RotationTransition(
                turns: _refreshController,
                child: const Icon(
                  Icons.refresh,
                  color: Color(0xFFFF6B35),
                ),
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
              const Color(0xFF1A1A1A),
            ]
                : [
              const Color(0xFFFAFAFA),
              const Color(0xFFF5F5F5),
              const Color(0xFFFFF5F0),
              const Color(0xFFFAFAFA),
            ],
          ),
        ),
        child: _isLoading
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: RotationTransition(
                  turns: _rotationAnimation,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFF6B35),
                          Color(0xFFFF8C42),
                          Color(0xFFFFB347),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B35).withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                        ),
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.2),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              ScaleTransition(
                scale: _pulseAnimation,
                child: Text(
                  l10n?.loading ?? 'Loading...',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFF6B35).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  _networkStatus,
                  style: TextStyle(
                    color: (isDark ? Colors.white : Colors.black87).withOpacity(0.8),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return AnimatedBuilder(
                    animation: _loadingController,
                    builder: (context, child) {
                      final delay = index * 0.2;
                      final animationValue = (_loadingController.value - delay).clamp(0.0, 1.0);
                      final scale = sin(animationValue * pi) * 0.5 + 0.5;

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFF6B35).withOpacity(0.7),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        )
            : SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 20),

                    FadeTransition(
                      opacity: _cardAnimation,
                      child: _buildMainBalanceCard(totalValue, isDark, l10n),
                    ),

                    const SizedBox(height: 28),

                    _buildQuickActions(l10n),

                    //const SizedBox(height: 40),

                    // Token List Section
                    //_buildTokenListSection(isDark),

                    const SizedBox(height: 40),

                    if (_isNetworkConnected) ...[
                      _buildMarketDataSection(isDark, l10n),
                      const SizedBox(height: 28),
                      _buildPriceChangesSection(isDark, l10n),
                      const SizedBox(height: 28),
                    ],

                    if (_recentTransactions.isNotEmpty) ...[
                      _buildRecentTransactionsSection(isDark, l10n),
                      const SizedBox(height: 28),
                    ],

                    _buildWalletAddressCard(isDark, l10n),

                    const SizedBox(height: 120),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainBalanceCard(double totalValue, bool isDark, AppLocalizations? l10n) {
    return _buildGlassCard(
      gradientColors: [const Color(0xFFFF6B35), const Color(0xFFFF8C42)],
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Total Portfolio',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCurrency(_totalPortfolioValue),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              '${_solBalance.toStringAsFixed(6)} SOL',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.bold,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '≈ ${_formatCurrency(totalValue)}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            if (!_isNetworkConnected) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n?.noNetworkConnection ?? 'No network connection. Running in offline mode.',
                        style: TextStyle(
                          color: Colors.orange.shade100,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: (_walletDailyChange >= 0 ? Colors.green : Colors.red).withOpacity(0.25),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _walletDailyChange >= 0 ? Icons.trending_up : Icons.trending_down,
                          color: _walletDailyChange >= 0 ? Colors.green : Colors.red,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_walletDailyChange >= 0 ? '+' : ''}${_formatCurrency(_walletDailyChange)}',
                          style: TextStyle(
                            color: _walletDailyChange >= 0 ? Colors.green : Colors.red,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(24h)',
                          style: TextStyle(
                            color: (_walletDailyChange >= 0 ? Colors.green : Colors.red).withOpacity(0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(AppLocalizations? l10n) {
    return RepaintBoundary(
      child: GridView.count(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.9,
        children: [
          _buildActionButton(
            icon: Icons.send_rounded,
            label: l10n?.send ?? 'Send',
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SendPage(wallet: widget.wallet),
                ),
              );
            },
          ),
          _buildActionButton(
            icon: Icons.qr_code_rounded,
            label: l10n?.receive ?? 'Receive',
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReceivePage(wallet: widget.wallet),
                ),
              );
            },
            color: Colors.green,
          ),
          _buildActionButton(
            icon: Icons.swap_horiz_rounded,
            label: l10n?.swap ?? 'Swap',
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SwapPage(wallet: widget.wallet),
                ),
              );
            },
            color: Colors.purple,
          ),
          _buildActionButton(
            icon: Icons.history_rounded,
            label: l10n?.history ?? 'History',
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TransactionHistoryPage(
                    wallet: widget.wallet,
                    transactions: _recentTransactions,
                  ),
                ),
              );
            },
            color: Colors.blue,
          ),
          _buildActionButton(
            icon: Icons.image_rounded,
            label: l10n?.nft ?? 'NFT',
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NFTPage(wallet: widget.wallet),
                ),
              );
            },
            color: Colors.pink,
          ),
          _buildActionButton(
            icon: Icons.show_chart_rounded,
            label: l10n?.charts ?? 'Charts',
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChartsPage(
                    solPrice: _solPrice,
                    dailyChange: _dailyChange,
                    weeklyChange: _weeklyChange,
                    monthlyChange: _monthlyChange,
                  ),
                ),
              );
            },
            color: Colors.teal,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: _buildGlassCard(
        gradientColors: [
          color ?? const Color(0xFFFF6B35),
          (color ?? const Color(0xFFFF6B35)).withOpacity(0.7)
        ],
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTokenListSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Tokens',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFF6B35).withOpacity(0.3),
                ),
              ),
              child: Text(
                '${_tokens.length} tokens',
                style: const TextStyle(
                  color: Color(0xFFFF6B35),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoadingTokens)
          _buildGlassCard(
            child: const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading tokens...',
                      style: TextStyle(
                        color: Color(0xFFFF6B35),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (_tokens.isEmpty)
          _buildGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.token,
                      size: 48,
                      color: (isDark ? Colors.white : Colors.black87).withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No tokens found',
                      style: TextStyle(
                        color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your tokens will appear here',
                      style: TextStyle(
                        color: (isDark ? Colors.white : Colors.black87).withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          RepaintBoundary(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _tokens.length,
              itemBuilder: (context, index) {
                return _buildTokenItem(_tokens[index], isDark);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildTokenItem(TokenInfo token, bool isDark) {
    final tokenValue = token.price != null ? token.balance * token.price! : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: _buildGlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Token Logo
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF6B35).withOpacity(0.1),
                  border: Border.all(
                    color: const Color(0xFFFF6B35).withOpacity(0.2),
                  ),
                ),
                child: token.logoUri != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.network(
                    token.logoUri!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildTokenFallbackIcon(token.symbol);
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFF6B35),
                            ),
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                )
                    : _buildTokenFallbackIcon(token.symbol),
              ),

              const SizedBox(width: 16),

              // Token Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            token.name,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (token.change24h != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (token.change24h! >= 0 ? Colors.green : Colors.red)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  token.change24h! >= 0
                                      ? Icons.trending_up
                                      : Icons.trending_down,
                                  color: token.change24h! >= 0 ? Colors.green : Colors.red,
                                  size: 12,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${token.change24h! >= 0 ? '+' : ''}${token.change24h!.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: token.change24h! >= 0 ? Colors.green : Colors.red,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          token.symbol,
                          style: TextStyle(
                            color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (token.price != null)
                          Text(
                            '\$${token.price!.toStringAsFixed(4)}',
                            style: TextStyle(
                              color: (isDark ? Colors.white : Colors.black87).withOpacity(0.6),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Balance and Value
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    token.balance.toStringAsFixed(token.decimals > 6 ? 6 : token.decimals),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (token.price != null)
                    Text(
                      _formatCurrency(tokenValue),
                      style: TextStyle(
                        color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  else
                    Text(
                      'Price N/A',
                      style: TextStyle(
                        color: (isDark ? Colors.white : Colors.black87).withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTokenFallbackIcon(String symbol) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6B35),
            const Color(0xFFFF8C42),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          symbol.length > 3 ? symbol.substring(0, 3) : symbol,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMarketDataSection(bool isDark, AppLocalizations? l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n?.marketData ?? 'Market Data',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        RepaintBoundary(
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.2,
            children: [
              _buildStatCard(
                title: l10n?.solPrice ?? 'SOL Price',
                value: '\$${_solPrice.toStringAsFixed(2)}',
                icon: Icons.monetization_on,
                color: const Color(0xFFFF6B35),
                changeValue: _dailyChange,
              ),
              _buildStatCard(
                title: l10n?.dailyVolume ?? 'Daily Volume',
                value: _formatCurrency(_dailyVolume),
                icon: Icons.bar_chart,
                color: Colors.blue,
              ),
              _buildStatCard(
                title: l10n?.marketCap ?? 'Market Cap',
                value: _formatCurrency(_marketCap),
                icon: Icons.account_balance,
                color: Colors.green,
              ),
              _buildStatCard(
                title: l10n?.transactionCount ?? 'Transactions',
                value: _transactionCount.toString(),
                icon: Icons.receipt_long,
                color: Colors.purple,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceChangesSection(bool isDark, AppLocalizations? l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n?.priceChanges ?? 'Price Changes',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        RepaintBoundary(
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.8,
            children: [
              _buildPriceChangeCard(
                period: l10n?.twentyFourHours ?? '24 Hours',
                percentage: _dailyChange,
                walletChange: _walletDailyChange,
                icon: Icons.today,
              ),
              _buildPriceChangeCard(
                period: l10n?.sevenDays ?? '7 Days',
                percentage: _weeklyChange,
                walletChange: _walletWeeklyChange,
                icon: Icons.date_range,
              ),
              _buildPriceChangeCard(
                period: l10n?.thirtyDays ?? '30 Days',
                percentage: _monthlyChange,
                walletChange: _walletMonthlyChange,
                icon: Icons.calendar_month,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTransactionsSection(bool isDark, AppLocalizations? l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n?.recentTransactions ?? 'Recent Transactions',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TransactionHistoryPage(
                      wallet: widget.wallet,
                      transactions: _recentTransactions,
                    ),
                  ),
                );
              },
              child: Text(
                l10n?.viewAll ?? 'View All',
                style: const TextStyle(color: Color(0xFFFF6B35)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        RepaintBoundary(
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentTransactions.length > 3 ? 3 : _recentTransactions.length,
            itemBuilder: (context, index) {
              return _buildTransactionItem(_recentTransactions[index], isDark, l10n);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWalletAddressCard(bool isDark, AppLocalizations? l10n) {
    return _buildGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B35).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: Color(0xFFFF6B35),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  l10n?.walletAddress ?? 'Wallet Address',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showFullAddress = !_showFullAddress;
                    });
                  },
                  icon: Icon(
                    _showFullAddress ? Icons.visibility_off : Icons.visibility,
                    color: const Color(0xFFFF6B35),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _copyAddress,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFFF6B35).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatAddress(widget.wallet.address),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 14,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.copy,
                      color: Color(0xFFFF6B35),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    Color? color,
    bool isLoading = false,
    String? subtitle,
    double? changeValue,
    Widget? trailing,
  }) {
    return _buildGlassCard(
      gradientColors: [color ?? const Color(0xFFFF6B35), const Color(0xFFFF8C42)],
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const Spacer(),
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else if (changeValue != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (changeValue >= 0 ? Colors.green : Colors.red).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          changeValue >= 0 ? Icons.trending_up : Icons.trending_down,
                          color: changeValue >= 0 ? Colors.green : Colors.red,
                          size: 14,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${changeValue >= 0 ? '+' : ''}${changeValue.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: changeValue >= 0 ? Colors.green : Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (trailing != null)
                    trailing,
              ],
            ),
            const SizedBox(height: 16),
            if (isLoading)
              Container(
                height: 24,
                width: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
              )
            else
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPriceChangeCard({
    required String period,
    required double percentage,
    required double walletChange,
    required IconData icon,
  }) {
    final isPositive = percentage >= 0;
    final color = isPositive ? Colors.green : Colors.red;

    return _buildGlassCard(
      borderColor: color.withOpacity(0.4),
      gradientColors: [color, color.withOpacity(0.7)],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isPositive ? Icons.trending_up : Icons.trending_down,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '${isPositive ? '+' : ''}${percentage.toStringAsFixed(2)}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              period,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${isPositive ? '+' : ''}${_formatCurrency(walletChange)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx, bool isDark, AppLocalizations? l10n) {
    final isSuccess = tx['err'] == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: _buildGlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isSuccess ? Colors.green : Colors.red).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isSuccess ? Icons.check_circle : Icons.error,
                  color: isSuccess ? Colors.green : Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${tx['signature'].toString().substring(0, 12)}...',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(tx['blockTime']),
                      style: TextStyle(
                        color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isSuccess ? Colors.green : Colors.red).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isSuccess ? (l10n?.successful ?? 'Success') : (l10n?.failed ?? 'Failed'),
                  style: TextStyle(
                    color: isSuccess ? Colors.green : Colors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
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
