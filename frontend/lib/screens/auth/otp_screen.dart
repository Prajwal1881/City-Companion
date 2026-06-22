import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../services/push_notification_service.dart';
import '../../widgets/city_field.dart';

// ─── OTP Screen ───────────────────────────────────────────────────────────────

class OtpScreen extends StatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  bool _resending = false;
  bool _verified = false;
  Timer? _timer;
  int _secondsLeft = 300;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 300);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        _timer?.cancel();
      }
    });
  }

  String get _timerText {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _resend() async {
    setState(() => _resending = true);
    try {
      await ApiClient.sendOtp(widget.phone);
      _startTimer();
      _ctrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('OTP resent successfully!'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to resend OTP')));
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _verify() async {
    if (_ctrl.text.length < 6 || _loading || _verified) return;
    setState(() => _loading = true);
    try {
      await ApiClient.verifyOtp(widget.phone, _ctrl.text);
      await PushNotificationService.registerForCurrentUser();
      final user = await ApiClient.getMe();
      if (!mounted) return;
      // Show the success animation briefly before routing onward.
      _timer?.cancel();
      setState(() {
        _verified = true;
        _loading = false;
      });
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      if (user['is_profile_complete'] == true) {
        context.go('/feed');
      } else {
        context.go('/auth/setup');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _ctrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid OTP')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(backgroundColor: AppColors.bg, elevation: 0),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _verified ? _buildSuccess() : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    final defaultPinTheme = PinTheme(
      width: 50,
      height: 56,
      textStyle: const TextStyle(
          fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
    );
    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.orange, width: 2),
      borderRadius: BorderRadius.circular(14),
    );
    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: AppColors.orange.withValues(alpha: 0.06),
        border: Border.all(color: AppColors.orange, width: 1.5),
      ),
    );

    return SingleChildScrollView(
      key: const ValueKey('otp-form'),
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Verify your number',
            style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text('Enter the 6-digit code sent to ${widget.phone}',
            style: const TextStyle(color: AppColors.sub)),
        const SizedBox(height: 36),
        Center(
          child: Pinput(
            length: 6,
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            defaultPinTheme: defaultPinTheme,
            focusedPinTheme: focusedPinTheme,
            submittedPinTheme: submittedPinTheme,
            separatorBuilder: (_) => const SizedBox(width: 8),
            onCompleted: (_) => _verify(),
            showCursor: true,
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Column(children: [
            if (_secondsLeft > 0)
              Text(
                'Code expires in $_timerText',
                style: TextStyle(
                    color: _secondsLeft <= 60 ? AppColors.rose : AppColors.sub,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            const SizedBox(height: 6),
            _resending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : TextButton(
                    onPressed: _secondsLeft == 0 ? _resend : null,
                    child: Text(
                      "Didn't receive the code? Resend",
                      style: TextStyle(
                        color:
                            _secondsLeft == 0 ? AppColors.orange : AppColors.sub,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ]),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_loading || _secondsLeft == 0) ? null : _verify,
            child: _loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Verify'),
          ),
        ),
      ]),
    );
  }

  Widget _buildSuccess() {
    return Center(
      key: const ValueKey('otp-success'),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 650),
            curve: Curves.elasticOut,
            builder: (_, v, __) => Transform.scale(
              scale: v,
              child: Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.green, width: 3),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.green.withValues(alpha: 0.25),
                        blurRadius: 24,
                        spreadRadius: 2),
                  ],
                ),
                child: const Icon(Icons.check_rounded,
                    color: AppColors.green, size: 56),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text('Verified successfully',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Your phone number has been verified.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.sub, fontSize: 14)),
        ]),
      ),
    );
  }
}

// ─── Profile Setup Screen ─────────────────────────────────────────────────────

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _hometown = TextEditingController();
  final _bio = TextEditingController();
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
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
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge
                  ?.copyWith(fontSize: 28)),
          const SizedBox(height: 24),
          if (_step == 0) ...[
            TextField(
                controller: _name,
                decoration: const InputDecoration(hintText: 'Full name')),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(hintText: 'Profession'),
              items: [
                'Software Engineer',
                'Designer',
                'Student',
                'Entrepreneur',
                'Other'
              ].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (v) => setState(() => _profession = v),
            ),
          ],
          if (_step == 1) ...[
            CityField(controller: _city, hint: 'Current city'),
            const SizedBox(height: 16),
            CityField(controller: _hometown, hint: 'Hometown'),

          ],
          if (_step == 2) ...[
            TextField(
                controller: _bio,
                maxLines: 4,
                decoration: const InputDecoration(
                    hintText: 'Tell people about yourself...')),
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
