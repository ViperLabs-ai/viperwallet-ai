import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solana/solana.dart';
import 'package:easy_localization/easy_localization.dart';

class TransactionHistoryPage extends StatefulWidget {
  final Ed25519HDKeyPair wallet;
  final List<Map<String, dynamic>> transactions;

  const TransactionHistoryPage({
    super.key,
    required this.wallet,
    required this.transactions,
  });

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  List<Map<String, dynamic>> _allTransactions = [];
  bool _isLoading = false;
  String? _lastSignature;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _allTransactions = List.from(widget.transactions);
    if (_allTransactions.isEmpty) {
      _fetchInitialTransactions();
    }
  }

  Future<void> _fetchInitialTransactions() async {
    _allTransactions.clear();
    _lastSignature = null;
    _errorMessage = '';
    await _loadMoreTransactions();
  }

  String _getConfirmationStatusString(dynamic status) {
    if (status == null) return 'confirmed';
    if (status is String) return status;
    if (status is Commitment) {
      switch (status) {
        case Commitment.processed:
          return 'processed';
        case Commitment.confirmed:
          return 'confirmed';
        case Commitment.finalized:
          return 'finalized';
        default:
          return 'confirmed';
      }
    }
    return status.toString();
  }

  Future<void> _loadMoreTransactions() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final client = SolanaClient(
        rpcUrl: Uri.parse('https://api.mainnet-beta.solana.com'),
        websocketUrl: Uri.parse('wss://api.mainnet-beta.solana.com'),
      );

      print('🔍 Loading transactions for: ${widget.wallet.address}');
      print('🔍 Before signature: $_lastSignature');

      final signatures = await client.rpcClient.getSignaturesForAddress(
        widget.wallet.address,
        limit: 20,
        before: _lastSignature,
      );

      print('📜 Found ${signatures.length} signatures');

      if (signatures.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            if (_allTransactions.isEmpty) {
              _errorMessage = 'No transactions found for this wallet';
            }
          });
        }
        return;
      }

      final List<Map<String, dynamic>> newTransactions = [];

      for (final sig in signatures) {
        try {
          print('🔍 Processing signature: ${sig.signature}');

          // Transaction detaylarını al
          final txDetail = await client.rpcClient.getTransaction(
            sig.signature,
            commitment: Commitment.confirmed,
          );

          final txData = {
            'signature': sig.signature,
            'slot': sig.slot,
            'blockTime': sig.blockTime,
            'confirmationStatus': _getConfirmationStatusString(sig.confirmationStatus),
            'err': sig.err,
            'fee': txDetail?.meta?.fee ?? 5000,
            'success': sig.err == null,
          };

          newTransactions.add(txData);
          print('✅ Added transaction: ${sig.signature.substring(0, 8)}...');

        } catch (e) {
          print('❌ Transaction detail error for ${sig.signature}: $e');
          // Hata olsa bile basit bilgilerle ekle
          final txData = {
            'signature': sig.signature,
            'slot': sig.slot,
            'blockTime': sig.blockTime,
            'confirmationStatus': _getConfirmationStatusString(sig.confirmationStatus),
            'err': sig.err,
            'fee': 5000,
            'success': sig.err == null,
          };
          newTransactions.add(txData);
        }

        // Her 5 işlemde bir kısa bir bekleme
        if (newTransactions.length % 5 == 0) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      if (mounted) {
        setState(() {
          _lastSignature = signatures.isNotEmpty ? signatures.last.signature : null;
          _allTransactions.addAll(newTransactions);
          _isLoading = false;
        });
      }

      print('✅ Successfully loaded ${newTransactions.length} transactions');
      print('📊 Total transactions: ${_allTransactions.length}');

    } catch (e) {
      print('❌ Transaction loading error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load transactions: ${e.toString()}';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading transactions: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _copySignature(String signature) {
    Clipboard.setData(ClipboardData(text: signature));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Transaction signature copied!'),
          ],
        ),
        backgroundColor: const Color(0xFFFF6B35),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _formatDate(int? blockTime) {
    if (blockTime == null) return 'Unknown';
    final date = DateTime.fromMillisecondsSinceEpoch(blockTime * 1000);
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateRelative(int? blockTime) {
    if (blockTime == null) return 'Unknown';
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

  Widget _buildGlassCard({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'İşlem Geçmişi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFFF6B35)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.3)),
            ),
            child: IconButton(
              onPressed: _isLoading ? null : _fetchInitialTransactions,
              icon: _isLoading
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
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Header card
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.receipt_long, color: Color(0xFFFF6B35), size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Toplam İşlem',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_allTransactions.length} işlem',
                                style: TextStyle(
                                  color: (isDark ? Colors.white : Colors.black87).withOpacity(0.8),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_isLoading) ...[
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // Content area
              Expanded(
                child: _buildContent(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_isLoading && _allTransactions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
            ),
            SizedBox(height: 16),
            Text(
              'İşlemler yükleniyor...',
              style: TextStyle(
                color: Color(0xFFFF6B35),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_allTransactions.isEmpty && _errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Hata',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black54,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage,
                style: TextStyle(
                  color: (isDark ? Colors.white : Colors.black54).withOpacity(0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchInitialTransactions,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    if (_allTransactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 64,
              color: (isDark ? Colors.white : Colors.black54).withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz işlem yok',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black54,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'İşlem geçmişiniz burada görünecek',
              style: TextStyle(
                color: (isDark ? Colors.white : Colors.black54).withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent &&
            !_isLoading &&
            _lastSignature != null) {
          _loadMoreTransactions();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _allTransactions.length + (_isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _allTransactions.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                ),
              ),
            );
          }

          final tx = _allTransactions[index];
          return _buildTransactionItem(tx, isDark);
        },
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx, bool isDark) {
    final isSuccess = tx['err'] == null;
    final signature = tx['signature'] ?? '';
    final shortSig = signature.length > 16 ? signature.substring(0, 16) : signature;
    final confirmationStatus = tx['confirmationStatus'] ?? 'confirmed';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: _buildGlassCard(
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
                      color: (isSuccess ? Colors.green : Colors.red).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isSuccess ? Icons.check_circle : Icons.error,
                      color: isSuccess ? Colors.green : Colors.red,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSuccess ? 'Başarılı' : 'Başarısız',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
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
                              '(${_formatDateRelative(tx['blockTime'])})',
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
                      confirmationStatus.toString(),
                      style: TextStyle(
                        color: isSuccess ? Colors.green : Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'İşlem İmzası',
                            style: TextStyle(
                              color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$shortSig...',
                            style: const TextStyle(
                              color: Color(0xFFFF6B35),
                              fontFamily: 'monospace',
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _copySignature(signature),
                      icon: const Icon(Icons.copy, color: Color(0xFFFF6B35), size: 18),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Slot: ${tx['slot']}',
                      style: TextStyle(
                        color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (tx['fee'] != null) ...[
                    Text(
                      'Ücret: ${(tx['fee'] / 1000000000).toStringAsFixed(6)} SOL',
                      style: TextStyle(
                        color: (isDark ? Colors.white : Colors.black87).withOpacity(0.5),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}