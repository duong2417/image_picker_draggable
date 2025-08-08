import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker_with_draggable/models/error_model.dart';

/// Default initial page size multiplier.
const defaultInitialPagedLimitMultiplier = 3;

/// Value listenable for paged data.
typedef PagedValueListenableBuilder<Key, Value> =
    ValueListenableBuilder<PagedValue<Key, Value>>;

/// A [PagedValueNotifier] that uses a [PagedListenable] to load data.
///
/// This class is useful when you need to load data from a server
/// using a [PagedListenable] and want to keep the UI-driven refresh
/// signals in the [PagedListenable].
///
/// [PagedValueNotifier] is a [ValueNotifier] that emits a [PagedValue]
/// whenever the data is loaded or an error occurs.
abstract class PagedValueNotifier<Key, Value>
    extends ValueNotifier<PagedValue<Key, Value>> {
  /// Creates a [PagedValueNotifier]
  PagedValueNotifier(this._initialValue) : super(_initialValue);

  /// Stores initialValue in case we need to call [refresh].
  final PagedValue<Key, Value> _initialValue;

  /// Returns the currently loaded items
  List<Value> get currentItems => value.asSuccess.items;

  /// Appends [newItems] to the previously loaded ones and replaces
  /// the next page's key.
  void appendPage({required List<Value> newItems, required Key nextPageKey}) {
    final updatedItems = currentItems + newItems;
    value = PagedValue.success(items: updatedItems, nextPageKey: nextPageKey);
  }

  /// Appends [newItems] to the previously loaded ones and sets the next page
  /// key to `null`.
  void appendLastPage(List<Value> newItems) {
    final updatedItems = currentItems + newItems;
    value = PagedValue.success(items: updatedItems);
  }

  /// Retry any failed load requests.
  ///
  /// Unlike [refresh], this does not resets the whole [value],
  /// it only retries the last failed load request.
  Future<void> retry() {
    final lastValue = value.asSuccess;
    assert(lastValue.hasError, '');

    final nextPageKey = lastValue.nextPageKey;
    // resetting the error
    value = lastValue.copyWith(error: null);
    // ignore: null_check_on_nullable_type_parameter
    return loadMore(nextPageKey!);
  }

  /// Refresh the data presented by this [PagedValueNotifier].
  ///
  /// Resets the [value] to the initial value in case [resetValue] is true.
  ///
  /// Note: This API is intended for UI-driven refresh signals,
  /// such as swipe-to-refresh.
  Future<void> refresh({bool resetValue = true}) {
    if (resetValue) value = _initialValue;
    return doInitialLoad();
  }

  /// Load initial data from the server.
  Future<void> doInitialLoad();

  /// Load more data from the server using [nextPageKey].
  Future<void> loadMore(Key nextPageKey);
}

/// Paged value that can be used with [PagedValueNotifier].
abstract class PagedValue<Key, Value> {
  const factory PagedValue({
    /// List with all items loaded so far.
    required List<Value> items,

    /// The key for the next page to be fetched.
    Key? nextPageKey,

    /// The current error, if any.
    ErrorModel? error,
  }) = Success<Key, Value>;

  const PagedValue._();

  /// Creates a success state with items and optional next page key and error
  const factory PagedValue.success({
    required List<Value> items,
    Key? nextPageKey,
    ErrorModel? error,
  }) = Success<Key, Value>;

  /// Creates a loading state
  const factory PagedValue.loading() = Loading<Key, Value>;

  /// Creates an error state
  const factory PagedValue.error(ErrorModel error) = Error<Key, Value>;

  /// Returns `true` if the [PagedValue] is [Success].
  bool get isSuccess => this is Success<Key, Value>;

  /// Returns `true` if the [PagedValue] is not [Success].
  bool get isNotSuccess => !isSuccess;

  /// Returns the [PagedValue] as [Success].
  Success<Key, Value> get asSuccess {
    assert(
      isSuccess,
      'Cannot get asSuccess if the PagedValue is not in the Success state',
    );
    return this as Success<Key, Value>;
  }

  /// Returns `true` if the [PagedValue] is [Success]
  /// and has more items to load.
  bool get hasNextPage => asSuccess.nextPageKey != null;

  /// Returns `true` if the [PagedValue] is [Success] and has an error.
  bool get hasError => asSuccess.error != null;

  /// Returns the item count
  int get itemCount {
    final count = asSuccess.items.length;
    if (hasNextPage || hasError) return count + 1;
    return count;
  }

  /// Pattern matching method
  T when<T>(
    T Function(List<Value> items, Key? nextPageKey, ErrorModel? error)
    success, {
    required T Function() loading,
    required T Function(ErrorModel error) error,
  }) {
    if (this is Success<Key, Value>) {
      final s = this as Success<Key, Value>;
      return success(s.items, s.nextPageKey, s.error);
    } else if (this is Loading<Key, Value>) {
      return loading();
    } else if (this is Error<Key, Value>) {
      final e = this as Error<Key, Value>;
      return error(e.error);
    }
    throw StateError('Unknown PagedValue type');
  }

  /// Pattern matching method with nullable callbacks
  T? whenOrNull<T>(
    T Function(List<Value> items, Key? nextPageKey, ErrorModel? error)?
    success, {
    T Function()? loading,
    T Function(ErrorModel error)? error,
  }) {
    if (this is Success<Key, Value>) {
      final s = this as Success<Key, Value>;
      return success?.call(s.items, s.nextPageKey, s.error);
    } else if (this is Loading<Key, Value>) {
      return loading?.call();
    } else if (this is Error<Key, Value>) {
      final e = this as Error<Key, Value>;
      return error?.call(e.error);
    }
    return null;
  }

  /// Pattern matching method with orElse
  T maybeWhen<T>(
    T Function(List<Value> items, Key? nextPageKey, ErrorModel? error)?
    success, {
    T Function()? loading,
    T Function(ErrorModel error)? error,
    required T orElse(),
  }) {
    final result = whenOrNull(success, loading: loading, error: error);
    return result ?? orElse();
  }
}

/// Success state of PagedValue
class Success<Key, Value> extends PagedValue<Key, Value> {
  const Success({required this.items, this.nextPageKey, this.error})
    : super._();

  /// List with all items loaded so far.
  final List<Value> items;

  /// The key for the next page to be fetched.
  final Key? nextPageKey;

  /// The current error, if any.
  final ErrorModel? error;

  /// Creates a copy with updated values
  Success<Key, Value> copyWith({
    List<Value>? items,
    Key? nextPageKey,
    ErrorModel? error,
  }) {
    return Success<Key, Value>(
      items: items ?? this.items,
      nextPageKey: nextPageKey ?? this.nextPageKey,
      error: error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Success<Key, Value> &&
        listEquals(other.items, items) &&
        other.nextPageKey == nextPageKey &&
        other.error == error;
  }

  @override
  int get hashCode => Object.hash(items, nextPageKey, error);

  @override
  String toString() {
    return 'Success(items: $items, nextPageKey: $nextPageKey, error: $error)';
  }
}

/// Loading state of PagedValue
class Loading<Key, Value> extends PagedValue<Key, Value> {
  const Loading() : super._();

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is Loading<Key, Value>;
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'Loading()';
}

/// Error state of PagedValue
class Error<Key, Value> extends PagedValue<Key, Value> {
  const Error(this.error) : super._();

  /// The error that occurred
  final ErrorModel error;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Error<Key, Value> && other.error == error;
  }

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'err: $error';
}
