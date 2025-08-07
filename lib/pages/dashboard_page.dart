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
import 'package:easy_localization/easy_localization.dart';

// Ensure this constant is defined somewhere accessible, e.g., in a utils file or directly here.
const int lamportsPerSol = 1000000000;

/// A simple data class to represent a token account from the public Solscan API.
/// (This class is not strictly used anymore as Solscan API is removed, but kept for reference if needed)
class TokenAccount {
  final String tokenAddress;
  final String tokenAccount;
  final int decimals;
  final double amount;

  TokenAccount({
    required this.tokenAddress,
    required this.tokenAccount,
    required this.amount,
    required this.decimals,
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

  // Token balances
  List<Map<String, dynamic>> _tokenBalances = [];
  bool _isLoadingTokens = false;

  double _solPrice = 0.0;
  double _dailyChange = 0.0;
  double _weeklyChange = 0.0;
  double _monthlyChange = 0.0;
  double _dailyVolume = 0.0;
  double _marketCap = 0.0;

  double _walletDailyChange = 0.0;
  double _walletWeeklyChange = 0.0;
  double _walletMonthlyChange = 0.0;
  double _totalWalletValue = 0.0; // Added for total wallet value

  List<Map<String, dynamic>> _recentTransactions = [];
  bool _isLoadingTransactions = false;

  bool _isNetworkConnected = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllData();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _retryCount = 0;
    });

    try {
      // SOL bakiyesini yükle
      await _loadSolBalance();
      if (!mounted) return;

      // SOL fiyat verilerini yükle
      await _loadSolPriceData();
      if (!mounted) return;

      // Token bakiyelerini yükle (fiyat ve değer hesaplaması dahil)
      await _loadTokenBalances(widget.wallet.address);
      if (!mounted) return;

      // Transaction history'yi yükle
      await _loadTransactionHistory();
      if (!mounted) return;

      setState(() {
        _isNetworkConnected = true;
      });
    } catch (e) {
      print('❌ Data loading error: $e');
      if (mounted) {
        setState(() {
          _isNetworkConnected = false;
          _retryCount++;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }

    _calculateWalletChanges();
    _calculateTotalWalletValue(); // Calculate total wallet value after all data is loaded
  }

  Future<void> _loadSolBalance() async {
    if (!mounted) return;

    try {
      print('🔍 Loading balance for wallet: ${widget.wallet.address}');

      // Solana client oluştur
      final client = SolanaClient(
        rpcUrl: Uri.parse('https://mainnet.helius-rpc.com/?api-key='),
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
        });
      }
    } catch (e) {
      print('❌ Balance loading error: $e');
      if (mounted) {
        setState(() {
          _solBalance = 0.0;
        });
      }
      rethrow;
    }
  }

