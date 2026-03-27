
// lib/main.dart
// Handwriting App — Low-vision UI (中文/English) + Voice Guide (Cantonese/English)
// ML Kit Digital Ink Recognition scores strokes from the canvas.

import 'dart:async'; // for Future.microtask
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Alias ML Kit Digital Ink to avoid 'Ink' name clash with Material library.
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart'
as di;


// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
bool isChineseNumeral(String s) => RegExp(r'^[一二三四五六七八九十]+$').hasMatch(s);
bool isArabicNumeral(String s) => RegExp(r'^\d+$').hasMatch(s);

// Text scale & template settings (BIGGER UI for low vision)
const double kTextScaleLinear = 2.0; // enlarged UI globally
const double kMinTemplateFont = 220.0;
const double kMaxTemplateFont = 420.0;
const double kTemplateMarginFactor = 0.88;
const double kTemplateExtraBottomPx = 72.0;

// ─────────────────────────────────────────────────────────────────────────────
// App Settings
// ─────────────────────────────────────────────────────────────────────────────
class AppSettings extends ChangeNotifier {
  String uiLang = 'zh'; // 'zh' or 'en'
  String voiceLang = 'yue'; // 'yue' or 'en'

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    uiLang = prefs.getString('ui_lang') ?? 'zh';
    voiceLang = prefs.getString('voice_lang') ?? 'yue';
    notifyListeners();
  }

  Future<void> setUiLang(String lang) async {
    if (lang != 'zh' && lang != 'en') return;
    uiLang = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ui_lang', uiLang);
    VoiceAnnouncer.instance.attach(this);
  }

  Future<void> setVoiceLang(String lang) async {
    if (lang != 'yue' && lang != 'en') return;
    voiceLang = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('voice_lang', voiceLang);
    VoiceAnnouncer.instance.attach(this);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Voice announcer (Back / Close / etc.)
// ─────────────────────────────────────────────────────────────────────────────
class VoiceAnnouncer {
  VoiceAnnouncer._internal();
  static final VoiceAnnouncer instance = VoiceAnnouncer._internal();

  final FlutterTts _tts = FlutterTts();
  AppSettings? _settings;
  bool _initialized = false;

  void attach(AppSettings s) {
    _settings = s;
    _init();
  }

  Future<void> _init() async {
    if (_initialized) return;
    try {
      await _tts.setSpeechRate(0.50);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(false);
      _initialized = true;
    } catch (e) {
      debugPrint('[Announcer] init error: $e');
    }
  }

  Future<void> _setLanguageForLabels() async {
    try {
      final s = _settings;
      if (s == null) return;
      await _tts.setLanguage(s.voiceLang == 'yue' ? 'yue-HK' : 'en-US');
    } catch (e) {
      debugPrint('[Announcer] setLanguage error: $e');
    }
  }

  Future<void> say({required String zh, required String en}) async {
    await _init();
    try {
      await _tts.stop();
    } catch (_) {}
    await _setLanguageForLabels();
    final s = _settings;
    if (s == null) return;
    final text = (s.voiceLang == 'yue') ? zh : en;
    try {
      await _tts.speak(text);
    } catch (e) {
      debugPrint('[Announcer] speak error: $e');
    }
  }

  Future<void> sayBack() => say(zh: '返回', en: 'Back');
  Future<void> sayClose() => say(zh: '關閉', en: 'Close');
}

// ─────────────────────────────────────────────────────────────────────────────
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = AppSettings();
  await settings.load();
  VoiceAnnouncer.instance.attach(settings);
  runApp(HandwritingApp(settings: settings));
}

