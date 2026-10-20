import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() { _busy = true; _error = null; });
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.lottopattern://login-callback/',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not start Google sign-in. Check your Supabase Google provider and redirect URL settings.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(padding: const EdgeInsets.all(28), child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.casino_rounded, size: 64, color: Color(0xFF6254DF)),
          const SizedBox(height: 18),
          const Text('LottoPattern PH', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          const Text('Sign in with Google to start your free trial. Your five-day access period begins after your first successful pattern generation.',
            textAlign: TextAlign.center, style: TextStyle(height: 1.5)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _signIn,
            icon: const Icon(Icons.login_rounded),
            label: Text(_busy ? 'Opening Google sign-in…' : 'Continue with Google'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 18),
          const Text('Your trial is limited to one use per eligible Google identity. Pattern tools do not predict winning numbers.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.45)),
        ],
      )),
    ))),
  );
}
