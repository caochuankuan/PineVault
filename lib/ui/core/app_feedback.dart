import 'dart:async';

import 'package:flutter/material.dart';

OverlayEntry? _activeEntry;

void showAppMessage(BuildContext context, String message) {
  final overlay = Overlay.of(context, rootOverlay: true);
  _activeEntry?.remove();
  final theme = Theme.of(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned(
      top: MediaQuery.paddingOf(context).top + 12,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Material(
                color: theme.colorScheme.surfaceContainerHigh,
                elevation: 4,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          message,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  _activeEntry = entry;
  overlay.insert(entry);
  unawaited(
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (_activeEntry == entry) {
        entry.remove();
        _activeEntry = null;
      }
    }),
  );
}
