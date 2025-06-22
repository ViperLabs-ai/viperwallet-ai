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
    // Solana Payment Request URI formatı: solana:<address>?amount=<amount>&spl-token=<mint>&memo=<memo>
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
      // Solana adresleri 32-44 karakter arası base58 encoded olmalı
      if (address.length < 32 || address.length > 44) return false;

      // Base58 karakterleri kontrol et
      final base58Regex = RegExp(r'^[1-9A-HJ-NP-Za-km-z]+$');
      return base58Regex.hasMatch(address);
    } catch (e) {
      return false;
    }
  }

  void _copyAddress() {
    // Adres doğrulaması
    if (!_isValidSolanaAddress(widget.wallet.address)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Geçersiz cüzdan adresi!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Clipboard.setData(ClipboardData(text: widget.wallet.address));

    // Haptic feedback ekle
    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            const Text('Adres güvenli şekilde kopyalandı!'),
          ],
        ),
        backgroundColor: const Color(0xFFFF6B35),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'Explorer\'da Gör',
          textColor: Colors.white,
          onPressed: () {
            // Solana Explorer'da adresi aç
            print('Open: https://explorer.solana.com/address/${widget.wallet.address}');
          },
        ),
      ),
    );
  }

  void _shareQRCode() async {
    try {
      final shareText = 'Solana cüzdan adresim: ${widget.wallet.address}\n\n'
          'QR kod ile ödeme: $_qrData\n\n'
          'Viper Wallet ile güvenli işlem yapın!';

      // Share package kullanılabilir: await Share.share(shareText);
      // Şimdilik clipboard'a kopyala
      await Clipboard.setData(ClipboardData(text: shareText));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Paylaşım bilgileri kopyalandı!'),
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
            content: Text('Paylaşım hatası: ${e.toString()}'),
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
        return 'Miktar 0\'dan büyük olmalı';
      }
      if (amount > 1000000) {
        return 'Miktar çok büyük';
      }
      // 9 decimal places check for SOL
      final parts = value.split('.');
      if (parts.length > 1 && parts[1].length > 9) {
        return 'En fazla 9 ondalık basamak';
      }
      return null;
    } catch (e) {
      return 'Geçersiz miktar';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'SOL Al',
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

                // QR Kod kartı
                _buildGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          'QR Kodu Taratın',
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
                          'Veya cüzdan adresini paylaşın',
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

                // Adres kartı
                _buildGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cüzdan Adresi',
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

                // Özelleştirme kartı
                _buildGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'QR Kodu Özelleştir',
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
                            labelText: 'Miktar (SOL)',
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
                            setState(() {}); // Validation mesajını güncellemek için
                          },
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller: _memoController,
                          maxLength: 32, // Solana memo limiti
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Memo (Opsiyonel)',
                            labelStyle: TextStyle(
                              color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                            ),
                            hintText: 'İşlem notu (max 32 karakter)',
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

                // Bilgi kartı
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
                          'Güvenlik Uyarısı',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'QR kodunuzu ve cüzdan adresinizi yalnızca güvendiğiniz kişilerle paylaşın. '
                              'Bu bilgiler size SOL göndermek için kullanılır. '
                              'Sahte QR kodlara dikkat edin ve işlemleri her zaman doğrulayın.',
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
