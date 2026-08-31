import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/theme.dart';
import '../models/member.dart';
import 'auth_service.dart';

class PinEntryScreen extends StatefulWidget {
  const PinEntryScreen({
    super.key,
    required this.authService,
    required this.member,
    required this.onLoggedIn,
  });

  final AuthService authService;
  final Member member;
  final ValueChanged<Member> onLoggedIn;

  @override
  State<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<PinEntryScreen> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.text.isEmpty || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final member = await widget.authService.login(
      memberId: widget.member.id,
      pin: _controller.text,
    );

    if (!mounted) return;

    if (member == null) {
      setState(() {
        _submitting = false;
        _error = 'Incorrect PIN. Try again.';
      });
      _controller.clear();
      return;
    }

    widget.onLoggedIn(member);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Hi, ${widget.member.name}')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Enter your PIN', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 8,
              textAlign: TextAlign.center,
              style: AppTextStyles.pinEntry,
              decoration: InputDecoration(
                counterText: '',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
