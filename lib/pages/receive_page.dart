import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:solana/solana.dart';
import 'package:easy_localization/easy_localization.dart';

class ReceivePage extends StatefulWidget {
  final Ed25519HDKeyPair wallet;

  const ReceivePage({super.key, required this.wallet});

  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage> {
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  String _qrData = '';

  @override
  void initState() {
    super.initState();
    _qrData = widget.wallet.address;
  }

  void _updateQRCode() {
    // Solana Payment Request URI format: solana:<address>?amount=<amount>&spl-token=<mint>&memo=<memo>
    String qrData = 'solana:${widget.wallet.address}';

    List<String> params = [];

    if (_amountController.text.isNotEmpty) {
      try {
        final amount = double.parse(_amountController.text);
        if (amount > 0) {
          params.add('amount=${amount.toStringAsFixed(9)}'); // SOL has 9 decimals
        }
      } catch (e) {
        // Invalid amount, skip
      }
    }

    if (_memoController.text.isNotEmpty) {
      // URL encode memo for safety
      final encodedMemo = Uri.encodeComponent(_memoController.text);
      params.add('memo=$encodedMemo');
    }

    if (params.isNotEmpty) {
      qrData += '?${params.join('&')}';
    }

    setState(() {
      _qrData = qrData;
    });
  }

  bool _isValidSolanaAddress(String address) {
    try {
      // Solana addresses should be 32-44 characters base58 encoded
      if (address.length < 32 || address.length > 44) return false;

      // Check for Base58 characters
      final base58Regex = RegExp(r'^[1-9A-HJ-NP-Za-km-z]+$');
      return base58Regex.hasMatch(address);
    } catch (e) {
      return false;
    }
  }

  void _copyAddress() {
    // Address validation
    if (!_isValidSolanaAddress(widget.wallet.address)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid wallet address!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Clipboard.setData(ClipboardData(text: widget.wallet.address));

    // Add haptic feedback
    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            const Text('Address securely copied!'),
          ],
        ),
        backgroundColor: const Color(0xFFFF6B35),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'View on Explorer',
          textColor: Colors.white,
          onPressed: () {
            // Open address on Solana Explorer
            print('Open: https://explorer.solana.com/address/${widget.wallet.address}');
          },
        ),
      ),
    );
  }

  void _shareQRCode() async {
    try {
      final shareText = 'My Solana wallet address: ${widget.wallet.address}\n\n'
          'Pay with QR code: $_qrData\n\n'
          'Transact securely with Viper Wallet!';

      // Can use share package: await Share.share(shareText);
      // For now, copy to clipboard
      await Clipboard.setData(ClipboardData(text: shareText));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share information copied!'.tr()),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  String? _validateAmount(String value) {
    if (value.isEmpty) return null;

    try {
      final amount = double.parse(value);
      if (amount <= 0) {
        return 'Amount must be greater than 0';
      }
      if (amount > 1000000) {
        return 'Amount is too large';
      }
      // 9 decimal places check for SOL
      final parts = value.split('.');
      if (parts.length > 1 && parts[1].length > 9) {
        return 'Max 9 decimal places';
      }
      return null;
    } catch (e) {
      return 'Invalid amount';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Receive SOL'.tr(),
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
        actions: [
          IconButton(
            onPressed: _shareQRCode,
            icon: const Icon(Icons.share),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                // QR Code card
                _buildGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          'Scan QR Code'.tr(),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // QR Code
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: _qrData,
                            version: QrVersions.auto,
                            size: 200.0,
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                          ),
                        ),

                        const SizedBox(height: 20),

                        Text(
                          'Or share your wallet address'.tr(),
                          style: TextStyle(
                            color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Address card
                _buildGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wallet Address'.tr(),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.black : Colors.grey[100])!.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFFF6B35).withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: SelectableText(
                                  widget.wallet.address,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black87,
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _copyAddress,
                                icon: const Icon(
                                  Icons.copy,
                                  color: Color(0xFFFF6B35),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Customization card
                _buildGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Customize QR Code'.tr(),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Amount (SOL)'.tr(),
                            labelStyle: TextStyle(
                              color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                            ),
                            hintText: '0.000000000',
                            hintStyle: TextStyle(
                              color: (isDark ? Colors.white : Colors.black87).withOpacity(0.5),
                            ),
                            prefixIcon: const Icon(
                              Icons.monetization_on,
                              color: Color(0xFFFF6B35),
                            ),
                            suffixText: 'SOL',
                            suffixStyle: TextStyle(
                              color: const Color(0xFFFF6B35),
                              fontWeight: FontWeight.bold,
                            ),
                            errorText: _amountController.text.isNotEmpty ? _validateAmount(_amountController.text) : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: const Color(0xFFFF6B35).withOpacity(0.3),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFFF6B35),
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 1,
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            _updateQRCode();
                            setState(() {}); // Update validation message
                          },
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller: _memoController,
                          maxLength: 32, // Solana memo limit
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Memo (Optional)'.tr(),
                            labelStyle: TextStyle(
                              color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                            ),
                            hintText: 'Transaction note (max 32 chars)'.tr(),
                            hintStyle: TextStyle(
                              color: (isDark ? Colors.white : Colors.black87).withOpacity(0.5),
                            ),
                            prefixIcon: const Icon(
                              Icons.note,
                              color: Color(0xFFFF6B35),
                            ),
                            counterStyle: TextStyle(
                              color: (isDark ? Colors.white : Colors.black87).withOpacity(0.6),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: const Color(0xFFFF6B35).withOpacity(0.3),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFFF6B35),
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (value) => _updateQRCode(),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Info card
                _buildGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: const Color(0xFFFF6B35),
                          size: 32,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Security Warning'.tr(),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Share your QR code and wallet address only with people you trust. '
                              'This information is used to send SOL to you. '
                              'Beware of fake QR codes and always verify transactions.'.tr(),
                          style: TextStyle(
                            color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
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
    );
  }
}
