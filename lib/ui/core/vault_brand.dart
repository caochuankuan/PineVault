import 'package:flutter/material.dart';

class VaultBrand extends StatelessWidget {
  const VaultBrand({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 40 : 56,
          height: compact ? 40 : 56,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(compact ? 12 : 18),
          ),
          child: Icon(
            Icons.shield_outlined,
            color: scheme.onPrimaryContainer,
            size: compact ? 24 : 32,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PineVault',
              style: compact
                  ? Theme.of(context).textTheme.titleLarge
                  : Theme.of(context).textTheme.headlineSmall,
            ),
            Text('松匣', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}
