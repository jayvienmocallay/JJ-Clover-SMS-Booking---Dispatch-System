// lib/ui/security/admin_gate.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/security/admin_auth_service.dart';
import 'admin_password_dialog.dart';

/// Shows the admin PIN dialog if the admin session is not currently unlocked.
///
/// Returns true if the caller may proceed (session was already unlocked, or
/// the user just entered the correct PIN). Returns false if the user cancelled
/// or entered a wrong PIN.
Future<bool> requireAdminPassword(
  BuildContext context, {
  required String reason,
}) async {
  final auth = context.read<AdminAuthService>();

  if (auth.isUnlocked) return true;

  final success = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AdminPasswordDialog(reason: reason, auth: auth),
  );

  if (success == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Admin unlocked for 5 minutes.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  return success == true;
}
