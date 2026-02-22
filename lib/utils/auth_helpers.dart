// lib/utils/auth_helpers.dart
import 'package:flutter/material.dart';

Future<void> requireAuth({
  required BuildContext context,
  required String featureName,
  required String currentUserId, // pass widget.currentUserId
  VoidCallback? onSuccess, // optional: what to do after login
}) async {
  if (currentUserId != null) {
    // already logged in → proceed
    onSuccess?.call();
    return;
  }

  final bool? shouldLogin = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text("Sign in to continue"),
      content: Text(
        "You need to be signed in to $featureName.\n"
        "Create or log into your account to save favorites, leave reviews, track your trips, and more.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text("Maybe later"),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.login, size: 18),
          label: const Text("Sign In"),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565FF),
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
        ),
      ],
    ),
  );

  if (shouldLogin == true) {
    // Go to login and wait for result
    final result = await Navigator.pushNamed(
      context,
      '/login',
      arguments: {'returnAfterLogin': true}, // optional flag
    );

    // If they logged in successfully, we can re-check or just call onSuccess
    if (result == true && onSuccess != null) {
      onSuccess();
    }
  }
}
