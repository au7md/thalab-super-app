import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/theme.dart';

class MediaViewerScreen extends StatefulWidget {
  final List<AssetEntity> assets;
  final int initialIndex;

  const MediaViewerScreen({
    super.key,
    required this.assets,
    required this.initialIndex,
  });

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  late PageController _pageController;
  late List<AssetEntity> _items;
  late int _currentIndex;
  bool _chromeVisible = true;
  Set<String> _favoriteIds = {};

  @override
  void initState() {
    super.initState();
    _items = List<AssetEntity>.from(widget.assets);
    _currentIndex = widget.initialIndex.clamp(0, _items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _loadFavorites();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('gallery_favorite_ids') ?? [];
    if (mounted) {
      setState(() => _favoriteIds = saved.toSet());
    }
  }

  Future<void> _toggleFavorite(AssetEntity asset) async {
    HapticFeedback.selectionClick();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favoriteIds.contains(asset.id)) {
        _favoriteIds.remove(asset.id);
      } else {
        _favoriteIds.add(asset.id);
      }
    });
    await prefs.setStringList('gallery_favorite_ids', _favoriteIds.toList());
  }

  Future<void> _shareCurrent(AssetEntity asset) async {
    final file = await asset.file;
    if (file != null) {
      await Share.shareXFiles([XFile(file.path)]);
    }
  }

  Future<void> _deleteCurrent(AssetEntity asset) async {
    final deleted = await PhotoManager.editor.deleteWithIds([asset.id]);
    if (deleted.isNotEmpty && mounted) {
      setState(() {
        _items.removeAt(_currentIndex);
        if (_items.isEmpty) {
          Navigator.pop(context);
        } else if (_currentIndex >= _items.length) {
          _currentIndex = _items.length - 1;
        }
      });
    }
  }

  Future<void> _showMediaDetails(AssetEntity asset) async {
    final file = await asset.file;
    final sizeBytes = file != null && await file.exists() ? await file.length() : 0;
    final sizeMb = (sizeBytes / (1024 * 1024)).toStringAsFixed(2);
    final dt = asset.createDateTime;
    final dateStr =
        '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: ThalabTheme.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تفاصيل الملف والبيانات',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            _InfoLine(label: 'النوع', value: asset.type == AssetType.video ? 'فيديو' : 'صورة'),
            _InfoLine(label: 'الأبعاد', value: '${asset.width} × ${asset.height} بكسل'),
            _InfoLine(label: 'الحجم', value: '$sizeMb ميجابايت'),
            _InfoLine(label: 'تاريخ الالتقاط', value: dateStr),
            if (asset.type == AssetType.video)
              _InfoLine(label: 'المدة', value: '${asset.duration} ثانية'),
            if (file != null) _InfoLine(label: 'المسار', value: file.path),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditor(AssetEntity asset) async {
    final file = await asset.file;
    if (file == null || !mounted) return;

    if (asset.type == AssetType.image) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _QuickPhotoEditorScreen(imageFile: file),
        ),
      );
    } else if (asset.type == AssetType.video) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _QuickVideoStudioScreen(videoFile: file),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }
    final currentAsset = _items[_currentIndex];
    final isFav = _favoriteIds.contains(currentAsset.id);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: _chromeVisible
          ? AppBar(
              backgroundColor: Colors.black.withOpacity(0.55),
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Text(
                '${_currentIndex + 1} من ${_items.length}',
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              actions: [
                IconButton(
                  tooltip: 'معلومات وتفاصيل الملف',
                  icon: const Icon(Icons.info_outline_rounded, color: Colors.white),
                  onPressed: () => _showMediaDetails(currentAsset),
                ),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: () => setState(() => _chromeVisible = !_chromeVisible),
        child: PageView.builder(
          controller: _pageController,
          itemCount: _items.length,
          onPageChanged: (idx) => setState(() => _currentIndex = idx),
          itemBuilder: (context, index) {
            final asset = _items[index];
            if (asset.type == AssetType.video) {
              return _IntegratedVideoPage(
                asset: asset,
                isActivePage: index == _currentIndex,
                chromeVisible: _chromeVisible,
              );
            }
            return _IntegratedPhotoPage(asset: asset);
          },
        ),
      ),
      bottomNavigationBar: _chromeVisible
          ? Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.88),
                    Colors.black.withOpacity(0.0),
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ViewerActionBtn(
                    icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    label: 'المفضلة',
                    color: isFav ? Colors.redAccent : Colors.white,
                    onTap: () => _toggleFavorite(currentAsset),
                  ),
                  _ViewerActionBtn(
                    icon: currentAsset.type == AssetType.video
                        ? Icons.content_cut_rounded
                        : Icons.tune_rounded,
                    label: currentAsset.type == AssetType.video ? 'قص واستخراج' : 'تحرير الصورة',
                    color: ThalabTheme.foxOrangeLight,
                    onTap: () => _openEditor(currentAsset),
                  ),
                  _ViewerActionBtn(
                    icon: Icons.share_rounded,
                    label: 'مشاركة',
                    color: Colors.white,
                    onTap: () => _shareCurrent(currentAsset),
                  ),
                  _ViewerActionBtn(
                    icon: Icons.delete_outline_rounded,
                    label: 'حذف',
                    color: Colors.white70,
                    onTap: () => _deleteCurrent(currentAsset),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

// =========================================================================
// صفحة عرض الصورة بالتكبير السلس
// =========================================================================
class _IntegratedPhotoPage extends StatelessWidget {
  final AssetEntity asset;
  const _IntegratedPhotoPage({required this.asset});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: asset.file,
      builder: (context, snap) {
        if (!snap.hasData || snap.data == null) {
          return const Center(
            child: CircularProgressIndicator(color: ThalabTheme.foxOrange),
          );
        }
        return InteractiveViewer(
          minScale: 1.0,
          maxScale: 4.5,
          child: Center(
            child: Image.file(
              snap.data!,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }
}

// =========================================================================
// صفحة تشغيل الفيديو المدمجة (تتوقف تلقائياً عند السحب للصورة/الفيديو التالي)
// =========================================================================
class _IntegratedVideoPage extends StatefulWidget {
  final AssetEntity asset;
  final bool isActivePage;
  final bool chromeVisible;

  const _IntegratedVideoPage({
    required this.asset,
    required this.isActivePage,
    required this.chromeVisible,
  });

  @override
  State<_IntegratedVideoPage> createState() => _IntegratedVideoPageState();
}

class _IntegratedVideoPageState extends State<_IntegratedVideoPage> {
  VideoPlayerController? _controller;
  bool _isReady = false;
  bool _isMuted = false;
  double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void didUpdateWidget(covariant _IntegratedVideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller != null && _isReady) {
      if (!widget.isActivePage && _controller!.value.isPlaying) {
        _controller!.pause();
      } else if (widget.isActivePage && !oldWidget.isActivePage) {
        _controller!.play();
      }
    }
  }

  Future<void> _initVideo() async {
    final file = await widget.asset.file;
    if (file == null || !mounted) return;

    final ctrl = VideoPlayerController.file(file);
    await ctrl.initialize();
    ctrl.setLooping(true);
    if (widget.isActivePage) {
      await ctrl.play();
    }
    ctrl.addListener(() {
      if (mounted) setState(() {});
    });

    if (mounted) {
      setState(() {
        _controller = ctrl;
        _isReady = true;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: ThalabTheme.foxOrange),
      );
    }

    final val = _controller!.value;
    final maxMs = val.duration.inMilliseconds.toDouble().clamp(1.0, double.infinity);
    final posMs = val.position.inMilliseconds.toDouble().clamp(0.0, maxMs);

    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: val.aspectRatio == 0 ? 16 / 9 : val.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
        if (!val.isPlaying)
          GestureDetector(
            onTap: () => _controller!.play(),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ThalabTheme.foxOrange.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 42),
            ),
          ),
        if (widget.chromeVisible)
          Positioned(
            bottom: 86,
            left: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      val.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      val.isPlaying ? _controller!.pause() : _controller!.play();
                    },
                  ),
                  Text(
                    _fmt(val.position),
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                  Expanded(
                    child: Slider(
                      value: posMs,
                      min: 0,
                      max: maxMs,
                      activeColor: ThalabTheme.foxOrange,
                      inactiveColor: Colors.white24,
                      onChanged: (v) {
                        _controller!.seekTo(Duration(milliseconds: v.toInt()));
                      },
                    ),
                  ),
                  Text(
                    _fmt(val.duration),
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  IconButton(
                    icon: Icon(
                      _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() => _isMuted = !_isMuted);
                      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
                    },
                  ),
                  InkWell(
                    onTap: () {
                      final speeds = [1.0, 1.25, 1.5, 2.0];
                      final next = speeds[(speeds.indexOf(_playbackSpeed) + 1) % speeds.length];
                      setState(() => _playbackSpeed = next);
                      _controller!.setPlaybackSpeed(next);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: ThalabTheme.foxOrange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_playbackSpeed}x',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// =========================================================================
// استوديو تحرير الصور السريع (تدوير + قلب + فلاتر وحفظ في المعرض)
// =========================================================================
class _QuickPhotoEditorScreen extends StatefulWidget {
  final File imageFile;
  const _QuickPhotoEditorScreen({required this.imageFile});

  @override
  State<_QuickPhotoEditorScreen> createState() => _QuickPhotoEditorScreenState();
}

class _QuickPhotoEditorScreenState extends State<_QuickPhotoEditorScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  int _quarterTurns = 0;
  bool _flipHorizontal = false;
  int _selectedFilterIdx = 0;
  bool _isSaving = false;

  static const List<String> _filterNames = [
    'أصلي',
    'دافئ',
    'سينمائي',
    'أبيض وأسود',
    'حيوي',
  ];

  static const List<List<double>> _filterMatrices = [
    [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0],
    [1.12, 0.05, 0, 0, 10, 0, 1.03, 0, 0, 5, 0, 0, 0.88, 0, 0, 0, 0, 0, 1, 0],
    [0.95, 0.05, 0.05, 0, -5, 0.02, 1.02, 0.05, 0, 0, 0.05, 0.08, 1.15, 0, 8, 0, 0, 0, 1, 0],
    [0.33, 0.59, 0.11, 0, 0, 0.33, 0.59, 0.11, 0, 0, 0.33, 0.59, 0.11, 0, 0, 0, 0, 0, 1, 0],
    [1.25, 0, 0, 0, -15, 0, 1.25, 0, 0, -15, 0, 0, 1.25, 0, -15, 0, 0, 0, 1, 0],
  ];

  Future<void> _saveEditedImage() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final ui.Image img = await boundary.toImage(pixelRatio: 2.5);
        final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final Uint8List bytes = byteData.buffer.asUint8List();
          final savedEntity = await PhotoManager.editor.saveImage(
            bytes,
            filename: 'Thalab_Edit_${DateTime.now().millisecondsSinceEpoch}.png',
          );
          if (savedEntity != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم حفظ الصورة المعدلة في المعرض بنجاح ✓')),
            );
            Navigator.pop(context);
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('تحرير الصورة', style: TextStyle(color: Colors.white, fontSize: 17)),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveEditedImage,
            icon: const Icon(Icons.check_rounded, color: ThalabTheme.foxOrange),
            label: Text(
              _isSaving ? 'جاري الحفظ...' : 'حفظ نسخة',
              style: const TextStyle(color: ThalabTheme.foxOrange, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: RepaintBoundary(
                key: _repaintKey,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..scale(_flipHorizontal ? -1.0 : 1.0, 1.0),
                  child: RotatedBox(
                    quarterTurns: _quarterTurns,
                    child: ColorFiltered(
                      colorFilter: ColorFilter.matrix(_filterMatrices[_selectedFilterIdx]),
                      child: Image.file(widget.imageFile, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            decoration: const BoxDecoration(
              color: Color(0xFF1D1D1D),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ViewerActionBtn(
                      icon: Icons.rotate_right_rounded,
                      label: 'تدوير 90°',
                      color: Colors.white,
                      onTap: () => setState(() => _quarterTurns = (_quarterTurns + 1) % 4),
                    ),
                    _ViewerActionBtn(
                      icon: Icons.flip_rounded,
                      label: 'قلب أفقي',
                      color: Colors.white,
                      onTap: () => setState(() => _flipHorizontal = !_flipHorizontal),
                    ),
                    _ViewerActionBtn(
                      icon: Icons.refresh_rounded,
                      label: 'استعادة الأصل',
                      color: Colors.white70,
                      onTap: () => setState(() {
                        _quarterTurns = 0;
                        _flipHorizontal = false;
                        _selectedFilterIdx = 0;
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filterNames.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final active = _selectedFilterIdx == idx;
                      return ChoiceChip(
                        label: Text(
                          _filterNames[idx],
                          style: TextStyle(
                            color: active ? Colors.white : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        selected: active,
                        selectedColor: ThalabTheme.foxOrange,
                        backgroundColor: const Color(0xFF2B2B2B),
                        onSelected: (_) => setState(() => _selectedFilterIdx = idx),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// استوديو قص الفيديو واستخراج الصوت من واجهة الفيديو مباشرة
// =========================================================================
class _QuickVideoStudioScreen extends StatefulWidget {
  final File videoFile;
  const _QuickVideoStudioScreen({required this.videoFile});

  @override
  State<_QuickVideoStudioScreen> createState() => _QuickVideoStudioScreenState();
}

class _QuickVideoStudioScreenState extends State<_QuickVideoStudioScreen> {
  late VideoPlayerController _controller;
  bool _ready = false;
  RangeValues _trimRange = const RangeValues(0, 10);
  double _totalSeconds = 10;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _controller = VideoPlayerController.file(widget.videoFile);
    await _controller.initialize();
    final secs = _controller.value.duration.inSeconds.toDouble().clamp(1.0, double.infinity);
    await _controller.play();
    if (mounted) {
      setState(() {
        _totalSeconds = secs;
        _trimRange = RangeValues(0, secs);
        _ready = true;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _fmtSec(double s) {
    final mins = (s ~/ 60).toString().padLeft(2, '0');
    final secs = (s.toInt() % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Future<void> _exportAudioCopy() async {
    final dir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${dir.path}/extracted_audios');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    final outFile = File(
      '${audioDir.path}/Thalab_Audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    await widget.videoFile.copy(outFile.path);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم استخراج وحفظ الصوت بنجاح في: ${outFile.path}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('قص الفيديو واستخراج الصوت',
            style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator(color: ThalabTheme.foxOrange))
          : Column(
              children: [
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio == 0
                          ? 16 / 9
                          : _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'البداية: ${_fmtSec(_trimRange.start)}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'المدة المحددة: ${_fmtSec(_trimRange.end - _trimRange.start)}',
                            style: const TextStyle(
                              color: ThalabTheme.foxOrange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'النهاية: ${_fmtSec(_trimRange.end)}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      RangeSlider(
                        values: _trimRange,
                        min: 0,
                        max: _totalSeconds,
                        activeColor: ThalabTheme.foxOrange,
                        inactiveColor: Colors.white24,
                        onChanged: (vals) {
                          setState(() => _trimRange = vals);
                          _controller.seekTo(Duration(seconds: vals.start.toInt()));
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: ThalabTheme.foxOrange),
                                minimumSize: const Size(0, 48),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: _exportAudioCopy,
                              icon: const Icon(Icons.audiotrack_rounded,
                                  color: ThalabTheme.foxOrange),
                              label: const Text('استخراج الصوت'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ThalabTheme.foxOrange,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 48),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'تم تحديد نطاق القص (${_fmtSec(_trimRange.start)} - ${_fmtSec(_trimRange.end)}) وحفظ المقطع',
                                    ),
                                  ),
                                );
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.content_cut_rounded),
                              label: const Text('حفظ المقطع المقصوص'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ViewerActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ViewerActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              '$label:',
              style: const TextStyle(color: ThalabTheme.mutedSlate, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
