import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/arabic.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../services/download_service.dart';
import '../services/player_controller.dart';
import '../services/storage_service.dart';
import '../state/library_state.dart';
import '../state/settings_state.dart';

/// الإعدادات والإحصاءات ومعلومات السلسلة.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();
    final library = context.watch<LibraryState>();
    final downloads = context.watch<DownloadService>();
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        Text(
          'الإعدادات',
          style: theme.textTheme.titleLarge?.copyWith(fontSize: 22),
        ),
        const SizedBox(height: 14),

        _Section(
          title: 'العرض',
          children: [
            ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: const Text('المظهر'),
              subtitle: Text(switch (settings.themeMode) {
                ThemeMode.system => 'حسب النظام',
                ThemeMode.light => 'فاتح',
                ThemeMode.dark => 'داكن',
              }),
              trailing: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_rounded, size: 18),
                  ),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (value) =>
                    settings.setThemeMode(value.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.format_size_rounded, size: 20),
                      const SizedBox(width: 12),
                      const Text('حجم خط النص'),
                      const Spacer(),
                      Text(
                        '×${toArabicDigits(settings.fontScale.toStringAsFixed(2))}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  Slider(
                    min: SettingsState.minFontScale,
                    max: SettingsState.maxFontScale,
                    divisions: 19,
                    value: settings.fontScale,
                    onChanged: settings.setFontScale,
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppColors.gold.withValues(alpha: 0.10),
                    ),
                    child: Text(
                      'الأمور بمقاصدها، واليقين لا يزول بالشك.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontSize: 19 * settings.fontScale,
                        height: 1.9,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.numbers_rounded),
              title: const Text('أرقام عربية (٠١٢٣)'),
              value: settings.arabicDigits,
              onChanged: settings.setArabicDigits,
            ),
          ],
        ),

        _Section(
          title: 'الاستماع',
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.vertical_align_center_rounded),
              title: const Text('تتبّع النص تلقائياً'),
              subtitle: const Text('ينتقل النص وحده مع الصوت أثناء التشغيل'),
              value: settings.autoScroll,
              onChanged: settings.setAutoScroll,
            ),
            ListTile(
              leading: const Icon(Icons.speed_rounded),
              title: const Text('سرعة التشغيل الافتراضية'),
              subtitle: Text(
                '×${toArabicDigits(StorageService.instance.playbackSpeed.toString())}',
              ),
              trailing: PopupMenuButton<double>(
                icon: const Icon(Icons.expand_more_rounded),
                onSelected: (value) => PlayerController.instance.setSpeed(value),
                itemBuilder: (context) => [
                  for (final speed in AppConstants.speeds)
                    PopupMenuItem(
                      value: speed,
                      child: Text('×${toArabicDigits('$speed')}'),
                    ),
                ],
              ),
            ),
          ],
        ),

        _Section(
          title: 'التحميلات',
          children: [
            ListTile(
              leading: const Icon(Icons.sd_storage_outlined),
              title: const Text('المساحة المستخدمة'),
              subtitle: FutureBuilder<int>(
                future: downloads.usedBytes(),
                builder: (context, snapshot) => Text(
                  '${toArabicDigits('${downloads.downloadedCount}')} من '
                  '${toArabicDigits('${library.allEpisodes.length}')} حلقة • '
                  '${formatBytes(snapshot.data ?? 0)}',
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.download_for_offline_outlined),
              title: const Text('تحميل كل الحلقات'),
              subtitle: const Text('يحتاج اتصالاً جيداً ومساحة كافية'),
              onTap: () => _downloadAll(context),
            ),
            ListTile(
              leading: Icon(Icons.delete_sweep_outlined,
                  color: theme.colorScheme.error),
              title: Text('حذف كل الملفات المحمّلة',
                  style: TextStyle(color: theme.colorScheme.error)),
              onTap: () => _deleteAll(context),
            ),
          ],
        ),

        _Section(
          title: 'إحصاءاتي',
          children: [
            ListTile(
              leading: const Icon(Icons.headphones_rounded),
              title: const Text('مدّة ما استمعتَ إليه'),
              subtitle: Text(describeDuration(library.listenedTotal)),
            ),
            ListTile(
              leading: const Icon(Icons.task_alt_rounded),
              title: const Text('الحلقات المكتملة'),
              subtitle: Text(
                '${toArabicDigits('${library.completedCount}')} من '
                '${toArabicDigits('${library.allEpisodes.length}')}',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.bookmarks_outlined),
              title: const Text('المفضلة والعلامات'),
              subtitle: Text(
                '${toArabicDigits('${library.favorites.length}')} مفضلة • '
                '${toArabicDigits('${library.bookmarks.length}')} علامة',
              ),
            ),
          ],
        ),

        _Section(
          title: 'عن السلسلة',
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: Text(AppConstants.author),
              subtitle: Text(AppConstants.authorTitle),
            ),
            ListTile(
              leading: const Icon(Icons.radio_outlined),
              title: const Text('المصدر'),
              subtitle: Text(AppConstants.source),
            ),
            ListTile(
              leading: const Icon(Icons.phone_outlined),
              title: const Text('للتواصل مع الشيخ'),
              subtitle: const Text(AppConstants.sheikhPhoneDisplay),
              trailing: const Icon(Icons.call_outlined, size: 20),
              onTap: () => _open(context, AppConstants.sheikhCallUri),
            ),
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: const Text('واتساب'),
              subtitle: const Text(AppConstants.sheikhPhoneDisplay),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () => _open(context, AppConstants.sheikhWhatsAppUri),
            ),
            ListTile(
              leading: const Icon(Icons.code_rounded),
              title: const Text('مستودع المشروع'),
              subtitle: const Text('GitHub'),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () =>
                  _open(context, Uri.parse(AppConstants.repoUrl)),
            ),
          ],
        ),

        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _resetEverything(context),
          icon: Icon(Icons.restart_alt_rounded, color: theme.colorScheme.error),
          label: Text('إعادة تعيين بياناتي',
              style: TextStyle(color: theme.colorScheme.error)),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            'نسخة ${toArabicDigits(AppConstants.appVersion)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ),
      ],
    );
  }

  /// يفتح رابطاً خارجياً، ويخبر المستخدم إن لم يوجد تطبيق يتعامل معه.
  Future<void> _open(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final opened =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        messenger.showSnackBar(
          const SnackBar(content: Text('لا يوجد تطبيق يفتح هذا الرابط')),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('تعذّر فتح الرابط')),
      );
    }
  }

  Future<void> _downloadAll(BuildContext context) async {
    final library = context.read<LibraryState>();
    final downloads = context.read<DownloadService>();
    final pending = library.allEpisodes
        .where((e) => !downloads.isDownloaded(e.id))
        .toList();

    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كل الحلقات محمّلة بالفعل')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تحميل كل الحلقات؟'),
        content: Text(
          'سيجري تحميل ${toArabicDigits('${pending.length}')} حلقة '
          '(نحو ${toArabicDigits('${(pending.length * 6).round()}')} ميجابايت). '
          'يمكنك إيقاف أي حلقة من زرّها.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تحميل'),
          ),
        ],
      ),
    );
    if (!(ok ?? false)) return;

    for (final episode in pending) {
      await downloads.download(episode);
    }
  }

  Future<void> _deleteAll(BuildContext context) async {
    final library = context.read<LibraryState>();
    final downloads = context.read<DownloadService>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف كل الملفات المحمّلة؟'),
        content: const Text(
          'ستبقى المفضلة والعلامات والتقدّم كما هي، ويبقى التشغيل متاحاً عبر الإنترنت.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (!(ok ?? false)) return;
    await downloads.deleteAll(library.allEpisodes);
  }

  Future<void> _resetEverything(BuildContext context) async {
    final library = context.read<LibraryState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعادة تعيين بياناتي؟'),
        content: const Text(
          'سيُحذف التقدّم والمفضلة والعلامات والإعدادات. لا يمكن التراجع.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إعادة التعيين'),
          ),
        ],
      ),
    );
    if (!(ok ?? false)) return;

    await StorageService.instance.clearAll();
    await library.load();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('أُعيد ضبط البيانات')),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.gold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Card(child: Column(children: children)),
        ],
      ),
    );
  }
}
