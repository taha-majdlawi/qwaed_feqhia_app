import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';

/// شاشة ترحيب تُعرض مرة واحدة عند أول تشغيل، ثم لا تظهر بعدها.
class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  /// لون خلفية الصورة الكريمي وزرّها العنابي، مأخوذان من التصميم نفسه.
  static const Color _cream = Color(0xFFFEFCEF);
  static const Color _button = Color(0xFF56454F);

  Future<void> _continue(BuildContext context) async {
    await StorageService.instance.setSeenIntro();
    if (!context.mounted) return;
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, _, _) => const HomeScreen(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Image.asset(
                AppConstants.introImage,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                width: double.infinity,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: FilledButton(
                  onPressed: () => _continue(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: _button,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'تابع',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
