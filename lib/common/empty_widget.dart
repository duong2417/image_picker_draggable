import 'package:flutter/material.dart';

class Empty extends StatelessWidget {
  /// Creates a widget that renders nothing and takes up no space.
  const Empty({super.key, this.t});
  final String? t;

  @override
  Widget build(BuildContext context) =>
      t != null ? Text(t!) : const SizedBox.shrink();
}
