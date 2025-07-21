import 'dart:typed_data';
import 'dart:convert';
import 'dart:ui'; // For ImageFilter for glassmorphism
import 'dart:math'; // For pow function
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:solana/solana.dart';
import 'package:solana/encoder.dart';
import 'package:http/http.dart' as http; // Import the http package

// Define the TokenInfo class (consider moving to a separate models/token_info.dart file)
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
}

class FixedSendPage extends StatefulWidget {
  final Ed25519HDKeyPair wallet;
  const FixedSendPage({super.key, required this.wallet});

  @override
  State<FixedSendPage> createState() => _FixedSendPageState();
}

class _FixedSendPageState extends State<FixedSendPage> {
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  bool _isSending = false;
  String _statusMessage = '';
  double? _walletSolBalance; // To store the wallet's SOL balance
  bool _isLoadingBalances = false;

  // --- Token related state variables ---
  // A hypothetical list of all known tokens (in a real app, this might come from an API)
  final List<TokenInfo> _allTokens = [
    // Example tokens (add more as needed)
    TokenInfo(
      address: 'So11111111111111111111111111111111111111112',
      name: 'Solana',
      symbol: 'SOL',
      decimals: 9,
      logoURI: 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/So11111111111111111111111111111111111111112/logo.png',
      verified: true,
    ),
    TokenInfo(
      address: 'EPjFWdd5AufqSSqeM2qN1xzybapCrunchzgA6waPHKSc',
      name: 'USD Coin',
      symbol: 'USDC',
      decimals: 6,
      logoURI: 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/EPjFWdd5AufqSSqeM2qN1xzybapCrunchzgA6waPHKSc/logo.png',
      verified: true,
    ),
    TokenInfo(
      address: 'Es9TvaJjsC3hS92q9hWzK2NPNuGk8gB62Q52f8XjK5L',
      name: 'Tether USD',
      symbol: 'USDT',
      decimals: 6,
      logoURI: 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/Es9TvaJjsC3hS92q9hWzK2NPNuGk8gB62Q52f8XjK5L/logo.png',
      verified: true,
    ),
  ];

  // Predefined tokens for easy access, especially for SOL
  final Map<String, TokenInfo> _predefinedTokens = {
    'SOL': TokenInfo(
      address: 'So11111111111111111111111111111111111111112',
      name: 'Solana',
      symbol: 'SOL',
      decimals: 9,
      logoURI: 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/So11111111111111111111111111111111111111112/logo.png',
      verified: true,
    ),
    'USDC': TokenInfo(
      address: 'EPjFWdd5AufqSSqeM2qN1xzybapCrunchzgA6waPHKSc',
      name: 'USD Coin',
      symbol: 'USDC',
      decimals: 6,
      logoURI: 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/EPjFWdd5AufqSSqeM2qN1xzybapCrunchzgA6waPHKSc/logo.png',
      verified: true,
    ),
  };

  List<TokenInfo> _walletTokens = []; // Tokens the user's wallet holds
  Map<String, double> _tokenBalances = {}; // Balances for each token symbol
  TokenInfo? _selectedFromTokenInfo; // The token currently selected for sending

  // New map to cache fetched token metadata
  final Map<String, TokenInfo> _tokenMetadataCache = {};

  @override
  void initState() {
    super.initState();
    _loadWalletData(); // Load both SOL and SPL token balances
  }

  // Combines SOL balance and SPL token balances loading
  Future<void> _loadWalletData() async {
    setState(() {
      _isLoadingBalances = true;
    });
    await _loadSolBalance(); // Load SOL balance first
    await _loadTokenBalances(); // Then load other token balances
    setState(() {
      _isLoadingBalances = false;
    });
  }

