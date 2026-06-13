import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Displays an SVG chart using native Android rendering via PlatformView.
/// This bypasses Flutter's image compositor for 1:1 pixel mapping.
class NativeSvgChartView extends StatefulWidget {
  final String svgString;
  final double width;
  final double height;

  /// Accessibility label set on the native ImageView's `contentDescription`
  /// (surfaces to TalkBack / UiAutomator2 as `content-desc`). A Flutter
  /// `Semantics` wrapper cannot reach this hybrid-composition PlatformView, so
  /// the label must travel natively. See SvgChartPlatformView.kt.
  final String? a11yLabel;

  const NativeSvgChartView({
    super.key,
    required this.svgString,
    required this.width,
    required this.height,
    this.a11yLabel,
  });

  @override
  State<NativeSvgChartView> createState() => _NativeSvgChartViewState();
}

class _NativeSvgChartViewState extends State<NativeSvgChartView> {
  MethodChannel? _channel;
  int? _viewId;
  String? _lastRenderedSvg;

  @override
  Widget build(BuildContext context) {
    // Only supported on Android
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }

    return AndroidView(
      viewType: 'svg_chart_view',
      creationParams: {
        'svg': widget.svgString,
        'width': widget.width.round(),
        'height': widget.height.round(),
        'a11yLabel': widget.a11yLabel,
      },
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _onPlatformViewCreated,
      gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
    );
  }

  void _onPlatformViewCreated(int viewId) {
    _viewId = viewId;
    _channel = MethodChannel('org.bortnik.svg_chart_view_$viewId');

    // If SVG changed while view was being created, render the latest version
    if (_lastRenderedSvg != null && _lastRenderedSvg != widget.svgString) {
      _channel!.invokeMethod('renderSvg', {
        'svg': widget.svgString,
        'width': widget.width.round(),
        'height': widget.height.round(),
      });
    }
    _lastRenderedSvg = widget.svgString;
  }

  @override
  void didUpdateWidget(NativeSvgChartView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Re-render if SVG or dimensions changed
    if (oldWidget.svgString != widget.svgString ||
        oldWidget.width != widget.width ||
        oldWidget.height != widget.height) {
      _lastRenderedSvg = widget.svgString;
      if (_viewId != null && _channel != null) {
        _channel!.invokeMethod('renderSvg', {
          'svg': widget.svgString,
          'width': widget.width.round(),
          'height': widget.height.round(),
        });
      }
      // If view not ready yet, it will render the latest SVG when created
    }
  }
}
