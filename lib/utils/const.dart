import 'package:flutter/material.dart';

double maxHeightKeyboard = 255;

/// The default maximum size for media attachments.
const kDefaultMaxAttachmentSize = 100 * 1024 * 1024; // 100MB in Bytes

/// The default maximum number of media attachments.
const kDefaultMaxAttachmentCount = 10;

/// Max image resolution which can be resized by the CDN.
// Taken from https://getstream.io/chat/docs/flutter-dart/file_uploads/?language=dart#image-resizing
const maxCDNImageResolution = 16800000;

const Color disabledColor = Colors.grey;

//////MESSAGE BUBBLE
final double widthSingleImage = 150;
final double heightSingleImage = 300;
const double borderRadiusBubble = 16;
const defaultBorderBubble = Radius.circular(borderRadiusBubble);
// final defaultBorderBubble = BorderRadius.circular(borderRadiusBubble);
