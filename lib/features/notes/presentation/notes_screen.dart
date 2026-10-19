import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/minimal_button.dart';
import '../../../data/providers/database_provider.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();

  void _showAddNoteDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassCard(
            padding: const EdgeInsets.all(AppTokens.space24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('QUICK CAPTURE / NOTE', style: AppTypography.label(isDark: isDark)),
                  const SizedBox(height: AppTokens.space16),
                  TextField(
                    controller: _titleController,
                    autofocus: true,
                    style: AppTypography.titleMedium(isDark: isDark),
                    decoration: InputDecoration(
                      hintText: 'Note Title or Idea',
                      hintStyle: AppTypography.titleMedium(isDark: isDark).copyWith(
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space12),
                  TextField(
                    controller: _contentController,
                    maxLines: 4,
                    style: AppTypography.body(isDark: isDark),
                    decoration: InputDecoration(
                      hintText: 'Jot down thoughts, checklists, or snippets...',
                      hintStyle: AppTypography.body(isDark: isDark).copyWith(
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space12),
                  TextField(
                    controller: _tagController,
                    style: AppTypography.bodySmall(isDark: isDark),
                    decoration: InputDecoration(
                      hintText: 'Tag (e.g. Ideas, Research, Quick)',
                      hintStyle: AppTypography.bodySmall(isDark: isDark).copyWith(
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      MinimalButton(
                        label: 'Cancel',
                        variant: MinimalButtonVariant.ghost,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: AppTokens.space12),
                      MinimalButton(
                        label: 'Save Note',
                        variant: MinimalButtonVariant.accent,
                        onPressed: () {
                          final title = _titleController.text.trim();
                          if (title.isNotEmpty) {
                            ref.read(noteListProvider.notifier).addNote(
                                  title: title,
                                  content: _contentController.text.trim(),
                                  tags: _tagController.text.trim(),
                                );
                            _titleController.clear();
                            _contentController.clear();
                            _tagController.clear();
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notesAsync = ref.watch(noteListProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text('Notes & Quick Capture', style: AppTypography.titleLarge(isDark: isDark)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.white,
        shape: const CircleBorder(),
        onPressed: _showAddNoteDialog,
        child: const Icon(LucideIcons.plus),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: notesAsync.when(
              data: (notes) {
                if (notes.isEmpty) {
                  return EmptyState(
                    icon: LucideIcons.fileText,
                    title: 'No Notes Captured',
                    subtitle: 'Capture ideas, snippets, and quick thoughts offline.',
                    actionLabel: 'Capture Note',
                    onAction: _showAddNoteDialog,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.space16,
                    vertical: AppTokens.space16,
                  ),
            itemCount: notes.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppTokens.space12),
            itemBuilder: (context, index) {
              final note = notes[index];
              return Dismissible(
                key: Key(note.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: AppColors.urgent.withValues(alpha: 0.85),
                    borderRadius: AppTokens.borderMedium,
                  ),
                  child: const Icon(LucideIcons.trash2, color: AppColors.white, size: 20),
                ),
                onDismissed: (_) {
                  ref.read(noteListProvider.notifier).deleteNote(note.id);
                },
                child: GlassCard(
                  padding: const EdgeInsets.all(AppTokens.space20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              note.title,
                              style: AppTypography.titleMedium(isDark: isDark),
                            ),
                          ),
                          if (note.tags.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkCardHover : AppColors.lightCardHover,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '#${note.tags}',
                                style: AppTypography.label(isDark: isDark).copyWith(
                                  fontSize: 10,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (note.content.isNotEmpty) ...[
                        const SizedBox(height: AppTokens.space8),
                        Text(
                          note.content,
                          style: AppTypography.body(isDark: isDark),
                        ),
                      ],
                      const SizedBox(height: AppTokens.space12),
                      Text(
                        'Captured ${DateFormat('MMM d • HH:mm').format(note.updatedAt)}',
                        style: AppTypography.bodySmall(isDark: isDark).copyWith(
                          fontSize: 11,
                          color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    ),
  ),
),
);
  }
}
