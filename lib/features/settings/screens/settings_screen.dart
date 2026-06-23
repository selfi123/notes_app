import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/providers/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notes = ref.watch(notesProvider);

    final lastSync = settings.lastSyncAt != null
        ? DateFormat('MMM d, h:mm a').format(settings.lastSyncAt!)
        : 'Never';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Icon(PhosphorIcons.caretLeft(PhosphorIconsStyle.light),
                          color: AppColors.textPrimary, size: 18),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text('Settings',
                      style: Theme.of(context).textTheme.headlineLarge),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  // Account section
                  _SectionLabel('ACCOUNT'),
                  _SettingsTile(
                    icon: PhosphorIcons.crown(settings.isActivePremium
                        ? PhosphorIconsStyle.fill
                        : PhosphorIconsStyle.light),
                    iconColor: settings.isActivePremium
                        ? AppColors.amber
                        : AppColors.textMuted,
                    title: 'Subscription',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: settings.isActivePremium
                            ? AppColors.amber.withValues(alpha: 0.15)
                            : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        settings.isActivePremium ? 'Premium' : 'Free',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: settings.isActivePremium
                                  ? AppColors.amber
                                  : AppColors.textSecondary,
                            ),
                      ),
                    ),
                    onTap: () => context.pushNamed('premium'),
                  ),
                  _SettingsTile(
                    icon: PhosphorIcons.database(PhosphorIconsStyle.light),
                    title: 'Notes stored',
                    trailing: Text(
                      '${notes.length}${settings.isActivePremium ? '' : ' / 50'}',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ),

                  const SizedBox(height: 24),
                  // Sync section
                  _SectionLabel('CLOUD SYNC'),
                  _SettingsTile(
                    icon: PhosphorIcons.cloud(PhosphorIconsStyle.light),
                    title: 'Cloud backup',
                    trailing: settings.isActivePremium
                        ? Icon(
                            PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                            color: AppColors.success,
                            size: 18,
                          )
                        : TextButton(
                            onPressed: () => context.pushNamed('premium'),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text('Upgrade',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: AppColors.amber)),
                          ),
                  ),
                  if (settings.isActivePremium)
                    _SettingsTile(
                      icon: PhosphorIcons.arrowClockwise(PhosphorIconsStyle.light),
                      title: 'Last synced',
                      trailing: Text(
                        lastSync,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ),

                  const SizedBox(height: 24),
                  // Preferences
                  _SectionLabel('PREFERENCES'),
                  _SettingsTile(
                    icon: PhosphorIcons.folders(PhosphorIconsStyle.light),
                    title: 'Group notes by contact',
                    trailing: Switch(
                      value: settings.useFolderLayout,
                      onChanged: (val) {
                        ref.read(settingsProvider.notifier).toggleFolderLayout(val);
                      },
                      activeThumbColor: AppColors.amber,
                      activeTrackColor: AppColors.amber.withValues(alpha: 0.3),
                    ),
                  ),

                  const SizedBox(height: 24),
                  // About
                  _SectionLabel('ABOUT'),
                  _SettingsTile(
                    icon: PhosphorIcons.info(PhosphorIconsStyle.light),
                    title: 'Version',
                    trailing: Text('1.0.0',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textMuted)),
                  ),
                  _SettingsTile(
                    icon: PhosphorIcons.shieldCheck(PhosphorIconsStyle.light),
                    title: 'Privacy Policy',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.amber,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    this.iconColor,
    required this.title,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor ?? AppColors.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            if (trailing != null) ...[
              trailing!,
              if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(PhosphorIcons.caretRight(PhosphorIconsStyle.light),
                    size: 14, color: AppColors.textMuted),
              ],
            ] else if (onTap != null)
              Icon(PhosphorIcons.caretRight(PhosphorIconsStyle.light),
                  size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
