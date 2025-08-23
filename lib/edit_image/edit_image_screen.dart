import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker_with_draggable/common/buttons/back_button.dart';
import 'package:image_picker_with_draggable/handler/attachment_handler.dart';

//https://www.youtube.com/watch?v=eULOiaHqfCU
class DrawingPoint {
  int id;
  List<Offset> offsets;
  Color color;
  double width;

  DrawingPoint({
    this.id = -1,
    this.offsets = const [],
    this.color = Colors.black,
    this.width = 2,
  });

  DrawingPoint copyWith({List<Offset>? offsets}) {
    return DrawingPoint(
      id: id,
      color: color,
      width: width,
      offsets: offsets ?? this.offsets,
    );
  }
}

// ignore: must_be_immutable
class DrawingRoomScreen extends StatefulWidget {
  DrawingRoomScreen({
    required this.filePath,
    // this.imageBytes,
    super.key,
    // required this.onDone,
    required this.onEditDone,
    this.pixelRatio,
    this.isHD = false,
    this.textSubmit = 'Xong',
  });
  final Function(String) onEditDone;
  String filePath;
  double? pixelRatio;
  bool isHD;
  String textSubmit;
  // Uint8List? imageBytes;
  @override
  State<DrawingRoomScreen> createState() => _DrawingRoomScreenState();
}

class _DrawingRoomScreenState extends State<DrawingRoomScreen> {
  var avaiableColor = [
    Colors.black,
    Colors.red,
    Colors.orange,
    Colors.amber,
    Colors.blue,
    Colors.green,
    Colors.purple,
    Colors.brown,
    Colors.white,
  ];

  var historyDrawingPoints = <DrawingPoint>[];
  var drawingPoints = <DrawingPoint>[];

  var selectedColor = Colors.black;
  var selectedWidth = 2.0;

  DrawingPoint? currentDrawingPoint;
  final editImg = AttachmentHandler.instance;
  GlobalKey globalKey = GlobalKey();

  // Kiểm tra nền ảnh sáng hay tối để hiển thị UI phù hợp
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;

  // Kiểm soát hiển thị của các công cụ
  bool _showControls = true;
  // late AnimationController _animationController;
  // late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Khởi tạo animation controller cho hiệu ứng fade
    // _animationController = AnimationController(
    //   vsync: this,
    //   duration: const Duration(milliseconds: 200),
    // );
    // _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
    //   CurvedAnimation(
    //     parent: _animationController,
    //     curve: Curves.easeInOut,
    //   ),
    // );

