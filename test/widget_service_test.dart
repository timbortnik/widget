import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meteogram_widget/services/widget_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('org.bortnik.meteogram/svg');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('WidgetService.isBackgroundRestricted', () {
    void answer(Object? Function(MethodCall call) handler) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'isWidgetBackgroundRestricted');
        return handler(call);
      });
    }

    test('passes the native answer through', () async {
      answer((_) => true);
      expect(await WidgetService().isBackgroundRestricted(), isTrue);

      answer((_) => false);
      expect(await WidgetService().isBackgroundRestricted(), isFalse);
    });

    test('is false when the native side returns nothing', () async {
      answer((_) => null);
      expect(await WidgetService().isBackgroundRestricted(), isFalse);
    });

    test('is false when the native call fails', () async {
      answer((_) => throw PlatformException(code: 'ERROR'));
      expect(await WidgetService().isBackgroundRestricted(), isFalse);
    });

    test('is false without a native implementation', () async {
      expect(await WidgetService().isBackgroundRestricted(), isFalse);
    });
  });
}
