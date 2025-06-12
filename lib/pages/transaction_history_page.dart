import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solana/solana.dart';
import '../l10n/app_localizations.dart';
import '../services/rpc_service.dart';

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

  @override
  void initState() {
    super.initState();
    _allTransactions = List.from(widget.transactions);
    _loadMoreTransactions();
  }

  Future<void> _loadMoreTransactions() async {
    setState(() => _isLoading = true);

    try {
      final signatures = await RpcService.executeWithFallback<List<dynamic>>(
            (client) => client.getSignaturesForAddress(
          widget.wallet.address,
          limit: 50,
        ),
      );

      setState(() {
        _allTransactions = signatures.map((sig) => {
          'signature': sig['signature'] ?? '',
          'slot': sig['slot'] ?? 0,
          'blockTime': sig['blockTime'],
          'confirmationStatus': sig['confirmationStatus'] ?? 'confirmed',
          'err': sig['err'],
        }).toList();
      });
    } catch (e) {
      print('İşlem geçmişi yüklenirken hata: $e');
    }

    setState(() => _isLoading = false);
  }

  void _copySignature(String signature) {
    final l10n = AppLocalizations.of(context)!;
    Clipboard.setData(ClipboardData(text: signature));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.transactionSignatureCopied),
        backgroundColor: const Color(0xFFFF6B35),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _formatDate(int? blockTime) {
    final l10n = AppLocalizations.of(context)!;
    if (blockTime == null) return l10n.unknown;
    final date = DateTime.fromMillisecondsSinceEpoch(blockTime * 1000);
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
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
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          l10n.transactionHistory,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
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
              border: Border.all(
                color: const Color(0xFFFF6B35).withOpacity(0.3),
              ),
            ),
            child: IconButton(
              onPressed: _isLoading ? null : _loadMoreTransactions,
              icon: _isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                ),
              )
                  : Icon(
                Icons.refresh,
                color: const Color(0xFFFF6B35),
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
              Colors.grey[50]!,
              Colors.grey[100]!,
              const Color(0xFFFFF5F0),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),

              // İstatistik kartı
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
                          child: const Icon(
                            Icons.receipt_long,
                            color: Color(0xFFFF6B35),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.totalTransactions,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_allTransactions.length} ${l10n.transactions}',
                                style: TextStyle(
                                  color: (isDark ? Colors.white : Colors.black87).withOpacity(0.8),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // İşlem listesi
              Expanded(
                child: _allTransactions.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B35).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.receipt_long,
                          color: Color(0xFFFF6B35),
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.noTransactionsYet,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.firstTransactionWillAppearHere,
                        style: TextStyle(
                          color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _allTransactions.length,
                  itemBuilder: (context, index) {
                    final tx = _allTransactions[index];
                    final isSuccess = tx['err'] == null;

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
                                          isSuccess ? l10n.successfulTransaction : l10n.failedTransaction,
                                          style: TextStyle(
                                            color: isDark ? Colors.white : Colors.black87,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
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
                                  Text(
                                    tx['confirmationStatus'] ?? l10n.confirmed,
                                    style: TextStyle(
                                      color: isSuccess ? Colors.green : Colors.red,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            l10n.transactionSignature,
                                            style: TextStyle(
                                              color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${tx['signature'].toString().substring(0, 16)}...',
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
                                      onPressed: () => _copySignature(tx['signature']),
                                      icon: const Icon(
                                        Icons.copy,
                                        color: Color(0xFFFF6B35),
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${l10n.slot}: ${tx['slot']}',
                                      style: TextStyle(
                                        color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
