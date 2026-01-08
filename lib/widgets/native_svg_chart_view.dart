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

  const NativeSvgChartView({
    super.key,
    required this.svgString,
    required this.width,
    required this.height,
  });

  @override
  State<NativeSvgChartView> createState() => _NativeSvgChartViewState();
}

class _NativeSvgChartViewState extends State<NativeSvgChartView> {
  MethodChannel? _channel;
  int? _viewId;

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
      },
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _onPlatformViewCreated,
      gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
    );
  }

  void _onPlatformViewCreated(int viewId) {
    _viewId = viewId;
    _channel = MethodChannel('org.bortnik.svg_chart_view_$viewId');
  }

  @override
  void didUpdateWidget(NativeSvgChartView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Re-render if SVG or dimensions changed
    if (_viewId != null &&
        _channel != null &&
        (oldWidget.svgString != widget.svgString ||
            oldWidget.width != widget.width ||
            oldWidget.height != widget.height)) {
      _channel!.invokeMethod('renderSvg', {
        'svg': widget.svgString,
        'width': widget.width.round(),
        'height': widget.height.round(),
      });
    }
  }
}
