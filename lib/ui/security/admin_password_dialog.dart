// lib/ui/security/admin_password_dialog.dart
import 'package:flutter/material.dart';
import '../../core/security/admin_auth_service.dart';
import '../theme/app_theme.dart';

class AdminPasswordDialog extends StatefulWidget {
  final String reason;
  final AdminAuthService auth;

  const AdminPasswordDialog({
    super.key,
    required this.reason,
    required this.auth,
  });

  @override
  State<AdminPasswordDialog> createState() => _AdminPasswordDialogState();
}

class _AdminPasswordDialogState extends State<AdminPasswordDialog> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  final _pinFocusNode = FocusNode();

  bool _isSetupMode = false;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkSetupMode();
  }

  Future<void> _checkSetupMode() async {
    final configured = await widget.auth.isAdminConfigured();
    if (!mounted) return;
    setState(() {
      _isSetupMode = !configured;
      _isLoading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pinFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final pin = _pinController.text;

    if (pin.isEmpty) {
      setState(() => _error = 'PIN cannot be empty.');
      return;
    }
    if (pin.length < 4) {
      setState(() => _error = 'PIN must be at least 4 characters.');
      return;
    }

    if (_isSetupMode) {
      final confirm = _confirmController.text;
      if (pin != confirm) {
        setState(() => _error = 'PINs do not match. Try again.');
        return;
      }
      setState(() {
        _isSubmitting = true;
        _error = null;
      });
      await widget.auth.setPassword(pin);
      await widget.auth.unlockFor();
      if (mounted) Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isSubmitting = true;
        _error = null;
      });
      final ok = await widget.auth.verifyPassword(pin);
      if (!mounted) return;
      if (ok) {
        await widget.auth.unlockFor();
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _isSubmitting = false;
          _error = 'Incorrect PIN. Try again.';
          _pinController.clear();
        });
        _pinFocusNode.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    if (_isLoading) {
      return AlertDialog(
        backgroundColor: palette.card,
        content: const SizedBox(
          height: 60,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AlertDialog(
      backgroundColor: palette.card,
      title: Row(
        children: [
          Icon(Icons.lock_outline, size: 20, color: palette.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isSetupMode ? 'Create Admin PIN' : 'Admin Required',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: palette.foreground,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isSetupMode
                ? 'No admin PIN has been set. Create one to protect sensitive actions.'
                : widget.reason,
            style: TextStyle(fontSize: 13, color: palette.mutedForeground),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            focusNode: _pinFocusNode,
            obscureText: true,
            enabled: !_isSubmitting,
            keyboardType: TextInputType.number,
            onSubmitted: _isSetupMode ? null : (_) => _submit(),
            decoration: InputDecoration(
              labelText: _isSetupMode ? 'New PIN' : 'Admin PIN',
              filled: true,
              fillColor: palette.background,
              prefixIcon: const Icon(Icons.pin_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_isSetupMode) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: true,
              enabled: !_isSubmitting,
              keyboardType: TextInputType.number,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Confirm PIN',
                filled: true,
                fillColor: palette.background,
                prefixIcon: const Icon(Icons.pin_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 13,
                color: palette.statusMaintenance,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isSetupMode ? 'Create PIN' : 'Unlock'),
        ),
      ],
    );
  }
}
