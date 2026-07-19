import 'package:flutter_test/flutter_test.dart';
import 'package:taplingo/utils/js_injection.dart';

void main() {
  group('JsInjection Scripts', () {
    test('scrollToY generates valid script for position 0', () {
      final js = JsInjection.scrollToY(0);
      expect(js.contains('window.scrollTo({ top: 0.0,'), isTrue);
    });

    test('scrollToY generates valid script for position 1050.5', () {
      final js = JsInjection.scrollToY(1050.5);
      expect(js.contains('window.scrollTo({ top: 1050.5,'), isTrue);
    });

    test('scrollWithImageWait injects TARGET properly', () {
      final js = JsInjection.scrollWithImageWait(9999);
      expect(js.contains('const TARGET = 9999.0;'), isTrue);
    });

    test('getScrollY logic is stable', () {
      final js = JsInjection.getScrollY;
      expect(js.contains('window.scrollY'), isTrue);
      expect(js.contains('document.documentElement.scrollTop'), isTrue);
      expect(js.contains('window.__tlgScrollResolver'), isTrue);
    });
  });
}
