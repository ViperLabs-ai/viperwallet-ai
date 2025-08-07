// login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:solana/solana.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:ui';

import '../providers/app_provider.dart';
import '../security/wallet_security.dart'; // WalletSecurity'yi import ettiğinizden emin olun
import 'dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _mnemonicController = TextEditingController();
  final _passwordController = TextEditingController(); // Şifre girişi için yeni controller
  bool _isLoading = false;
  bool _showMnemonic = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Yeni değişkenler
  bool _hasSavedMnemonic = false;
  bool _isPasswordLoginMode = false;
  final ValueNotifier<bool> _isPasswordVisible = ValueNotifier(false); // Şifre görünürlüğü için

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

    _checkSavedWalletStatus(); // Uygulama başladığında cüzdan durumunu kontrol et
  }

  Future<void> _checkSavedWalletStatus() async {
    final savedMnemonic = await WalletSecurity.getMnemonic();
    final savedPassword = await WalletSecurity.getPassword();

    setState(() {
      _hasSavedMnemonic = savedMnemonic != null;
      _isPasswordLoginMode = savedMnemonic != null && savedPassword != null;
    });

    if (_isPasswordLoginMode) {
      // Eğer şifre ile giriş modu aktifse, mnemonic alanını gizli tut
      _mnemonicController.clear();
    }
  }

  @override
  void dispose() {
    _mnemonicController.dispose();
    _passwordController.dispose(); // Şifre controller'ını da dispose et
    _animationController.dispose();
    _isPasswordVisible.dispose(); // ValueNotifier'ı dispose et
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);

    try {
      final isSecure = await WalletSecurity.validateEnvironment();
      if (!isSecure) {
        throw Exception('unsecureEnvironment'.tr());
      }

      if (_isPasswordLoginMode) {
        // Şifre ile giriş modu
        final enteredPassword = _passwordController.text.trim();
        final savedPassword = await WalletSecurity.getPassword();
        final savedMnemonic = await WalletSecurity.getMnemonic();

        if (enteredPassword.isEmpty) {
          _showErrorSnackBar('Password is required'.tr());
          return;
        }

        if (savedPassword != enteredPassword) {
          throw Exception('Incorrect password'.tr());
        }

        if (savedMnemonic == null) {
          throw Exception('No mnemonic found. Please restore wallet.'.tr());
        }

        final wallet = await Ed25519HDKeyPair.fromMnemonic(savedMnemonic);
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => DashboardPage(wallet: wallet),
            ),
          );
        }
      } else {
        // Mnemonic ile giriş modu (ilk kurulum veya geri yükleme)
        final mnemonic = _mnemonicController.text.trim();
        if (mnemonic.isEmpty) {
          _showErrorSnackBar('Mnemonic Required'.tr());
          return;
        }

        if (!WalletSecurity.validateMnemonic(mnemonic)) {
          throw Exception('Invalid Mnemonic'.tr());
        }

        // Mnemonic'i kaydet ve şifre oluşturma dialogunu göster
        await WalletSecurity.saveMnemonic(mnemonic);
        final String? password = await _showPasswordCreationDialog();

        if (password == null || password.isEmpty) {
          // Eğer şifre oluşturulmazsa, kaydedilen mnemonic'i sil ve işlemi iptal et
          await WalletSecurity.deleteMnemonic();
          throw Exception('Password is required to proceed.'.tr());
        }
        await WalletSecurity.savePassword(password);


        final wallet = await Ed25519HDKeyPair.fromMnemonic(mnemonic);
        _mnemonicController.clear();

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => DashboardPage(wallet: wallet),
            ),
          );
        }
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
        throw Exception('Unsecure Environment'.tr());
      }

      final newMnemonic = await WalletSecurity.generateMnemonic();

      if (mounted) {
        await _showMnemonicBackupDialog(newMnemonic);
      }

      if (mounted) {
        final String? password = await _showPasswordCreationDialog();
        if (password == null || password.isEmpty) {
          throw Exception('Password is required for new wallet.'.tr());
        }
        await WalletSecurity.saveMnemonic(newMnemonic); // Mnemonic'i kaydet
        await WalletSecurity.savePassword(password); // Şifreyi kaydet
      }

      // Yeni oluşturulan mnemonic ile doğrudan cüzdanı oluştur
      final wallet = await Ed25519HDKeyPair.fromMnemonic(newMnemonic);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => DashboardPage(wallet: wallet),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('${'Wallet CreationError'.tr()}: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showMnemonicBackupDialog(String mnemonic) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (BuildContext buildContext, Animation<double> animation, Animation<double> secondaryAnimation) {
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
                            _hasCopiedNotifier.value = true;
                          },
                          child: Text('Copy'.tr()),
                        ),
                        const SizedBox(width: 12),
                        ValueListenableBuilder<bool>(
                          valueListenable: _hasCopiedNotifier,
                          builder: (context, hasCopiedValue, child) {
                            return ElevatedButton(
                              onPressed: hasCopiedValue
                                  ? () async {
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
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                }
                              }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: hasCopiedValue
                                    ? const Color(0xFFFF6B35)
                                    : Colors.grey,
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

  Future<String?> _showPasswordCreationDialog() async {
    final TextEditingController _passwordController = TextEditingController();
    final TextEditingController _confirmPasswordController = TextEditingController();
    final ValueNotifier<bool> _passwordsMatchNotifier = ValueNotifier(true);
    final ValueNotifier<bool> _isPasswordVisible = ValueNotifier(false);
    final ValueNotifier<bool> _isConfirmPasswordVisible = ValueNotifier(false);

    _passwordController.addListener(() {
      _passwordsMatchNotifier.value = _passwordController.text == _confirmPasswordController.text;
    });
    _confirmPasswordController.addListener(() {
      _passwordsMatchNotifier.value = _passwordController.text == _confirmPasswordController.text;
    });

    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Create Password'.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Set a strong password for your wallet. This will be used to unlock your wallet for daily use.'.tr(),
                  style: TextStyle(fontSize: 14, color: Theme.of(dialogContext).textTheme.bodySmall?.color),
                ),
                const SizedBox(height: 20),
                ValueListenableBuilder<bool>(
                  valueListenable: _isPasswordVisible,
                  builder: (context, isVisible, child) {
                    return TextField(
                      controller: _passwordController,
                      obscureText: !isVisible,
                      decoration: InputDecoration(
                        labelText: 'Password'.tr(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            isVisible ? Icons.visibility : Icons.visibility_off,
                            color: const Color(0xFFFF6B35),
                          ),
                          onPressed: () {
                            _isPasswordVisible.value = !isVisible;
                          },
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<bool>(
                  valueListenable: _isConfirmPasswordVisible,
                  builder: (context, isVisible, child) {
                    return TextField(
                      controller: _confirmPasswordController,
                      obscureText: !isVisible,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password'.tr(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            isVisible ? Icons.visibility : Icons.visibility_off,
                            color: const Color(0xFFFF6B35),
                          ),
                          onPressed: () {
                            _isConfirmPasswordVisible.value = !isVisible;
                          },
                        ),
                      ),
                    );
                  },
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: _passwordsMatchNotifier,
                  builder: (context, passwordsMatch, child) {
                    if (!passwordsMatch) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Passwords do not match.'.tr(),
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(null); // Return null if cancelled
              },
              child: Text('Cancel'.tr()),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _passwordsMatchNotifier,
              builder: (context, passwordsMatch, child) {
                return ElevatedButton(
                  onPressed: passwordsMatch && _passwordController.text.isNotEmpty
                      ? () {
                    Navigator.of(dialogContext).pop(_passwordController.text);
                  }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Set Password'.tr()),
                );
              },
            ),
          ],
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
                                color: Colors.transparent,
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
                          'Welcome'.tr(),
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 48),

                    // Mnemonic veya Şifre girişi
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
                          if (_isPasswordLoginMode) // Eğer şifre ile giriş modu aktifse
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Enter Password'.tr(),
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ValueListenableBuilder<bool>(
                                  valueListenable: _isPasswordVisible,
                                  builder: (context, isVisible, child) {
                                    return TextField(
                                      controller: _passwordController,
                                      obscureText: !isVisible,
                                      style: TextStyle(
                                        color: isDark ? Colors.white : Colors.black,
                                        fontSize: 16,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Your wallet password'.tr(),
                                        hintStyle: TextStyle(
                                          color: isDark ? Colors.white60 : Colors.black54,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.lock_outline,
                                          color: const Color(0xFFFF6B35),
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            isVisible ? Icons.visibility_off : Icons.visibility,
                                            color: const Color(0xFFFF6B35),
                                          ),
                                          onPressed: () {
                                            _isPasswordVisible.value = !isVisible;
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
                                      onSubmitted: (_) => _login(), // Enter'a basınca giriş yap
                                    );
                                  },
                                ),
                              ],
                            )
                          else // Mnemonic girişi (eğer kaydedilmiş bir cüzdan yoksa)
                            Column(
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
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Giriş butonu
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
                        _isPasswordLoginMode ? 'Unlock Wallet'.tr() : 'Login / Restore Wallet'.tr(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Yeni cüzdan oluştur butonu (sadece mnemonic modu aktifken göster)
                    if (!_isPasswordLoginMode)
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
                    // Eğer şifre ile giriş modundaysak, "Restore Wallet" seçeneğini sunabiliriz
                    if (_isPasswordLoginMode)
                      TextButton(
                        onPressed: () {
                          // Modu mnemonic girişine çevir
                          setState(() {
                            _isPasswordLoginMode = false;
                            _passwordController.clear(); // Şifre alanını temizle
                            _mnemonicController.clear(); // Mnemonic alanını temizle (eğer önceden bir şey yazıldıysa)
                          });
                        },
                        child: Text(
                          'Restore Wallet with Mnemonic'.tr(),
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontSize: 16,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Güvenlik bilgisi
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