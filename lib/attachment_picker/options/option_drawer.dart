import 'package:flutter/material.dart';
import 'package:image_picker_with_draggable/common/empty_widget.dart';

const _kDefaultOptionDrawerShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.only(
    topLeft: Radius.circular(16),
    topRight: Radius.circular(16),
  ),
);

/// A widget that will be shown in the attachment picker.
/// It can be used to show a custom view for each attachment picker option.
class OptionDrawer extends StatelessWidget {
  /// Creates a widget that will be shown in the attachment picker.
  const OptionDrawer({
    super.key,
    required this.child,
    this.color,
    this.elevation = 2,
    this.margin = EdgeInsets.zero,
    this.clipBehavior = Clip.hardEdge,
    this.shape = _kDefaultOptionDrawerShape,
    this.title,
    this.actions = const [],
  });

  /// The widget below this widget in the tree.
  final Widget child;

  /// The background color of the options card.
  ///
  /// Defaults to [StreamColorTheme.barsBg].
  final Color? color;

  /// The elevation of the options card.
  ///
  /// The default value is 2.
  final double elevation;

  /// The margin of the options card.
  ///
  /// The default value is [EdgeInsets.zero].
  final EdgeInsetsGeometry margin;

  /// The clip behavior of the options card.
  ///
  /// The default value is [Clip.hardEdge].
  final Clip clipBehavior;

  /// The shape of the options card.
  final ShapeBorder shape;

  /// The title of the options card.
  final Widget? title;

  /// The actions available for the options card.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    var height = 20.0;
    if (title != null || actions.isNotEmpty) {
      height = 40.0;
    }

    final leading = title ?? const Empty();

    Widget trailing;
    if (actions.isNotEmpty) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: actions,
      );
    } else {
      trailing = const Empty();
    }

    return Card(
      elevation: elevation,
      color: color ?? Colors.blue,
      margin: margin,
      shape: shape,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // SizedBox(
          //   height: height,
          //   child: Row(
          //     children: [
          //       Expanded(child: leading),
          //       Container(
          //         height: 4,
          //         width: 40,
          //         decoration: BoxDecoration(
          //           color: Colors.grey,
          //           borderRadius: BorderRadius.circular(6),
          //         ),
          //       ),
          //       Expanded(child: trailing),
          //     ],
          //   ),
          // ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