    // _animationController.value = 1.0; // Hiển thị công cụ lúc khởi đầu
  }

  @override
  void dispose() {
    // _animationController.dispose();
    super.dispose();
  }

  // Hàm chuyển đổi hiển thị công cụ
  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      // if (_showControls) {
      //   _animationController.forward();
      // } else {
      //   _animationController.reverse();
      // }
    });
  }

  // Hàm ẩn công cụ khi bắt đầu vẽ
  void _hideControls() {
    if (_showControls) {
      setState(() {
        _showControls = false;
        // _animationController.reverse();
      });
    }
  }

  // Hàm hiện công cụ khi ngừng vẽ
  void _showControlsDelayed() {
    if (!_showControls) {
      // Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _showControls = true;
          // _animationController.forward();
        });
      }
      // });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final safeArea = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true, // Cho phép body kéo lên phía sau AppBar
      appBar:
          _showControls
              ? PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight),
                child: AppBar(
                  leading: const MyBackButton(color: Colors.white),
                  //rm FadeTransition
                  backgroundColor: Colors.black.withOpacity(0.5),
                  elevation: 0,
                  title: const Text(
                    'Chỉnh ảnh',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  actions: [
                    // Nút Hoàn thành
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: TextButton.icon(
                        onPressed: () async {
                          final path = await editImg.captureWidget(
                            context,
                            globalKey: globalKey,
                            pixelRatio:
                                widget.isHD ? 2 : widget.pixelRatio ?? 0.7,
                          );
                          widget.onEditDone(path);
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(widget.textSubmit),
                      ),
                    ),
                  ],
                ),
              )
              : null,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Ảnh nền full screen
          GestureDetector(
            // onTap: _toggleControls, // Ẩn/hiện công cụ khi tap vào màn hình
            onPanStart: (details) {
              _hideControls(); // Ẩn công cụ khi bắt đầu vẽ
              setState(() {
                currentDrawingPoint = DrawingPoint(
                  id: DateTime.now().microsecondsSinceEpoch,
                  offsets: [details.localPosition],
                  color: selectedColor,
                  width: selectedWidth,
                );

                if (currentDrawingPoint == null) return;
                drawingPoints.add(currentDrawingPoint!);
                historyDrawingPoints = List.of(drawingPoints);
              });
            },
            onPanUpdate: (details) {
              setState(() {
                if (currentDrawingPoint == null) return;

                currentDrawingPoint = currentDrawingPoint?.copyWith(
                  offsets:
                      currentDrawingPoint!.offsets..add(details.localPosition),
                );
                drawingPoints.last = currentDrawingPoint!;
                historyDrawingPoints = List.of(drawingPoints);
              });
            },
            onPanEnd: (_) {
              currentDrawingPoint = null;
              _showControlsDelayed(); // Hiện công cụ sau khi thả tay
            },
            child: RepaintBoundary(
              key: globalKey,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Hình ảnh
                  Container(
                    width: screenSize.width,
                    height: screenSize.height,
                    color: Colors.black,
                    child:
                    //  widget.imageBytes != null
                    //     ? Image.memory(
                    //         widget.imageBytes!,
                    //         fit: BoxFit.contain,
                    //       )
                    //     :
                    Image.file(File(widget.filePath), fit: BoxFit.contain),
                  ),

                  // Layer vẽ
                  CustomPaint(
                    painter: DrawingPainter(drawingPoints: drawingPoints),
                    child: SizedBox(
                      width: screenSize.width,
                      height: screenSize.height,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showControls)
            // Panel điều khiển phía dưới
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                //rm FadeTransition
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Thanh màu sắc
                    SizedBox(
                      height: 50,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: avaiableColor.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedColor = avaiableColor[index];
                              });
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: avaiableColor[index],
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      avaiableColor[index] == Colors.white
                                          ? Colors.grey.withOpacity(0.5)
                                          : Colors.transparent,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              foregroundDecoration: BoxDecoration(
                                border:
                                    selectedColor == avaiableColor[index]
                                        ? Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        )
                                        : null,
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Thanh điều chỉnh độ rộng bút
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.line_weight,
                            size: 20,
                            color: Colors.white,
                          ),
                          Expanded(
                            child: Slider(
                              value: selectedWidth,
                              min: 1,
                              max: 20,
                              activeColor: selectedColor,
                              inactiveColor: Colors.grey.withOpacity(0.3),
                              label: '${selectedWidth.toInt()}',
                              divisions: 19,
                              onChanged: (value) {
                                setState(() {
                                  selectedWidth = value;
                                });
                              },
                            ),
                          ),
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selectedColor,
                            ),
                            child: Center(
                              child: Container(
                                width: selectedWidth,
                                height: selectedWidth,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // const SizedBox(height: 16),

                    // // Hàng các nút chức năng
                    // Row(
                    //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    //   children: [
                    //     _buildActionButton(
                    //       icon: Icons.crop,
                    //       label: 'Cắt',
                    //       onTap: () async {
                    //         final file = await editImg.cropImage(
                    //             context, widget.filePath);
                    //         if (file != null) {
                    //           setState(() {
                    //             widget.filePath = file.path;
                    //           });
                    //         }
                    //       },
                    //       color: Colors.green,
                    //     ),
                    //     _buildActionButton(
                    //       icon: Icons.undo,
                    //       label: 'Hoàn tác',
                    //       onTap: () {
                    //         if (drawingPoints.isNotEmpty &&
                    //             historyDrawingPoints.isNotEmpty) {
                    //           setState(() {
                    //             drawingPoints.removeLast();
                    //           });
                    //         }
                    //       },
                    //       color: Colors.blue,
                    //     ),
                    //     _buildActionButton(
                    //       icon: Icons.redo,
                    //       label: 'Làm lại',
                    //       onTap: () {
                    //         setState(() {
                    //           if (drawingPoints.length <
                    //               historyDrawingPoints.length) {
                    //             final index = drawingPoints.length;
                    //             drawingPoints.add(historyDrawingPoints[index]);
                    //           }
                    //         });
                    //       },
                    //       color: Colors.orange,
                    //     ),
                    //     _buildActionButton(
                    //       icon: Icons.clear,
                    //       label: 'Xóa hết',
                    //       onTap: () {
                    //         setState(() {
                    //           drawingPoints.clear();
                    //           historyDrawingPoints.clear();
                    //         });
                    //       },
                    //       color: Colors.red,
                    //     ),
                    //   ],
                    // ),
                    // An toàn cho các thiết bị có notch
                    SizedBox(height: MediaQuery.of(context).padding.bottom),
                  ],
                ),
              ),
            ),

          // Panel điều khiển phía bên phải
          if (_showControls)
            Positioned(
              top: kToolbarHeight + safeArea.top + 8,
              right: 8,
              child: Container(
                //rm FadeTransition
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // IconButton(
                    //   onPressed: () async {
                    //     // final file =
                    //     //     await editImg.cropImage(context, widget.filePath);
                    //     // if (file != null) {
                    //     //   setState(() {
                    //     //     widget.filePath = file.path;
                    //     //   });
                    //     // }
                    //   },
                    //   icon: const Icon(Icons.crop, color: Colors.white),
                    //   tooltip: 'Cắt ảnh',
                    // ),
                    IconButton(
                      onPressed: () {
                        if (drawingPoints.isNotEmpty &&
                            historyDrawingPoints.isNotEmpty) {
                          setState(() {
                            drawingPoints.removeLast();
                          });
                        }
                      },
                      icon: const Icon(Icons.undo, color: Colors.white),
                      tooltip: 'Hoàn tác',
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          if (drawingPoints.length <
                              historyDrawingPoints.length) {
                            final index = drawingPoints.length;
                            drawingPoints.add(historyDrawingPoints[index]);
                          }
                        });
                      },
                      icon: const Icon(Icons.redo, color: Colors.white),
                      tooltip: 'Làm lại',
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          drawingPoints.clear();
                          historyDrawingPoints.clear();
                        });
                      },
                      icon: const Icon(Icons.clear, color: Colors.white),
                      tooltip: 'Xóa hết',
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPoint> drawingPoints;

  DrawingPainter({required this.drawingPoints});

  @override
  void paint(Canvas canvas, Size size) {
    for (var drawingPoint in drawingPoints) {
      final paint =
          Paint()
            ..color = drawingPoint.color
            ..isAntiAlias = true
            ..strokeWidth = drawingPoint.width
            ..strokeCap = StrokeCap.round;

      for (var i = 0; i < drawingPoint.offsets.length; i++) {
        var notLastOffset = i != drawingPoint.offsets.length - 1;

        if (notLastOffset) {
          final current = drawingPoint.offsets[i];
          final next = drawingPoint.offsets[i + 1];
          canvas.drawLine(current, next, paint);
        } else {
          /// we do nothing
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
