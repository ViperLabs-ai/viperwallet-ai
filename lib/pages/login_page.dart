import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:solana/solana.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
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
      // Security validation
      final isSecure = await WalletSecurity.validateEnvironment();
      if (!isSecure) {
        throw Exception('unsecureEnvironment'.tr());
      }

      // Validate mnemonic
      final mnemonic = _mnemonicController.text.trim();
      if (!WalletSecurity.validateMnemonic(mnemonic)) {
        throw Exception('invalidMnemonic'.tr());
      }

      // Create wallet from mnemonic
      final wallet = await Ed25519HDKeyPair.fromMnemonic(mnemonic);

      // Clear sensitive data
      _mnemonicController.clear();

      // Navigate to dashboard
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
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
                              gradient: const LinearGradient(
                                colors: [Color(0x00111111), Color(0x00111111)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF6B35).withOpacity(0.2),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Image.asset('assets/icon/icon1.png')
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'appTitle'.tr(),
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'welcome'.tr(),
                            style: TextStyle(
                              color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 48),

                      // Mnemonic input
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withOpacity(0.3)
                              : Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFF6B35).withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'mnemonicPhrase'.tr(),
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _mnemonicController,
                              maxLines: _showMnemonic ? 3 : 1,
                              obscureText: !_showMnemonic,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                hintText: _showMnemonic
                                    ? 'mnemonicHintExpanded'.tr()
                                    : 'mnemonicHint'.tr(),
                                hintStyle: TextStyle(
                                  color: (isDark ? Colors.white : Colors.black87).withOpacity(0.5),
                                ),
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  color: Color(0xFFFF6B35),
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
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(16),
                              ),
                              enabled: !_isLoading,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Login button
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B35).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          )
                              : Text(
                            'login'.tr(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
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
                            const Icon(
                              Icons.security,
                              color: Colors.blue,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'securityInfo'.tr(),
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 12,
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
      ),
    );
  }
}
