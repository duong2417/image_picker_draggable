import 'dart:async';
import 'dart:math';

import 'package:image_picker_with_draggable/models/attachment.dart';
import 'package:image_picker_with_draggable/models/upload_state.dart';

class UploadSimulator {
  UploadSimulator._();
  static final UploadSimulator instance = UploadSimulator._();

  /// Simulate an upload and emit UploadState over time.
  /// - Starts with a brief preparing state
  /// - Emits inProgress every [tick]
  /// - Randomly fails with [failureProbability]
  /// - Finishes with success
  Stream<UploadState> uploadAttachment(Attachment attachment, {
    Duration preparingDelay = const Duration(milliseconds: 300),
    Duration tick = const Duration(milliseconds: 180),
    double failureProbability = 0.18,
    int? bytesPerTick,
  }) async* {
    // Preparing
    yield const UploadState.preparing();
    await Future<void>.delayed(preparingDelay);

    final total = attachment.fileSize ?? attachment.file?.size ?? 1;
    final rnd = Random(attachment.id.hashCode ^ DateTime.now().millisecondsSinceEpoch);
    final fail = rnd.nextDouble() < failureProbability;
    final step = bytesPerTick ?? _roughSpeed(total);

    int uploaded = 0;
    // Make sure we always emit at least one inProgress event.
    while (uploaded < total) {
      await Future<void>.delayed(tick);
      uploaded = (uploaded + step).clamp(0, total);
      yield UploadState.inProgress(uploaded: uploaded, total: total);

      // Optional random fail near middle
      if (fail && uploaded > total * 0.35 && uploaded < total * 0.85 && rnd.nextBool()) {
        await Future<void>.delayed(tick);
        yield const UploadState.failed(error: 'Network error');
        return;
      }
    }

    // Success
    yield const UploadState.success();
  }

  int _roughSpeed(int total) {
    // Keep uploads around 2-3 seconds depending on size.
    // Use a basic heuristic so small files are still visible.
    final targetTicks = 14 + (total ~/ (150 * 1024)).clamp(0, 20);
    return (total / targetTicks).ceil().clamp(1024, 512 * 1024);
  }
}
