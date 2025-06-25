import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:solana/solana.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:ui';

import '../providers/app_provider.dart';
import '../security/wallet_security.dart';
import 'dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _mnemonicController = TextEditingController();
  bool _isLoading = false;
  bool _showMnemonic = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _mnemonicController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_mnemonicController.text.trim().isEmpty) {
      _showErrorSnackBar('mnemonicRequired'.tr());
      return;
    }

    setState(() => _isLoading = true);

    try {
      final isSecure = await WalletSecurity.validateEnvironment();
      if (!isSecure) {
        throw Exception('unsecureEnvironment'.tr());
      }

      final mnemonic = _mnemonicController.text.trim();
      if (!WalletSecurity.validateMnemonic(mnemonic)) {
        throw Exception('invalidMnemonic'.tr());
      }

      final wallet = await Ed25519HDKeyPair.fromMnemonic(mnemonic);

      _mnemonicController.clear();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => DashboardPage(wallet: wallet),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('${'loginError'.tr()}: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createAndExportWallet() async {
    setState(() => _isLoading = true);

    try {
      final isSecure = await WalletSecurity.validateEnvironment();
      if (!isSecure) {
        throw Exception('unsecureEnvironment'.tr());
      }

      final newMnemonic = await WalletSecurity.generateMnemonic();
      final wallet = await Ed25519HDKeyPair.fromMnemonic(newMnemonic);

      if (mounted) {
        await _showMnemonicBackupDialog(newMnemonic);
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => DashboardPage(wallet: wallet),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('${'walletCreationError'.tr()}: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Modified _showMnemonicBackupDialog
  Future<void> _showMnemonicBackupDialog(String mnemonic) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: false, // User must interact with buttons
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (BuildContext buildContext, Animation<double> animation, Animation<double> secondaryAnimation) {
        // Use ValueNotifier to manage the state of the 'Done' button locally within the dialog
        final ValueNotifier<bool> _hasCopiedNotifier = ValueNotifier(false);

        return Center(
          child: ScaleTransition(
            scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[900]
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Backup Mnemonic'.tr(),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[800]
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.3)
                              : Colors.black.withOpacity(0.3),
                        ),
                      ),
                      child: SelectableText(
                        mnemonic,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: mnemonic));
                            /*ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Copy to clipboard'.tr()),
                                backgroundColor: Colors.green,
                              ),
                            );
                             */
                            // Update the notifier value to enable the Done button
                            _hasCopiedNotifier.value = true;
                          },
                          child: Text('Copy'.tr()),
                        ),
                        const SizedBox(width: 12),
                        // Use ValueListenableBuilder to react to changes in _hasCopiedNotifier
                        ValueListenableBuilder<bool>(
                          valueListenable: _hasCopiedNotifier,
                          builder: (context, hasCopiedValue, child) {
                            return ElevatedButton(
                              // Disable the button if hasCopiedValue is false
                              onPressed: hasCopiedValue
                                  ? () async {
                                // Show confirmation dialog before popping
                                final bool? confirmed = await showDialog<bool>(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (BuildContext dialogContext) {
                                    return AlertDialog(
                                      title: Text('Confirmation'.tr()),
                                      content: Text('Are you sure you have backed up your Mnemonic?'.tr()),
                                      actions: <Widget>[
                                        TextButton(
                                          onPressed: () => Navigator.of(dialogContext).pop(false),
                                          child: Text('No'.tr()),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.of(dialogContext).pop(true),
                                          child: Text('Yes'.tr()),
                                        ),
                                      ],
                                    );
                                  },
                                );

                                if (confirmed == true) {
                                  // Only pop the mnemonic dialog if confirmed
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                }
                              }
                                  : null, // Set to null to disable the button
                              style: ElevatedButton.styleFrom(
                                backgroundColor: hasCopiedValue
                                    ? const Color(0xFFFF6B35)
                                    : Colors.grey, // Change color when disabled
                                foregroundColor: Colors.white,
                              ),
                              child: Text('Done'.tr()),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
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
              const Color(0xFFE0F2F7),
              const Color(0xFFB3E5FC),
              const Color(0xFF81D4FA),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo and title
                    Column(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.transparent
                                : Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.transparent, // Changed to transparent as it was covering image for dark mode
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Image.asset('assets/icon/icon1.png'),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'ViperWallet',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'welcome'.tr(),
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 48),

                    // Mnemonic input
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900] : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'mnemonicPhrase'.tr(),
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _mnemonicController,
                            maxLines: _showMnemonic ? 3 : 1,
                            obscureText: !_showMnemonic,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 16,
                            ),
                            decoration: InputDecoration(
                              hintText: _showMnemonic
                                  ? 'mnemonicHintExpanded'.tr()
                                  : 'mnemonicHint'.tr(),
                              hintStyle: TextStyle(
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: const Color(0xFFFF6B35),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showMnemonic ? Icons.visibility_off : Icons.visibility,
                                  color: const Color(0xFFFF6B35),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showMnemonic = !_showMnemonic;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: isDark ? Colors.grey[800] : Colors.grey[200],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            enabled: !_isLoading,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Login button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B35),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                          : Text(
                        'login'.tr(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Create new wallet button
                    OutlinedButton(
                      onPressed: _isLoading ? null : _createAndExportWallet,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: const Color(0xFFFF6B35),
                          width: 2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF6B35),
                          strokeWidth: 3,
                        ),
                      )
                          : Text(
                        'Create New Wallet'.tr(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF6B35),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Security info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.security,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'securityInfo'.tr(),
                              style: TextStyle(
                                color: isDark ? Colors.blue[200] : Colors.blue[800],
                                fontSize: 14,
                              ),
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
        ),
      ),
    );
  }
}
