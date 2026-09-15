import 'package:flutter/material.dart';

import 'account_page.dart';
import 'account_service.dart';
import 'admin_page.dart';

/// Protects the web-only /admin entry point with an administrator session.
class AdminGate extends StatefulWidget {
  const AdminGate({super.key});

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  final _accountService = AccountService();
  AccountSession? _session;
  bool _isCheckingSession = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final session = await _accountService.restoreSession();
    if (!mounted) return;
    setState(() {
      _session = session;
      _isCheckingSession = false;
    });
  }

  @override
  void dispose() {
    _accountService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSession) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final session = _session;
    if (session?.isAdmin == true) {
      return AdminPage(accountService: _accountService, session: session!);
    }

    return AccountPage(
      accountService: _accountService,
      session: session,
      closeAfterSignIn: false,
      closeAfterGuest: false,
      onSignedIn: (newSession) async {
        await _accountService.saveSession(newSession);
        if (mounted) setState(() => _session = newSession);
      },
      onSignedOut: () async {
        await _accountService.clearSession();
        if (mounted) setState(() => _session = null);
      },
      onContinueAsGuest: () async {},
    );
  }
}