class HandwritingApp extends StatelessWidget {
  const HandwritingApp({super.key, required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    // GLOBAL UI FONT: English UI -> KGPrimaryPenmanship; Chinese UI -> NotoSansTC
    final String uiFamily =
    settings.uiLang == 'zh' ? 'NotoSansTC' : 'KGPrimaryPenmanship';

    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return MaterialApp(
          title: t(settings, 'app_title'),
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            scaffoldBackgroundColor: const Color(0xFF0A0A3F),
            fontFamily: uiFamily,
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Colors.white, fontSize: 28, height: 1.35),
              bodyMedium: TextStyle(color: Colors.white, fontSize: 26, height: 1.35),
              bodySmall: TextStyle(color: Colors.white, fontSize: 24, height: 1.35),
            ),
            iconTheme: const IconThemeData(color: Colors.white, size: 36),
            useMaterial3: false,
          ),
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(textScaler: const TextScaler.linear(kTextScaleLinear)),
              child: child!,
            );
          },
          initialRoute: '/',
          routes: {
            '/': (context) => HomePage(settings: settings),
            '/smallLetters': (context) => SmallLetterSelectPage(settings: settings),
            '/capitalLetters': (context) =>
                CapitalLetterSelectPage(settings: settings),
            '/numbers': (context) => NumbersSelectPage(settings: settings),
            '/practice': (context) => PracticeTemplatePage(settings: settings),
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Localization (+ helper fmt)
// ─────────────────────────────────────────────────────────────────────────────
String t(AppSettings s, String key) {
  const zh = <String, String>{
    'app_title': '手寫練習',
    'choose_item': '選擇項目',
    'lowercase': 'a–z',
    'uppercase': 'A–Z',
    'numbers': '數字',
    'back': '返回',
    'close': '關閉',
    'practice_done': '完成',
    'done_detail': '完成 {rounds} 次 {target}\n平均：{percent}%',
    'toolbar': '工具列',
    'brush': '畫筆',
    'eraser': '橡皮',
    'next': '下一次',
    'play_guide': '播放語音導引',
    'canvas_semantics': '畫布。雙擊重播語音。長按高對比。雙指縮放。',
    'ui_lang': '介面',
    'voice_lang': '語音',
    'ui_lang_zh': '中文',
    'ui_lang_en': 'English',
    'voice_yue': '粵語',
    'voice_en': 'English',
    'progress_of': '{n}/10',
    'home_header': '手寫練習',
    'rounds_3': '三次',
    'rounds_10': '十次',
    'say_selected': '已選擇：{glyph}',
    'say_numbers_zh': '阿拉伯及中文數字一至十',
    'say_complete': '完成 {rounds} 次 {target}，平均準確度：{percent} 百分比。',
  };
  const en = <String, String>{
    'app_title': 'Handwriting',
    'choose_item': 'Select',
    'lowercase': 'a–z',
    'uppercase': 'A–Z',
    'numbers': 'Numbers',
    'back': 'Back',
    'close': 'Close',
    'practice_done': 'Done',
    'done_detail': '{rounds} rounds of {target}\nAvg: {percent}%',
    'toolbar': 'Toolbar',
    'brush': 'Brush',
    'eraser': 'Eraser',
    'next': 'Next',
    'play_guide': 'Play Voice Guide',
    'canvas_semantics': 'Canvas. Double-tap to replay. Long press for high contrast. Pinch to zoom.',
    'ui_lang': 'UI',
    'voice_lang': 'Voice',
    'ui_lang_zh': '中文',
    'ui_lang_en': 'English',
    'voice_yue': 'Cantonese',
    'voice_en': 'English',
    'progress_of': '{n}/10',
    'home_header': 'Handwriting',
    'rounds_3': '3 rounds',
    'rounds_10': '10 rounds',
    'say_selected': 'Selected: {glyph}',
    'say_numbers_en': 'Arabic and Chinese numerals one to ten',
    'say_complete':
    'Completed {rounds} rounds of {target}. Average accuracy: {percent} percent.',
  };
  final dict = s.uiLang == 'en' ? en : zh;
  return dict[key] ?? key;
}

String fmt(AppSettings s, String key, Map<String, String> vars) {
  String out = t(s, key);
  vars.forEach((k, v) => out = out.replaceAll('{$k}', v));
  return out;
}

// ─────────────────────────────────────────────────────────────────────────────
// Home Page
// ─────────────────────────────────────────────────────────────────────────────
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.settings});
  final AppSettings settings;

  void _announceHomeTapNumbers() => VoiceAnnouncer.instance.say(
    zh: t(settings, 'say_numbers_zh'),
    en: t(settings, 'say_numbers_en'),
  );

  void _announceHomeTap(String zh, String en) =>
      VoiceAnnouncer.instance.say(zh: zh, en: en);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          // Top bar: larger Voice/UI language buttons for low vision
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              const Expanded(child: SizedBox()),
              _LanguageControls(settings: settings),
            ]),
          ),
          const SizedBox(height: 12),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(children: [
                _headerBox(t(settings, 'home_header')),
                const SizedBox(height: 28),
                _optionBox(
                  context,
                  t(settings, 'lowercase'),
                  '/smallLetters',
                  onTapAnnounce: () =>
                      _announceHomeTap('小寫 a–z', 'Lowercase a–z'),
                ),
                const SizedBox(height: 20),
                _optionBox(
                  context,
                  t(settings, 'uppercase'),
                  '/capitalLetters',
                  onTapAnnounce: () =>
                      _announceHomeTap('大寫 A–Z', 'Uppercase A–Z'),
                ),
                const SizedBox(height: 20),
                _optionBox(
                  context,
                  t(settings, 'numbers'),
                  '/numbers',
                  onTapAnnounce: _announceHomeTapNumbers,
                ),

                if (settings.uiLang == 'en') ...[
                  const SizedBox(height: 20),
                  PoemFeatureHomeButton(settings: settings),
                ],

              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _headerBox(String text) {
    return Container(
      width: double.infinity,
      height: 96,
      decoration: const BoxDecoration(
        color: Color(0xFF4A90E2),
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      alignment: Alignment.center,
      child: NoTextScale(
        child: FitText(
          text,
          minFont: 26.0,
          maxFont: 56.0,
          color: const Color(0xFF0A0A3F),
          fontWeight: FontWeight.w900,
          padding:
          const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        ),
      ),
    );
  }

  Widget _optionBox(
      BuildContext context,
      String text,
      String route, {
        required VoidCallback onTapAnnounce,
      }) {
    final navigator = Navigator.of(context);
    return GestureDetector(
      onTap: () {
        onTapAnnounce();
        navigator.pushNamed(route);
      },
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          border: Border.all(color: Colors.white, width: 3),
        ),
        alignment: Alignment.center,
        child: NoTextScale(
          child: FitText(
            text,
            minFont: 28.0,
            maxFont: 52.0,
            color: Colors.white,
            fontWeight: FontWeight.w800,
            padding:
            const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top-right toggles (Voice + UI Language) — larger & localized
// ─────────────────────────────────────────────────────────────────────────────
class _LanguageControls extends StatelessWidget {
  const _LanguageControls({required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      // Voice language — localized menu labels
      PopupMenuButton<String>(
        tooltip: t(settings, 'voice_lang'),
        icon: SizedBox(
          width: 80,
          height: 80,
          child: Semantics(
            label: t(settings, 'voice_lang'),
            button: true,
            child: const Icon(Icons.volume_up, color: Colors.white, size: 60),
          ),
        ),
        onSelected: (value) {
          settings.setVoiceLang(value);
          VoiceAnnouncer.instance.say(
            zh: value == 'yue' ? '已選擇：粵語語音' : '已選擇：英文語音',
            en: value == 'yue'
                ? 'Selected: Cantonese voice'
                : 'Selected: English voice',
          );
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: 'yue', child: Text(t(settings, 'voice_yue'))),
          PopupMenuItem(value: 'en', child: Text(t(settings, 'voice_en'))),
        ],
      ),
      const SizedBox(width: 16),
      // UI language — localized menu labels
      PopupMenuButton<String>(
        tooltip: t(settings, 'ui_lang'),
        icon: SizedBox(
          width: 80,
          height: 80,
          child: Semantics(
            label: t(settings, 'ui_lang'),
            button: true,
            child: const Icon(Icons.language, color: Colors.white, size: 60),
          ),
        ),
        onSelected: (value) {
          settings.setUiLang(value);
          VoiceAnnouncer.instance.say(
            zh: value == 'zh' ? '已選擇：中文介面' : '已選擇：英文介面',
            en: value == 'zh' ? 'Selected: Chinese UI' : 'Selected: English UI',
          );
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: 'zh', child: Text(t(settings, 'ui_lang_zh'))),
          PopupMenuItem(value: 'en', child: Text(t(settings, 'ui_lang_en'))),
        ],
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Selection Pages (Close voice on pop)
// ─────────────────────────────────────────────────────────────────────────────
Widget _gridSelectPage(
    AppSettings settings,
    BuildContext context,
    String title,
    List<String> items,
    String type,
    ) {
  return PopScope(
    canPop: true,
    onPopInvokedWithResult: (didPop, result) {
      // Speak "Close" (not Back) for all normal returns
      Future.microtask(() {
        VoiceAnnouncer.instance.sayClose();
      });
    },
    child: Scaffold(
      body: SafeArea(
        child: Column(children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: NoTextScale(
                    child: FitText(
                      title,
                      minFont: 28.0,
                      maxFont: 56.0,
                      color: Colors.yellow,
                      fontWeight: FontWeight.w900,
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ),
              ),
              _LanguageControls(settings: settings),
              const SizedBox(width: 8),
              const _CloseButtonIcon(), // X icon, voice "Close"
            ]),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 18,
                crossAxisSpacing: 18,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final glyph = items[index];
                final navigator = Navigator.of(context); // capture before await
                return GestureDetector(
                  onTap: () async {
                    // Announce selection: numbers use arabic/chinese wording; letters use generic
                    final bool isNum = type.contains('Numbers');
                    String zhSel, enSel;
                    if (isNum && isChineseNumeral(glyph)) {
                      zhSel = '已選擇：中文數字 $glyph';
                      enSel = 'Selected Chinese numeral $glyph';
                    } else if (isNum && isArabicNumeral(glyph)) {
                      zhSel = '已選擇：阿拉伯數字 $glyph';
                      enSel = 'Selected Arabic numeral $glyph';
                    } else {
                      zhSel = fmt(settings, 'say_selected', {'glyph': glyph});
                      enSel = fmt(settings, 'say_selected', {'glyph': glyph});
                    }
                    VoiceAnnouncer.instance.say(zh: zhSel, en: enSel);

                    final result = await navigator.pushNamed(
                      '/practice',
                      arguments: '$type: $glyph',
                    );
                    if (result is double) {
                      final percent =
                      (result * 100).clamp(0, 100).toStringAsFixed(0);
                      VoiceAnnouncer.instance.say(
                        zh: '完成練習，準確度：$percent 百分比。',
                        en: 'Practice completed. Accuracy: $percent percent.',
                      );
                    }
                  },
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFB0A999),
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                    alignment: Alignment.center,
                    child: NoTextScale(
                      child: FitText(
                        glyph,
                        minFont: 26.0,
                        maxFont: 48.0,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 6.0),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    ),
  );
}

// Close (X) button widget
class _CloseButtonIcon extends StatelessWidget {
  const _CloseButtonIcon();
  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    return GestureDetector(
      onTap: () {
        VoiceAnnouncer.instance.sayClose(); // voice "Close"
        navigator.pop();
      },
      child: const Icon(Icons.close, color: Colors.white, size: 40),
    );
  }
}

class SmallLetterSelectPage extends StatelessWidget {
  const SmallLetterSelectPage({super.key, required this.settings});
  final AppSettings settings;
  @override
  Widget build(BuildContext context) {
    final letters = List.generate(26, (i) => String.fromCharCode(97 + i));
    return _gridSelectPage(
        settings, context, t(settings, 'lowercase'), letters, 'Small Letter');
  }
}

class CapitalLetterSelectPage extends StatelessWidget {
  const CapitalLetterSelectPage({super.key, required this.settings});
  final AppSettings settings;
  @override
  Widget build(BuildContext context) {
    final letters = List.generate(26, (i) => String.fromCharCode(65 + i));
    return _gridSelectPage(
        settings, context, t(settings, 'uppercase'), letters, 'Capital Letter');
  }
}

class NumbersSelectPage extends StatelessWidget {
  const NumbersSelectPage({super.key, required this.settings});
  final AppSettings settings;
  @override
  Widget build(BuildContext context) {
    const arabic = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10'];
    const chinese = ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十'];
    final items = [...arabic, ...chinese];
    return _gridSelectPage(
        settings, context, t(settings, 'numbers'), items, 'Numbers');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Voice Guide Content (letters + numbers)
// ─────────────────────────────────────────────────────────────────────────────

// English — Capital Letters (A–Z)
const Map<String, List<String>> kUpperEnGuide = {
  'A': ['Start at the top.', 'Draw a diagonal down-left.', 'Go back up and draw a diagonal down-right.', 'Add a horizontal bar across the middle.'],
  'B': ['Draw a vertical line down.', 'Curve outward to make the upper loop.', 'Curve outward again to make the lower loop.'],
  'C': ['Start near the top right.', 'Curve left and down like an open circle.', 'Finish near the bottom right.'],
  'D': ['Draw a vertical line down.', 'Make a large curve from top to bottom to close the letter.'],
  'E': ['Draw a vertical line down.', 'Add a horizontal line at the top.', 'Add a shorter horizontal in the middle.', 'Add a horizontal line at the bottom.'],
  'F': ['Draw a vertical line down.', 'Add a horizontal line at the top.', 'Add a shorter horizontal in the middle.'],
  'G': ['Draw a big C shape.', 'At the lower right, add a short horizontal line to the right.'],
  'H': ['Draw two vertical lines.', 'Connect them with a horizontal line in the middle.'],
  'I': ['Draw a short horizontal line at the top.', 'Draw a vertical line down the center.', 'Draw a short horizontal line at the bottom.'],
  'J': ['Draw a short horizontal line at the top.', 'Draw a vertical line down.', 'Curve left at the bottom to make a hook.'],
  'K': ['Draw a vertical line.', 'From the middle, a diagonal up-right.', 'From the same middle point, a diagonal down-right.'],
  'L': ['Draw a vertical line down.', 'Add a horizontal line to the right at the bottom.'],
  'M': ['Draw a vertical line down.', 'From the top, diagonal down to the center.', 'Diagonal up to the top on the right.', 'Draw a final vertical line down.'],
  'N': ['Draw a vertical line down on the left.', 'Diagonal from top-left to bottom-right.', 'Draw a vertical line down on the right.'],
  'O': ['Draw a large closed oval.'],
  'P': ['Draw a vertical line down.', 'Curve to the right to make the upper loop.'],
  'Q': ['Draw a large closed oval.', 'Add a short tail diagonally at the bottom right.'],
  'R': ['Draw a vertical line down.', 'Curve to the right for the upper loop.', 'Add a diagonal down-right from the middle.'],
  'S': ['Begin with a small curve at top.', 'Reverse curve to the bottom.', 'A gentle zig made of curves.'],
  'T': ['Draw a long horizontal line at the top.', 'Draw a vertical line down from its center.'],
  'U': ['Draw down on the left, curve around, and go up on the right.'],
  'V': ['Draw a diagonal down to the center.', 'Draw a diagonal up to the right.'],
  'W': ['Diagonal down, up, down, up — a wide zig pattern.'],
  'X': ['Draw a diagonal down-right.', 'Cross it with a diagonal down-left.'],
  'Y': ['Draw two short diagonals meeting in the center.', 'From the meeting point, draw a vertical line down.'],
  'Z': ['Draw a top horizontal.', 'Diagonal down-left.', 'Draw a bottom horizontal to the right.'],
};

// English — Lowercase Letters (a–z)
const Map<String, List<String>> kLowerEnGuide = {
  'a': ['Draw a small circle.', 'Add a short vertical on the right.'],
  'b': ['Draw a vertical line down.', 'Add a round belly on the right (lower half).'],
  'c': ['Draw a small open curve to the right.'],
  'd': ['Draw a round belly on the left.', 'Add a tall vertical line on the right.'],
  'e': ['Draw a short horizontal line.', 'Curve around to form a small loop.'],
  'f': ['Draw a tall vertical with a little curve at top.', 'Add a short horizontal bar in the middle.'],
  'g': ['Draw a small circle.', 'Add a tail that goes down and curves to the left.'],
  'h': ['Draw a vertical line down.', 'Add a small hump on the right.'],
  'i': ['Draw a short vertical line.', 'Place a dot above.'],
  'j': ['Draw a short vertical with a hook below.', 'Place a dot above.'],
  'k': ['Draw a vertical line.', 'From the middle, a short diagonal up-right.', 'From the middle, a short diagonal down-right.'],
  'l': ['Draw a simple vertical line.'],
  'm': ['Draw a short vertical.', 'Add two small humps to the right.'],
  'n': ['Draw a short vertical.', 'Add one small hump to the right.'],
  'o': ['Draw a small closed oval.'],
  'p': ['Draw a long vertical down (below baseline).', 'Add a small round belly on the right.'],
  'q': ['Draw a small closed oval.', 'Add a short tail down-right.'],
  'r': ['Draw a short vertical.', 'Add a tiny curve to the right.'],
  's': ['Small curve at top, reverse curve to bottom.'],
  't': ['Draw a short vertical line.', 'Add a small horizontal bar near the top.'],
  'u': ['Draw down and curve up on the right.'],
  'v': ['Short diagonal down and diagonal up.'],
  'w': ['Down-up-down-up — small zig pattern.'],
  'x': ['Small diagonal down-right, then down-left crossing.'],
  'y': ['Draw a small v shape.', 'Add a tail going below baseline.'],
  'z': ['Short top horizontal.', 'Diagonal down-left.', 'Short bottom horizontal.'],
};

// Cantonese — Capital Letters (A–Z)
const Map<String, List<String>> kUpperYueGuide = {
  'A': ['由頂部開始。', '畫一條斜線向左落。', '返上頂部，再畫一條斜線向右落。', '喺中間加一條橫線連接。'],
  'B': ['先畫一條直線落。', '向右畫上半個圓肚。', '再向右畫下半個圓肚。'],
  'C': ['由右上開始向左下畫圓弧。', '好似未封口嘅圓形。'],
  'D': ['先畫一條直線落。', '由頂到尾畫一個大弧形包住。'],
  'E': ['畫一條直線落。', '喺頂部畫一條橫線。', '中間畫短橫線。', '底部再畫一條橫線。'],
  'F': ['畫一條直線落。', '頂部畫一條橫線。', '中間畫短橫線。'],
  'G': ['先畫一個大 C。', '喺右下加一短橫線向右。'],
  'H': ['畫兩條直線。', '中間加一條橫線連接。'],
  'I': ['頂部畫短橫線。', '中間畫直線落。', '底部畫短橫線。'],
  'J': ['頂部畫短橫線。', '向下畫直線。', '底部向左彎做勾。'],
  'K': ['畫一條直線。', '由中間向右上畫斜線。', '再由中間向右下畫斜線。'],
  'L': ['畫一條直線落。', '底部向右畫一條橫線。'],
  'M': ['左邊畫直線落。', '由左上斜落中間。', '再斜上返右上。', '右邊畫直線落。'],
  'N': ['左邊畫直線落。', '由左上斜到右下。', '右邊畫直線落。'],
  'O': ['畫一個大椭圓封口。'],
  'P': ['畫一條直線落。', '右邊畫上半個圓肚。'],
  'Q': ['畫一個大椭圓封口。', '右下加一條斜尾。'],
  'R': ['畫一條直線落。', '右邊畫上半個圓肚。', '中間斜落右下。'],
  'S': ['上半部細彎。', '再向下反向彎。', '好似連住嘅兩個弧。'],
  'T': ['頂部畫長橫線。', '中心向下畫直線。'],
  'U': ['左邊向下，底部彎，再向上到右邊。'],
  'V': ['由左斜落到中間。', '再斜上到右邊。'],
  'W': ['斜落、斜上、斜落、斜上，寬闊嘅 W。'],
  'X': ['斜落右線。', '再斜落左線交叉。'],
  'Y': ['上面兩條短斜線相交。', '由交點向下畫直線。'],
  'Z': ['頂部一條橫線。', '斜線落左下。', '底部一條橫線向右。'],
};

// Cantonese — Lowercase Letters (a–z)
const Map<String, List<String>> kLowerYueGuide = {
  'a': ['先畫細圓。', '右邊加短直線。'],
  'b': ['先畫直線落。', '右邊下半部畫圓肚。'],
  'c': ['向右開口嘅小弧線。'],
  'd': ['左邊畫圓肚。', '右邊加高直線。'],
  'e': ['先畫短橫線。', '再圍成細圈。'],
  'f': ['畫高直線，上端帶少少彎。', '中間加短橫線。'],
  'g': ['先畫細圓。', '向下加尾，左邊稍微彎。'],
  'h': ['畫直線落。', '右邊加小拱。'],
  'i': ['畫短直線。', '上面點一點。'],
  'j': ['畫短直線，下端勾住。', '上面加一點。'],
  'k': ['畫直線。', '中間向右上畫短斜線。', '中間向右下再畫短斜線。'],
  'l': ['畫簡單直線。'],
  'm': ['畫短直線。', '右邊連續兩個小拱。'],
  'n': ['畫短直線。', '右邊加一個小拱。'],
  'o': ['畫細椭圓封口。'],
  'p': ['畫長直線向下越過底線。', '右邊加細圓肚。'],
  'q': ['畫細椭圓封口。', '右下加短尾。'],
  'r': ['畫短直線。', '右邊微微彎一下。'],
  's': ['上半小彎，再向下反彎。'],
  't': ['畫短直線。', '上方加短橫線。'],
  'u': ['向下畫，底部彎，再向上到右邊。'],
  'v': ['斜落再斜上。'],
  'w': ['細小斜落斜上斜落斜上。'],
  'x': ['斜落右線，再斜落左線交叉。'],
  'y': ['先畫細 v。', '再向下加尾越過底線。'],
  'z': ['上短橫線。', '斜落左下。', '下短橫線。'],
};

// English — Numbers (Arabic 1–10 + UPDATED Chinese 一–十)
const Map<String, List<String>> kNumbersEnGuide = {
  // Arabic digits
  '1': ['Draw a short top flick or serif.', 'Draw a straight vertical line down.'],
  '2': ['Small curve from top left.', 'Diagonal to bottom right, then a short base line.'],
  '3': ['Two outward curves stacked — upper curve and lower curve.'],
  '4': ['Diagonal down-right.', 'Add a horizontal across.', 'Vertical down on the right.'],
  '5': ['Top horizontal line.', 'Short vertical down-left.', 'Curve at bottom to the right.'],
  '6': ['Small loop at top-left, curve down to close a round belly.'],
  '7': ['Top horizontal line.', 'Diagonal down-right.'],
  '8': ['Small loop on top.', 'Larger loop below to join.'],
  '9': ['Small loop at top-right.', 'Long curve down to form the tail.'],
  '10': ['Straight vertical for “1”.', 'Next to it, draw a round “0”.'],

  // UPDATED Chinese numerals
  '一': [
    'Start from the left.',
    'Draw one horizontal stroke to the right.',
  ],
  '二': [
    'First draw the top horizontal stroke (shorter).',
    'Then draw the bottom horizontal stroke (longer).',
  ],
  '三': [
    'First draw the top horizontal stroke (short).',
    'Then draw the middle horizontal stroke (medium length).',
    'Finally draw the bottom horizontal stroke (long).',
  ],
  '四': [
    'First draw the left vertical stroke.',
    'Draw the top horizontal stroke.',
    'Draw the right vertical stroke.',
    'Inside, first draw a short left-slanting stroke, then a vertical curved stroke to the right.',
    'Add the bottom horizontal stroke to close the box.',
  ],
  '五': [
    'First draw the top horizontal stroke.',
    'Draw a vertical stroke downward in the middle.',
    'From the left, draw a horizontal hook.',
    'Finally draw the bottom horizontal stroke.',
  ],
  '六': [
    'First draw a small dot at the top.',
    'Draw a horizontal stroke.',
    'Below the horizontal stroke, first draw a left-slanting stroke, then a right-slanting stroke.',
  ],
  '七': [
    'First draw a horizontal stroke.',
    'From the middle, draw a vertical stroke downward.',
    'Add a hook to the right at the bottom.',
  ],
  '八': [
    'First draw a diagonal stroke slanting down to the left (撇).',
    'Then draw another diagonal stroke slanting down to the right (捺).',
  ],
  '九': [
    'First draw a horizontal curved hook (from top left to bottom right).',
    'Then draw a slanting stroke downward.',
  ],
  '十': [
    'First draw a horizontal stroke.',
    'Then draw a vertical stroke through the middle.',
  ],
};

// Cantonese — Numbers (Arabic 1–10 + UPDATED Chinese 一–十)
const Map<String, List<String>> kNumbersYueGuide = {
  // Arabic digits
  '1': ['上面輕輕一撇或短橫。', '再向下畫直線。'],
  '2': ['由左上細彎開始。', '斜落右下，底部再加短橫。'],
  '3': ['上下兩個向外嘅弧線，堆疊形成「3」。'],
  '4': ['先斜落右下。', '中間畫橫線。', '右邊畫直線落。'],
  '5': ['頂部一條橫線。', '左邊短直線落。', '底部向右畫彎線。'],
  '6': ['左上細圈，向下延伸形成圓肚封口。'],
  '7': ['頂部一條橫線。', '斜線向右下。'],
  '8': ['上面細圈，下面大圈，兩圈相連。'],
  '9': ['右上細圈。', '向下畫長彎尾。'],
  '10': ['先畫「1」嘅直線。', '旁邊畫一個圓形代表「0」。'],

  // UPDATED Chinese numerals
  '一': [
    '由左邊開始。',
    '畫一條橫線向右。',
  ],
  '二': [
    '先畫上面一條橫線（短啲）。',
    '再畫下面一條橫線（長啲）。',
  ],
  '三': [
    '先畫上面一條橫線（短）。',
    '再畫中間一條橫線（中等）。',
    '最後畫下面一條橫線（長）。',
  ],
  '四': [
    '先畫左邊直線。',
    '畫頂部橫線。',
    '畫右邊直線。',
    '入面先向左畫一撇，再向右畫一豎彎。',
    '底部加橫線封口。',
  ],
  '五': [
    '先畫頂部橫線。',
    '在中間向下畫一直線。',
    '左邊開始畫一條橫鈎。',
    '最後畫底部橫線。',
  ],
  '六': [
    '先畫頂部細點。',
    '畫一條橫線。',
    '在橫線下面先向左畫一撇，再向右畫一捺。',
  ],
  '七': [
    '先畫一條橫線。',
    '由中間畫一條直線向下。',
    '底部加鉤向右。',
  ],
  '八': [
    '先畫一條斜線向左下（撇）。',
    '再畫另一條斜線向右下（捺）。',
  ],
  '九': [
    '先畫一條橫彎鈎（左上向右下）。',
    '再畫一撇，由上向下。',
  ],
  '十': [
    '先畫一條橫線。',
    '再畫一條直線穿過中間。',
  ],
};

// ─────────────────────────────────────────────────────────────────────────────
// Voice Guide Service (announces numeral system; step-numbered)
// ─────────────────────────────────────────────────────────────────────────────
class VoiceGuideService {
  final FlutterTts _tts = FlutterTts();
  final AppSettings settings;
  bool _initialized = false;
  VoiceGuideService(this.settings) {
    _initTts();
  }

  Future<void> _initTts() async {
    if (_initialized) return;
    try {
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true); // step-by-step in order
      _initialized = true;
    } catch (e) {
      debugPrint('[TTS] init error: $e');
    }
  }

  Future<void> _setSelectedLanguage() async {
    try {
      await _tts.setLanguage(settings.voiceLang == 'yue' ? 'yue-HK' : 'en-US');
    } catch (e) {
      try {
        await _tts.setLanguage(settings.voiceLang == 'yue' ? 'zh-HK' : 'en-US');
      } catch (e2) {
        debugPrint('[TTS] setLanguage fallback error: $e2');
      }
    }
  }

  Future<void> speakForTarget(String practiceType) async {
    await _initTts();
    await _setSelectedLanguage();

    final target = practiceType.split(':').last.trim();
    final category = practiceType.split(':').first.trim();
    List<String> steps = const [];

    // Announce numeral system first (Numbers only)
    if (category.contains('Numbers')) {
      final isCN = isChineseNumeral(target);
      if (settings.voiceLang == 'yue') {
        await _tts.speak(isCN ? '目標：中文數字。' : '目標：阿拉伯數字。');
      } else {
        await _tts.speak(isCN ? 'Target: Chinese numerals.' : 'Target: Arabic numerals.');
      }
    }

    // Choose the guide steps
    if (category.contains('Capital Letter')) {
      steps = settings.voiceLang == 'yue'
          ? (kUpperYueGuide[target] ?? ['未有指引。'])
          : (kUpperEnGuide[target] ?? ['No guidance available.']);
    } else if (category.contains('Small Letter')) {
      steps = settings.voiceLang == 'yue'
          ? (kLowerYueGuide[target] ?? ['未有指引。'])
          : (kLowerEnGuide[target] ?? ['No guidance available.']);
    } else if (category.contains('Numbers')) {
      steps = settings.voiceLang == 'yue'
          ? (kNumbersYueGuide[target] ?? ['未有指引。'])
          : (kNumbersEnGuide[target] ?? ['No guidance available.']);
    }

    // Speak steps with numbering (consistent)
    for (int i = 0; i < steps.length; i++) {
      final prefix =
      (settings.voiceLang == 'yue') ? '步驟${i + 1}：' : 'Step ${i + 1}: ';
      await _tts.speak('$prefix${steps[i]}');
    }
  }

  Future<void> speakScore(double score) async {
    await _initTts();
    await _setSelectedLanguage();
    final percent = (score * 100).clamp(0, 100).toStringAsFixed(0);
    if (settings.voiceLang == 'yue') {
      await _tts.speak('準確度：$percent 百分比。');
    } else {
      await _tts.speak('Accuracy: $percent percent.');
    }
  }

  // Completion summary using UI language wording
  Future<void> speakCompletionSummary({
    required String target,
    required int rounds,
    required double avgAccuracy01,
  }) async {
    await _initTts();
    await _setSelectedLanguage();
    final percentStr =
    (avgAccuracy01 * 100).clamp(0, 100).toStringAsFixed(0);

    final textZh = fmt(settings, 'say_complete', {
      'rounds': rounds.toString(),
      'target': target,
      'percent': percentStr,
    });
    final textEn = fmt(settings, 'say_complete', {
      'rounds': rounds.toString(),
      'target': target,
      'percent': percentStr,
    });

    final sayText = settings.uiLang == 'zh' ? textZh : textEn;
    await _tts.speak(sayText);
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('[TTS] stop error: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stroke Painter
// ─────────────────────────────────────────────────────────────────────────────
class StrokePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;
  final Color strokeColor;
  final double strokeWidth;
  const StrokePainter(
      this.strokes,
      this.currentStroke, {
        this.strokeColor = Colors.white,
        this.strokeWidth = 8.0,
      });
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final s in strokes) {
      for (int i = 0; i < s.length - 1; i++) {
        canvas.drawLine(s[i], s[i + 1], paint);
      }
    }
    for (int i = 0; i < currentStroke.length - 1; i++) {
      canvas.drawLine(currentStroke[i], currentStroke[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant StrokePainter oldDelegate) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Practice Template Page — ML Kit + PopScope ("Close" on normal pop)
// ─────────────────────────────────────────────────────────────────────────────
class PracticeTemplatePage extends StatefulWidget {
  const PracticeTemplatePage({super.key, required this.settings});
  final AppSettings settings;
  @override
  State<PracticeTemplatePage> createState() => _PracticeTemplatePageState();
}

class _PracticeTemplatePageState extends State<PracticeTemplatePage> {
  String practiceType = '';
  int practiceCount = 0;
  int totalRounds = 10;
  late List<List<Offset>> strokes;
  List<Offset> currentStroke = [];
  bool isEraser = false;
  bool highContrast = false;
  double strokeWidth = 8.0;

  // Voice
  late final VoiceGuideService _voice;

  // Canvas key
  final GlobalKey _canvasKey = GlobalKey();

  // Scores
  final List<double> _attemptScores = [];

  // Input handling
  bool _isScaling = false;
  bool _autoPlayed = false;

  AppSettings get settings => widget.settings;

  // ML Kit: Digital Ink
  di.DigitalInkRecognizer? _inkRecognizer;
  final di.DigitalInkRecognizerModelManager _modelManager =
  di.DigitalInkRecognizerModelManager();

  @override
  void initState() {
    super.initState();
    strokes = [];
    _voice = VoiceGuideService(settings);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    practiceType =
        (ModalRoute.of(context)?.settings.arguments as String?) ??
            'Practice: ?';
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_autoPlayed && practiceCount == 0) {
        _autoPlayed = true;
        // ENTRY: Numbers get specific wording; letters generic
        final glyph = practiceType.split(':').last.trim();
        final category = practiceType.split(':').first.trim();
        final bool isNum = category.contains('Numbers');

        String zhSel, enSel;
        if (isNum && isChineseNumeral(glyph)) {
          zhSel = '已選擇：中文數字 $glyph';
          enSel = 'Selected Chinese numeral $glyph';
        } else if (isNum && isArabicNumeral(glyph)) {
          zhSel = '已選擇：阿拉伯數字 $glyph';
          enSel = 'Selected Arabic numeral $glyph';
        } else {
          zhSel = fmt(settings, 'say_selected', {'glyph': glyph});
          enSel = fmt(settings, 'say_selected', {'glyph': glyph});
        }
        VoiceAnnouncer.instance.say(zh: zhSel, en: enSel);
      }
    });
  }

  @override
  void dispose() {
    _voice.stop();
    _inkRecognizer?.close();
    super.dispose();
  }

  // ── Stroke interactions
  void _startStroke(Offset point) {
    if (isEraser) {
      _eraseStroke(point);
    } else {
      currentStroke = [point];
    }
  }

  void _updateStroke(Offset point) {
    if (isEraser) {
      _eraseStroke(point);
      return;
    }
    if (currentStroke.isEmpty) {
      currentStroke = [point];
    } else {
      currentStroke.add(point);
    }
    setState(() {});
  }

  void _endStroke() {
    if (!isEraser && currentStroke.isNotEmpty) {
      strokes.add(List.from(currentStroke));
      currentStroke.clear();
    }
  }

  void _eraseStroke(Offset point) {
    setState(() {
      strokes.removeWhere((stroke) {
        for (final p in stroke) {
          if ((p - point).distance < 20) return true;
        }
        return false;
      });
    });
  }

  // ── Next: accuracy first -> gap -> Next/Done
  Future<void> _nextPractice() async {
    await _voice.stop();
    final score = await _computeAccuracy(); // ML Kit scoring
    _attemptScores.add(score);

    final key = 'accuracy_${practiceType.replaceAll(' ', '_')}_$totalRounds';
    await AccuracyRecorder(key).saveAttempt(score);

    // Speak per-attempt accuracy
    await _voice.speakScore(score);

    // Gap
    await Future.delayed(const Duration(milliseconds: 150));

    // Confirm
    final isFinal = (practiceCount + 1 >= totalRounds);
    await VoiceAnnouncer.instance.say(
      zh: isFinal ? '完成' : '下一次',
      en: isFinal ? 'Done' : 'Next',
    );
    HapticFeedback.mediumImpact();

    if (!isFinal) {
      setState(() {
        practiceCount++;
        strokes.clear();
        currentStroke.clear();
      });
    } else {
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    final avg = _attemptScores.isEmpty
        ? 0.0
        : _attemptScores.reduce((a, b) => a + b) / _attemptScores.length;

    // Speak completion summary using UI language wording
    final targetGlyph = practiceType.split(':').last.trim();
    _voice.speakCompletionSummary(
      target: targetGlyph,
      rounds: totalRounds,
      avgAccuracy01: avg,
    );

    showDialog(
      context: context,
      builder: (context) {
        final navigator = Navigator.of(context); // capture before awaits
        return AlertDialog(
          title: Text(
            t(settings, 'practice_done'),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                fmt(
                  settings,
                  'done_detail',
                  {
                    'rounds': totalRounds.toString(),
                    'target': targetGlyph,
                    'percent': (avg * 100).toStringAsFixed(1),
                  },
                ),
                style: const TextStyle(fontSize: 30, height: 1.4),
              ),
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: avg,
                backgroundColor: Colors.grey,
                color: avg >= 0.8
                    ? Colors.green
                    : (avg >= 0.5 ? Colors.orange : Colors.red),
                minHeight: 14,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Dialog "Back": speak BACK (not Close)
                VoiceAnnouncer.instance.sayBack();
                navigator.pop(avg); // close dialog
                navigator.pop(avg); // back to selection page
              },
              child: Text(
                t(settings, 'back'),
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Template fitting
  double _fitTemplateFont({
    required Size canvas,
    required String glyph,
    required TextStyle baseStyle,
  }) {
    double low = kMinTemplateFont;
    double high = kMaxTemplateFont;
    const double padW = 24.0;
    const double padH = 24.0 + kTemplateExtraBottomPx;
    final double maxW = (canvas.width - padW).clamp(100.0, canvas.width);
    final double maxH = (canvas.height - padH).clamp(100.0, canvas.height);

    bool fits(double size) {
      final tp = TextPainter(
        text: TextSpan(text: glyph, style: baseStyle.copyWith(fontSize: size)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: maxW);
      return (tp.width <= maxW) && (tp.height <= maxH);
    }

    if (!fits(low)) {
      double s = low;
      while (s > 120.0) {
        s -= 10.0;
        if (fits(s)) return s;
      }
      return 120.0;
    }
    for (int i = 0; i < 18; i++) {
      final mid = (low + high) / 2.0;
      if (fits(mid)) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return low;
  }

  // Render the template glyph into an image (handwriting fonts)
  Future<ui.Image> _renderTemplateToImage(Size size) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final Paint bg = Paint()..color = const Color(0x00000000);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    final String glyph = practiceType.split(':').last.trim();
    final bool isCN =
        isChineseNumeral(glyph) || RegExp(r'[\u4e00-\u9fff]').hasMatch(glyph);
    final String handwritingFamily =
    isCN ? 'NotoSansTC' : 'KGPrimaryPenmanship';
    final Color color = highContrast ? Colors.yellowAccent : Colors.white;

    final TextStyle baseStyle = TextStyle(
      fontWeight: FontWeight.w400,
      fontFamily: handwritingFamily, // KG Primary (EN/Arabic) or Noto Sans TC (Chinese)
      fontFamilyFallback: const ['PingFang HK', 'sans-serif'],
      color: color,
    );
    final double fittedFontExact =
    _fitTemplateFont(canvas: size, glyph: glyph, baseStyle: baseStyle);
    final double fittedFont = fittedFontExact * kTemplateMarginFactor;

    final textSpan = TextSpan(
      text: glyph,
      style: baseStyle.copyWith(fontSize: fittedFont),
    );
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    tp.layout(maxWidth: size.width - 24.0);
    final double dx = (size.width - tp.width) / 2;
    final double dy = (size.height - tp.height) / 2;
    tp.paint(canvas, Offset(dx, dy));

    final pic = recorder.endRecording();
    return pic.toImage(size.width.toInt(), size.height.toInt());
  }

  void _toggleHighContrast() {
    setState(() => highContrast = !highContrast);
    VoiceAnnouncer.instance.say(
      zh: highContrast ? '高對比：開啟' : '高對比：關閉',
      en: highContrast ? 'High contrast: on' : 'High contrast: off',
    );
    HapticFeedback.selectionClick();
  }

  void _cycleStrokeWidth() {
    setState(() {
      if (strokeWidth == 8.0) {
        strokeWidth = 12.0;
      } else if (strokeWidth == 12.0) {
        strokeWidth = 16.0;
      } else {
        strokeWidth = 8.0;
      }
    });
    VoiceAnnouncer.instance.say(
      zh: '畫筆粗細：$strokeWidth',
      en: 'Stroke width: $strokeWidth',
    );
    HapticFeedback.lightImpact();
  }

  // ── ML Kit recognition & scoring
  String _languageForPractice() {
    final target = practiceType.split(':').last.trim();
    return isChineseNumeral(target) ? 'zh-Hant' : 'en-US';
  }

  Future<void> _ensureInkModel() async {
    final tag = _languageForPractice();
    final exists = await _modelManager.isModelDownloaded(tag);
    if (!exists) {
      await _modelManager.downloadModel(tag);
    }
    _inkRecognizer?.close();
    _inkRecognizer = di.DigitalInkRecognizer(languageCode: tag);
  }

  di.Ink _toInk(Size canvasSize) {
    final ink = di.Ink();
    int t = DateTime.now().millisecondsSinceEpoch;
    const int dt = 16;

    for (final s in strokes) {
      final stroke = di.Stroke();
      final pts = <di.StrokePoint>[];
      for (final p in s) {
        pts.add(di.StrokePoint(x: p.dx, y: p.dy, t: t));
        t += dt;
      }
      stroke.points = pts;
      ink.strokes.add(stroke);
    }
    return ink;
  }

  double _candidateScore(List<di.RecognitionCandidate> cands, String target) {
    if (cands.isEmpty) return 0.0;
    final normalizedTarget = target.trim();

    final idx = cands.indexWhere((c) => c.text.trim() == normalizedTarget);
    if (idx < 0) {
      double bestSim = 0.0;
      for (final c in cands.take(5)) {
        bestSim =
            math.max(bestSim, _stringSimilarity(c.text.trim(), normalizedTarget));
      }
      return bestSim * 0.6;
    }

    const List<double> weights = [1.0, 0.85, 0.70, 0.55, 0.40, 0.30];
    final rankW = weights[idx < weights.length ? idx : weights.length - 1];

    final dynamic rawScore = cands[idx].score;
    double conf01;
    if (rawScore is double) {
      conf01 = (rawScore > 0.0 && rawScore <= 1.0) ? rawScore : 1.0;
    } else {
      conf01 = 1.0;
    }

    return (rankW * conf01).clamp(0.0, 1.0);
  }

  double _stringSimilarity(String a, String b) {
    if (a == b) return 1.0;
    final la = a.length, lb = b.length;
    if (la == 0 || lb == 0) return 0.0;
    final dist = _levenshtein(a, b).toDouble();
    return (1.0 - dist / math.max(la, lb)).clamp(0.0, 1.0);
  }

  int _levenshtein(String s, String t) {
    final m = s.length, n = t.length;
    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
    for (int i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j <= n; j++) {
      dp[0][j] = j;
    }
    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        dp[i][j] = math.min(
          math.min(dp[i - 1][j] + 1, dp[i][j - 1] + 1),
          dp[i - 1][j - 1] + cost,
        );
      }
    }
    return dp[m][n];
  }

  Future<double> _computeAccuracy() async {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return 0.0;
    final size = box.size;

    await _ensureInkModel();
    if (_inkRecognizer == null) return 0.0;

    final ink = _toInk(size);
    final ctx = di.DigitalInkRecognitionContext(
      writingArea: di.WritingArea(width: size.width, height: size.height),
    );

    List<di.RecognitionCandidate> candidates = [];
    try {
      candidates = await _inkRecognizer!.recognize(ink, context: ctx);
    } catch (e) {
      debugPrint('[MLKit] recognize error: $e');
      return 0.0;
    }

    final target = practiceType.split(':').last.trim();
    final mlScore = _candidateScore(candidates, target);

    final templateImg = await _renderTemplateToImage(size);
    final coverage =
    await _simpleCoverageAgainstTemplate(strokes, templateImg, size);

    return (0.80 * mlScore + 0.20 * coverage).clamp(0.0, 1.0);
  }

  Future<double> _simpleCoverageAgainstTemplate(
      List<List<Offset>> s, ui.Image template, Size canvas) async {
    const int dim = 160;
    final picRec = ui.PictureRecorder();
    final canvas2 = Canvas(picRec);
    final paint = Paint()..isAntiAlias = false;

    canvas2.drawImageRect(
      template,
      Rect.fromLTWH(
          0, 0, template.width.toDouble(), template.height.toDouble()),
      Rect.fromLTWH(0, 0, dim.toDouble(), dim.toDouble()),
      paint,
    );

    final pic = picRec.endRecording();
    final img = await pic.toImage(dim, dim);
    final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bd == null) return 0.0;
    final bytes = bd.buffer.asUint8List();

    final sx = dim / canvas.width;
    final sy = dim / canvas.height;

    int total = 0, inside = 0;
    for (final st in s) {
      for (final p in st) {
        final int x = (p.dx * sx).round().clamp(0, dim - 1);
        final int y = (p.dy * sy).round().clamp(0, dim - 1);
        final int idx = (y * dim + x) * 4; // RGBA
        final int a = bytes[idx + 3];
        total++;
        if (a >= 16) {
          inside++;
        }
      }
    }
    if (total == 0) return 0.0;
    return (inside / total).clamp(0.0, 1.0);
  }

  // ── UI (PopScope with Close speech)
  @override
  Widget build(BuildContext context) {
    final progressValue = (practiceCount + 1) / totalRounds;
    final toolbarColor =
    highContrast ? Colors.black : const Color(0xFFB0A999);
    final brushColor =
    isEraser ? Colors.black : (highContrast ? Colors.white : Colors.blueAccent);
    final eraserColor = isEraser ? Colors.red : Colors.black;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    final String glyph = practiceType.split(':').last.trim();
    final bool isCN =
        isChineseNumeral(glyph) || RegExp(r'[\u4e00-\u9fff]').hasMatch(glyph);
    final String handwritingFamily =
    isCN ? 'NotoSansTC' : 'KGPrimaryPenmanship';
    const Color normalTemplateColor = Color(0xFFB0A999);
    final Color templateColor =
    highContrast ? Colors.yellowAccent : normalTemplateColor;

    final TextStyle baseStyle = TextStyle(
      fontWeight: FontWeight.w400,
      fontFamily: handwritingFamily,
      fontFamilyFallback: const ['PingFang HK', 'sans-serif'],
    );

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // For normal pop from practice: voice "Close"
        Future.microtask(() {
          VoiceAnnouncer.instance.sayClose();
        });
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(children: [
            const SizedBox(height: 10),
            // Top row: progress, rounds, language buttons, close (X)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: NoTextScale(
                      child: FitText(
                        '${practiceCount + 1}/$totalRounds',
                        minFont: 24.0,
                        maxFont: 38.0,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ToggleButtons(
                    isSelected: [totalRounds == 3, totalRounds == 10],
                    onPressed: (index) {
                      final newRounds = (index == 0) ? 3 : 10;
                      if (newRounds != totalRounds) {
                        setState(() {
                          totalRounds = newRounds;
                          practiceCount = 0;
                          strokes.clear();
                          currentStroke.clear();
                        });
                        HapticFeedback.selectionClick();
                        VoiceAnnouncer.instance.say(
                          zh: index == 0
                              ? t(settings, 'rounds_3')
                              : t(settings, 'rounds_10'),
                          en: index == 0
                              ? t(settings, 'rounds_3')
                              : t(settings, 'rounds_10'),
                        );
                      }
                    },
                    color: Colors.white70,
                    selectedColor: Colors.white,
                    fillColor: const Color(0xFF4A90E2),
                    borderColor: Colors.white,
                    selectedBorderColor: Colors.white,
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text('3'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text('10'),
                      ),
                    ],
                  ),
                ),
                _LanguageControls(settings: settings),
                const SizedBox(width: 8),
                const _CloseButtonIcon(), // X icon, voice "Close"
              ]),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(
                value: progressValue,
                backgroundColor: Colors.grey,
                color: Colors.green,
                minHeight: 16,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 84,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
                    foregroundColor: const Color(0xFF0A0A3F),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                    elevation: 0,
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  onPressed: () async {
                    VoiceAnnouncer.instance.say(
                      zh: t(settings, 'play_guide'),
                      en: t(settings, 'play_guide'),
                    );
                    await _voice.stop();
                    await _voice.speakForTarget(practiceType);
                  },
                  icon: const Icon(Icons.volume_up, size: 40),
                  label: NoTextScale(
                    child: SizedBox(
                      height: 40,
                      child: FitText(
                        t(settings, 'play_guide'),
                        minFont: 20.0,
                        maxFont: 32.0,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0A0A3F),
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Canvas
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                final Size canvasSize =
                Size(constraints.maxWidth, constraints.maxHeight);

                final double fittedExact = _fitTemplateFont(
                    canvas: canvasSize, glyph: glyph, baseStyle: baseStyle);
                final double fittedFont = fittedExact * kTemplateMarginFactor;

                return Semantics(
                  label: t(settings, 'canvas_semantics'),
                  child: GestureDetector(
                    onDoubleTap: () async {
                      VoiceAnnouncer.instance.say(
                          zh: '重播導引', en: 'Replay guide');
                      await _voice.stop();
                      await _voice.speakForTarget(practiceType);
                    },
                    onLongPress: _toggleHighContrast,
                    onScaleStart: (_) => _isScaling = false,
                    onScaleUpdate: (details) {
                      _isScaling = false;
                      final p = details.localFocalPoint;
                      if (isEraser) {
                        _eraseStroke(p);
                      } else {
                        if (currentStroke.isEmpty) {
                          _startStroke(p);
                        } else {
                          _updateStroke(p);
                        }
                      }
                    },
                    onScaleEnd: (_) {
                      if (!_isScaling &&
                          currentStroke.isNotEmpty &&
                          !isEraser) {
                        _endStroke();
                      }
                      _isScaling = false;
                    },
                    child: NoTextScale(
                      child: Stack(children: [
                        Center(
                          child: Text(
                            glyph,
                            textAlign: TextAlign.center,
                            style: baseStyle.copyWith(
                              fontSize: fittedFont,
                              color: templateColor,
                            ),
                          ),
                        ),
                        // Proxy layer to get canvas size
                        RepaintBoundary(
                          key: _canvasKey,
                          child: const SizedBox.expand(),
                        ),
                        // Strokes
                        Positioned.fill(
                          child: CustomPaint(
                            painter: StrokePainter(
                              strokes,
                              currentStroke,
                              strokeColor: Colors.white,
                              strokeWidth: strokeWidth,
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),
            // Toolbox
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  bottom: bottomInset > 0 ? 12 : 16,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: toolbarColor,
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                  ),
                  padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() => isEraser = false);
                          VoiceAnnouncer.instance.say(
                            zh: t(settings, 'brush'),
                            en: t(settings, 'brush'),
                          );
                          HapticFeedback.selectionClick();
                        },
                        onLongPress: _cycleStrokeWidth,
                        child: Semantics(
                          button: true,
                          label: t(settings, 'brush'),
                          child:
                          Icon(Icons.brush, size: 52, color: brushColor),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() => isEraser = true);
                          VoiceAnnouncer.instance.say(
                            zh: t(settings, 'eraser'),
                            en: t(settings, 'eraser'),
                          );
                          HapticFeedback.selectionClick();
                        },
                        child: Semantics(
                          button: true,
                          label: t(settings, 'eraser'),
                          child: Icon(Icons.cleaning_services,
                              size: 52, color: eraserColor),
                        ),
                      ),
                      GestureDetector(
                        onTap: _nextPractice,
                        child: Semantics(
                          button: true,
                          label: t(settings, 'next'),
                          child:
                          const Icon(Icons.arrow_forward, size: 52),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NoTextScale
// ─────────────────────────────────────────────────────────────────────────────
class NoTextScale extends StatelessWidget {
  const NoTextScale({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(textScaler: const TextScaler.linear(1.0)),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FitText (defaults to current Theme font family)
// ─────────────────────────────────────────────────────────────────────────────
class FitText extends StatelessWidget {
  const FitText(
      this.text, {
        super.key,
        this.minFont = 20.0,
        this.maxFont = 72.0, // bigger max for low vision
        this.padding =
        const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        this.style,
        this.textAlign = TextAlign.center,
        this.color,
        this.fontFamily,
        this.fontFamilyFallback = const ['PingFang HK', 'sans-serif'],
        this.fontWeight = FontWeight.w900,
      });
  final String text;
  final double minFont;
  final double maxFont;
  final EdgeInsets padding;
  final TextStyle? style;
  final TextAlign textAlign;
  final Color? color;
  final String? fontFamily;
  final List<String> fontFamilyFallback;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final Size box = Size(constraints.maxWidth, constraints.maxHeight);
      final double maxW =
      (box.width - padding.horizontal).clamp(24.0, box.width);
      final double maxH =
      (box.height - padding.vertical).clamp(24.0, box.height);

      // Default to current Theme fontFamily
      final String themeFamily =
          Theme.of(context).textTheme.bodyLarge?.fontFamily ??
              'KGPrimaryPenmanship';

      TextStyle base = TextStyle(
        fontSize: minFont,
        fontWeight: fontWeight,
        color:
        color ?? Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white,
        fontFamily: fontFamily ?? themeFamily,
        fontFamilyFallback: fontFamilyFallback,
        height: style?.height ?? 1.2,
      );
      if (style != null) base = base.merge(style);

      bool fits(double size) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: base.copyWith(fontSize: size)),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: maxW);
        return painter.width <= maxW && painter.height <= maxH;
      }

      double low = minFont;
      double high = maxFont;
      if (!fits(low)) {
        double s = low;
        while (true) {
          s -= 2.0;
          if (s <= 10.0) break;
          if (fits(s)) {
            low = s;
            break;
          }
        }
      }
      for (int i = 0; i < 18; i++) {
        final mid = (low + high) / 2.0;
        if (fits(mid)) {
          low = mid;
        } else {
          high = mid;
        }
      }
      final double best = low;
      return Padding(
        padding: padding,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.visible,
          textAlign: textAlign,
          style: base.copyWith(fontSize: best),
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Accuracy Recorder
// ─────────────────────────────────────────────────────────────────────────────
class AccuracyRecorder {
  final String key;
  const AccuracyRecorder(this.key);

  Future<void> saveAttempt(double score) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    final list = raw == null
        ? <double>[]
        : (jsonDecode(raw) as List)
        .map((e) => (e as num).toDouble())
        .toList();
    list.add(score);
    await prefs.setString(key, jsonEncode(list));
  }

  Future<List<double>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return <double>[];
    return (jsonDecode(raw) as List)
        .map((e) => (e as num).toDouble())
        .toList();
  }
}
// ======================================================================
// POEM FEATURE — SINGLE-FILE DROP-IN (no new imports here)
// ======================================================================

/// Home button for Poem feature — visible only when UI language is English.
/// Place this widget in HomePage.build() after the Numbers tile:
/// if (settings.uiLang == 'en') ...[ SizedBox(height: 20), PoemFeatureHomeButton(settings: settings), ],
class PoemFeatureHomeButton extends StatelessWidget {
  final AppSettings settings;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double height;

  const PoemFeatureHomeButton({
    super.key,
    required this.settings,
    this.padding = const EdgeInsets.all(12),
    this.width,
    this.height = 56,
  });

  bool _isEnglish() => settings.uiLang == 'en';

  @override
  Widget build(BuildContext context) {
    if (!_isEnglish()) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: padding,
      child: SizedBox(
        width: width ?? double.infinity,
        height: height,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.menu_book),
          label: const Text('Poem'),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const PoemFeatureListPage(),
              ),
            );
          },
        ),
      ),
    );
  }
}


/// Simple data model for a poem (public-domain texts below).
class PoemFeaturePoem {
  final String id;
  final String title;
  final String author;
  final String text;

  const PoemFeaturePoem({
    required this.id,
    required this.title,
    required this.author,
    required this.text,
  });

  /// Split poem text into words. Keeps apostrophes; strips other punctuation.
  List<String> get words {
    final normalized = text
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('’', "'")
        .trim();
    final tokens = normalized.split(RegExp(r"[^\w']+"));
    return tokens.where((w) => w.isNotEmpty).toList();
  }
}

/// Public-domain / nursery rhymes (safe for shipping).
const List<PoemFeaturePoem> kPoemFeaturePoems = [
  PoemFeaturePoem(
    id: 'twinkle',
    title: 'Twinkle, Twinkle, Little Star',
    author: 'Jane Taylor (1806)',
    text: '''
Twinkle, twinkle, little star,
How I wonder what you are!
Up above the world so high,
Like a diamond in the sky.
''',
  ),
  PoemFeaturePoem(
    id: 'mary_lamb',
    title: 'Mary Had a Little Lamb',
    author: 'Sarah Josepha Hale (1830)',
    text: '''
Mary had a little lamb,
Its fleece was white as snow;
And everywhere that Mary went
The lamb was sure to go.
''',
  ),
  PoemFeaturePoem(
    id: 'humpty',
    title: 'Humpty Dumpty',
    author: 'Mother Goose',
    text: '''
Humpty Dumpty sat on a wall,
Humpty Dumpty had a great fall;
All the king's horses and all the king's men
Couldn't put Humpty together again.
''',
  ),
];

/// A simple list page that shows available poems (English-only feature).
/// Tapping a poem opens the practice screen.
class PoemFeatureListPage extends StatelessWidget {
  final List<PoemFeaturePoem> poems;

  /// If you already declared `kPoemFeaturePoems`, leave this empty.
  const PoemFeatureListPage({super.key, this.poems = kPoemFeaturePoems});

  @override
  Widget build(BuildContext context) {
    final data = poems.isEmpty ? kPoemFeaturePoems : poems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Poem'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        itemCount: data.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final poem = data[index];
          final subtitle = [
            if (poem.author.trim().isNotEmpty) poem.author.trim(),
            '${poem.words.length} words',
          ].join(' • ');

          return InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PoemFeaturePracticePage(poem: poem),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.menu_book,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PoemTitleSubtitle(
                        title: poem.title,
                        subtitle: subtitle,
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PoemTitleSubtitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PoemTitleSubtitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    final subtitleStyle = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.8));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: subtitleStyle,
        ),
      ],
    );
  }
}


// =============================================================================
// POEM FEATURE — PRACTICE PAGE
// UPDATED FULL VERSION (Option‑C Difficulty + Auto‑Scaling Writing Area)
// =============================================================================

class PoemFeaturePracticePage extends StatefulWidget {
  final PoemFeaturePoem poem;

  const PoemFeaturePracticePage({super.key, required this.poem});

  @override
  State<PoemFeaturePracticePage> createState() =>
      _PoemFeaturePracticePageState();
}

class _PoemFeaturePracticePageState extends State<PoemFeaturePracticePage> {

  // ✅ LANDSCAPE MODE TOGGLE
  bool forceLandscape = false;

  void _toggleForceLandscape() {
    setState(() => forceLandscape = !forceLandscape);

    if (forceLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  // ---------------------------------------------------------------------------
  // WORD / CHARACTER NAVIGATION
  // ---------------------------------------------------------------------------

  late final List<String> _words;
  int _wordIndex = 0;
  int _charIndex = 0;

  // Raw indices of visible characters
  List<int> _rawIndices = [];

  List<String> _charsForWord(String w) => w
      .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
      .split('')
      .where((c) => c.isNotEmpty)
      .toList();

  String get _currentWord =>
      (_wordIndex < _words.length) ? _words[_wordIndex] : '';

  List<String> get _chars => _charsForWord(_currentWord);

  String get _activeChar =>
      (_charIndex < _chars.length) ? _chars[_charIndex] : '';

  bool get _isLastCharInWord => _charIndex >= _chars.length - 1;

  int get _activeRawIndex =>
      (_charIndex < _rawIndices.length) ? _rawIndices[_charIndex] : 0;

  void _skipToFirstNonEmptyWord() {
    while (_wordIndex < _words.length &&
        _charsForWord(_words[_wordIndex]).isEmpty) {
      _wordIndex++;
    }
    _charIndex = 0;
  }

  void _rebuildRawIndices() {
    _rawIndices = [];
    for (int i = 0; i < _currentWord.length; i++) {
      if (RegExp(r'[A-Za-z0-9]').hasMatch(_currentWord[i])) {
        _rawIndices.add(i);
      }
    }
    if (_charIndex >= _rawIndices.length) _charIndex = 0;
  }

  // ---------------------------------------------------------------------------
  // STROKES + CANVAS
  // ---------------------------------------------------------------------------

  final GlobalKey _canvasKey = GlobalKey();
  final List<List<Offset>> _strokes = [];
  List<Offset> _current = [];
  double _strokeWidth = 10.0;

  void _clearCanvas() {
    setState(() {
      _strokes.clear();
      _current.clear();
    });
  }

  // ---------------------------------------------------------------------------
  // AUTO-NEXT
  // ---------------------------------------------------------------------------

  bool _autoNextEnabled = true;
  double _autoNextThreshold = 0.50;
  Timer? _evalDebounce;

  // ---------------------------------------------------------------------------
  // ML KIT
  // ---------------------------------------------------------------------------

  di.DigitalInkRecognizer? _ink;
  final di.DigitalInkRecognizerModelManager _modelMgr =
  di.DigitalInkRecognizerModelManager();

  // ---------------------------------------------------------------------------
  // TTS
  // ---------------------------------------------------------------------------

  final FlutterTts _tts = FlutterTts();
  bool _ttsReady = false;

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('en-US');
    } catch (_) {
      try {
        await _tts.setLanguage('en_US');
      } catch (_) {}
    }
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(0.45);
    await _tts.awaitSpeakCompletion(false);
    _ttsReady = true;
  }

  Future<void> _speak(String t) async {
    if (!_ttsReady || t.isEmpty) return;
    try {
      await _tts.stop();
    } catch (_) {}
    await _tts.speak(t);
  }

  Future<void> _announceWordThenChar() async {
    if (_currentWord.isEmpty || _activeChar.isEmpty) return;
    await _speak("You are writing: $_currentWord.");
    await Future.delayed(const Duration(milliseconds: 120));
    await _speak(_activeChar);
  }

  Future<void> _speakCharOnly() async {
    if (_activeChar.isEmpty) return;
    await _speak(_activeChar);
  }

  // ---------------------------------------------------------------------------
  // FEEDBACK METRICS + DIFFICULTY TRACKING
  // ---------------------------------------------------------------------------

  late DateTime _sessionStart;
  DateTime? _charStart;

  int _charsCompleted = 0;
  double _sumAccuracy = 0.0;
  Duration _sumCharTime = Duration.zero;

  final Map<String, int> _charMistakeCount = {};
  final Map<String, int> _wordMistakeCount = {};
  final Map<String, List<double>> _wordAccuracies = {};

  void _startCharTimer() => _charStart = DateTime.now();

  String _fmtTimeShort(Duration d) {
    if (d.inMinutes >= 1) {
      final m = d.inMinutes;
      final s = d.inSeconds % 60;
      return s > 0 ? '$m minutes $s seconds' : '$m minutes';
    }
    return '${d.inSeconds} seconds';
  }

  // Characters that often confuse ML models
  final Set<String> _simpleChars = {'l', 'I', '1', '|', 't', 'i'};

  // ---------------------------------------------------------------------------
  // LIFECYCLE
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    _words = widget.poem.words.toList();
    for (final w in _words) {
      _wordAccuracies[w] = [];
    }

    _skipToFirstNonEmptyWord();
    _rebuildRawIndices();
    _rebuildLetterKeys();

    _initTts();
    _sessionStart = DateTime.now();
    _startCharTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _centerActiveLetter();
      await _announceWordThenChar();
      _startCharTimer();
    });
  }

  @override
  void dispose() {
    _evalDebounce?.cancel();
    try {
      _ink?.close();
    } catch (_) {}
    _tts.stop();
    _stripController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // CENTER ACTIVE LETTER (ensureVisible)
  // ---------------------------------------------------------------------------

  final ScrollController _stripController = ScrollController();
  static const EdgeInsets _stripPadding =
  EdgeInsets.symmetric(horizontal: 36.0);
  static const double _gap = 10.0;

  List<GlobalKey> _letterKeys = [];

  void _rebuildLetterKeys() {
    _letterKeys = List.generate(_currentWord.length, (_) => GlobalKey());
  }

  Future<void> _centerActiveLetter() async {
    final idx = _activeRawIndex;
    if (idx < 0 || idx >= _letterKeys.length) return;

    final ctx = _letterKeys[idx].currentContext;
    if (ctx == null) return;

    await Scrollable.ensureVisible(
      ctx,
      alignment: 0.50,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
  }

  // ---------------------------------------------------------------------------
  // ACCURACY ENGINE — UPDATED (ML + coverage + simple char fixes)
  // ---------------------------------------------------------------------------

  String _langTagForChar(String c) {
    final isCJK = RegExp(r'[\u4e00-\u9fff]').hasMatch(c);
    return isCJK ? 'zh-Hant' : 'en-US';
  }

  Future<void> _ensureModel(String c) async {
    final tag = _langTagForChar(c);
    if (!await _modelMgr.isModelDownloaded(tag)) {
      await _modelMgr.downloadModel(tag);
    }
    if (_ink == null || _ink!.languageCode != tag) {
      try {
        await _ink?.close();
      } catch (_) {}
      _ink = di.DigitalInkRecognizer(languageCode: tag);
    }
  }

  di.Ink _inkFromStrokes(Size size) {
    final ink = di.Ink();
    int t = DateTime.now().millisecondsSinceEpoch;
    const dt = 16;

    for (final s in _strokes) {
      final stroke = di.Stroke();
      final pts = <di.StrokePoint>[];
      for (final p in s) {
        pts.add(di.StrokePoint(x: p.dx, y: p.dy, t: t));
        t += dt;
      }
      stroke.points = pts;
      ink.strokes.add(stroke);
    }
    return ink;
  }

  // ----------------- Levenshtein Similarity -----------------

  int _lev(String a, String b) {
    if (a == b) return 0;
    final m = a.length;
    final n = b.length;

    final dp =
    List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));

    for (int i = 0; i <= m; i++) dp[i][0] = i;
    for (int j = 0; j <= n; j++) dp[0][j] = j;

    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = math.min(
          math.min(dp[i - 1][j] + 1, dp[i][j - 1] + 1),
          dp[i - 1][j - 1] + cost,
        );
      }
    }
    return dp[m][n];
  }

  double _sim01(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    final d = _lev(a, b);
    return (1.0 - d / math.max(a.length, b.length))
        .clamp(0.0, 1.0);
  }

  // ----------------- Ranked ML Score -----------------

  double _rankedScore01(
      List<di.RecognitionCandidate> cands, String target) {
    if (cands.isEmpty) return 0.0;

    final t = target.trim();
    final idx =
    cands.indexWhere((c) => c.text.trim() == t);

    if (idx < 0) {
      // No exact match → fallback to similarity
      double best = 0.0;
      for (final c in cands.take(5)) {
        best = math.max(best, _sim01(c.text.trim(), t));
      }
      return (best * 0.6).clamp(0.0, 1.0);
    }

    // Weighted rank scores
    const weights = [
      1.0,
      0.85,
      0.70,
      0.55,
      0.40,
      0.30
    ];

    final w = weights[idx < weights.length
        ? idx
        : weights.length - 1];
    final raw = cands[idx].score;

    final conf =
    (raw is double && raw > 0 && raw <= 1.0)
        ? raw
        : 1.0;

    return (w * conf).clamp(0.0, 1.0);
  }

  // ----------------- Render Template Glyph -----------------

  Future<ui.Image> _renderTemplate(Size size, String ch) async {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0x00000000),
    );

    const base = TextStyle(
      fontFamily: 'KGPrimaryPenmanship',
      color: Color(0xFFB0A999),
    );

    double lo = 100;
    double hi = 520;

    bool fits(double fs) {
      final tp = TextPainter(
        text: TextSpan(
            text: ch, style: base.copyWith(fontSize: fs)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 24);

      return tp.width <= size.width - 24 &&
          tp.height <= size.height - 24;
    }

    // Binary search optimal font size
    for (int i = 0; i < 16; i++) {
      final mid = (lo + hi) / 2;
      if (fits(mid))
        lo = mid;
      else
        hi = mid;
    }

    final tp = TextPainter(
      text: TextSpan(
          text: ch, style: base.copyWith(fontSize: lo)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 24);

    tp.paint(
      canvas,
      Offset((size.width - tp.width) / 2,
          (size.height - tp.height) / 2),
    );

    return rec
        .endRecording()
        .toImage(size.width.toInt(), size.height.toInt());
  }

  // ----------------- Coverage (template hit test) -----------------

  Future<double> _coverage01(
      List<List<Offset>> strokes,
      ui.Image template,
      Size canvas) async {
    const int dim = 160;

    final rec = ui.PictureRecorder();
    final c = Canvas(rec);

    c.drawImageRect(
      template,
      Rect.fromLTWH(
          0, 0,
          template.width.toDouble(),
          template.height.toDouble()),
      Rect.fromLTWH(
          0, 0,
          dim.toDouble(),
          dim.toDouble()),
      Paint()..isAntiAlias = false,
    );

    final img =
    await rec.endRecording().toImage(dim, dim);
    final bd = await img.toByteData(
        format: ui.ImageByteFormat.rawRgba);

    if (bd == null) return 0.0;
    final bytes = bd.buffer.asUint8List();

    final sx = dim / canvas.width;
    final sy = dim / canvas.height;

    int total = 0;
    int inside = 0;

    for (final s in strokes) {
      for (final p in s) {
        final x = (p.dx * sx).round().clamp(0, dim - 1);
        final y = (p.dy * sy).round().clamp(0, dim - 1);

        final idx = (y * dim + x) * 4;
        final a = bytes[idx + 3];

        total++;
        if (a >= 16) inside++;
      }
    }

    if (total == 0) return 0.0;
    return (inside / total).clamp(0.0, 1.0);
  }

  // ---------------------------------------------------------------------------
  // ✅ FINAL ACCURACY COMPUTATION (ML + Coverage + Fixes)
  // ---------------------------------------------------------------------------

  Future<double> _computeAccuracy01() async {
    final rb =
    _canvasKey.currentContext?.findRenderObject()
    as RenderBox?;
    if (rb == null) return 0.0;

    final size = rb.size;
    final ch = _activeChar;

    if (ch.isEmpty) return 0.0;

    await _ensureModel(ch);
    if (_ink == null) return 0.0;

    final ink = _inkFromStrokes(size);

    final ctx = di.DigitalInkRecognitionContext(
      writingArea: di.WritingArea(
          width: size.width, height: size.height),
    );

    List<di.RecognitionCandidate> cands = const [];
    try {
      cands = await _ink!.recognize(ink, context: ctx);
    } catch (_) {}

    double ml = _rankedScore01(cands, ch);

    final tmpl = await _renderTemplate(size, ch);
    final cov = await _coverage01(
        _strokes, tmpl, size);

    // ✅ Prevent scribble pass
    if (cov < 0.25) return 0.05;

    // ✅ Simple character fixes
    if (_simpleChars.contains(ch)) {
      if (cov >= 0.65) ml = math.max(ml, 0.60);
      if (cov >= 0.70 && ml < 0.50) ml = 0.60;
    }

    // ✅ Weighted final score
    double wML = 0.80;
    double wCov = 0.20;

    if (_simpleChars.contains(ch)) {
      wML = 0.60;
      wCov = 0.40;
    }

    return (wML * ml + wCov * cov).clamp(0.0, 1.0);
  }

  // ---------------------------------------------------------------------------
  // FINALIZE CHARACTER (record accuracy, time, difficulty stats)
  // ---------------------------------------------------------------------------

  Future<double> _finalizeCurrentChar() async {
    final acc = await _computeAccuracy01();

    // Overall metrics
    _sumAccuracy += acc;
    _charsCompleted += 1;

    final now = DateTime.now();
    if (_charStart != null) {
      _sumCharTime += now.difference(_charStart!);
    }
    _charStart = now;

    // Difficulty tracking
    final w = _currentWord;
    final c = _activeChar;

    _wordAccuracies[w] ??= [];
    _wordAccuracies[w]!.add(acc);

    if (acc < 0.70) {
      _charMistakeCount[c] = (_charMistakeCount[c] ?? 0) + 1;
      _wordMistakeCount[w] = (_wordMistakeCount[w] ?? 0) + 1;
    }

    return acc;
  }

  // ---------------------------------------------------------------------------
  // AUTO EVALUATION (auto-next engine)
  // ---------------------------------------------------------------------------

  void _scheduleEval() {
    if (!_autoNextEnabled) return;

    _evalDebounce?.cancel();
    _evalDebounce = Timer(const Duration(milliseconds: 260), () async {
      final score = await _finalizeCurrentChar();
      final pct = (score * 100).toStringAsFixed(0);

      await _speak("Accuracy: $pct percent.");
      await Future.delayed(const Duration(milliseconds: 80));

      if (score >= _autoNextThreshold) {
        await _speak("Next");
        HapticFeedback.selectionClick();
        _toNextChar(force: false);
      } else {
        await _speak("Write again.");
        _charsCompleted -= 1;
        _sumAccuracy -= score;
        _charStart = DateTime.now();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION — Next char / Next word / Finish poem
  // ---------------------------------------------------------------------------

  Future<void> _forceNext() async => _toNextChar(force: true);

  Future<void> _toNextChar({required bool force}) async {
    if (force) await _finalizeCurrentChar();

    // Not last char → go to next char
    if (!_isLastCharInWord) {
      setState(() => _charIndex++);
      _clearCanvas();

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _centerActiveLetter();
        await _speakCharOnly();
        _startCharTimer();
      });
      return;
    }

    // Last char → move to next word
    int next = _wordIndex + 1;
    while (next < _words.length &&
        _charsForWord(_words[next]).isEmpty) next++;

    if (next < _words.length) {
      setState(() {
        _wordIndex = next;
        _charIndex = 0;
        _rebuildRawIndices();
        _rebuildLetterKeys();
      });
      _clearCanvas();

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _centerActiveLetter();
        await _announceWordThenChar();
        _startCharTimer();
      });
      return;
    }

    // No more words → complete poem
    _finishPoemSummary();
  }

  // ---------------------------------------------------------------------------
  // POINTER HANDLING (strokes)
  // ---------------------------------------------------------------------------

  void _start(Offset p) {
    _current = [p];
    setState(() {});
  }

  void _move(Offset p) {
    if (_current.isEmpty) {
      _current = [p];
    } else {
      _current.add(p);
    }
    setState(() {});
  }

  void _end() {
    if (_current.isNotEmpty) {
      _strokes.add(List.of(_current));
      _current.clear();
      setState(() {});
      _scheduleEval();
    }
  }

  // ---------------------------------------------------------------------------
  // UI BUILD — Auto-Scaling Writing Area (Option B)
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_wordIndex >= _words.length) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.poem.title)),
        body: const Center(child: Text("No characters to practice.")),
      );
    }

    final practiced = _chars;
    if (practiced.isEmpty) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _toNextChar(force: true));
      return const SizedBox.shrink();
    }

    // Colors
    const bgColor = Color(0xFF0A0A3F);
    const wordColor = Color(0xFFF2F6FF);
    const activeColor = Color(0xFFFFD84D);

    // -------------------------
    // Top-level Scaffold
    // -------------------------
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: InkWell(
          onTap: () => _speak(widget.poem.title),
          child: Text(
            widget.poem.title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ),

      body: Column(
        children: [

          // ✅ Landscape button
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton(
              onPressed: _toggleForceLandscape,
              child: Text(
                forceLandscape
                    ? "Landscape Mode (ON)"
                    : "Landscape Mode (OFF)",
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          // -------------------------------------------------------------------
          // TOP WORD LABEL (tap to speak whole word)
          // -------------------------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: InkWell(
              onTap: () => _speak("You are writing: $_currentWord."),
              child: Text(
                _currentWord,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'KGPrimaryPenmanship',
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: wordColor,
                ),
              ),
            ),
          ),

          // -------------------------------------------------------------------
          // PROGRESS TEXT
          // -------------------------------------------------------------------
          Text(
            "Word ${_wordIndex + 1}/${_words.length} • "
                "Char ${_charIndex + 1}/${_chars.length}",
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 12),

          // -------------------------------------------------------------------
          // AUTO-SCALING WRITING AREA (OPTION B)
          // -------------------------------------------------------------------
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenH = constraints.maxHeight;

                // Estimate character height (based on available height)
                final estCharHeight =
                (screenH * 0.32).clamp(120.0, 260.0);

                // Auto-shift: dynamically move writing area upward
                final double autoShift = (estCharHeight * 0.55)
                    .clamp(40.0, screenH * 0.30);

                // Compute active/normal font sizes (matching the template row)
                final activeFs =
                (screenH * 0.28).clamp(90.0, 180.0);
                final normalFs =
                (activeFs * 0.60).clamp(50.0, activeFs - 10);

                TextStyle makeShadow(double fs, Color c) => TextStyle(
                  fontFamily: 'KGPrimaryPenmanship',
                  fontWeight: FontWeight.w900,
                  fontSize: fs,
                  color: c,
                  shadows: [
                    Shadow(
                        color: Colors.black.withOpacity(0.9),
                        blurRadius: 6),
                    Shadow(
                        color: Colors.black.withOpacity(0.9),
                        blurRadius: 6),
                  ],
                );

                final activeStyle = makeShadow(activeFs, activeColor);
                final normalStyle = makeShadow(normalFs, wordColor);

                // ---------------------------
                // The scrolling template row
                // ---------------------------
                Widget _wordRow() {
                  final w = _currentWord;
                  return SingleChildScrollView(
                    controller: _stripController,
                    physics: const NeverScrollableScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: _stripPadding,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(w.length, (i) {
                          final isActive = (i == _activeRawIndex);
                          return Padding(
                            key: _letterKeys[i],
                            padding: const EdgeInsets.symmetric(
                                horizontal: _gap / 2),
                            child: Text(
                              w[i],
                              style: isActive
                                  ? activeStyle
                                  : normalStyle,
                            ),
                          );
                        }),
                      ),
                    ),
                  );
                }

                // Recenter after layout changes
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _centerActiveLetter());

                // ---------------------------
                // AUTO-SCALED WRITING AREA
                // ---------------------------
                return Padding(
                  padding: EdgeInsets.only(top: autoShift),
                  child: GestureDetector(
                    onTap: () async {
                      await _centerActiveLetter();
                      await _announceWordThenChar();
                    },
                    onPanStart: (d) => _start(d.localPosition),
                    onPanUpdate: (d) => _move(d.localPosition),
                    onPanEnd: (_) => _end(),
                    onDoubleTap: _speakCharOnly,

                    child: Stack(
                      children: [
                        // Word display row
                        Positioned.fill(
                          child: Align(
                            alignment: Alignment.center,
                            child: _wordRow(),
                          ),
                        ),

                        // Template canvas
                        Positioned.fill(
                          child: RepaintBoundary(
                            key: _canvasKey,
                            child: const SizedBox.expand(),
                          ),
                        ),

                        // User strokes
                        Positioned.fill(
                          child: CustomPaint(
                            painter: StrokePainter(
                              _strokes,
                              _current,
                              strokeColor: Colors.white,
                              strokeWidth: _strokeWidth,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // -------------------------------------------------------------------
          // BOTTOM BUTTON BAR
          // -------------------------------------------------------------------
          SafeArea(
            top: false,
            child: Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  _BigIconButton(
                    icon: Icons.record_voice_over,
                    semanticLabel: "Speak",
                    onPressed: _speakCharOnly,
                  ),
                  _BigIconButton(
                    icon: Icons.cleaning_services,
                    semanticLabel: "Clear",
                    onPressed: _clearCanvas,
                  ),
                  _BigIconButton(
                    icon: Icons.arrow_forward,
                    semanticLabel: "Next",
                    onPressed: () => _forceNext(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  // ---------------------------------------------------------------------------
  // FINAL SUMMARY (Dialog + TTS + Difficulty)
  // ---------------------------------------------------------------------------

  void _finishPoemSummary() async {
    final totalTime = DateTime.now().difference(_sessionStart);

    final overallAcc = (_charsCompleted == 0)
        ? 0.0
        : (_sumAccuracy / _charsCompleted).clamp(0.0, 1.0);

    final avgCharTime = (_charsCompleted == 0)
        ? Duration.zero
        : Duration(
      milliseconds:
      (_sumCharTime.inMilliseconds / _charsCompleted).round(),
    );

    final difficultWords = _computeDifficultWords();

    // Build TTS summary
    String speakSummary =
        "Completed. Overall accuracy ${(overallAcc * 100).toStringAsFixed(0)} percent. "
        "Average time per character ${_fmtTimeShort(avgCharTime)}. "
        "Total time ${_fmtTimeShort(totalTime)}. ";

    if (difficultWords.isNotEmpty) {
      speakSummary +=
      "Words needing improvement include: ${difficultWords.join(", ")}.";
    }

    await _speak(speakSummary);

    if (!mounted) return;

    // UI dialog summary
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text(
            "Poem Summary",
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Overall accuracy: ${(overallAcc * 100).toStringAsFixed(0)}%",
              ),
              Text(
                "Average time per character: ${_fmtTimeShort(avgCharTime)}",
              ),
              Text(
                "Total time: ${_fmtTimeShort(totalTime)}",
              ),
              if (difficultWords.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  "Difficult Words:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                for (final w in difficultWords)
                  Text("• $w", style: const TextStyle(fontSize: 16)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.popUntil(context, (r) => r.isFirst),
              child: const Text("Close"),
            )
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // DIFFICULT WORD COMPUTATION (Option‑C logic)
  // ---------------------------------------------------------------------------

  List<String> _computeDifficultWords() {
    final scores = <String, double>{};

    for (final w in _words) {
      final mistakes = _wordMistakeCount[w] ?? 0;
      final accList = _wordAccuracies[w] ?? [];

      final avgAcc = accList.isEmpty
          ? 1.0
          : accList.reduce((a, b) => a + b) / accList.length;

      // Weighted difficulty score
      final difficulty = mistakes * 1.0 + (1.0 - avgAcc) * 2.0;

      if (difficulty > 0.3) {
        scores[w] = difficulty;
      }
    }

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.map((e) => e.key).take(3).toList();
  }
}

// ============================================================================
// LARGE ICON BUTTON (bottom toolbar buttons)
// ============================================================================

class _BigIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String semanticLabel;

  const _BigIconButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              minimumSize: const Size.fromHeight(64),
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
            ),
            onPressed: onPressed,
            child: Icon(icon, size: 42),
          ),
        ),
      ),
    );
  }
}
