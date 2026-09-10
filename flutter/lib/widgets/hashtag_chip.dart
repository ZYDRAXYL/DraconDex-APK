import 'package:flutter/material.dart';
import 'color_dot.dart';
import '../data/models/hashtag_model.dart';

class HashtagChip extends StatelessWidget {
  final HashtagModel tag;
  final VoidCallback? onDeleted;
  final VoidCallback? onTap;

  const HashtagChip({super.key, required this.tag, this.onDeleted, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = tag.colorCode != null ? hexToColor(tag.colorCode!) : Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '#${tag.name}',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (onDeleted != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDeleted,
                child: Icon(Icons.close, size: 12, color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
