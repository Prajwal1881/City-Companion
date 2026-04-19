import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';

// ─── OTP Screen ───────────────────────────────────────────────────────────────

class OtpScreen extends StatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});
  @override State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;

  void _verify() async {
    if (_ctrl.text.length < 6) return;
    setState(() => _loading = true);
    try {
      await ApiClient.verifyOtp(widget.phone, _ctrl.text);
      final user = await ApiClient.getMe();
      if (mounted) {
        if (user['name'] == 'New User' || user['name'] == null) {
          context.go('/auth/setup');
        } else {
          context.go('/feed');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid OTP')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(backgroundColor: AppColors.bg, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Enter OTP', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text('Sent to ${widget.phone}', style: TextStyle(color: AppColors.sub)),
          const SizedBox(height: 36),
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 12),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(counterText: '', hintText: '000000'),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _verify,
              child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Verify'),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Profile Setup Screen ─────────────────────────────────────────────────────

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});
  @override State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _name     = TextEditingController();
  final _city     = TextEditingController();
  final _hometown = TextEditingController();
  final _bio      = TextEditingController();
  String? _profession;
  int _step = 0;
  bool _loading = false;

  void _next() async {
    if (_step < 2) {
      setState(() => _step++);
      return;
    }
    setState(() => _loading = true);
    try {
      await ApiClient.updateMe({
        'name': _name.text,
        'current_city': _city.text,
        'hometown': _hometown.text,
        'bio': _bio.text,
        'profession': _profession,
      });
      if (mounted) context.go('/feed');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg, elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / 3,
            backgroundColor: AppColors.border,
            color: AppColors.orange,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(['Your name', 'Your city', 'About you'][_step],
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 28)),
          const SizedBox(height: 24),

          if (_step == 0) ...[
            TextField(controller: _name, decoration: const InputDecoration(hintText: 'Full name')),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(hintText: 'Profession'),
              items: ['Software Engineer','Designer','Student','Entrepreneur','Other']
                .map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (v) => setState(() => _profession = v),
            ),
          ],

          if (_step == 1) ...[
            TextField(controller: _city, decoration: const InputDecoration(hintText: 'Current city (e.g. Bangalore)')),
            const SizedBox(height: 16),
            TextField(controller: _hometown, decoration: const InputDecoration(hintText: 'Hometown (e.g. Pune)')),
          ],

          if (_step == 2) ...[
            TextField(controller: _bio, maxLines: 4,
              decoration: const InputDecoration(hintText: 'Tell people about yourself...')),
          ],

          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _next,
              child: _loading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(_step < 2 ? 'Continue →' : 'Finish Setup 🚀'),
            ),
          ),
        ]),
      ),
    );
  }
}