  // Fetches SOL balance specifically
  Future<void> _loadSolBalance() async {
    try {
      final rpcClient = SolanaClient(
        rpcUrl: Uri.parse('https://mainnet.helius-rpc.com/?api-key='),
        websocketUrl: Uri.parse('wss://api.mainnet-beta.solana.com'),
      );
      final balanceResponse = await rpcClient.rpcClient.getBalance(
        widget.wallet.publicKey.toBase58(),
      );
      if (mounted) {
        setState(() {
          _walletSolBalance = balanceResponse.value / lamportsPerSol.toDouble();
          _tokenBalances['SOL'] = _walletSolBalance!; // Update tokenBalances map for SOL
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to load SOL balance: $e');
      if (mounted) {
        setState(() {
          _statusMessage = 'Failed to load SOL balance: $e';
        });
      }
    }
  }

  // --- New functions for token handling ---

  // Function to fetch token metadata from Jupiter's token list
  Future<TokenInfo> _getJupiterTokenMetadata(String mintAddress) async {
    if (_tokenMetadataCache.containsKey(mintAddress)) {
      return _tokenMetadataCache[mintAddress]!;
    }

    // Check predefined tokens first
    final predefined = _predefinedTokens.values.firstWhere(
            (t) => t.address == mintAddress,
        orElse: () => TokenInfo(address: '', name: '', symbol: '', decimals: 0));

    if (predefined.address.isNotEmpty) {
      _tokenMetadataCache[mintAddress] = predefined;
      return predefined;
    }


    try {
      final response = await http.get(Uri.parse('https://token.jup.ag/strict'));
      if (response.statusCode == 200) {
        final List<dynamic> tokens = jsonDecode(response.body);
        final tokenData = tokens.firstWhere(
              (token) => token['address'] == mintAddress,
          orElse: () => null,
        );

        if (tokenData != null) {
          final tokenInfo = TokenInfo(
            address: tokenData['address'],
            name: tokenData['name'],
            symbol: tokenData['symbol'],
            decimals: tokenData['decimals'],
            logoURI: tokenData['logoURI'],
            verified: tokenData['verified'] ?? false,
          );
          _tokenMetadataCache[mintAddress] = tokenInfo; // Cache the result
          return tokenInfo;
        }
      }
    } catch (e) {
      debugPrint('Error fetching token metadata from Jupiter: $e');
    }

    // Fallback if not found in Jupiter or predefined, or on error
    final fallbackToken = _allTokens.firstWhere(
          (t) => t.address == mintAddress,
      orElse: () => TokenInfo(
        address: mintAddress,
        name: 'Unknown Token',
        symbol: mintAddress.substring(0, 6),
        decimals: 0, // Default, will be updated if found
        verified: false,
      ),
    );
    _tokenMetadataCache[mintAddress] = fallbackToken; // Cache fallback
    return fallbackToken;
  }

  // New function to fetch token balances using Helius
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
            "showNativeBalance": false, // We fetch native SOL balance separately
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
            final tokenInfo = await _getJupiterTokenMetadata(mint); // Use Jupiter metadata
            tokens.add({
              'mint': mint,
              'balance': uiAmount,
              'decimals': decimals,
              'name': tokenInfo.name,
              'symbol': tokenInfo.symbol,
              'logoURI': tokenInfo.logoURI,
              'verified': tokenInfo.verified,
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

    // Do not clear _tokenBalances or _walletTokens here entirely
    // as SOL balance might have been loaded already.
    // Clear only non-SOL tokens if you want to refresh all except SOL.
    _walletTokens.removeWhere((token) => token.symbol != 'SOL');
    _tokenBalances.removeWhere((key, value) => key != 'SOL');


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
            // Add to _walletTokens only if not already present (e.g., SOL is added via _predefinedTokens)
            if (!_walletTokens.any((t) => t.address == tokenInfo.address)) {
              _walletTokens.add(tokenInfo);
            }
          }

          // Ensure SOL is always in _walletTokens if not already added by Helius
          if (!_walletTokens.any((token) => token.symbol == 'SOL')) {
            _walletTokens.insert(0, _predefinedTokens['SOL']!);
          }

          // Set the default selected token to SOL if it exists, otherwise the first token
          if (_walletTokens.isNotEmpty && _selectedFromTokenInfo == null) {
            _selectedFromTokenInfo = _walletTokens.firstWhere(
                  (token) => token.symbol == 'SOL',
              orElse: () => _walletTokens.first,
            );
          } else if (_walletTokens.isNotEmpty && _selectedFromTokenInfo != null) {
            // If a token was previously selected, try to keep it selected if it's still in the list
            _selectedFromTokenInfo = _walletTokens.firstWhere(
                  (token) => token.address == _selectedFromTokenInfo!.address,
              orElse: () => _walletTokens.first,
            );
          } else if (_walletTokens.isEmpty) {
            _selectedFromTokenInfo = null;
          }
        });
        debugPrint('✅ Wallet balances loaded: $_tokenBalances');
      }
    } catch (e) {
      debugPrint('❌ Balance loading error: $e');
      if (mounted) {
        _showErrorDialog('Balance Error', 'Could not load wallet token balances. Please try again.\n$e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingBalances = false);
      }
    }
  }

