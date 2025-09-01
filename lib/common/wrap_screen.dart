import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker_with_draggable/print.dart';

class ScreenWrap extends StatefulWidget {
  final Widget child;
  final double? width;
  const ScreenWrap({super.key, required this.child, this.width});

  @override
  State<ScreenWrap> createState() => _ScreenWrapState();
}

class _ScreenWrapState extends State<ScreenWrap> {
  bool expand = true;
  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return widget.child;
    }
    return Stack(
      children: [
        widget.child,
        SizedBox(
          width: widget.width,
          child: SafeArea(
            child: GestureDetector(
              onLongPress: () {
                resetLuong();
              },
              onTap: () {
                setState(() {
                  expand = !expand;
                });
              },
              child: SingleChildScrollView(
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: StreamBuilder<String>(
                      stream: luongStream.stream,
                      builder: (context, snapshot) {
                        if (!expand) {
                          return const Text('Tap vào đây để hiện\n\n luồng');
                        }
                        return Text(snapshot.data ?? 'No data',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ));
                      }),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
