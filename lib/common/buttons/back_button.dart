import 'package:flutter/material.dart';

class MyBackButton extends StatelessWidget {
  const MyBackButton({super.key, this.color, this.onPressed});
  final Color? color;
  final Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // print('backbutton: onTap');
        if (onPressed != null) {
          onPressed?.call();
        } else {
          Navigator.pop(context);
        }
      },
      child: Icon(Icons.arrow_back, color: Colors.white),
    );
  }
}
