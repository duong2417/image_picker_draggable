import 'package:image_picker_with_draggable/common/paged_value_notifier.dart';
import 'package:image_picker_with_draggable/models/error_model.dart';
import 'package:photo_manager/photo_manager.dart';

class PhotoGalleryController extends PagedValueNotifier<int, AssetEntity> {
  PhotoGalleryController({this.limit = 50}) : super(const PagedValue.loading());

  /// The maximum number of items to load at once.
  final int limit;

  Future<AssetPathEntity?> _getRecentAssetPathList({
    RequestType type = RequestType.image,
    // RequestType type = RequestType.common, //image and video
    FilterOptionGroup? filterOption,
  }) {
    return PhotoManager.getAssetPathList(
      type: type,
      onlyAll: true,
      filterOption: filterOption,
    ).then((it) => it.firstOrNull);
  }

  @override
  Future<void> doInitialLoad() async {
    try {
      final assets = await _getRecentAssetPathList();

      if (assets == null) {
        value = PagedValue(items: const []);
        return;
      }

      final mediaList = await assets.getAssetListPaged(page: 0, size: limit);

      final nextKey = mediaList.length < limit ? null : 1;
      value = PagedValue(items: mediaList, nextPageKey: nextKey);
    } on ErrorModel catch (error) {
      value = PagedValue.error(error);
    } catch (error) {
      final chatError = ErrorModel(error.toString());
      value = PagedValue.error(chatError);
    }
  }

  @override
  Future<void> loadMore(int page) async {
    final previousValue = value.asSuccess;

    try {
      final assets = await _getRecentAssetPathList();

      if (assets == null) {
        const chatError = ErrorModel('No media found');
        value = previousValue.copyWith(error: chatError);
        return;
      }

      final mediaList = await assets.getAssetListPaged(page: page, size: limit);

      final previousItems = previousValue.items;
      final newItems = previousItems + mediaList;
      final nextKey = mediaList.length < limit ? null : page + 1;
      value = PagedValue(items: newItems, nextPageKey: nextKey);
    } on ErrorModel catch (error) {
      value = previousValue.copyWith(error: error);
    } catch (error) {
      final chatError = ErrorModel(error.toString());
      value = previousValue.copyWith(error: chatError);
    }
  }
}
