import 'dart:ui';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solana/dto.dart';
import 'package:solana/solana.dart';
import 'package:bs58/bs58.dart';
import 'package:crypto/crypto.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../l10n/app_localizations.dart';
import '../services/rpc_service.dart';

class SendPage extends StatefulWidget {
  final Ed25519HDKeyPair wallet;

  const SendPage({super.key, required this.wallet});

  @override
  State<SendPage> createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  int? _balance;
  double? _estimatedFee;
  String? _recentBlockhash;
  String _networkStatus = '';

  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadBalance();
    _estimateFee();
    _loadRecentBlockhash();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
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

    _slideController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    _memoController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    final l10n = AppLocalizations.of(context);

    try {
      setState(() {
        _networkStatus = l10n?.loadingBalance ?? 'Loading balance...';
      });

      final balanceResult = await RpcService.executeWithFallback<BalanceResult>(
            (client) => client.getBalance(widget.wallet.address),
      );

      if (mounted) {
        setState(() {
          _balance = balanceResult.value;
          _networkStatus = l10n?.connected ?? 'Connected';
        });
      }
    } catch (e) {
      print('Bakiye yüklenirken hata: $e');
      if (mounted) {
        setState(() {
          _networkStatus = l10n?.connectionError ?? 'Connection Error';
        });
        _showErrorSnackBar(l10n?.balanceLoadFailed ?? 'Balance could not be loaded: Check network connection');
      }
    }
  }

  Future<void> _loadRecentBlockhash() async {
    try {
      final blockhashResult = await RpcService.executeWithFallback<LatestBlockhashResult>(
            (client) => client.getLatestBlockhash(),
      );

      if (mounted) {
        setState(() {
          _recentBlockhash = blockhashResult.value.blockhash;
        });
      }
    } catch (e) {
      print('Blockhash yüklenirken hata: $e');
    }
  }

  Future<void> _estimateFee() async {
    try {
      setState(() {
        _estimatedFee = 0.000005;
      });
    } catch (e) {
      print('Fee estimation error: $e');
    }
  }

  bool _isValidSolanaAddress(String address) {
    try {
      if (address.length < 32 || address.length > 44) return false;
      final base58Regex = RegExp(r'^[1-9A-HJ-NP-Za-km-z]+$');
      return base58Regex.hasMatch(address);
    } catch (e) {
      return false;
    }
  }

  String? _validateAmount(String value) {
    final l10n = AppLocalizations.of(context);

    if (value.isEmpty) return 'Amount is required' ?? 'Amount is required';

    try {
      final amount = double.parse(value);
      if (amount <= 0) return 'Amount must be greater than 0' ?? 'Amount must be greater than 0';

      final lamports = (amount * 1000000000).toInt();
      final fee = (_estimatedFee ?? 0.000005) * 1000000000;
      final totalRequired = lamports + fee.toInt();

      if (_balance != null && totalRequired > _balance!) {
        return l10n?.insufficientBalance ?? 'Insufficient balance (including fee)';
      }

      final parts = value.split('.');
      if (parts.length > 1 && parts[1].length > 9) {
        return 'Maximum 9 decimal places' ?? 'Maximum 9 decimal places';
      }

      return null;
    } catch (e) {
      return 'Invalid amount' ?? 'Invalid amount';
    }
  }

  Widget _buildGlassCard({
    required Widget child,
    EdgeInsets? padding,
    double? borderRadius,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius ?? 24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: padding ?? const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(borderRadius ?? 24),
              border: Border.all(
                color: const Color(0xFFFF6B35).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Future<void> _scanQRCode() async {
    final l10n = AppLocalizations.of(context);

    try {
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => QRScannerPage(l10n: l10n),
        ),
      );

      if (result != null && mounted) {
        setState(() {
          _recipientController.text = result;
        });

        HapticFeedback.lightImpact();
        _showSuccessSnackBar(l10n?.scanQRCode ?? 'QR code scanned successfully!', '');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('${l10n?.error ?? 'QR code scanning error'}: $e');
      }
    }
  }

  Future<bool> _showConfirmationDialog() async {
    final l10n = AppLocalizations.of(context);
    final amount = double.parse(_amountController.text);
    final fee = _estimatedFee ?? 0.000005;
    final total = amount + fee;

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.warning, color: Colors.orange, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n?.confirmTransaction ?? 'Transaction Confirmation',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n?.irreversibleTransaction ?? 'WARNING: IRREVERSIBLE TRANSACTION',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• ${l10n?.irreversibleTransaction ?? 'This transaction will occur on Solana mainnet'}\n'
                          '• ${l10n?.irreversibleTransaction ?? 'Transaction cannot be reversed'}\n'
                          '• ${l10n?.irreversibleTransaction ?? 'Carefully check recipient address'}\n'
                          '• ${l10n?.networkFee ?? 'Network fee will be paid'}\n'
                          '• ${l10n?.irreversibleTransaction ?? 'Private key will be used'}',
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n?.transactionDetails ?? 'Transaction Details:',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.black54,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFF6B35).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(l10n?.receiver ?? 'Recipient:', '${_recipientController.text.substring(0, 8)}...${_recipientController.text.substring(_recipientController.text.length - 8)}'),
                    const SizedBox(height: 8),
                    _buildDetailRow(l10n?.amount ?? 'Amount:', '${double.parse(_amountController.text).toStringAsFixed(9)} SOL'),
                    const SizedBox(height: 8),
                    _buildDetailRow(l10n?.networkFee ?? 'Network Fee:', '${(_estimatedFee ?? 0.000005).toStringAsFixed(9)} SOL'),
                    const Divider(height: 20),
                    _buildDetailRow(l10n?.total ?? 'Total:', '${double.parse(_amountController.text) + (_estimatedFee ?? 0.000005)} SOL', isTotal: true),
                    if (_memoController.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildDetailRow(l10n?.memo ?? 'Memo:', _memoController.text),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              l10n?.cancel ?? 'Cancel',
              style: const TextStyle(fontSize: 16),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              l10n?.confirmAndSend ?? 'CONFIRM AND SEND',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 14 : 13,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 14 : 13,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Future<void> _sendTransaction() async {
    final l10n = AppLocalizations.of(context);

    if (_recipientController.text.isEmpty || _amountController.text.isEmpty) {
      //_showErrorSnackBar(l10n?.invalidAmount ?? 'Please fill in all required fields');
      return;
    }

    if (!_isValidSolanaAddress(_recipientController.text)) {
      _showErrorSnackBar(l10n?.invalidSolanaAddress ?? 'Invalid Solana address');
      return;
    }

    final amountError = _validateAmount(_amountController.text);
    if (amountError != null) {
      _showErrorSnackBar(amountError);
      return;
    }

    if (_recentBlockhash == null) {
      _showErrorSnackBar('Blockhash loading, please wait...');
      await _loadRecentBlockhash();
      return;
    }

    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text);
      final lamports = (amount * 1000000000).toInt();

      final signature = await _createAndSendTransaction(
        recipient: _recipientController.text,
        lamports: lamports,
        memo: _memoController.text.isNotEmpty ? _memoController.text : null,
      );

      if (mounted) {
        HapticFeedback.heavyImpact();
        _showSuccessSnackBar(l10n?.transactionSuccessful ?? 'Transaction sent successfully!', signature);

        _recipientController.clear();
        _amountController.clear();
        _memoController.clear();
        await _loadBalance();

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) Navigator.pop(context, true);
        });
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        //_showErrorSnackBar('${l10n?.transactionError ?? 'Transaction error'}: ${e.toString()}');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<String> _createAndSendTransaction({
    required String recipient,
    required int lamports,
    String? memo,
  }) async {
    try {
      await _loadRecentBlockhash();

      if (_recentBlockhash == null) {
        throw Exception('Could not get blockhash');
      }

      final transferInstruction = SystemInstruction.transfer(
        fundingAccount: widget.wallet.publicKey,
        recipientAccount: Ed25519HDPublicKey.fromBase58(recipient),
        lamports: lamports,
      );

      final instructions = [transferInstruction];
      final message = Message(instructions: instructions);

      final compiledMessage = message.compile(
        recentBlockhash: _recentBlockhash!,
        feePayer: widget.wallet.publicKey,
      );

      final signature = await _sendCompiledTransactionWithFallback(compiledMessage);

      if (memo != null && memo.isNotEmpty) {
        print('Memo (not added to transaction): $memo');
      }

      await _waitForConfirmation(signature);

      return signature;
    } catch (e) {
      print('Transaction error details: $e');
      throw Exception('Transaction failed: ${e.toString()}');
    }
  }

  Future<String> _sendCompiledTransactionWithFallback(dynamic compiledMessage) async {
    try {
      final messageBytes = compiledMessage.toByteArray();
      final messageList = <int>[];
      for (int i = 0; i < messageBytes.length; i++) {
        messageList.add(messageBytes[i]);
      }

      final messageUint8List = Uint8List.fromList(messageList);
      final signature = await widget.wallet.sign(messageUint8List);
      final signatureBytes = await signature.bytes;

      final transactionBytes = <int>[];
      transactionBytes.add(1);
      transactionBytes.addAll(signatureBytes);
      transactionBytes.addAll(messageList);

      final encodedTransaction = base64.encode(transactionBytes);

      final txSignature = await RpcService.executeWithFallback<String>(
            (client) => client.sendTransaction(
          encodedTransaction,
          preflightCommitment: Commitment.processed,
        ),
      );

      return txSignature;
    } catch (e) {
      throw Exception('Transaction sending error: $e');
    }
  }

  Future<void> _waitForConfirmation(String signature) async {
    print('Transaction sent, waiting for confirmation: $signature');

    for (int i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 1));

      try {
        final statuses = await RpcService.executeWithFallback<SignatureStatusesResult>(
              (client) => client.getSignatureStatuses([signature]),
        );

        if (statuses.value.isNotEmpty && statuses.value.first != null) {
          final status = statuses.value.first!;

          print('Transaction status: ${status.confirmationStatus}');

          if (status.confirmationStatus == 'confirmed' ||
              status.confirmationStatus == 'finalized') {
            print('Transaction confirmed!');
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

    print('Confirmation timeout - transaction may still be processing');
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar(String message, String signature) {
    final l10n = AppLocalizations.of(context);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 6),
        margin: const EdgeInsets.all(16),
        action: signature.isNotEmpty ? SnackBarAction(
          label: l10n?.viewInExplorer ?? 'View in Explorer',
          textColor: Colors.white,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: 'https://explorer.solana.com/tx/$signature'));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n?.viewInExplorer ?? 'Explorer link copied!'),
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.blue.shade600,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.all(16),
              ),
            );
          },
        ) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sol = _balance != null ? _balance! / 1000000000 : 0.0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          l10n?.sendSOL ?? 'Send SOL',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isDark ? Colors.black : Colors.white).withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFF6B35).withOpacity(0.3),
              ),
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Color(0xFFFF6B35),
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (_recentBlockhash != null ? Colors.green : Colors.orange).withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (_recentBlockhash != null ? Colors.green : Colors.orange).withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _recentBlockhash != null ? Colors.green : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _networkStatus,
                  style: TextStyle(
                    color: _recentBlockhash != null ? Colors.green : Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
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
              onPressed: () async {
                HapticFeedback.lightImpact();
                await _loadBalance();
                await _loadRecentBlockhash();
              },
              icon: const Icon(
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
              const Color(0xFFFAFAFA),
              const Color(0xFFF5F5F5),
              const Color(0xFFFFF5F0),
            ],
          ),
        ),
        child: SafeArea(
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),

                    // Balance card
                    _buildGlassCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6B35).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.account_balance_wallet,
                                  color: Color(0xFFFF6B35),
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n?.currentBalance ?? 'Current Balance',
                                      style: TextStyle(
                                        color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${sol.toStringAsFixed(6)} SOL',
                                      style: TextStyle(
                                        color: isDark ? Colors.white : Colors.black87,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (_estimatedFee != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '${l10n?.estimatedFee ?? 'Estimated Fee'}: ${_estimatedFee!.toStringAsFixed(9)} SOL',
                                        style: TextStyle(
                                          color: (isDark ? Colors.white : Colors.black87).withOpacity(0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Form
                    Expanded(
                      child: _buildGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n?.recipientAddress ?? 'Recipient Address',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _recipientController,
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: l10n?.enterRecipientAddress ?? 'Enter Solana wallet address...',
                                      hintStyle: TextStyle(
                                        color: (isDark ? Colors.white : Colors.black87).withOpacity(0.5),
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.person_outline,
                                        color: Color(0xFFFF6B35),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: const Color(0xFFFF6B35).withOpacity(0.3),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: const Color(0xFFFF6B35).withOpacity(0.3),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFFF6B35),
                                          width: 2,
                                        ),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(
                                          color: Colors.red,
                                          width: 1,
                                        ),
                                      ),
                                      suffixIcon: _recipientController.text.isNotEmpty &&
                                          _isValidSolanaAddress(_recipientController.text)
                                          ? const Icon(Icons.check_circle, color: Colors.green)
                                          : null,
                                    ),
                                    onChanged: (value) => setState(() {}),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return l10n?.recipientAddress ?? 'Recipient address is required';
                                      }
                                      if (!_isValidSolanaAddress(value)) {
                                        return l10n?.invalidSolanaAddress ?? 'Invalid Solana address';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF6B35).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFFF6B35).withOpacity(0.3),
                                    ),
                                  ),
                                  child: IconButton(
                                    onPressed: _scanQRCode,
                                    icon: const Icon(
                                      Icons.qr_code_scanner,
                                      color: Color(0xFFFF6B35),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            Text(
                              l10n?.amountInSOL ?? 'Amount (SOL)',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: '0.000000',
                                hintStyle: TextStyle(
                                  color: (isDark ? Colors.white : Colors.black87).withOpacity(0.5),
                                ),
                                prefixIcon: const Icon(
                                  Icons.monetization_on_outlined,
                                  color: Color(0xFFFF6B35),
                                ),
                                suffixText: 'SOL',
                                suffixStyle: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: const Color(0xFFFF6B35).withOpacity(0.3),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: const Color(0xFFFF6B35).withOpacity(0.3),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFFF6B35),
                                    width: 2,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Colors.red,
                                    width: 1,
                                  ),
                                ),
                              ),
                              onChanged: (value) => setState(() {}),
                              validator: (value) => _validateAmount(value ?? ''),
                            ),

                            const SizedBox(height: 16),

                            // Quick amount buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildQuickAmountButton('25%', 0.25, l10n),
                                _buildQuickAmountButton('50%', 0.5, l10n),
                                _buildQuickAmountButton('75%', 0.75, l10n),
                                _buildQuickAmountButton(l10n?.maxAmount ?? 'MAX', 0.95, l10n),
                              ],
                            ),

                            const SizedBox(height: 24),

                            Text(
                              l10n?.memoOptional ?? 'Memo (Optional)',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _memoController,
                              maxLength: 32,
                              maxLines: 2,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              decoration: InputDecoration(
                                hintText: l10n?.transactionMemo ?? 'Transaction note (max 32 characters)',
                                hintStyle: TextStyle(
                                  color: (isDark ? Colors.white : Colors.black87).withOpacity(0.5),
                                ),
                                prefixIcon: const Icon(
                                  Icons.note_outlined,
                                  color: Color(0xFFFF6B35),
                                ),
                                counterStyle: TextStyle(
                                  color: (isDark ? Colors.white : Colors.black87).withOpacity(0.6),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: const Color(0xFFFF6B35).withOpacity(0.3),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: const Color(0xFFFF6B35).withOpacity(0.3),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFFF6B35),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),

                            const Spacer(),

                            // Send button
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _canSend() && !_isLoading ? _pulseAnimation.value : 1.0,
                                  child: Container(
                                    width: double.infinity,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: _canSend()
                                            ? [const Color(0xFFFF6B35), const Color(0xFFFF8C42)]
                                            : [Colors.grey.shade400, Colors.grey.shade600],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: _canSend() && !_isLoading
                                          ? [
                                        BoxShadow(
                                          color: const Color(0xFFFF6B35).withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                          : null,
                                    ),
                                    child: ElevatedButton(
                                      onPressed: (_isLoading || !_canSend()) ? null : _sendTransaction,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          strokeWidth: 2,
                                        ),
                                      )
                                          : Text(
                                        l10n?.secureTransfer ?? 'SECURE SEND',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
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
    );
  }

  Widget _buildQuickAmountButton(String label, double percentage, AppLocalizations? l10n) {
    final sol = _balance != null ? _balance! / 1000000000 : 0.0;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: OutlinedButton(
          onPressed: () {
            final maxAmount = sol - (_estimatedFee ?? 0.000005);
            if (maxAmount > 0) {
              _amountController.text = (maxAmount * percentage).toStringAsFixed(6);
              setState(() {});
              HapticFeedback.lightImpact();
            }
          },
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFFF6B35)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFF6B35),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  bool _canSend() {
    return _recipientController.text.isNotEmpty &&
        _amountController.text.isNotEmpty &&
        _isValidSolanaAddress(_recipientController.text) &&
        _validateAmount(_amountController.text) == null &&
        _recentBlockhash != null &&
        !_isLoading;
  }
}

class QRScannerPage extends StatefulWidget {
  final AppLocalizations? l10n;

  const QRScannerPage({super.key, this.l10n});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.l10n?.scanQRCode ?? 'Scan QR Code',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => cameraController.toggleTorch(),
            icon: const Icon(Icons.flash_on),
          ),
          IconButton(
            onPressed: () => cameraController.switchCamera(),
            icon: const Icon(Icons.camera_rear),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              if (!_isScanned) {
                _isScanned = true;
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    HapticFeedback.heavyImpact();
                    Navigator.pop(context, barcode.rawValue);
                    break;
                  }
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFFFF6B35),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                widget.l10n?.scanToReceive ?? 'Place QR code within the frame',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}
