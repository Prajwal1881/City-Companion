// ─── Phone Auth Screen ────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});
  @override State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;

  void _sendOtp() async {
    if (_ctrl.text.length < 10) return;
    setState(() => _loading = true);
    try {
      await ApiClient.sendOtp('+91${_ctrl.text}');
      if (mounted) context.push('/auth/otp', extra: '+91${_ctrl.text}');
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Text('City\nCompanion', style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontSize: 52, color: AppColors.ink, height: 1.1,
              )),
              const SizedBox(height: 12),
              Text('Connect with people in your city for plans, rooms & more.',
                style: TextStyle(fontSize: 16, color: AppColors.sub)),
              const SizedBox(height: 40),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.card, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 1.5),
                  ),
                  child: const Text('+91', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    decoration: const InputDecoration(
                      hintText: 'Phone number',
                      counterText: '',
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _sendOtp,
                  child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Send OTP'),
                ),
              ),
              const Spacer(flex: 2),
              Center(
                child: Text('By continuing, you agree to our Terms & Privacy Policy.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                  textAlign: TextAlign.center),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
