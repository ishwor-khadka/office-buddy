import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/firebase/firebase_bootstrap.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/ui/ob_background.dart';

class GoogleLoginScreen extends StatefulWidget {
  const GoogleLoginScreen({super.key});

  @override
  State<GoogleLoginScreen> createState() => _GoogleLoginScreenState();
}

class _GoogleLoginScreenState extends State<GoogleLoginScreen> {
  static const _kOnboarded = 'onboarded_v1';
  static const _kServerClientId =
      '261131547010-00grjmhfe1fbl3f9jvlmnugrs7hade4j.apps.googleusercontent.com';

  bool _loading = false;
  late final Future<void> _googleSignInInit;

  @override
  void initState() {
    super.initState();
    _googleSignInInit = _initializeGoogleSignIn();
    WidgetsBinding.instance.addPostFrameCallback((_) => _skipIfSignedIn());
  }

  Future<void> _initializeGoogleSignIn() async {
    await GoogleSignIn.instance.initialize(
      serverClientId: _kServerClientId,
    );
  }

  Future<void> _skipIfSignedIn() async {
    final auth = FirebaseBootstrap.authOrNull;
    if (auth?.currentUser == null || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    context.go(
      prefs.getBool(_kOnboarded) ?? false
          ? AppRoutes.homeScreen
          : AppRoutes.onBoardingScreen,
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      await _googleSignInInit;

      final auth = FirebaseBootstrap.authOrNull;
      if (auth == null) {
        throw StateError('Firebase is not configured.');
      }

      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw StateError('Google sign-in is not supported on this platform.');
      }

      final account = await GoogleSignIn.instance.authenticate();
      final googleAuth = account.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        throw StateError('Google authentication did not return an id token.');
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await auth.signInWithCredential(credential);

      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      context.go(
        prefs.getBool(_kOnboarded) ?? false
            ? AppRoutes.homeScreen
            : AppRoutes.onBoardingScreen,
      );
    } on GoogleSignInException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.description ?? 'Google sign-in failed')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Google sign-in failed')),
      );
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Google sign-in failed')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F5F2),
      body: ObBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.78),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 30,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/app_logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    Text(
                      'Office Buddy',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: const Color(0xFF162033),
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to continue',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF5D6B77),
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loading ? null : _signInWithGoogle,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF162033),
                          disabledBackgroundColor: Colors.white,
                          disabledForegroundColor: const Color(0xFF162033),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 2,
                          shadowColor: Colors.black.withValues(alpha: 0.16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFF5F5F5),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'G',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF4285F4),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _loading
                                  ? 'Signing in...'
                                  : 'Sign in with Google',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: const Color(0xFF162033),
                                fontWeight: FontWeight.w700,
                              ),
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
}
