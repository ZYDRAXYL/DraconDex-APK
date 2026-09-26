import 'package:flutter/material.dart';

import 'danger_button.dart';

Future<bool> showConfirmDialog(BuildContext context, {String? title, String? message}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title ?? 'Confirm'),
      content: Text(message ?? 'This action cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        DdxDangerButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return result ?? false;
}
