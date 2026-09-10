part of 'vault_home_screen.dart';

class _GroupSelector extends StatelessWidget {
  const _GroupSelector({
    required this.groups,
    required this.selectedId,
    required this.enabled,
    required this.onSelected,
  });

  final List<VaultGroup> groups;
  final String selectedId;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = groups.firstWhere(
      (group) => group.id == selectedId,
      orElse: () => groups.first,
    );
    return GestureDetector(
      onTap: enabled
          ? () async {
              final value = await showModalBottomSheet<String>(
                context: context,
                showDragHandle: true,
                useSafeArea: true,
                builder: (context) => SafeArea(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 20),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                        child: Text(
                          '选择分组',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      ...groups.map(
                        (group) => ListTile(
                          leading: Icon(
                            group.id == selected.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: group.id == selected.id
                                ? theme.colorScheme.primary
                                : null,
                          ),
                          title: Text(group.name),
                          onTap: () => Navigator.pop(context, group.id),
                        ),
                      ),
                    ],
                  ),
                ),
              );
              if (value != null) onSelected(value);
            }
          : null,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.folder_outlined, size: 20),
            const SizedBox(width: 12),
            const Text('分组'),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                selected.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.expand_more),
          ],
        ),
      ),
    );
  }
}
