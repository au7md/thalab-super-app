import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/fox_mascot.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import 'media_viewer_screen.dart';

enum _GallerySortType { newest, oldest, nameAsc, nameDesc }

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
  bool _isExportingPdf = false;
  _GallerySortType _sortType = _GallerySortType.newest;

  List<AssetEntity> _allAssets = [];
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _selectedAlbum;
  List<AssetEntity> _albumAssets = [];
  Set<String> _favoriteIds = {};

  bool _isSelectionMode = false;
  final Set<String> _selectedAssetIds = {};
  final Map<String, Uint8List?> _thumbCache = {};

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _cardBg => Theme.of(context).cardColor;
  Color get _innerBg => Theme.of(context).scaffoldBackgroundColor;
  Color get _borderColor => _isDark ? ThalabTheme.darkBorder : ThalabTheme.softBorder;
  Color get _textColor => _isDark ? ThalabTheme.darkTextPrimary : ThalabTheme.darkSlate;

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
    final savedSortIdx = prefs.getInt('gallery_sort_type') ?? 0;

    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth && !ps.hasAccess) {
      if (mounted) {
        setState(() {
          _favoriteIds = savedFavs.toSet();
          _gridColumns = savedCols;
          _sortType = _GallerySortType.values[savedSortIdx.clamp(0, _GallerySortType.values.length - 1)];
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
        _sortType = _GallerySortType.values[savedSortIdx.clamp(0, _GallerySortType.values.length - 1)];
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
    List<AssetEntity> baseList;
    if (_selectedCategory == 3 && _selectedAlbum != null) {
      baseList = List<AssetEntity>.from(_albumAssets);
    } else {
      switch (_selectedCategory) {
        case 1:
          baseList = _allAssets.where((a) => a.type == AssetType.image).toList();
          break;
        case 2:
          baseList = _allAssets.where((a) => a.type == AssetType.video).toList();
          break;
        case 4:
          baseList = _allAssets.where((a) => _favoriteIds.contains(a.id)).toList();
          break;
        default:
          baseList = List<AssetEntity>.from(_allAssets);
      }
    }

    switch (_sortType) {
      case _GallerySortType.newest:
        baseList.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
        break;
      case _GallerySortType.oldest:
        baseList.sort((a, b) => a.createDateTime.compareTo(b.createDateTime));
        break;
      case _GallerySortType.nameAsc:
        baseList.sort((a, b) => (a.title ?? '').toLowerCase().compareTo((b.title ?? '').toLowerCase()));
        break;
      case _GallerySortType.nameDesc:
        baseList.sort((a, b) => (b.title ?? '').toLowerCase().compareTo((a.title ?? '').toLowerCase()));
        break;
    }

    return baseList;
  }

  bool get _onlyImagesSelected {
    if (_selectedAssetIds.isEmpty) return false;
    final selected = _displayedAssets.where((a) => _selectedAssetIds.contains(a.id));
    return selected.isNotEmpty && selected.every((a) => a.type == AssetType.image);
  }

  Future<void> _exportSelectedImagesToPdf() async {
    if (_isExportingPdf) return;
    final selected = _displayedAssets
        .where((a) => _selectedAssetIds.contains(a.id) && a.type == AssetType.image)
        .toList();
    if (selected.isEmpty) return;

    setState(() => _isExportingPdf = true);
    try {
      final pdf = pw.Document();
      for (final asset in selected) {
        final bytes = await asset.originBytes;
        if (bytes != null) {
          final image = pw.MemoryImage(bytes);
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(16),
              build: (_) => pw.Center(
                child: pw.Image(image, fit: pw.BoxFit.contain),
              ),
            ),
          );
        }
      }

      Directory targetDir;
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (Platform.isAndroid && await downloadDir.exists()) {
        targetDir = downloadDir;
      } else {
        targetDir = await getApplicationDocumentsDirectory();
      }

      final fileName = 'Thalab_Images_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${targetDir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        setState(() {
          _isSelectionMode = false;
          _selectedAssetIds.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حفظ ملف PDF في: ${file.path}'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'مشاركة',
              textColor: ThalabTheme.foxOrange,
              onPressed: () => Share.shareXFiles([XFile(file.path)]),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إنشاء ملف PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
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
            if (_onlyImagesSelected)
              IconButton(
                tooltip: 'تحويل إلى PDF',
                icon: _isExportingPdf
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: ThalabTheme.foxOrange),
                      )
                    : const Icon(Icons.picture_as_pdf_rounded, color: ThalabTheme.foxOrange),
                onPressed: _isExportingPdf ? null : _exportSelectedImagesToPdf,
              ),
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
            PopupMenuButton<_GallerySortType>(
              tooltip: 'ترتيب الوسائط',
              icon: const Icon(Icons.sort_rounded, color: ThalabTheme.foxOrange),
              color: _cardBg,
              initialValue: _sortType,
              onSelected: (val) async {
                setState(() => _sortType = val);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('gallery_sort_type', val.index);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _GallerySortType.newest,
                  child: Text('الأحدث أولاً'),
                ),
                PopupMenuItem(
                  value: _GallerySortType.oldest,
                  child: Text('الأقدم أولاً'),
                ),
                PopupMenuItem(
                  value: _GallerySortType.nameAsc,
                  child: Text('الاسم أبجدياً (أ - ي)'),
                ),
                PopupMenuItem(
                  value: _GallerySortType.nameDesc,
                  child: Text('الاسم أبجدياً (ي - أ)'),
                ),
              ],
            ),
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              ThalabTheme.foxOrange.withOpacity(
                                  Theme.of(context).brightness == Brightness.dark ? 0.22 : 0.12),
                              _cardBg,
                            ],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: ThalabTheme.foxOrange.withOpacity(0.28)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            const FoxMascot(size: 46, mood: FoxMood.camera),
                            _MiniStatChip(
                              icon: Icons.photo_rounded,
                              label: 'الصور',
                              count: '$imagesCount',
                              onTap: () => setState(() {
                                _selectedCategory = 1;
                                _selectedAlbum = null;
                              }),
                            ),
                            Container(width: 1, height: 22, color: _borderColor),
                            _MiniStatChip(
                              icon: Icons.videocam_rounded,
                              label: 'الفيديو',
                              count: '$videosCount',
                              onTap: () => setState(() {
                                _selectedCategory = 2;
                                _selectedAlbum = null;
                              }),
                            ),
                            Container(width: 1, height: 22, color: _borderColor),
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
                                color: selected ? Colors.white : _textColor,
                              ),
                            ),
                            selected: selected,
                            selectedColor: ThalabTheme.foxOrange,
                            backgroundColor: _cardBg,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(
                                color: selected ? ThalabTheme.foxOrange : _borderColor,
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

                    Expanded(
                      child: (_selectedCategory == 3 && _selectedAlbum == null)
                          ? _buildAlbumsGrid()
                          : currentList.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const FoxMascot(size: 96, mood: FoxMood.sleepy),
                                      const SizedBox(height: 14),
                                      Text(
                                        _selectedCategory == 4
                                            ? 'لا توجد صور أو فيديوهات في المفضلة بعد 💛'
                                            : 'لا توجد وسائط في هذا القسم',
                                        style: TextStyle(
                                          color: thalabMuted(context),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
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
            const FoxMascot(size: 120, mood: FoxMood.camera),
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
            return FadeSlideIn(
              delay: Duration(milliseconds: (index % 8) * 55),
              child: PressableScale(
              onTap: () => _openAlbum(album),
              child: Container(
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _borderColor),
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
                                color: _innerBg,
                                child: const Icon(Icons.folder_rounded,
                                    size: 42, color: ThalabTheme.foxOrange),
                              );
                            }
                            return FutureBuilder<Uint8List?>(
                              future: _getThumb(firstAsset),
                              builder: (context, thumbSnap) {
                                if (thumbSnap.data == null) {
                                  return Container(color: _innerBg);
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
                      return Container(color: _borderColor.withOpacity(0.4));
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
    return PressableScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: ThalabTheme.foxOrange),
                const SizedBox(width: 4),
                Text(
                  count,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: thalabMuted(context)),
            ),
          ],
        ),
      ),
    );
  }
}
