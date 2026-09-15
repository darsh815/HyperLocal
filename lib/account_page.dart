import 'package:flutter/material.dart';

import 'account_service.dart';
import 'admin_page.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({
    required this.accountService,
    required this.session,
    required this.onSignedIn,
    required this.onSignedOut,
    required this.onContinueAsGuest,
    this.initiallyRegistering = false,
    this.closeAfterSignIn = true,
    this.closeAfterGuest = true,
    super.key,
  });

  final AccountService accountService;
  final AccountSession? session;
  final Future<void> Function(AccountSession session) onSignedIn;
  final Future<void> Function() onSignedOut;
  final Future<void> Function() onContinueAsGuest;
  final bool initiallyRegistering;
  final bool closeAfterSignIn;
  final bool closeAfterGuest;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late bool _isRegistering;
  bool _isBusy = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _isRegistering = widget.initiallyRegistering;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isBusy) return;
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      final session = _isRegistering
          ? await widget.accountService.register(
              _emailController.text,
              _passwordController.text,
            )
          : await widget.accountService.login(
              _emailController.text,
              _passwordController.text,
            );
      await widget.onSignedIn(session);
      if (mounted && widget.closeAfterSignIn) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      final session = await widget.accountService.signInWithGoogle();
      await widget.onSignedIn(session);
      if (mounted && widget.closeAfterSignIn) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }
  Future<void> _signOut() async {
    setState(() => _isBusy = true);
    await widget.onSignedOut();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _continueAsGuest() async {
    await widget.onContinueAsGuest();
    if (mounted && widget.closeAfterGuest) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = widget.session != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
        ),
        title: const Text(
          'Your account',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 36),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: signedIn ? _buildSignedInState() : _buildAuthForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFB94D2F),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.soup_kitchen_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 26),
          Text(
            _isRegistering
                ? 'Keep your recipes\nwith you.'
                : 'Welcome\nback to the lab.',
            style: const TextStyle(
              color: Color(0xFF29251F),
              fontSize: 38,
              height: 1.05,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isRegistering
                ? 'Create an account to sync your saved recipes across devices.'
                : 'Sign in to pick up your saved recipes wherever you cook.',
            style: TextStyle(
              color: Colors.brown.shade400,
              fontFamily: 'sans-serif',
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Email address',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
            validator: (value) {
              if (value == null ||
                  !RegExp(r'^\S+@\S+\.\S+$').hasMatch(value.trim())) {
                return 'Enter a valid email address.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofillHints: const [AutofillHints.password],
            textInputAction: _isRegistering
                ? TextInputAction.next
                : TextInputAction.done,
            onFieldSubmitted: (_) => _isRegistering ? null : _submit(),
            decoration: InputDecoration(
              labelText: 'Password',
              helperText: _isRegistering ? 'Use at least 8 characters.' : null,
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
              ),
            ),
            validator: (value) {
              if (value == null || value.length < 8) {
                return 'Use at least 8 characters.';
              }
              return null;
            },
          ),
          if (_isRegistering) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: Icon(Icons.verified_user_outlined),
              ),
              validator: (value) => value != _passwordController.text
                  ? 'Passwords do not match.'
                  : null,
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFFCE9E4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Color(0xFF9D3925),
                  fontFamily: 'sans-serif',
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: _isBusy ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB94D2F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isBusy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_isRegistering ? 'Create account' : 'Sign in'),
            ),
          ),
          if (widget.accountService.usesFirebase) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _isBusy ? null : _signInWithGoogle,
                icon: const Icon(Icons.g_mobiledata_rounded, size: 27),
                label: const Text('Continue with Google'),
              ),
            ),
          ],          const SizedBox(height: 14),
          Center(
            child: TextButton(
              onPressed: _isBusy
                  ? null
                  : () => setState(() {
                      _isRegistering = !_isRegistering;
                      _errorMessage = null;
                    }),
              child: Text(
                _isRegistering
                    ? 'Already have an account? Sign in'
                    : 'New here? Create an account',
              ),
            ),
          ),
          if (!widget.accountService.isConfigured)
            Center(
              child: Text(
                'Connect the API to enable accounts.',
                style: TextStyle(
                  color: Colors.brown.shade400,
                  fontFamily: 'sans-serif',
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: 10),
          Center(
            child: TextButton.icon(
              onPressed: _isBusy ? null : _continueAsGuest,
              icon: const Icon(Icons.explore_outlined, size: 18),
              label: const Text('Explore as guest'),
            ),
          ),
          Center(
            child: Text(
              'You can save recipes locally and connect an account later.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.brown.shade400,
                fontFamily: 'sans-serif',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignedInState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.verified_user_rounded,
          color: Color(0xFF2E5D50),
          size: 56,
        ),
        const SizedBox(height: 24),
        const Text(
          'You are signed in.',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          widget.session!.email,
          style: TextStyle(
            color: Colors.brown.shade500,
            fontFamily: 'sans-serif',
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 28),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFE7F0E9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(Icons.cloud_done_outlined, color: Color(0xFF2E5D50)),
              SizedBox(width: 12),
              Expanded(child: Text('Your saved recipes sync to your account.')),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (widget.session!.isAdmin) ...[
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminPage(
                    accountService: widget.accountService,
                    session: widget.session!,
                  ),
                ),
              ),
              icon: const Icon(Icons.dashboard_outlined),
              label: const Text('Open admin insights'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E5D50),
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _isBusy ? null : _signOut,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
          ),
        ),
      ],
    );
  }
}