  /// Fetches token accounts from the public Solscan API.
  /// Note: Public APIs may have rate limits or change their data format without notice.
  /// For production, consider official RPC providers (like Helius) or SDKs.
  /// This function is no longer used directly in _loadTokenBalances but kept for reference.
  Future<List<TokenAccount>> fetchTokenAccountsPublic(String walletAddress) async {
    final url = Uri.parse('https://public-api.solscan.io/account/tokens?account=$walletAddress');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // Data format may differ from pro-api, careful parsing needed
      final List<dynamic> tokens = data;
      return tokens.map((json) {
        return TokenAccount(
          tokenAddress: json['tokenAddress'],
          tokenAccount: json['tokenAccount'],
          decimals: json['decimals'] ?? 0,
          amount: (json['tokenAmount'] != null)
              ? (json['tokenAmount']['uiAmount'] as num).toDouble()
              : 0,
        );
      }).toList();
    } else {
      throw Exception('Token accounts could not be retrieved from Solscan public API: ${response.statusCode}');
    }
  }

  Future<void> _loadTokenBalances(String walletAddress) async {
    if (!mounted) return;

    setState(() {
      _isLoadingTokens = true;
    });

    try {
      List<Map<String, dynamic>> fetchedTokens = [];

      // Helius API'den token bakiyelerini al
      try {
        fetchedTokens.addAll(await fetchTokenBalancesFromHelius(walletAddress));
      } catch (e) {
        print('Error fetching from Helius: $e');
      }

      // Solscan API'den token bakiyelerini al
      try {
        fetchedTokens.addAll(await fetchTokenBalancesFromSolscan(walletAddress));
      } catch (e) {
        print('Error fetching from Solscan: $e');
      }

      // Solana Explorer API'den token bakiyelerini al
      try {
        List<Map<String, dynamic>> explorerTokens = await fetchTokenBalancesFromExplorer(walletAddress);
        for (var token in explorerTokens) {
          bool exists = fetchedTokens.any((element) => element['mint'] == token['mint']);
          if (!exists) {
            final metadata = await _getTokenMetadata(token['mint']);
            token['name'] = metadata['name'];
            token['symbol'] = metadata['symbol'];
            token['logoURI'] = metadata['logoURI'];
            token['verified'] = metadata['verified'];
            fetchedTokens.add(token);
          }
        }
        if (mounted) {
          setState(() {
            _tokenBalances = fetchedTokens; // Update the state variable
            _isLoadingTokens = false; // Set loading state to false
          });
        }
      } catch (e) {
        print('Error fetching from Solana Explorer: $e');
      }

      // Her bir token için fiyatı çek ve değeri hesapla
      for (var token in fetchedTokens) {
        final mint = token['mint'] as String;
        final balance = token['balance'] as double;
        double price = await _getTokenPrice(mint);
        token['price'] = price;
        token['value'] = balance * price; // Correctly multiplying balance by price
      }

      if (mounted) {
        setState(() {
          _tokenBalances = fetchedTokens;
          _isLoadingTokens = false;
        });
      }

      print('Loaded tokens: $_tokenBalances');
    } catch (e) {
      print('Error loading token balances: $e');
      if (mounted) {
        setState(() {
          _isLoadingTokens = false;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> fetchTokenBalancesFromSolscan(String walletAddress) async {
    final url = Uri.parse('https://public-api.solscan.io/account/tokens?account=$walletAddress');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> tokens = data['data'] ?? [];
      List<Map<String, dynamic>> tokenList = [];

      for (var token in tokens) {
        tokenList.add({
          'mint': token['tokenAddress'],
          'balance': token['tokenAmount']['uiAmount'],
          'decimals': token['decimals'],
          'name': token['tokenInfo']['name'] ?? 'Unknown Token',
          'symbol': token['tokenInfo']['symbol'] ?? token['tokenAddress'].substring(0, 6),
          'logoURI': token['tokenInfo']['logoURI'],
          'verified': token['tokenInfo']['verified'] ?? false,
        });
      }
      return tokenList;
    } else {
      throw Exception('Solscan API error: ${response.statusCode}');
    }
  }

// Solana Explorer API ile token bakiyelerini çekme
  Future<List<Map<String, dynamic>>> fetchTokenBalancesFromExplorer(String walletAddress) async {
    final url = Uri.parse('https://api.solana.com/v1/getTokenAccountsByOwner?owner=$walletAddress');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> tokens = data['result'] ?? [];
      List<Map<String, dynamic>> tokenList = [];

      for (var token in tokens) {
        tokenList.add({
          'mint': token['account']['data']['parsed']['info']['mint'],
          'balance': token['account']['data']['parsed']['info']['tokenAmount']['uiAmount'],
          'decimals': token['account']['data']['parsed']['info']['tokenAmount']['decimals'],
          'name': 'Unknown Token', // Explorer API'den isim almak zor olabilir
          'symbol': 'Unknown', // Explorer API'den sembol almak zor olabilir
          'logoURI': null,
          'verified': false,
        });
      }
      return tokenList;
    } else {
      throw Exception('Explorer API error: ${response.statusCode}');
    }
  }

// Helius API ile token bakiyelerini çekme
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
            final tokenInfo = await _getTokenMetadata(mint); // Token metadata al
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

  Future<double> _getTokenPrice(String mint) async {
    try {
      // Updated to Jupiter Price API V3 (lite URL)
      final response = await http.get(
        Uri.parse('https://lite-api.jup.ag/price/v3?ids=$mint'),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'ViperWallet/1.0',
        },
      ).timeout(const Duration(seconds: 10)); // Increased timeout

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data[mint] != null) { // Accessing directly from data[mint] as per V3 response
          return (data[mint]['usdPrice'] as num).toDouble(); // Corrected to 'usdPrice'
        } else {
          print('❌ Token price data not found in response for $mint. Body: ${response.body}');
        }
      } else {
        print('❌ Token price API returned status code ${response.statusCode} for $mint. Body: ${response.body}');
      }
    } on http.ClientException catch (e) {
      print('❌ Token price ClientException for $mint: $e');
    } on Exception catch (e) {
      print('❌ Token price general error for $mint: $e');
    }
    return 0.0; // Default to 0 if price cannot be fetched
  }

  Future<void> _loadSolPriceData() async {
    if (!mounted) return;

    try {
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
      ).timeout(const Duration(seconds: 15)); // Increased timeout

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
        });

        print('💲 SOL Price loaded: \$${_solPrice.toStringAsFixed(2)}');
      } else {
        print('❌ Price API returned status code ${response.statusCode}. Body: ${response.body}');
        throw Exception('Price API returned ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Price loading error: $e');
      if (mounted) {
        setState(() {
          _solPrice = 0.0;
        });
      }
    }
  }

  Future<void> _loadTransactionHistory() async {
    if (!mounted) return;

    setState(() {
      _isLoadingTransactions = true;
    });

    try {
      print('📜 Loading transaction history for: ${widget.wallet.address}');

      final client = SolanaClient(
        rpcUrl: Uri.parse('https://mainnet.helius-rpc.com/?api-key='),
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
            transactions.add({
              'signature': sig.signature,
              'slot': sig.slot,
              'blockTime': sig.blockTime,
              'confirmationStatus': sig.confirmationStatus,
              'err': sig.err,
              'fee': 5000, // Default fee if txDetail is null
              'success': sig.err == null,
            });
          }
        } catch (e) {
          print('❌ Transaction detail error for ${sig.signature}: $e');
          transactions.add({
            'signature': sig.signature,
            'slot': sig.slot,
            'blockTime': sig.blockTime,
            'confirmationStatus': sig.confirmationStatus,
            'err': sig.err,
            'fee': 5000, // Default fee on error
            'success': sig.err == null,
          });
        }
      }

      if (mounted) {
        setState(() {
          _recentTransactions = transactions;
          _isLoadingTransactions = false;
        });
      }

      print('✅ Transaction history loaded: ${transactions.length} items');
    } catch (e) {
      print('❌ Transaction history error: $e');
      if (mounted) {
        setState(() {
          _recentTransactions = [];
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

  void _calculateTotalWalletValue() {
    double total = _solBalance * _solPrice;
    for (var token in _tokenBalances) {
      total += (token['value'] as double? ?? 0.0);
    }
    setState(() {
      _totalWalletValue = total;
    });
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
        ] else ...[
          // Solana (SOL) token item - always displayed first
          _buildTokenItem(
            {
              'mint': 'So11111111111111111111111111111111111111112', // SOL mint address
              'balance': _solBalance,
              'decimals': 9,
              'name': 'Solana',
              'symbol': 'SOL',
              'logoURI': 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/So11111111111111111111111111111111111111112/logo.png',
              'verified': true,
              'price': _solPrice,
              'value': _solBalance * _solPrice,
            },
            isDark,
          ),
          // Other token items fetched from Helius
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _tokenBalances.length,
            itemBuilder: (context, index) {
              return _buildTokenItem(_tokenBalances[index], isDark);
            },
          ),
          if (_tokenBalances.isEmpty && _solBalance == 0.0) // Only show "no tokens" if both SOL and other tokens are empty
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
    final value = token['value'] as double? ?? 0.0; // Get token value

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
                child: logoURI != null && logoURI.isNotEmpty
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    logoURI,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      print('Error loading image for ${token['symbol']}: $error');
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
              // Balance and Value
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
                    _formatCurrency(value), // Display token value in USD
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
                  _isNetworkConnected ? ''.tr() : ''.tr(), // Localized
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
              icon: const Icon( // Removed RotationTransition
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
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 20),

                    // Total Wallet Balance (Phantom Wallet style)
                    _buildTotalWalletBalanceCard(isDark),

                    const SizedBox(height: 28),

                    // Quick actions
                    _buildQuickActions(),

                    const SizedBox(height: 28),

                    // Token balances section
                    _buildTokenBalancesSection(isDark),

                    const SizedBox(height: 28),

                    // Market data
                    _buildMarketDataSection(isDark),
                    const SizedBox(height: 28),

                    // Price changes
                    _buildPriceChangesSection(isDark),
                    const SizedBox(height: 28),

                    // Recent transactions
                    _buildRecentTransactionsSection(isDark),
                    const SizedBox(height: 28),

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

  Widget _buildTotalWalletBalanceCard(bool isDark) {
    return _buildGlassCard(
      gradientColors: [const Color(0xFFFF6B35), const Color(0xFFFF8C42)],
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Text(
                'Total Balance',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.normal,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatCurrency(_totalWalletValue),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.normal,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 10),
              if (_solPrice > 0) ...[
                if (_walletDailyChange != 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: (_walletDailyChange >= 0 ? Colors.transparent : Colors.transparent).withOpacity(0.25),
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
                builder: (context) => FixedSendPage(wallet: widget.wallet), // Changed to FixedSendPage
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
                // Navigate to TransactionHistoryPage
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
        ] else if (_recentTransactions.isEmpty) ...[
          _buildGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.history,
                      size: 48,
                      color: (isDark ? Colors.white : Colors.black87).withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No recent transactions'.tr(), // Localized
                      style: TextStyle(
                        color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your transaction history will appear here'.tr(), // Localized
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