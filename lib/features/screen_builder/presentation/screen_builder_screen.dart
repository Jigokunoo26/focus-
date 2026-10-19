import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/minimal_button.dart';
import '../../../data/providers/database_provider.dart';
import '../models/widget_registry.dart';

// Riverpod Provider for Active Screen Layout
class ActiveLayoutNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    _loadFromDb();
    return WidgetRegistry.presets['Full Command Center']!;
  }

  Future<void> _loadFromDb() async {
    try {
      final db = await ref.read(databaseProvider.future);
      final rows = db.rawDb.select("SELECT layout_json FROM screens WHERE id = 'home' LIMIT 1;");
      if (rows.isNotEmpty) {
        final jsonStr = rows.first['layout_json'] as String;
        final data = json.decode(jsonStr) as Map<String, dynamic>;
        final widgets = List<String>.from(data['widgets'] as List);
        state = widgets;
      }
    } catch (_) {}
  }

  Future<void> updateLayout(List<String> newLayout) async {
    state = List.from(newLayout);
    try {
      final db = await ref.read(databaseProvider.future);
      final jsonStr = json.encode({'widgets': newLayout});
      db.rawDb.execute(
        "UPDATE screens SET layout_json = ? WHERE id = 'home';",
        [jsonStr],
      );
    } catch (_) {}
  }

  void reorder(int oldIndex, int newIndex) {
    final list = List<String>.from(state);
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    updateLayout(list);
  }

  void toggleWidget(String widgetId) {
    final list = List<String>.from(state);
    if (list.contains(widgetId)) {
      list.remove(widgetId);
    } else {
      list.add(widgetId);
    }
    updateLayout(list);
  }

  void applyPreset(String presetName) {
    final preset = WidgetRegistry.presets[presetName];
    if (preset != null) {
      updateLayout(preset);
    }
  }
}

final activeLayoutProvider = NotifierProvider<ActiveLayoutNotifier, List<String>>(
  ActiveLayoutNotifier.new,
);

class ScreenBuilderScreen extends ConsumerWidget {
  const ScreenBuilderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeWidgets = ref.watch(activeLayoutProvider);
    final layoutNotifier = ref.read(activeLayoutProvider.notifier);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text('Personal OS Screen Builder', style: AppTypography.titleLarge(isDark: isDark)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.space16,
                vertical: AppTokens.space16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Presets Selector
                  Text('LAYOUT PRESETS', style: AppTypography.label(isDark: isDark)),
                  const SizedBox(height: AppTokens.space8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: WidgetRegistry.presets.keys.map((presetName) {
                        return Padding(
                          padding: const EdgeInsets.only(right: AppTokens.space8),
                          child: MinimalButton(
                            label: presetName,
                            variant: MinimalButtonVariant.secondary,
                            onPressed: () {
                              layoutNotifier.applyPreset(presetName);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Applied preset: $presetName')),
                              );
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space24),

                  // Active Widgets (Drag & Drop Reorder)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'ACTIVE DASHBOARD WIDGETS',
                          style: AppTypography.label(isDark: isDark),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${activeWidgets.length} active', style: AppTypography.bodySmall(isDark: isDark)),
                    ],
                  ),
                  const SizedBox(height: AppTokens.space8),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeWidgets.length,
              // ignore: deprecated_member_use
              onReorder: (oldIdx, newIdx) => layoutNotifier.reorder(oldIdx, newIdx),
              itemBuilder: (context, index) {
                final id = activeWidgets[index];
                final descriptor = WidgetRegistry.getById(id);
                if (descriptor == null) return const SizedBox.shrink(key: ValueKey('empty'));

                return Padding(
                  key: ValueKey(id),
                  padding: const EdgeInsets.only(bottom: AppTokens.space8),
                  child: GlassCard(
                    padding: const EdgeInsets.all(AppTokens.space12),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.gripVertical, size: 16),
                        const SizedBox(width: AppTokens.space12),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCardHover : AppColors.lightCardHover,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(descriptor.icon, size: 16, color: AppColors.accent),
                        ),
                        const SizedBox(width: AppTokens.space12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(descriptor.name, style: AppTypography.body(isDark: isDark).copyWith(fontWeight: FontWeight.w600)),
                              Text(descriptor.description, style: AppTypography.bodySmall(isDark: isDark).copyWith(fontSize: 11)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.minusCircle, size: 18, color: AppColors.urgent),
                          onPressed: () => layoutNotifier.toggleWidget(id),
                          tooltip: 'Remove Widget',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppTokens.space24),

            // Inactive / Available Widget Library
            Text('WIDGET LIBRARY (TAP TO ADD)', style: AppTypography.label(isDark: isDark)),
            const SizedBox(height: AppTokens.space8),
            ...WidgetRegistry.availableWidgets
                .where((w) => !activeWidgets.contains(w.id))
                .map((descriptor) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppTokens.space8),
                child: GlassCard(
                  padding: const EdgeInsets.all(AppTokens.space12),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCardHover : AppColors.lightCardHover,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(descriptor.icon, size: 16),
                      ),
                      const SizedBox(width: AppTokens.space12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(descriptor.name, style: AppTypography.body(isDark: isDark)),
                            Text(descriptor.description, style: AppTypography.bodySmall(isDark: isDark).copyWith(fontSize: 11)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.plusCircle, size: 18, color: AppColors.success),
                        onPressed: () => layoutNotifier.toggleWidget(descriptor.id),
                        tooltip: 'Add Widget',
                      ),
                    ],
                  ),
                ),
              );
            }),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
}