  // --- End of new functions for token handling ---

  Future<void> _sendSol() async {
    if (_selectedFromTokenInfo == null) {
      _showErrorDialog('No Token Selected', 'Please select a token to send.');
      return;
    }

    if (_selectedFromTokenInfo!.symbol != 'SOL') {
      _showErrorDialog('Coming Soon', 'Currently, only SOL transfers are supported. Support for other tokens is coming soon!');
      return;
    }

    setState(() {
      _isSending = true;
      _statusMessage = '';
    });

    try {
      final rpcClient = SolanaClient(
        rpcUrl: Uri.parse('https://mainnet.helius-rpc.com/?api-key='),
        websocketUrl: Uri.parse('wss://api.mainnet-beta.solana.com'),
      );

      final lamports = ((double.tryParse(_amountController.text) ?? 0) * lamportsPerSol).toInt();
      final recipient = Ed25519HDPublicKey.fromBase58(_recipientController.text.trim());

      final latestBlockhash = await rpcClient.rpcClient.getLatestBlockhash();
      final blockhashValue = latestBlockhash.value.blockhash;

      final transferIx = SystemInstruction.transfer(
        fundingAccount: widget.wallet.publicKey,
        recipientAccount: recipient,
        lamports: lamports,
      );

      final instructions = <Instruction>[transferIx];

      if (_memoController.text.isNotEmpty) {
        final memoInstruction = Instruction(
          programId: Ed25519HDPublicKey.fromBase58('MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr'),
          accounts: [],
          data: ByteArray(utf8.encode(_memoController.text)),
        );
        instructions.add(memoInstruction);
      }

      final message = Message(instructions: instructions);
      final compiled = message.compile(
        recentBlockhash: blockhashValue,
        feePayer: widget.wallet.publicKey,
      );

      final signature = await widget.wallet.sign(compiled.toByteArray());
      final signedTx = SignedTx(
        compiledMessage: compiled,
        signatures: [signature],
      );

      final txSig = await rpcClient.rpcClient.sendTransaction(signedTx.encode());

      setState(() {
        _statusMessage = '✅ Sent! Transaction ID: $txSig';
      });

      // Show success alert dialog
      _showSuccessAlertDialog();

      // Refresh balance after successful transaction
      _loadWalletData(); // Reload all balances

    } catch (e) {
      setState(() {
        _statusMessage = '❌ Send error: $e';
      });
      _showErrorDialog('Transaction Failed', 'An error occurred during the transaction:\n$e');
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _showSuccessAlertDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Stack(
          children: [
            // Blurred background for glassmorphism
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
              child: Container(
                color: Colors.black.withOpacity(0.1),
              ),
            ),
            AlertDialog(
              backgroundColor: Colors.transparent, // Make background transparent to show blur
              contentPadding: EdgeInsets.zero,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              content: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0), // Apply blur to the dialog content
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1), // Translucent background
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 60),
                          const SizedBox(height: 20),
                          const Text(
                            'Transaction Successful',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Your transaction has been successfully completed.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () {
                                Navigator.of(context).pop(); // Dismiss the dialog
                                Navigator.of(context).pop(); // Go back to the previous screen (optional)
                              },
                              child: const Text(
                                'OK',
                                style: TextStyle(
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
              ),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.orange,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'OK',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Function to add a decimal point to the amount controller
  void _addDecimalPoint() {
    if (!_amountController.text.contains('.')) {
      if (_amountController.text.isEmpty) {
        _amountController.text = '0.';
      } else {
        _amountController.text += '.';
      }
    }
  }

  // Function to set the maximum wallet balance for the selected token
  void _setMaxAmount() {
    if (_selectedFromTokenInfo != null && _tokenBalances.containsKey(_selectedFromTokenInfo!.symbol)) {
      final balance = _tokenBalances[_selectedFromTokenInfo!.symbol];
      if (balance != null) {
        _amountController.text = balance.toStringAsFixed(_selectedFromTokenInfo!.decimals);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Send ${_selectedFromTokenInfo?.symbol ?? 'Token'}'.tr(), // Dynamic based on selected token
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF000000),
              Color(0xFF1A1A1A),
              Color(0xFF2D1810),
              Color(0xFF1A1A1A),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Wallet info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.purple,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sender Wallet'.tr(),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${widget.wallet.address.substring(0, 8)}...${widget.wallet.address.substring(widget.wallet.address.length - 8)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          // Display SOL balance
                          if (_tokenBalances.containsKey('SOL'))
                            Text(
                              'SOL Balance: ${_tokenBalances['SOL']!.toStringAsFixed(4)} SOL',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          if (!_tokenBalances.containsKey('SOL') && _isLoadingBalances)
                            const Text(
                              'SOL Balance: Loading...',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          if (!_tokenBalances.containsKey('SOL') && !_isLoadingBalances && _statusMessage.contains('Failed to load SOL balance'))
                            const Text(
                              'SOL Balance: N/A',
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

              // Recipient Address
              Text(
                'Recipient Address'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                child: TextField(
                  controller: _recipientController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter Solana wallet address'.tr(),
                    hintStyle: const TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                    prefixIcon: const Icon(Icons.person, color: Colors.grey),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Token Selector (Dropdown)
              Text(
                'Select Token'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<TokenInfo>(
                    value: _selectedFromTokenInfo,
                    hint: Text(
                      _isLoadingBalances ? 'Loading Tokens...' : 'Select a token',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    icon: _isLoadingBalances
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                    )
                        : const Icon(Icons.arrow_drop_down, color: Colors.white),
                    dropdownColor: const Color(0xFF0A0A0A), // Dropdown background color
                    isExpanded: true,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    onChanged: _isLoadingBalances
                        ? null
                        : (TokenInfo? newValue) {
                      setState(() {
                        _selectedFromTokenInfo = newValue;
                        _amountController.clear(); // Clear amount when token changes
                        if (newValue?.symbol != 'SOL') {
                          _showErrorDialog('Coming Soon', 'Currently, only SOL transfers are supported. Support for other tokens is coming soon!');
                          _statusMessage = 'Note: Only SOL transfers are currently supported. Other tokens coming soon!';
                        } else {
                          _statusMessage = '';
                        }
                      });
                    },
                    items: _walletTokens.map<DropdownMenuItem<TokenInfo>>((TokenInfo token) {
                      return DropdownMenuItem<TokenInfo>(
                        value: token,
                        child: Row(
                          children: [
                            if (token.logoURI != null && Uri.tryParse(token.logoURI!)?.isAbsolute == true)
                              Image.network(
                                token.logoURI!,
                                width: 24,
                                height: 24,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.token, color: Colors.grey),
                              )
                            else
                              const Icon(Icons.token, color: Colors.grey),
                            const SizedBox(width: 10),
                            Text(
                              token.symbol,
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${_tokenBalances[token.symbol]?.toStringAsFixed(4) ?? '0.0000'})',
                              style: const TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Amount
              Text(
                'Amount (${_selectedFromTokenInfo?.symbol ?? 'SOL'})'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                child: TextField(
                  controller: _amountController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'Min 0.001',
                    hintStyle: const TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                    prefixIcon: const Icon(Icons.monetization_on, color: Colors.orange),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // "Max" button
                        GestureDetector(
                          onTap: _setMaxAmount,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Max'.tr(),
                              style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        // Decimal point button
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: IconButton(
                            icon: const Text(
                              '.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: _addDecimalPoint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Memo (Optional)
              Text(
                'Memo (Optional)'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                child: TextField(
                  controller: _memoController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Add a transaction note (optional)'.tr(),
                    hintStyle: const TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                    prefixIcon: const Icon(Icons.note, color: Colors.grey),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Send Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSending ? null : _sendSol,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isSending
                      ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Sending...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                      : Text(
                    'SEND ${_selectedFromTokenInfo?.symbol ?? 'SOL'}'.tr(), // Dynamic button text
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Status Message
              if (_statusMessage.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _statusMessage.startsWith('✅')
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _statusMessage.startsWith('✅')
                          ? Colors.green.withOpacity(0.3)
                          : Colors.red.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _statusMessage.startsWith('✅')
                            ? Icons.check_circle
                            : Icons.error_outline_rounded,
                        color: _statusMessage.startsWith('✅')
                            ? Colors.green
                            : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _statusMessage.tr(), // Translate the status message
                          style: TextStyle(
                            color: _statusMessage.startsWith('✅')
                                ? Colors.green
                                : (_statusMessage.startsWith('Note:') ? Colors.orange : Colors.red),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Security Notice
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.security,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Security Warning'.tr(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Carefully check the recipient address. Transactions are irreversible. Tokens sent to the wrong address may be lost.'.tr(),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
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
    );
  }
}

const lamportsPerSol = 1000000000;