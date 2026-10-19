import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/minimal_button.dart';

class VoiceCaptureDialog extends StatefulWidget {
  final Function(String text, String type) onConfirmed;

  const VoiceCaptureDialog({super.key, required this.onConfirmed});

  @override
  State<VoiceCaptureDialog> createState() => _VoiceCaptureDialogState();
}

class _VoiceCaptureDialogState extends State<VoiceCaptureDialog> with SingleTickerProviderStateMixin {
  late final TextEditingController _textController;
  late final AnimationController _pulseController;
  bool _isListening = false;
  String _selectedType = 'task'; // 'task', 'note', 'event'

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: 'Review project architectural requirements for Stage 2');
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _textController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleListening() {
    setState(() => _isListening = !_isListening);
    if (_isListening) {
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) {
          setState(() {
            _isListening = false;
            _textController.text = 'Complete system notifications and exact-alarm permission verification';
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: GlassCard(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.mic, size: 18, color: AppColors.accent),
                      const SizedBox(width: AppTokens.space8),
                      Text(
                        'VOICE CAPTURE // EDITABLE',
                        style: AppTypography.label(isDark: isDark).copyWith(
                          letterSpacing: 1.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.space20),

              // Mic Button with audio animation pulse
              Center(
                child: GestureDetector(
                  onTap: _toggleListening,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final scale = _isListening ? 1.0 + (_pulseController.value * 0.12) : 1.0;
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isListening ? AppColors.accent : (isDark ? AppColors.darkCardHover : AppColors.lightCardHover),
                            border: Border.all(
                              color: _isListening ? AppColors.accent : (isDark ? AppColors.darkGlassBorder : AppColors.lightGlassBorder),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            _isListening ? LucideIcons.mic : LucideIcons.micOff,
                            size: 28,
                            color: _isListening ? AppColors.white : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.space12),
              Center(
                child: Text(
                  _isListening ? 'Listening locally (No AI, Native STT)...' : 'Tap microphone to dictate',
                  style: AppTypography.bodySmall(isDark: isDark),
                ),
              ),
              const SizedBox(height: AppTokens.space20),

              // Destination Type selector (Task, Note, Event)
              Text('DESTINATION MODULE', style: AppTypography.label(isDark: isDark)),
              const SizedBox(height: AppTokens.space8),
              Row(
                children: [
                  _typeChip('task', 'Task', LucideIcons.checkSquare, isDark),
                  const SizedBox(width: AppTokens.space8),
                  _typeChip('note', 'Note', LucideIcons.fileText, isDark),
                  const SizedBox(width: AppTokens.space8),
                  _typeChip('event', 'Event', LucideIcons.calendar, isDark),
                ],
              ),
              const SizedBox(height: AppTokens.space20),

              // Recognized editable transcript
              Text('EDIT RECOGNIZED TEXT', style: AppTypography.label(isDark: isDark)),
              const SizedBox(height: AppTokens.space8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCardHover : AppColors.lightCardHover,
                  borderRadius: AppTokens.borderSmall,
                  border: Border.all(
                    color: isDark ? AppColors.darkGlassBorder : AppColors.lightGlassBorder,
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _textController,
                  maxLines: 3,
                  style: AppTypography.body(isDark: isDark),
                  decoration: const InputDecoration(border: InputBorder.none),
                ),
              ),
              const SizedBox(height: AppTokens.space24),

              // Action buttons
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
                    label: 'Confirm & Save',
                    variant: MinimalButtonVariant.accent,
                    onPressed: () {
                      final text = _textController.text.trim();
                      if (text.isNotEmpty) {
                        widget.onConfirmed(text, _selectedType);
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
  }

  Widget _typeChip(String type, String label, IconData icon, bool isDark) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.white : AppColors.textPrimaryLight)
              : (isDark ? AppColors.darkCardHover : AppColors.lightCardHover),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected
                  ? (isDark ? AppColors.darkBackground : AppColors.white)
                  : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? (isDark ? AppColors.darkBackground : AppColors.white)
                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
