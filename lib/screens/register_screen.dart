import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';

class RegisterScreen extends StatefulWidget {
  final bool isResidentMode;
  const RegisterScreen({super.key, required this.isResidentMode});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl     = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  bool _showPass = false, _showConfirm = false;
  bool _loading = false, _success = false;
  String _localError = '';
  int _selectedRoleId = 0;
  List<Map<String, dynamic>> _roles = [];

  @override
  void initState() {
    super.initState();
    _loadRoles();
    if (widget.isResidentMode) _selectedRoleId = 7;
  }

  Future<void> _loadRoles() async {
    final roles = await SupabaseService.fetchRoles();
    if (mounted) setState(() => _roles = roles);
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _usernameCtrl.dispose();
    _passCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final auth = context.read<AuthService>();
    auth.clearError();
    setState(() => _localError = '');

    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _localError = 'Passwords do not match');
      return;
    }
    if (_passCtrl.text.length < 8) {
      setState(() => _localError = 'Password must be at least 8 characters');
      return;
    }

    setState(() => _loading = true);
    final ok = await auth.createUser({
      'name':     _nameCtrl.text.trim(),
      'phone':    _phoneCtrl.text.trim(),
      'username': _usernameCtrl.text.trim(),
      'password': _passCtrl.text,
      'role_id':  widget.isResidentMode ? 7 : _selectedRoleId,
    });
    setState(() => _loading = false);

    if (ok) {
      setState(() {
        _success = true;
        _nameCtrl.clear(); _phoneCtrl.clear(); _usernameCtrl.clear();
        _passCtrl.clear(); _confirmCtrl.clear();
        if (widget.isResidentMode) _selectedRoleId = 7;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth  = context.watch<AuthService>();
    final error = _localError.isNotEmpty ? _localError : auth.error;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              widget.isResidentMode ? 'Add Resident' : 'Create Account',
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 20),

            if (_success)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.blueCard, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.blueBorder),
                ),
                child: Column(children: [
                  const Text('✅', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 12),
                  Text(
                    widget.isResidentMode ? 'Resident registered!' : 'Account created!',
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (widget.isResidentMode)
                    TextButton(
                      onPressed: () => setState(() => _success = false),
                      child: const Text('Register another'),
                    ),
                ]),
              )
            else
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.blueCard, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.blueBorder),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (widget.isResidentMode) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
                      ),
                      child: const Text('🏘️ Registering as Resident',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  _Field(label: 'FULL NAME',     ctrl: _nameCtrl,     hint: 'e.g. Maria Santos'),
                  const SizedBox(height: 14),
                  _Field(label: 'PHONE NUMBER',  ctrl: _phoneCtrl,    hint: 'e.g. 09123456789', keyboardType: TextInputType.phone),
                  const SizedBox(height: 14),
                  _Field(label: 'USERNAME',      ctrl: _usernameCtrl, hint: 'e.g. maria_santos'),
                  const SizedBox(height: 14),
                  _Field(label: 'PASSWORD',      ctrl: _passCtrl,     hint: '••••••••', obscure: !_showPass,
                    suffix: IconButton(
                      icon: Icon(_showPass ? Icons.visibility : Icons.visibility_off, color: AppColors.textSecondary, size: 20),
                      onPressed: () => setState(() => _showPass = !_showPass),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('At least 8 characters with letters and numbers',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  ),
                  const SizedBox(height: 14),
                  _Field(label: 'CONFIRM PASSWORD', ctrl: _confirmCtrl, hint: '••••••••', obscure: !_showConfirm,
                    suffix: IconButton(
                      icon: Icon(_showConfirm ? Icons.visibility : Icons.visibility_off, color: AppColors.textSecondary, size: 20),
                      onPressed: () => setState(() => _showConfirm = !_showConfirm),
                    ),
                  ),

                  if (!widget.isResidentMode && _roles.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text('ROLE', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedRoleId == 0 ? null : _selectedRoleId,
                      dropdownColor: AppColors.blueMid,
                      style: const TextStyle(color: AppColors.textPrimary),
                      hint: const Text('Select a role...', style: TextStyle(color: AppColors.textMuted)),
                      decoration: InputDecoration(
                        filled: true, fillColor: AppColors.blueMid,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.blueBorder),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                      items: _roles.map((r) => DropdownMenuItem<int>(
                        value: r['role_id'] as int,
                        child: Text(r['role_desc'] ?? ''),
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedRoleId = v ?? 0),
                    ),
                  ],

                  if (error.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.red),
                      ),
                      child: Text('⚠️ $error',
                          style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13)),
                    ),
                  ],

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.blueDark,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _loading
                          ? const SizedBox(height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.blueDark))
                          : Text(
                              widget.isResidentMode ? '🏘️  Register Resident' : '✅  Register',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                    ),
                  ),
                ]),
              ),

            const SizedBox(height: 20),
            const Center(
              child: Text('AGOS v1.0 — Capstone Prototype · Data from PAGASA / DOST-ASTI',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label, hint;
  final TextEditingController ctrl;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;

  const _Field({
    required this.label, required this.ctrl, required this.hint,
    this.obscure = false, this.suffix, this.keyboardType,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textMuted),
          suffixIcon: suffix,
          filled: true, fillColor: AppColors.blueMid,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.blueBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.blueBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accent)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    ],
  );
}