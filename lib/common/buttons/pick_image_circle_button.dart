import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class PickImageCircleButton extends StatelessWidget {
  const PickImageCircleButton({
    super.key,
    required this.selected,
    required this.onPickImage,
    required this.asset,
    this.showAmount = true,
    this.currentIndex = 0,
  });
  final bool selected;
  final Function(AssetEntity) onPickImage;
  // final List<AssetEntity> selectedAssets;
  final AssetEntity asset;
  final int currentIndex;
  final bool showAmount;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onPickImage(asset);
      },
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: selected
              ? Colors.blue
              // Theme.of(context).primaryColor
              : Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 1.5,
          ),
        ),
        child: selected
            ? Center(
                child: Text(
                  showAmount ? '${currentIndex + 1}' : '',
                  // '${widget.selectedAssets.indexOf(widget.asset) + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : Container(),
      ),
    );
  }
}
