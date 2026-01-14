import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meteogram_widget/services/native_svg_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NativeSvgRenderer', () {
    const channel = MethodChannel('org.bortnik.meteogram/svg');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('calls renderSvg with correct arguments', () async {
      String? capturedMethod;
      Map<dynamic, dynamic>? capturedArgs;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        capturedMethod = methodCall.method;
        capturedArgs = methodCall.arguments as Map<dynamic, dynamic>;
        return Uint8List.fromList([1, 2, 3, 4]);
      });

      await NativeSvgRenderer.renderSvgToPng(
        svgString: '<svg></svg>',
        width: 800,
        height: 400,
      );

      expect(capturedMethod, 'renderSvg');
      expect(capturedArgs?['svg'], '<svg></svg>');
      expect(capturedArgs?['width'], 800);
      expect(capturedArgs?['height'], 400);
    });

    test('returns PNG bytes on success', () async {
      final expectedBytes = Uint8List.fromList([137, 80, 78, 71]); // PNG magic

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return expectedBytes;
      });

      final result = await NativeSvgRenderer.renderSvgToPng(
        svgString: '<svg></svg>',
        width: 100,
        height: 100,
      );

      expect(result, expectedBytes);
    });

    test('returns null on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(code: 'ERROR', message: 'Render failed');
      });

      final result = await NativeSvgRenderer.renderSvgToPng(
        svgString: '<svg></svg>',
        width: 100,
        height: 100,
      );

      expect(result, isNull);
    });

    test('returns null when native returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return null;
      });

      final result = await NativeSvgRenderer.renderSvgToPng(
        svgString: '<svg></svg>',
        width: 100,
        height: 100,
      );

      expect(result, isNull);
    });

    test('handles large SVG strings', () async {
      final largeSvg = '<svg>${'<rect/>' * 1000}</svg>';

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        final args = methodCall.arguments as Map<dynamic, dynamic>;
        expect((args['svg'] as String).length, greaterThan(5000));
        return Uint8List.fromList([1, 2, 3]);
      });

      final result = await NativeSvgRenderer.renderSvgToPng(
        svgString: largeSvg,
        width: 1000,
        height: 500,
      );

      expect(result, isNotNull);
    });

    test('handles various dimensions', () async {
      final testCases = [
        (width: 1, height: 1),
        (width: 100, height: 50),
        (width: 1920, height: 1080),
        (width: 4000, height: 2000),
      ];

      for (final testCase in testCases) {
        int? capturedWidth;
        int? capturedHeight;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          final args = methodCall.arguments as Map<dynamic, dynamic>;
          capturedWidth = args['width'] as int;
          capturedHeight = args['height'] as int;
          return Uint8List.fromList([0]);
        });

        await NativeSvgRenderer.renderSvgToPng(
          svgString: '<svg></svg>',
          width: testCase.width,
          height: testCase.height,
        );

        expect(capturedWidth, testCase.width,
            reason: 'Width ${testCase.width} should be passed correctly');
        expect(capturedHeight, testCase.height,
            reason: 'Height ${testCase.height} should be passed correctly');
      }
    });
  });
}
