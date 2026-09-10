import 'package:flutter/material.dart';

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
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return result ?? false;
}
