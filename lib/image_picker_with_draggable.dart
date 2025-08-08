// import 'package:flutter/material.dart';
// import 'package:image_picker_with_draggable/attachment_picker/attachment_picker_controller.dart';
// import 'package:image_picker_with_draggable/attachment_picker/options/gallery_picker.dart';

// import 'const.dart';
// import 'models/attachment_picker.dart';

// class ImagePickerBottomsheet extends StatefulWidget {
//   final double height;
//   // final AttachmentPickerController controller;
//   const ImagePickerBottomsheet({
//     super.key,
//     required this.height,
//     // required this.controller,
//   });

//   @override
//   State<ImagePickerBottomsheet> createState() => _ImagePickerBottomsheetState();
// }

// class _ImagePickerBottomsheetState extends State<ImagePickerBottomsheet> {
//   late DraggableScrollableController _draggableController;
//   double? height;
//   late final AttachmentPickerController _controller;
//   @override
//   void initState() {
//     super.initState();
//     _draggableController = DraggableScrollableController();
//     _controller = AttachmentPickerController();
//   }

//   @override
//   void dispose() {
//     _draggableController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final screenHeight = MediaQuery.sizeOf(context).height;
//     final minChildSize = maxHeightKeyboard / screenHeight;
//     final initChildSize = widget.height / screenHeight;
//     return Container(
//       color: Colors.blue,
//       height: height ?? widget.height,
//       child: DraggableScrollableSheet(
//         controller: _draggableController,
//         initialChildSize: 1,
//         minChildSize: minChildSize,
//         builder: (context, scrollController) {
//           return ValueListenableBuilder<AttachmentPickerValue>(
//             valueListenable: _controller,
//             builder: (context, atms, _) {
//               return Material(
//                 elevation: 8,
//                 borderRadius: const BorderRadius.vertical(
//                   top: Radius.circular(16),
//                 ),
//                 child: Container(
//                   decoration: BoxDecoration(
//                     color: Colors.grey,
//                     borderRadius: const BorderRadius.vertical(
//                       top: Radius.circular(16),
//                     ),
//                   ),
//                   child: Column(
//                     children: [
//                       // Handle bar để kéo - vùng có thể chạm để kéo sheet
//                       GestureDetector(
//                         behavior: HitTestBehavior.translucent,
//                         onPanUpdate: (details) {
//                           print('onPanUpdate: ${details.delta.dy}');
//                           // Tính toán hướng kéo và điều chỉnh kích thước sheet
//                           const sensitivity =
//                               0.002; //  Độ nhạy của thao tác kéo. Giảm sensitivity để kéo mượt hơn. Giá trị nhỏ hơn khiến người dùng phải kéo xa hơn để đạt hiệu ứng tương tự
//                           final deltaY = details.delta.dy;
//                           final currentSize =
//                               _draggableController
//                                   .size; //Lấy kích thước hiện tại của sheet (tỉ lệ so với chiều cao màn hình)
//                           final newSize = (currentSize - (deltaY * sensitivity))
//                               .clamp(minChildSize, 1.0); //0.45
//                           print('newSize: $newSize');
//                           // Sử dụng jumpTo thay vì animateTo để responsive hơn
//                           // _draggableController.jumpTo(newSize);
//                           final minHeight =
//                               maxHeightKeyboard; //minChildSize * screenHeight;
//                           print('minHeight: $minHeight');
//                           height ??= minHeight;
//                           final temp = height! + -deltaY;
//                           print('temp: $temp');
//                           if (temp > minHeight) {
//                             setState(() {
//                               height = temp;
//                               // height = newSize * screenHeight;
//                             });
//                           } else {
//                             setState(() {
//                               height = minHeight;
//                             });
//                           }
//                           // if (deltaY < 0) {}//kéo lên
//                         },

//                         child: Container(
//                           //thanh kéo
//                           height: 30,
//                           width: double.infinity,
//                           padding: const EdgeInsets.symmetric(vertical: 14),
//                           child: Center(
//                             child: Container(
//                               height: 4,
//                               width: 40,
//                               decoration: BoxDecoration(
//                                 color: Colors.grey[600],
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                       Expanded(
//                         child: GalleryPicker(
//                           scrollController: scrollController,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }
