import 'package:flutter/material.dart';
import 'package:image_picker_with_draggable/print.dart';
import 'package:image_picker_with_draggable/utils/const.dart';

class DraggableSheet extends StatefulWidget {
  const DraggableSheet({
    super.key,
    required this.height,
    required this.hideBottomSheet,
    this.maxHeight,
    required this.builder,
  });
  final double? maxHeight;
  final double height;
  final VoidCallback hideBottomSheet;
  final Function(ScrollController) builder;

  @override
  State<DraggableSheet> createState() => _DraggableSheetState();
}

class _DraggableSheetState extends State<DraggableSheet> {
  double? height;
  late double minHeight;
  late double maxHeight;
  late DraggableScrollableController _draggableController;

  @override
  void initState() {
    super.initState();
    minHeight = widget.height;
    _draggableController = DraggableScrollableController();
  }

  @override
  Widget build(BuildContext context) {
    maxHeight = widget.maxHeight ?? MediaQuery.sizeOf(context).height * 0.9;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final minChildSize = maxHeightKeyboard / screenHeight;
    return DraggableScrollableSheet(
      // height: height ?? minHeight,
      controller: _draggableController,
      initialChildSize: 1,
      minChildSize: minChildSize,
      builder: (context, scrollController) {
        return Material(
          elevation: 8,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Container(
            color: Colors.white,
            child: Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanUpdate: (details) {
                    print('onPanUpdate: ${details.delta.dy}');
                    // Tính toán hướng kéo và điều chỉnh kích thước sheet
                    const sensitivity =
                        0.002; //  Độ nhạy của thao tác kéo. Giảm sensitivity để kéo mượt hơn. Giá trị nhỏ hơn khiến người dùng phải kéo xa hơn để đạt hiệu ứng tương tự
                    final deltaY = details.delta.dy;
                    final currentSize =
                        _draggableController
                            .size; //Lấy kích thước hiện tại của sheet (tỉ lệ so với chiều cao màn hình)
                    final newSize = (currentSize - (deltaY * sensitivity))
                        .clamp(minChildSize, 1.0); //0.45
                    print('newSize: $newSize');
                    // Sử dụng jumpTo thay vì animateTo để responsive hơn
                    _draggableController.jumpTo(newSize);
                    /////////tran thanh trà
                    // height ??= minHeight;
                    // Nếu đang ở minHeight và người dùng vuốt xuống
                    // if ((height == minHeight || height! <= minHeight + 1) &&
                    //     details.delta.dy > 0) {
                    //   luon(
                    //     '👋 Vuốt xuống khi đang ở minHeight',
                    //     print: true,
                    //   ); //ko dô đây
                    //   widget.hideBottomSheet();
                    // }
                    // final newHeight = (height! - details.delta.dy).clamp(
                    //   minHeight,
                    //   maxHeight,
                    // );
                    // luon(
                    //   'onPanUpdate:newHeight: $newHeight, minHeight: $minHeight, maxHeight: $maxHeight, details.delta.dy: ${details.delta.dy}',
                    //   print: true,
                    // );
                    // setState(() {
                    //   height = newHeight;
                    // });
                  },
                  onPanEnd: (details) {
                    final currentHeight = height ?? minHeight;
                    final velocity = details.velocity.pixelsPerSecond.dy;

                    // Logic tự mở rộng/thu nhỏ:
                    // Vuốt lên (velocity âm) hoặc đã kéo lên kha khá thì mở rộng
                    // Vuốt xuống (velocity dương) hoặc đã kéo xuống thì thu nhỏ
                    final bool shouldExpand =
                        velocity < -200 ||
                        currentHeight >
                            (minHeight + (maxHeight - minHeight) * 0.2);
                    final bool shouldCollapse =
                        velocity > 200 ||
                        currentHeight <=
                            (minHeight + (maxHeight - minHeight) * 0.2);
                    luon(
                      'pnPanEnd:shouldExpand: $shouldExpand, shouldCollapse: $shouldCollapse, velocity: $velocity, currentHeight: $currentHeight, minHeight: $minHeight, maxHeight: $maxHeight',
                      print: true,
                    );

                    setState(() {
                      // height = shouldExpand ? maxHeight : 700;
                      height = shouldExpand ? maxHeight : minHeight;
                    });
                  },
                  child: Container(
                    //header bar để kéo - vùng có thể chạm để kéo sheet
                    height: 30,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: Container(
                        height: 4,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[600],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(child: widget.builder(scrollController)),
              ],
            ),
          ),
        );
      },
    );
  }
}
