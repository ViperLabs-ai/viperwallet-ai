import 'dart:ui';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solana/dto.dart';
import 'package:solana/solana.dart';
import 'package:http/http.dart' as http;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:viperwallet/pages/nft_page.dart';
import 'package:viperwallet/pages/settings_page.dart';
import 'charts_page.dart';
import 'send_page.dart' hide lamportsPerSol;
import 'swap_page.dart' hide lamportsPerSol;
import 'receive_page.dart';
import 'swap_page.dart';
import 'transaction_history_page.dart';
import '../services/rpc_service.dart';
import 'package:easy_localization/easy_localization.dart'; // Added easy_localization import

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

  // Token balances
  List<Map<String, dynamic>> _tokenBalances = [];
  bool _isLoadingTokens = false;

  late AnimationController _refreshController;
  late AnimationController _cardController;
  late AnimationController _pulseController;
  late AnimationController _loadingController;
  late Animation<double> _cardAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  double _solPrice = 0.0;
  double _dailyChange = 0.0;
  double _weeklyChange = 0.0;
  double _monthlyChange = 0.0;
  double _dailyVolume = 0.0;
  double _marketCap = 0.0;

  double _walletDailyChange = 0.0;
  double _walletWeeklyChange = 0.0;
  double _walletMonthlyChange = 0.0;

  List<Map<String, dynamic>> _recentTransactions = [];
  bool _isLoadingTransactions = false;

  String _networkStatus = '';
  bool _isNetworkConnected = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;

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

    setState(() {
      _isLoading = true;
      _networkStatus = 'Connecting...'.tr(); // Localized
      _retryCount = 0;
    });

    _refreshController.repeat();

    try {
      // SOL bakiyesini yükle
      await _loadSolBalance();
      if (!mounted) return;

      // Token bakiyelerini yükle
      await _loadTokenBalances();
      if (!mounted) return;

      // SOL fiyat verilerini yükle
      await _loadSolPriceData();
      if (!mounted) return;

      // Transaction history'yi yükle
      await _loadTransactionHistory();
      if (!mounted) return;

      setState(() {
        _isNetworkConnected = true;
        _networkStatus = 'Connected'.tr(); // Localized
      });

    } catch (e) {
      print('❌ Data loading error: $e');
      if (mounted) {
        setState(() {
          _isNetworkConnected = false;
          _networkStatus = 'Connection Error'.tr(); // Localized
          _retryCount++;
        });
      }
    }

    _calculateWalletChanges();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }

    _refreshController.stop();
    _refreshController.reset();
  }

  Future<void> _loadSolBalance() async {
    if (!mounted) return;

    try {
      setState(() {
        _networkStatus = 'Loading SOL balance...'.tr(); // Localized
      });

      print('🔍 Loading balance for wallet: ${widget.wallet.address}');

      // Solana client oluştur
      final client = SolanaClient(
        rpcUrl: Uri.parse('https://api.mainnet-beta.solana.com'),
        websocketUrl: Uri.parse('wss://api.mainnet-beta.solana.com'),
      );

      // Balance'ı al
      final balance = await client.rpcClient.getBalance(widget.wallet.address);

      print('💰 Raw balance response: $balance');

      final balanceInSol = balance.value / lamportsPerSol;

      print('💰 Balance in SOL: $balanceInSol');

      if (mounted) {
        setState(() {
          _solBalance = balanceInSol;
          _networkStatus = 'SOL balance: ${balanceInSol.toStringAsFixed(6)}'.tr(); // Localized
        });
      }

    } catch (e) {
      print('❌ Balance loading error: $e');
      if (mounted) {
        setState(() {
          _solBalance = 0.0;
          _networkStatus = 'Balance loading failed: ${e.toString()}'.tr(); // Localized
        });
      }
      rethrow;
    }
  }

  Future<void> _loadTokenBalances() async {
    if (!mounted) return;

    setState(() {
      _isLoadingTokens = true;
      _networkStatus = 'Loading token balances...'.tr(); // Localized
    });

    try {
      print('🪙 Loading token balances for wallet: ${widget.wallet.address}');

      final client = SolanaClient(
        rpcUrl: Uri.parse('https://api.mainnet-beta.solana.com'),
        websocketUrl: Uri.parse('wss://api.mainnet-beta.solana.com'),
      );

      // Token accounts'ları al
      final tokenAccounts = await client.rpcClient.getTokenAccountsByOwner(
        widget.wallet.address,
        const TokenAccountsFilter.byProgramId('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA'),
        encoding: Encoding.jsonParsed,
      );

      print('🪙 Found ${tokenAccounts.value.length} token accounts');

      List<Map<String, dynamic>> tokens = [];

      for (final account in tokenAccounts.value) {
        try {
          final accountData = account.account.data;
          if (accountData is ParsedAccountData) {
            final parsed = accountData.parsed;
            if (parsed is Map<String, dynamic>) {
              final info = parsed['info'] as Map<String, dynamic>?;
              if (info != null) {
                final tokenAmount = info['tokenAmount'] as Map<String, dynamic>?;
                final mint = info['mint'] as String?;

                if (tokenAmount != null && mint != null) {
                  final uiAmount = tokenAmount['uiAmount'];
                  final decimals = tokenAmount['decimals'] as int? ?? 0;

                  // Sadece bakiyesi olan tokenları ekle
                  if (uiAmount != null && uiAmount > 0) {
                    // Token metadata'sını al
                    final tokenInfo = await _getTokenMetadata(mint);

                    tokens.add({
                      'mint': mint,
                      'balance': uiAmount,
                      'decimals': decimals,
                      'name': tokenInfo['name'] ?? 'Unknown Token'.tr(), // Localized
                      'symbol': tokenInfo['symbol'] ?? mint.substring(0, 6),
                      'logoURI': tokenInfo['logoURI'],
                      'verified': tokenInfo['verified'] ?? false,
                    });
                  }
                }
              }
            }
          }
        } catch (e) {
          print('❌ Error processing token account: $e');
          continue;
        }
      }

      print('✅ Loaded ${tokens.length} tokens with balance');

      if (mounted) {
        setState(() {
          _tokenBalances = tokens;
          _isLoadingTokens = false;
          _networkStatus = 'Loaded ${tokens.length} tokens'.tr(); // Localized
        });
      }

    } catch (e) {
      print('❌ Token balance loading error: $e');
      if (mounted) {
        setState(() {
          _tokenBalances = [];
          _isLoadingTokens = false;
          _networkStatus = 'Token loading failed'.tr(); // Localized
        });
      }
    }
  }

  Future<Map<String, dynamic>> _getTokenMetadata(String mint) async {
    try {
      // Jupiter token listesinden metadata al
      final response = await http.get(
        Uri.parse('https://tokens.jup.ag/token/$mint'),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'ViperWallet/1.0',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'name': data['name'],
          'symbol': data['symbol'],
          'logoURI': data['logoURI'],
          'verified': (data['tags'] as List?)?.contains('verified') ?? false,
        };
      }
    } catch (e) {
      print('❌ Token metadata error for $mint: $e');
    }

    // Fallback
    return {
      'name': 'Token ${mint.substring(0, 6)}...${mint.substring(mint.length - 4)}'.tr(), // Localized
      'symbol': mint.substring(0, 6).toUpperCase(),
      'logoURI': null,
      'verified': false,
    };
  }

  Future<void> _loadSolPriceData() async {
    if (!mounted) return;

    try {
      setState(() {
        _networkStatus = 'Loading SOL price...'.tr(); // Localized
      });

      // CoinGecko API
      final response = await http.get(
        Uri.parse(
            'https://api.coingecko.com/api/v3/simple/price?'
                'ids=solana&'
                'vs_currencies=usd&'
                'include_24hr_change=true&'
                'include_7d_change=true&'
                'include_30d_change=true&'
                'include_24hr_vol=true&'
                'include_market_cap=true'
        ),
        headers: {
          'User-Agent': 'ViperWallet/1.0',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final solData = data['solana'];

        setState(() {
          _solPrice = (solData['usd'] as num).toDouble();
          _dailyChange = (solData['usd_24h_change'] as num?)?.toDouble() ?? 0.0;
          _weeklyChange = (solData['usd_7d_change'] as num?)?.toDouble() ?? 0.0;
          _monthlyChange = (solData['usd_30d_change'] as num?)?.toDouble() ?? 0.0;
          _dailyVolume = (solData['usd_24h_vol'] as num?)?.toDouble() ?? 0.0;
          _marketCap = (solData['usd_market_cap'] as num?)?.toDouble() ?? 0.0;
          _networkStatus = 'SOL price: \$${_solPrice.toStringAsFixed(2)}'.tr(); // Localized
        });

        print('💲 SOL Price loaded: \$${_solPrice.toStringAsFixed(2)}');
      } else {
        throw Exception('Price API returned ${response.statusCode}');
      }

    } catch (e) {
      print('❌ Price loading error: $e');
      if (mounted) {
        setState(() {
          _solPrice = 0.0;
          _networkStatus = 'Price loading failed'.tr(); // Localized
        });
      }
    }
  }

  Future<void> _loadTransactionHistory() async {
    if (!mounted) return;

    setState(() {
      _isLoadingTransactions = true;
      _networkStatus = 'Loading transactions...'.tr(); // Localized
    });

    try {
      print('📜 Loading transaction history for: ${widget.wallet.address}');

      final client = SolanaClient(
        rpcUrl: Uri.parse('https://api.mainnet-beta.solana.com'),
        websocketUrl: Uri.parse('wss://api.mainnet-beta.solana.com'),
      );

      final signatures = await client.rpcClient.getSignaturesForAddress(
        widget.wallet.address,
        limit: 10,
      );

      print('📜 Found ${signatures.length} transactions');

      final List<Map<String, dynamic>> transactions = [];

      for (final sig in signatures) {
        try {
          // Transaction detaylarını al
          final txDetail = await client.rpcClient.getTransaction(
            sig.signature,
            encoding: Encoding.json,
            commitment: Commitment.confirmed,
          );

          if (txDetail != null) {
            transactions.add({
              'signature': sig.signature,
              'slot': sig.slot,
              'blockTime': sig.blockTime,
              'confirmationStatus': sig.confirmationStatus,
              'err': sig.err,
              'fee': txDetail.meta?.fee ?? 0,
              'success': sig.err == null,
            });
          } else {
            // Detay alınamazsa basit bilgilerle ekle
            transactions.add({
              'signature': sig.signature,
              'slot': sig.slot,
              'blockTime': sig.blockTime,
              'confirmationStatus': sig.confirmationStatus,
              'err': sig.err,
              'fee': 5000, // Default fee
              'success': sig.err == null,
            });
          }
        } catch (e) {
          print('❌ Transaction detail error for ${sig.signature}: $e');
          // Hata olsa bile basit bilgilerle ekle
          transactions.add({
            'signature': sig.signature,
            'slot': sig.slot,
            'blockTime': sig.blockTime,
            'confirmationStatus': sig.confirmationStatus,
            'err': sig.err,
            'fee': 5000,
            'success': sig.err == null,
          });
        }
      }

      if (mounted) {
        setState(() {
          _recentTransactions = transactions;
          _networkStatus = 'Loaded ${transactions.length} transactions'.tr(); // Localized
          _isLoadingTransactions = false;
        });
      }

      print('✅ Transaction history loaded: ${transactions.length} items');

    } catch (e) {
      print('❌ Transaction history error: $e');
      if (mounted) {
        setState(() {
          _recentTransactions = [];
          _networkStatus = 'Transaction loading failed'.tr(); // Localized
          _isLoadingTransactions = false;
        });
      }
    }
  }

  void _calculateWalletChanges() {
    if (_solPrice > 0) {
      final portfolioValue = _solBalance * _solPrice;
      _walletDailyChange = portfolioValue * _dailyChange / 100;
      _walletWeeklyChange = portfolioValue * _weeklyChange / 100;
      _walletMonthlyChange = portfolioValue * _monthlyChange / 100;
    }
  }

  void _copyAddress() {
    Clipboard.setData(ClipboardData(text: widget.wallet.address));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text('Address copied to clipboard'.tr()), // Localized
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
    if (blockTime == null) return 'Unknown'.tr(); // Localized
    final date = DateTime.fromMillisecondsSinceEpoch(blockTime * 1000);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago'.tr(); // Localized
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago'.tr(); // Localized
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago'.tr(); // Localized
    } else {
      return 'Just now'.tr(); // Localized
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

  Widget _buildTokenBalancesSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Token Bakiyeleri'.tr(), // Localized
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoadingTokens) ...[
          const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
            ),
          ),
        ] else if (_tokenBalances.isEmpty) ...[
          _buildGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.token,
                      size: 48,
                      color: (isDark ? Colors.white : Colors.black87).withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Henüz token bulunamadı'.tr(), // Localized
                      style: TextStyle(
                        color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cüzdanınızda token bakiyesi bulunmuyor'.tr(), // Localized
                      style: TextStyle(
                        color: (isDark ? Colors.white : Colors.black87).withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ] else ...[
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _tokenBalances.length,
            itemBuilder: (context, index) {
              return _buildTokenItem(_tokenBalances[index], isDark);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildTokenItem(Map<String, dynamic> token, bool isDark) {
    final balance = token['balance'] as double;
    final symbol = token['symbol'] as String;
    final name = token['name'] as String;
    final logoURI = token['logoURI'] as String?;
    final verified = token['verified'] as bool;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: _buildGlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Token icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: logoURI != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    logoURI,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.token,
                        color: Color(0xFFFF6B35),
                        size: 24,
                      );
                    },
                  ),
                )
                    : const Icon(
                  Icons.token,
                  color: Color(0xFFFF6B35),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Token info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          symbol,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (verified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified,
                            color: Colors.blue,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      style: TextStyle(
                        color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Balance
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    balance.toStringAsFixed(6),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    symbol,
                    style: TextStyle(
                      color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                      fontSize: 12,
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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final totalValue = _solBalance * _solPrice;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/icon/icon1.png',
              width: 32,
              height: 32,
            ),
            const SizedBox(width: 10),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
              ).createShader(bounds),
              child: Text(
                'Viper Wallet'.tr(), // Localized
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ),
          ],
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
                  _isNetworkConnected ? 'Online'.tr() : 'Offline'.tr(), // Localized
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
            margin: const EdgeInsets.only(right: 5),
            decoration: BoxDecoration(
              color: (isDark ? Colors.black : Colors.white).withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFF6B35).withOpacity(0.3),
              ),
            ),
            child: IconButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
                },
                icon: Icon(Icons.settings, color: Color(0xFFFF6B35),)
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
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0x00FF6B35),
                        Color(0x00FF8C42),
                        Color(0x00FFB347),
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
                  child: Image.asset('assets/icon/icon1.png'),
                ),
              ),

              const SizedBox(height: 40),

              ScaleTransition(
                scale: _pulseAnimation,
                child: Text(
                  'Loading Wallet...'.tr(), // Localized
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

                    // Ana SOL bakiye kartı
                    FadeTransition(
                      opacity: _cardAnimation,
                      child: _buildMainBalanceCard(totalValue, isDark),
                    ),

                    const SizedBox(height: 28),

                    // Quick actions
                    _buildQuickActions(),

                    const SizedBox(height: 28),

                    // Token balances section - Market data'nın hemen üstüne taşındı
                    //_buildTokenBalancesSection(isDark),

                    //const SizedBox(height: 28),

                    // Market data

                    _buildMarketDataSection(isDark),
                    const SizedBox(height: 28),


                    // Price changes

                    _buildPriceChangesSection(isDark),
                    const SizedBox(height: 28),

                    // Recent transactions
                    if (_recentTransactions.isNotEmpty) ...[
                      _buildRecentTransactionsSection(isDark),
                      const SizedBox(height: 28),
                    ],

                    // Wallet address
                    _buildWalletAddressCard(isDark),

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

  Widget _buildMainBalanceCard(double totalValue, bool isDark) {
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
                  child: const FaIcon(
                    FontAwesomeIcons.wallet,
                    color: Colors.white,
                    size: 24,
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
                        'SOL Balance'.tr(), // Localized
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCurrency(totalValue),
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
            if (_solPrice > 0) ...[
              Text(
                '≈ ${_formatCurrency(totalValue)}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              if (_walletDailyChange != 0) ...[
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
                          FaIcon(
                            _walletDailyChange >= 0 ? FontAwesomeIcons.arrowTrendUp : FontAwesomeIcons.arrowTrendDown,
                            color: _walletDailyChange >= 0 ? Colors.green : Colors.red,
                            size: 16,
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
                            '(24h)'.tr(), // Localized
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
            ] else ...[
              Text(
                'Price data loading...'.tr(), // Localized
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.9,
      children: [
        _buildActionButton(
          icon: FontAwesomeIcons.paperPlane,
          label: 'Send'.tr(), // Localized
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FixedSendPage(wallet: widget.wallet),
              ),
            );
          },
        ),
        _buildActionButton(
          icon: FontAwesomeIcons.qrcode,
          label: 'Receive'.tr(), // Localized
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
          icon: FontAwesomeIcons.rightLeft,
          label: 'Swap'.tr(), // Localized
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
        /*_buildActionButton(
          icon: FontAwesomeIcons.images,
          label: 'NFT'.tr(), // Localized
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NFTPage(wallet: widget.wallet),
              ),
            );
          },
          color: Colors.blue,
        ),

         */
      ],
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
              FaIcon(
                icon,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
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

  Widget _buildMarketDataSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Market Data'.tr(), // Localized
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.2,
          children: [
            _buildStatCard(
              title: 'SOL Price'.tr(), // Localized
              value: '\$${_solPrice.toStringAsFixed(2)}',
              icon: FontAwesomeIcons.dollarSign,
              color: const Color(0xFFFF6B35),
              changeValue: _dailyChange,
            ),
            _buildStatCard(
              title: 'Market Cap'.tr(), // Localized
              value: _formatCurrency(_marketCap),
              icon: FontAwesomeIcons.buildingColumns,
              color: Colors.green,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceChangesSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Price Changes'.tr(), // Localized
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.8,
          children: [
            _buildPriceChangeCard(
              period: '24 Hours'.tr(), // Localized
              percentage: _dailyChange,
              walletChange: _walletDailyChange,
              icon: FontAwesomeIcons.clock,
            ),
            _buildPriceChangeCard(
              period: '7 Days'.tr(), // Localized
              percentage: _weeklyChange,
              walletChange: _walletWeeklyChange,
              icon: FontAwesomeIcons.calendarDay,
            ),
            _buildPriceChangeCard(
              period: '30 Days'.tr(), // Localized
              percentage: _monthlyChange,
              walletChange: _walletMonthlyChange,
              icon: FontAwesomeIcons.calendarDays,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentTransactionsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Transactions'.tr(), // Localized
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
                'View All'.tr(), // Localized
                style: const TextStyle(color: Color(0xFFFF6B35)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoadingTransactions) ...[
          const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
            ),
          ),
        ] else ...[
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentTransactions.length > 5 ? 5 : _recentTransactions.length,
            itemBuilder: (context, index) {
              return _buildTransactionItem(_recentTransactions[index], isDark);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildWalletAddressCard(bool isDark) {
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
                  child: const FaIcon(
                    FontAwesomeIcons.addressCard,
                    color: Color(0xFFFF6B35),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Wallet Address'.tr(), // Localized
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
                  icon: FaIcon(
                    _showFullAddress ? FontAwesomeIcons.eyeSlash : FontAwesomeIcons.eye,
                    color: const Color(0xFFFF6B35),
                    size: 18,
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
                    const FaIcon(
                      FontAwesomeIcons.copy,
                      color: Color(0xFFFF6B35),
                      size: 16,
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
    double? changeValue,
  }) {
    return _buildGlassCard(
      gradientColors: [color ?? const Color(0xFFFF6B35), const Color(0xFFFF8C42)],
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                  child: FaIcon(
                    icon,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const Spacer(),
                if (changeValue != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (changeValue >= 0 ? Colors.green : Colors.red).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FaIcon(
                          changeValue >= 0 ? FontAwesomeIcons.arrowUp : FontAwesomeIcons.arrowDown,
                          color: changeValue >= 0 ? Colors.green : Colors.red,
                          size: 12,
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
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
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
                  child: FaIcon(
                    icon,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FaIcon(
                    isPositive ? FontAwesomeIcons.arrowTrendUp : FontAwesomeIcons.arrowTrendDown,
                    color: Colors.white,
                    size: 14,
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

  Widget _buildTransactionItem(Map<String, dynamic> tx, bool isDark) {
    final isSuccess = tx['success'] ?? (tx['err'] == null);
    final fee = tx['fee'] ?? 5000;

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
                child: FaIcon(
                  isSuccess ? FontAwesomeIcons.circleCheck : FontAwesomeIcons.circleExclamation,
                  color: isSuccess ? Colors.green : Colors.red,
                  size: 18,
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
                    Row(
                      children: [
                        Text(
                          _formatDate(tx['blockTime']),
                          style: TextStyle(
                            color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Fee: ${(fee / lamportsPerSol).toStringAsFixed(6)} SOL'.tr(), // Localized
                          style: TextStyle(
                            color: (isDark ? Colors.white : Colors.black87).withOpacity(0.5),
                            fontSize: 10,
                          ),
                        ),
                      ],
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
                  isSuccess ? 'Success'.tr() : 'Failed'.tr(), // Localized
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