import 'dart:typed_data';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:solana/solana.dart';
import 'package:solana/encoder.dart';

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

  Future<void> _sendSol() async {
    setState(() {
      _isSending = true;
      _statusMessage = '';
    });

    try {
      final rpcClient = SolanaClient(
        rpcUrl: Uri.parse('https://api.mainnet-beta.solana.com'),
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
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Send error: $e';
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Send SOL'.tr(), // Translated from 'SOL Gönder'
          style: TextStyle(
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
        child: Padding(
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
                            'Sender Wallet'.tr(), // Translated from 'Gönderen Cüzdan'
                            style: TextStyle(
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Recipient Address
              Text(
                'Recipient Address'.tr(), // Translated from 'Alıcı Adresi'
                style: TextStyle(
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
                    hintText: 'Enter Solana wallet address'.tr(), // Translated from 'Solana cüzdan adresini girin'
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                    prefixIcon: Icon(Icons.person, color: Colors.grey),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Amount
               Text(
                'Amount (SOL)'.tr(), // Translated from 'Miktar (SOL)'
                style: TextStyle(
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
                  decoration: const InputDecoration(
                    hintText: 'Min 0.001',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                    prefixIcon: Icon(Icons.monetization_on, color: Colors.orange),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Memo (Optional)
              Text(
                'Memo (Optional)'.tr(), // Translated from 'Not (Opsiyonel)'
                style: TextStyle(
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
                    hintText: 'Add a transaction note (optional)'.tr(), // Translated from 'İşlem notu ekleyin (opsiyonel)'
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                    prefixIcon: Icon(Icons.note, color: Colors.grey),
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
                      ? Row(
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
                        'Sending...'.tr(), // Translated from 'Gönderiliyor...'
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                      : Text(
                    'SEND SOL'.tr(), // Translated from 'SOL GÖNDER'
                    style: TextStyle(
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
                            : Icons.error,
                        color: _statusMessage.startsWith('✅')
                            ? Colors.green
                            : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: TextStyle(
                            color: _statusMessage.startsWith('✅')
                                ? Colors.green
                                : Colors.red,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const Spacer(),

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
                            'Security Warning'.tr(), // Translated from 'Güvenlik Uyarısı'
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Carefully check the recipient address. SOL transfers are irreversible. Tokens sent to the wrong address may be lost.'.tr(), // Translated from 'Alıcı adresini dikkatli kontrol edin. SOL transferleri geri alınamaz. Yanlış adrese gönderilen tokenlar kaybolabilir.'
                            style: TextStyle(
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
