import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme.dart';
import 'media_viewer_screen.dart';

class GalleryScreen extends StatefulWidget {
  final int initialCategoryIndex; // 0: الكل, 1: الصور, 2: الفيديوهات, 3: الألبومات, 4: المفضلة
  const GalleryScreen({super.key, this.initialCategoryIndex = 0});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  late int _selectedCategory;
  int _gridColumns = 3;
  bool _isLoading = true;
  bool _hasPermission = false;

  List<AssetEntity> _allAssets = [];
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _selectedAlbum;
  List<AssetEntity> _albumAssets = [];
  Set<String> _favoriteIds = {};

  bool _isSelectionMode = false;
  final Set<String> _selectedAssetIds = {};
  final Map<String, Uint8List?> _thumbCache = {};

  static const List<String> _categories = [
    'الكل',
    'الصور',
    'الفيديوهات',
    'الألبومات',
    'المفضلة',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategoryIndex.clamp(0, _categories.length - 1);
    _initGallery();
  }

  Future<void> _initGallery() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final savedFavs = prefs.getStringList('gallery_favorite_ids') ?? [];
    final savedCols = prefs.getInt('gallery_grid_cols') ?? 3;

    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth && !ps.hasAccess) {
      if (mounted) {
        setState(() {
          _favoriteIds = savedFavs.toSet();
          _gridColumns = savedCols;
          _hasPermission = false;
          _isLoading = false;
        });
      }
      return;
    }

    final filterOption = FilterOptionGroup(
      orders: [
        const OrderOption(type: OrderOptionType.createDate, asc: false),
      ],
    );

    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      filterOption: filterOption,
    );

    List<AssetEntity> loadedAssets = [];
    if (paths.isNotEmpty) {
      final recentAlbum = paths.first;
      final totalCount = await recentAlbum.assetCountAsync;
      final fetchCount = totalCount > 600 ? 600 : totalCount;
      if (fetchCount > 0) {
        loadedAssets = await recentAlbum.getAssetListRange(start: 0, end: fetchCount);
      }
    }

    if (mounted) {
      setState(() {
        _favoriteIds = savedFavs.toSet();
        _gridColumns = savedCols;
        _hasPermission = true;
        _albums = paths;
        _allAssets = loadedAssets;
        _isLoading = false;
      });
    }
  }

  Future<void> _openAlbum(AssetPathEntity album) async {
    setState(() {
      _isLoading = true;
      _selectedAlbum = album;
    });
    final total = await album.assetCountAsync;
    final count = total > 500 ? 500 : total;
    final list = count > 0
        ? await album.getAssetListRange(start: 0, end: count)
        : <AssetEntity>[];
    if (mounted) {
      setState(() {
        _albumAssets = list;
        _isLoading = false;
      });
    }
  }

  List<AssetEntity> get _displayedAssets {
    if (_selectedCategory == 3 && _selectedAlbum != null) {
      return _albumAssets;
    }
    switch (_selectedCategory) {
      case 1:
        return _allAssets.where((a) => a.type == AssetType.image).toList();
      case 2:
        return _allAssets.where((a) => a.type == AssetType.video).toList();
      case 4:
        return _allAssets.where((a) => _favoriteIds.contains(a.id)).toList();
      default:
        return _allAssets;
    }
  }

  Future<Uint8List?> _getThumb(AssetEntity asset) async {
    if (_thumbCache.containsKey(asset.id)) {
      return _thumbCache[asset.id];
    }
    final data = await asset.thumbnailDataWithSize(
      const ThumbnailSize.square(260),
      quality: 82,
    );
    _thumbCache[asset.id] = data;
    return data;
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _toggleSelection(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedAssetIds.contains(id)) {
        _selectedAssetIds.remove(id);
        if (_selectedAssetIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedAssetIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  Future<void> _shareSelectedAssets() async {
    final selected = _displayedAssets
        .where((a) => _selectedAssetIds.contains(a.id))
        .toList();
    if (selected.isEmpty) return;

    final List<XFile> files = [];
    for (final asset in selected) {
      final f = await asset.file;
      if (f != null) {
        files.add(XFile(f.path));
      }
    }
    if (files.isNotEmpty) {
      await Share.shareXFiles(files);
    }
    setState(() {
      _isSelectionMode = false;
      _selectedAssetIds.clear();
    });
  }

  Future<void> _favoriteSelectedAssets() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoriteIds.addAll(_selectedAssetIds);
      _isSelectionMode = false;
      _selectedAssetIds.clear();
    });
    await prefs.setStringList('gallery_favorite_ids', _favoriteIds.toList());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة العناصر المحددة إلى المفضلة')),
      );
    }
  }

  Future<void> _deleteSelectedAssets() async {
    final idsToDelete = _selectedAssetIds.toList();
    if (idsToDelete.isEmpty) return;

    final result = await PhotoManager.editor.deleteWithIds(idsToDelete);
    if (result.isNotEmpty) {
      setState(() {
        _allAssets.removeWhere((a) => result.contains(a.id));
        _albumAssets.removeWhere((a) => result.contains(a.id));
        _favoriteIds.removeAll(result);
        _isSelectionMode = false;
        _selectedAssetIds.clear();
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('gallery_favorite_ids', _favoriteIds.toList());
    }
  }

  Future<void> _openViewer(List<AssetEntity> list, int initialIndex) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaViewerScreen(
          assets: list,
          initialIndex: initialIndex,
        ),
      ),
    );
    await _initGallery();
  }

  @override
  Widget build(BuildContext context) {
    final imagesCount = _allAssets.where((a) => a.type == AssetType.image).length;
    final videosCount = _allAssets.where((a) => a.type == AssetType.video).length;
    final currentList = _displayedAssets;

    return Scaffold(
      appBar: AppBar(
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedAssetIds.clear();
                  });
                },
              )
            : (_selectedCategory == 3 && _selectedAlbum != null)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => setState(() => _selectedAlbum = null),
                  )
                : null,
        title: Text(
          _isSelectionMode
              ? 'محدد (${_selectedAssetIds.length})'
              : (_selectedCategory == 3 && _selectedAlbum != null)
                  ? _selectedAlbum!.name
                  : 'المعرض الذكي',
        ),
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              tooltip: 'إضافة للمفضلة',
              icon: const Icon(Icons.favorite_rounded, color: Colors.redAccent),
              onPressed: _favoriteSelectedAssets,
            ),
            IconButton(
              tooltip: 'مشاركة المحدد',
              icon: const Icon(Icons.share_rounded, color: ThalabTheme.foxOrange),
              onPressed: _shareSelectedAssets,
            ),
            IconButton(
              tooltip: 'حذف المحدد',
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              onPressed: _deleteSelectedAssets,
            ),
          ] else ...[
            IconButton(
              tooltip: 'تغيير حجم العرض',
              icon: Icon(
                _gridColumns == 3 ? Icons.grid_view_rounded : Icons.apps_rounded,
                color: ThalabTheme.foxOrange,
              ),
              onPressed: () async {
                final next = _gridColumns == 3 ? 4 : 3;
                setState(() => _gridColumns = next);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('gallery_grid_cols', next);
              },
            ),
            IconButton(
              tooltip: 'تحديث المعرض',
              icon: const Icon(Icons.refresh_rounded, color: ThalabTheme.foxOrange),
              onPressed: _initGallery,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: ThalabTheme.foxOrange))
          : !_hasPermission
              ? _buildPermissionPlaceholder()
              : Column(
                  children: [
                    // شريط الاختصارات والإحصائيات الموجزة
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: ThalabTheme.cardSurface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: ThalabTheme.softBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _MiniStatChip(
                              icon: Icons.photo_rounded,
                              label: 'الصور',
                              count: '$imagesCount',
                              onTap: () => setState(() {
                                _selectedCategory = 1;
                                _selectedAlbum = null;
                              }),
                            ),
                            Container(width: 1, height: 22, color: ThalabTheme.softBorder),
                            _MiniStatChip(
                              icon: Icons.videocam_rounded,
                              label: 'الفيديو',
                              count: '$videosCount',
                              onTap: () => setState(() {
                                _selectedCategory = 2;
                                _selectedAlbum = null;
                              }),
                            ),
                            Container(width: 1, height: 22, color: ThalabTheme.softBorder),
                            _MiniStatChip(
                              icon: Icons.favorite_rounded,
                              label: 'المفضلة',
                              count: '${_favoriteIds.length}',
                              onTap: () => setState(() {
                                _selectedCategory = 4;
                                _selectedAlbum = null;
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // شريط التبويبات الأفقية
                    SizedBox(
                      height: 42,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, idx) {
                          final selected = _selectedCategory == idx;
                          return ChoiceChip(
                            label: Text(
                              _categories[idx],
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: selected ? Colors.white : ThalabTheme.darkSlate,
                              ),
                            ),
                            selected: selected,
                            selectedColor: ThalabTheme.foxOrange,
                            backgroundColor: ThalabTheme.cardSurface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(
                                color: selected ? ThalabTheme.foxOrange : ThalabTheme.softBorder,
                              ),
                            ),
                            onSelected: (_) {
                              setState(() {
                                _selectedCategory = idx;
                                _selectedAlbum = null;
                                _isSelectionMode = false;
                                _selectedAssetIds.clear();
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),

                    // محتوى المعرض (ألبومات أو شبكة وسائط موحدة)
                    Expanded(
                      child: (_selectedCategory == 3 && _selectedAlbum == null)
                          ? _buildAlbumsGrid()
                          : currentList.isEmpty
                              ? Center(
                                  child: Text(
                                    _selectedCategory == 4
                                        ? 'لا توجد صور أو فيديوهات في المفضلة بعد'
                                        : 'لا توجد وسائط في هذا القسم',
                                    style: const TextStyle(
                                      color: ThalabTheme.mutedSlate,
                                      fontSize: 14,
                                    ),
                                  ),
                                )
                              : _buildMediaGrid(currentList),
                    ),
                  ],
                ),
    );
  }

  Widget _buildPermissionPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: ThalabTheme.foxOrange.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.photo_library_rounded,
                  size: 46, color: ThalabTheme.foxOrange),
            ),
            const SizedBox(height: 16),
            const Text(
              'السماح بالوصول إلى الصور والفيديوهات',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'لعرض صورك وفيديوهاتك وتنظيم الألبومات وتحريرها مباشرة داخل تطبيق الثعلب، يرجى منح صلاحية الوصول للوسائط.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ThalabTheme.mutedSlate, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ThalabTheme.foxOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () async {
                await PhotoManager.openSetting();
                _initGallery();
              },
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('منح الصلاحية الآن', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumsGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      itemCount: _albums.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.92,
      ),
      itemBuilder: (context, index) {
        final album = _albums[index];
        return FutureBuilder<int>(
          future: album.assetCountAsync,
          builder: (context, countSnap) {
            final count = countSnap.data ?? 0;
            return InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => _openAlbum(album),
              child: Container(
                decoration: BoxDecoration(
                  color: ThalabTheme.cardSurface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: ThalabTheme.softBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
                        child: FutureBuilder<List<AssetEntity>>(
                          future: album.getAssetListRange(start: 0, end: 1),
                          builder: (context, assetSnap) {
                            final firstAsset = (assetSnap.data != null && assetSnap.data!.isNotEmpty)
                                ? assetSnap.data!.first
                                : null;
                            if (firstAsset == null) {
                              return Container(
                                color: ThalabTheme.creamBackground,
                                child: const Icon(Icons.folder_rounded,
                                    size: 42, color: ThalabTheme.foxOrange),
                              );
                            }
                            return FutureBuilder<Uint8List?>(
                              future: _getThumb(firstAsset),
                              builder: (context, thumbSnap) {
                                if (thumbSnap.data == null) {
                                  return Container(color: ThalabTheme.creamBackground);
                                }
                                return Image.memory(thumbSnap.data!, fit: BoxFit.cover);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            album.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          Text(
                            '$count عنصر',
                            style: const TextStyle(color: ThalabTheme.mutedSlate, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMediaGrid(List<AssetEntity> list) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 110),
      itemCount: list.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _gridColumns,
        mainAxisSpacing: 5,
        crossAxisSpacing: 5,
      ),
      itemBuilder: (context, index) {
        final asset = list[index];
        final isVideo = asset.type == AssetType.video;
        final isFav = _favoriteIds.contains(asset.id);
        final isSelected = _selectedAssetIds.contains(asset.id);

        return GestureDetector(
          onLongPress: () => _toggleSelection(asset.id),
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(asset.id);
            } else {
              _openViewer(list, index);
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                FutureBuilder<Uint8List?>(
                  future: _getThumb(asset),
                  builder: (context, snapshot) {
                    if (snapshot.data == null) {
                      return Container(color: ThalabTheme.softBorder.withOpacity(0.4));
                    }
                    return AnimatedScale(
                      scale: isSelected ? 0.88 : 1.0,
                      duration: const Duration(milliseconds: 160),
                      child: Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    );
                  },
                ),
                if (isVideo)
                  Positioned(
                    bottom: 5,
                    right: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.68),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 13),
                          const SizedBox(width: 2),
                          Text(
                            _formatDuration(asset.duration),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (isFav && !isSelected)
                  const Positioned(
                    top: 5,
                    left: 5,
                    child: Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 16),
                  ),
                if (isSelected)
                  Container(
                    color: ThalabTheme.foxOrange.withOpacity(0.32),
                    alignment: Alignment.topRight,
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 22),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MiniStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String count;
  final VoidCallback onTap;

  const _MiniStatChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          children: [
            Icon(icon, size: 17, color: ThalabTheme.foxOrange),
            const SizedBox(width: 6),
            Text(
              '$label: ',
              style: const TextStyle(fontSize: 12, color: ThalabTheme.mutedSlate),
            ),
            Text(
              count,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
