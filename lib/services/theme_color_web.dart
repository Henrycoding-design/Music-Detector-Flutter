import 'package:web/web.dart' as web;

void setBrowserThemeColor(bool isDark) {
  final color = isDark ? '#0F172A' : '#F8FAFC';
  web.document
      .querySelector('meta[name="theme-color"]')
      ?.setAttribute('content', color);
}