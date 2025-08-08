/// Union class to hold various [UploadState] of a attachment.
abstract class UploadState {
  const UploadState();

  /// Creates a new instance from a json
  factory UploadState.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'preparing':
        return const Preparing();
      case 'inProgress':
        return InProgress(
          uploaded: json['uploaded'] as int,
          total: json['total'] as int,
        );
      case 'success':
        return const Success();
      case 'failed':
        return Failed(error: json['error'] as String);
      default:
        throw ArgumentError('Unknown UploadState type: $type');
    }
  }

  /// Serialize to json
  Map<String, dynamic> toJson();

  /// Returns true if state is [Preparing]
  bool get isPreparing => this is Preparing;

  /// Returns true if state is [InProgress]
  bool get isInProgress => this is InProgress;

  /// Returns true if state is [Success]
  bool get isSuccess => this is Success;

  /// Returns true if state is [Failed]
  bool get isFailed => this is Failed;

  const factory UploadState.preparing() = Preparing;

  const factory UploadState.inProgress({
    required int uploaded,
    required int total,
  }) = InProgress;

  const factory UploadState.success() = Success;

  const factory UploadState.failed({required String error}) = Failed;
}

/// Preparing state of the union
class Preparing extends UploadState {
  const Preparing();

  @override
  Map<String, dynamic> toJson() => {'type': 'preparing'};

  @override
  bool operator ==(Object other) => other is Preparing;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// InProgress state of the union
class InProgress extends UploadState {
  const InProgress({required this.uploaded, required this.total});

  final int uploaded;
  final int total;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'inProgress',
    'uploaded': uploaded,
    'total': total,
  };

  @override
  bool operator ==(Object other) =>
      other is InProgress && other.uploaded == uploaded && other.total == total;

  @override
  int get hashCode => Object.hash(runtimeType, uploaded, total);
}

/// Success state of the union
class Success extends UploadState {
  const Success();

  @override
  Map<String, dynamic> toJson() => {'type': 'success'};

  @override
  bool operator ==(Object other) => other is Success;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Failed state of the union
class Failed extends UploadState {
  const Failed({required this.error});

  final String error;

  @override
  Map<String, dynamic> toJson() => {'type': 'failed', 'error': error};

  @override
  bool operator ==(Object other) => other is Failed && other.error == error;

  @override
  int get hashCode => Object.hash(runtimeType, error);
}
