import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meteogram_widget/services/native_svg_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NativeSvgService', () {
    const channel = MethodChannel('org.bortnik.meteogram/svg');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    group('generateSvg', () {
      test('calls generateSvg with correct arguments', () async {
        String? capturedMethod;
        Map<dynamic, dynamic>? capturedArgs;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          capturedMethod = methodCall.method;
          capturedArgs = methodCall.arguments as Map<dynamic, dynamic>;
          return '<svg>test</svg>';
        });

        await NativeSvgService.generateSvg(
          width: 1000,
          height: 500,
          isLight: true,
          usesFahrenheit: false,
        );

        expect(capturedMethod, 'generateSvg');
        expect(capturedArgs?['width'], 1000);
        expect(capturedArgs?['height'], 500);
        expect(capturedArgs?['isLight'], true);
        expect(capturedArgs?['usesFahrenheit'], false);
      });

      test('passes isLight=false for dark theme', () async {
        Map<dynamic, dynamic>? capturedArgs;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          capturedArgs = methodCall.arguments as Map<dynamic, dynamic>;
          return '<svg>dark</svg>';
        });

        await NativeSvgService.generateSvg(
          width: 800,
          height: 400,
          isLight: false,
          usesFahrenheit: true,
        );

        expect(capturedArgs?['isLight'], false);
        expect(capturedArgs?['usesFahrenheit'], true);
      });

      test('returns SVG string on success', () async {
        const expectedSvg = '<svg><rect fill="red"/></svg>';

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return expectedSvg;
        });

        final result = await NativeSvgService.generateSvg(
          width: 100,
          height: 100,
          isLight: true,
          usesFahrenheit: false,
        );

        expect(result, expectedSvg);
      });

      test('returns null on PlatformException', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          throw PlatformException(code: 'NO_DATA', message: 'No weather data');
        });

        final result = await NativeSvgService.generateSvg(
          width: 100,
          height: 100,
          isLight: true,
          usesFahrenheit: false,
        );

        expect(result, isNull);
      });

      test('returns null when native returns null', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return null;
        });

        final result = await NativeSvgService.generateSvg(
          width: 100,
          height: 100,
          isLight: true,
          usesFahrenheit: false,
        );

        expect(result, isNull);
      });
    });

    group('generateSvgPair', () {
      test('generates both light and dark SVGs', () async {
        final calls = <Map<dynamic, dynamic>>[];

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          final args = methodCall.arguments as Map<dynamic, dynamic>;
          calls.add(args);
          final isLight = args['isLight'] as bool;
          return isLight ? '<svg>light</svg>' : '<svg>dark</svg>';
        });

        final result = await NativeSvgService.generateSvgPair(
          width: 1000,
          height: 500,
          usesFahrenheit: false,
        );

        expect(calls.length, 2);
        expect(calls[0]['isLight'], true);
        expect(calls[1]['isLight'], false);
        expect(result.light, '<svg>light</svg>');
        expect(result.dark, '<svg>dark</svg>');
      });

      test('returns nulls when generation fails', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          throw PlatformException(code: 'ERROR', message: 'Failed');
        });

        final result = await NativeSvgService.generateSvgPair(
          width: 100,
          height: 100,
          usesFahrenheit: false,
        );

        expect(result.light, isNull);
        expect(result.dark, isNull);
      });

      test('passes usesFahrenheit correctly', () async {
        final capturedUsesFahrenheit = <bool>[];

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          final args = methodCall.arguments as Map<dynamic, dynamic>;
          capturedUsesFahrenheit.add(args['usesFahrenheit'] as bool);
          return '<svg></svg>';
        });

        await NativeSvgService.generateSvgPair(
          width: 100,
          height: 100,
          usesFahrenheit: true,
        );

        expect(capturedUsesFahrenheit, [true, true]);
      });
    });
  });
}
