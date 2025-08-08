import 'package:equatable/equatable.dart';

class ErrorModel with EquatableMixin implements Exception {
  const ErrorModel(this.message);

  final String message;

  @override
  List<Object?> get props => [message];

  @override
  String toString() => 'err message: $message';
}
