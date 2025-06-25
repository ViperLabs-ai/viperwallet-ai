import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For clipboard
import 'package:solana/solana.dart';
import '../security/wallet_security.dart';
import 'dashboard_page.dart'; // To navigate to after wallet creation and PIN setup

class CreateWalletPage extends StatefulWidget {
  const CreateWalletPage({super.key});

  @override
  State<CreateWalletPage> createState() => _CreateWalletPageState();
}

class _CreateWalletPageState extends State<CreateWalletPage> {
  String? _newMnemonic;
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final TextEditingController _mnemonicConfirmationController = TextEditingController();

  int _currentStep = 0; // 0: Display Mnemonic, 1: Confirm Mnemonic, 2: Set PIN
  bool _isLoading = false;
  bool _showMnemonic = false; // To toggle visibility of the mnemonic

  @override
  void initState() {
    super.initState();
    _generateAndDisplayMnemonic();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    _mnemonicConfirmationController.dispose();
    super.dispose();
  }

  Future<void> _generateAndDisplayMnemonic() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final isSecure = await WalletSecurity.validateEnvironment();
      if (!isSecure) {
        _showErrorSnackBar('Unsecure Environment Detected. Cannot create wallet.');
        if (mounted) Navigator.of(context).pop(); // Go back to login if unsecure
        return;
      }
      _newMnemonic = WalletSecurity.generateMnemonic();
    } catch (e) {
      _showErrorSnackBar('Failed to generate mnemonic: $e');
      if (mounted) Navigator.of(context).pop(); // Go back to login on error
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _nextStep() {
    setState(() {
      _currentStep++;
    });
  }

  void _previousStep() {
    setState(() {
      _currentStep--;
    });
  }

  Future<void> _confirmMnemonicAndProceed() async {
    if (_mnemonicConfirmationController.text.trim() != _newMnemonic) {
      _showErrorSnackBar('Mnemonic does not match. Please try again.');
      return;
    }
    _nextStep(); // Move to Set PIN step
  }

  Future<void> _setPinAndFinalize() async {
    if (_pinController.text.isEmpty || _confirmPinController.text.isEmpty) {
      _showErrorSnackBar('PIN cannot be empty.');
      return;
    }
    if (_pinController.text != _confirmPinController.text) {
      _showErrorSnackBar('PINs do not match.');
      return;
    }
    if (_pinController.text.length < 6) { // Example: enforce minimum PIN length
      _showErrorSnackBar('PIN must be at least 6 digits long.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_newMnemonic == null) {
        throw Exception('Mnemonic is missing. Please restart wallet creation.');
      }

      // Generate wallet from mnemonic
      final wallet = await Ed25519HDKeyPair.fromMnemonic(_newMnemonic!);

      // Securely store the mnemonic, encrypted with the PIN
      await WalletSecurity.saveEncryptedMnemonic(_newMnemonic!, _pinController.text);

      // Clear sensitive data after saving
      final List<int> mnemonicCodeUnits = List<int>.from(_newMnemonic!.codeUnits);
      WalletSecurity.clearSensitiveMemory(mnemonicCodeUnits);
      _newMnemonic = null; // Clear from memory

      _pinController.clear();
      _confirmPinController.clear();
      _mnemonicConfirmationController.clear();

      if (mounted) {
        _showSuccessSnackBar('Wallet created and PIN set successfully!');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => DashboardPage(wallet: wallet),
          ),
        );
      }
    } catch (e) {
      debugPrint('Finalization error: $e');
      _showErrorSnackBar('Failed to finalize wallet setup: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Wallet'),
        backgroundColor: isDark ? Colors.black : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        leading: _currentStep > 0
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _previousStep,
        )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_currentStep == 0) // Step 0: Display Mnemonic
              _buildDisplayMnemonicStep(isDark),
            if (_currentStep == 1) // Step 1: Confirm Mnemonic
              _buildConfirmMnemonicStep(isDark),
            if (_currentStep == 2) // Step 2: Set PIN
              _buildSetPinStep(isDark),

            const SizedBox(height: 32),

            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplayMnemonicStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Your Secret Recovery Phrase',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Write down or store these 12 words in a safe place. They are the ONLY way to recover your wallet.',
          style: TextStyle(
            fontSize: 16,
            color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.red.withOpacity(0.1) : Colors.red.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(
                _newMnemonic ?? 'Generating Mnemonic...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.redAccent : Colors.red[700],
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _newMnemonic == null
                    ? null
                    : () {
                  Clipboard.setData(ClipboardData(text: _newMnemonic!));
                  _showSuccessSnackBar('Mnemonic copied to clipboard!');
                },
                icon: const Icon(Icons.copy, color: Colors.white),
                label: const Text(
                  'Copy to Clipboard (Use with caution!)',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Checkbox(
              value: _showMnemonic,
              onChanged: (bool? value) {
                setState(() {
                  _showMnemonic = value ?? false;
                });
              },
            ),
            Expanded(
              child: Text(
                'I have securely written down my recovery phrase.',
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildConfirmMnemonicStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Confirm Your Recovery Phrase',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'To ensure you have correctly saved your phrase, please re-enter it below.',
          style: TextStyle(
            fontSize: 16,
            color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _mnemonicConfirmationController,
          minLines: 3,
          maxLines: 5,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            hintText: 'Enter your recovery phrase here (e.g., word1 word2...)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: isDark ? Colors.grey[800] : Colors.grey[200],
          ),
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSetPinStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Set a Wallet PIN',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'This PIN will be used to unlock your wallet on this device. Do NOT share it.',
          style: TextStyle(
            fontSize: 16,
            color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _pinController,
          decoration: InputDecoration(
            labelText: 'New PIN (e.g., 6 digits)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: isDark ? Colors.grey[800] : Colors.grey[200],
          ),
          keyboardType: TextInputType.number,
          obscureText: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPinController,
          decoration: InputDecoration(
            labelText: 'Confirm PIN',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: isDark ? Colors.grey[800] : Colors.grey[200],
          ),
          keyboardType: TextInputType.number,
          obscureText: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Column(
      children: [
        if (_currentStep == 0)
          ElevatedButton(
            onPressed: _newMnemonic == null || !_showMnemonic // Enable only if mnemonic is generated and checkbox is checked
                ? null
                : _nextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              'I have backed it up, Continue',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        if (_currentStep == 1)
          ElevatedButton(
            onPressed: _isLoading ? null : _confirmMnemonicAndProceed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                : const Text(
              'Confirm and Continue',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        if (_currentStep == 2)
          ElevatedButton(
            onPressed: _isLoading ? null : _setPinAndFinalize,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                : const Text(
              'Create Wallet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
}