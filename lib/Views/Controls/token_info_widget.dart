// lib/Views/Common/token_info_widget.dart
import 'package:flutter/material.dart';
import 'package:del_pick/Services/auth_service.dart';

class TokenInfoWidget extends StatefulWidget {
  const TokenInfoWidget({Key? key}) : super(key: key);

  @override
  State<TokenInfoWidget> createState() => _TokenInfoWidgetState();
}

class _TokenInfoWidgetState extends State<TokenInfoWidget> {
  Map<String, dynamic>? tokenInfo;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTokenInfo();
  }

  Future<void> _loadTokenInfo() async {
    try {
      final info = await AuthService.getTokenInfo();
      setState(() {
        tokenInfo = info;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const CircularProgressIndicator();
    }

    if (tokenInfo == null) {
      return const Text('Token info not available');
    }

    final remainingDays = tokenInfo!['remainingDays'] as int? ?? 0;
    final isValid = tokenInfo!['isValid'] as bool? ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session Info',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isValid ? Icons.check_circle : Icons.error,
                  color: isValid ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  isValid
                      ? 'Session valid for $remainingDays days'
                      : 'Session expired',
                  style: TextStyle(
                    color: isValid ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            if (remainingDays <= 3 && remainingDays > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Your session will expire soon. You may need to login again.',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
