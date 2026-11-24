import 'dart:io';
import 'dart:math' as math;
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
  bool _isScreenLocked = false;
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
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
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

  void _goToNext() {
    if (_currentIndex + 1 < _items.length) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
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
      backgroundColor: Theme.of(context).cardColor,
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
          builder: (_) => _ProPhotoEditorScreen(imageFile: file),
        ),
      );
    } else if (asset.type == AssetType.video) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _ProVideoStudioScreen(videoFile: file),
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
      appBar: (_chromeVisible && !_isScreenLocked)
          ? AppBar(
              backgroundColor: Colors.black.withOpacity(0.55),
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Text(
                '${_currentIndex + 1} / ${_items.length}',
                style: const TextStyle(color: Colors.white, fontSize: 14.5),
              ),
              actions: [
                IconButton(
                  tooltip: isFav ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
                  icon: Icon(
                    isFav ? Icons.star_rounded : Icons.star_border_rounded,
                    color: isFav ? const Color(0xFFFFB703) : Colors.white,
                    size: 26,
                  ),
                  onPressed: () => _toggleFavorite(currentAsset),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                  color: const Color(0xFF1F1F1F),
                  onSelected: (val) {
                    if (val == 'edit') _openEditor(currentAsset);
                    if (val == 'share') _shareCurrent(currentAsset);
                    if (val == 'info') _showMediaDetails(currentAsset);
                    if (val == 'delete') _deleteCurrent(currentAsset);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            currentAsset.type == AssetType.video
                                ? Icons.content_cut_rounded
                                : Icons.crop_rotate_rounded,
                            color: ThalabTheme.foxOrange,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            currentAsset.type == AssetType.video
                                ? 'تحرير وقص الفيديو'
                                : 'قص وتحرير الصورة',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share_outlined, color: Colors.white70, size: 20),
                          SizedBox(width: 10),
                          Text('مشاركة', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'info',
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Colors.white70, size: 20),
                          SizedBox(width: 10),
                          Text('تفاصيل الملف', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                          SizedBox(width: 10),
                          Text('حذف من الجهاز', style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            )
          : null,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            physics: _isScreenLocked
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            itemCount: _items.length,
            onPageChanged: (idx) => setState(() => _currentIndex = idx),
            itemBuilder: (context, index) {
              final asset = _items[index];
              if (asset.type == AssetType.video) {
                return _CinematicVideoPage(
                  asset: asset,
                  isActivePage: index == _currentIndex,
                  chromeVisible: _chromeVisible,
                  isLocked: _isScreenLocked,
                  hasPrevious: index > 0,
                  hasNext: index + 1 < _items.length,
                  onToggleChrome: () => setState(() => _chromeVisible = !_chromeVisible),
                  onToggleLock: () => setState(() => _isScreenLocked = !_isScreenLocked),
                  onPrevious: _goToPrevious,
                  onNext: _goToNext,
                  onOpenEditor: () => _openEditor(asset),
                );
              }
              return GestureDetector(
                onTap: () => setState(() => _chromeVisible = !_chromeVisible),
                child: _IntegratedPhotoPage(asset: asset),
              );
            },
          ),
          if (_isScreenLocked)
            Positioned(
              top: 44,
              right: 18,
              child: GestureDetector(
                onTap: () => setState(() => _isScreenLocked = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.72),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ThalabTheme.foxOrange),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, color: ThalabTheme.foxOrange, size: 18),
                      SizedBox(width: 6),
                      Text('اضغط لفتح القفل',
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: (_chromeVisible &&
              !_isScreenLocked &&
              currentAsset.type == AssetType.image)
          ? Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ViewerActionBtn(
                    icon: Icons.crop_rotate_rounded,
                    label: 'قص وتحرير',
                    color: ThalabTheme.foxOrangeLight,
                    onTap: () => _openEditor(currentAsset),
                  ),
                  _ViewerActionBtn(
                    icon: Icons.share_outlined,
                    label: 'مشاركة',
                    color: Colors.white,
                    onTap: () => _shareCurrent(currentAsset),
                  ),
                  _ViewerActionBtn(
                    icon: Icons.info_outline_rounded,
                    label: 'التفاصيل',
                    color: Colors.white,
                    onTap: () => _showMediaDetails(currentAsset),
                  ),
                  _ViewerActionBtn(
                    icon: Icons.delete_outline_rounded,
                    label: 'حذف',
                    color: Colors.redAccent,
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
// مشغل الفيديو السينمائي المتكامل
// =========================================================================
class _CinematicVideoPage extends StatefulWidget {
  final AssetEntity asset;
  final bool isActivePage;
  final bool chromeVisible;
  final bool isLocked;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onToggleChrome;
  final VoidCallback onToggleLock;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onOpenEditor;

  const _CinematicVideoPage({
    required this.asset,
    required this.isActivePage,
    required this.chromeVisible,
    required this.isLocked,
    required this.hasPrevious,
    required this.hasNext,
    required this.onToggleChrome,
    required this.onToggleLock,
    required this.onPrevious,
    required this.onNext,
    required this.onOpenEditor,
  });

  @override
  State<_CinematicVideoPage> createState() => _CinematicVideoPageState();
}

class _CinematicVideoPageState extends State<_CinematicVideoPage> {
  static const MethodChannel _volumeChannel =
      MethodChannel('com.au7md.thalab_app/system_volume');

  VideoPlayerController? _controller;
  bool _isReady = false;
  bool _isLandscape = false;
  bool _isZoomFill = false;
  double _playbackSpeed = 1.0;

  double _currentVolume = 0.5;
  bool _showVolumeHud = false;
  String _seekHudText = '';

  @override
  void initState() {
    super.initState();
    _initVolume();
    _initVideo();
  }

  Future<void> _initVolume() async {
    try {
      final vol = await _volumeChannel.invokeMethod<double>('getVolume');
      if (mounted && vol != null) {
        setState(() => _currentVolume = vol.clamp(0.0, 1.0));
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant _CinematicVideoPage oldWidget) {
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

  void _seekRelative(int seconds) {
    if (_controller == null || !_isReady) return;
    final current = _controller!.value.position;
    final total = _controller!.value.duration;
    final targetMs = (current.inMilliseconds + seconds * 1000)
        .clamp(0, total.inMilliseconds);
    _controller!.seekTo(Duration(milliseconds: targetMs));
    setState(() {
      _seekHudText = seconds > 0 ? '+$seconds ث' : '$seconds ث';
    });
    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _seekHudText = '');
    });
  }

  void _toggleOrientation() {
    setState(() => _isLandscape = !_isLandscape);
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (widget.isLocked) return;
    final screenH = MediaQuery.of(context).size.height;
    final delta = -details.delta.dy / (screenH * 0.55);
    final nextVol = (_currentVolume + delta).clamp(0.0, 1.0);
    setState(() {
      _currentVolume = nextVol;
      _showVolumeHud = true;
    });
    try {
      _volumeChannel.invokeMethod('setVolume', {'volume': nextVol});
    } catch (_) {}
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showVolumeHud = false);
    });
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!widget.isLocked) widget.onToggleChrome();
      },
      onDoubleTapDown: (details) {
        if (widget.isLocked) return;
        final w = MediaQuery.of(context).size.width;
        if (details.localPosition.dx < w * 0.45) {
          _seekRelative(-10);
        } else {
          _seekRelative(10);
        }
      },
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: FittedBox(
              fit: _isZoomFill ? BoxFit.cover : BoxFit.contain,
              child: SizedBox(
                width: val.size.width == 0 ? 1080 : val.size.width,
                height: val.size.height == 0 ? 1920 : val.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
          ),

          if (widget.chromeVisible && !widget.isLocked)
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.45),
                      Colors.transparent,
                      Colors.black.withOpacity(0.78),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),

          if (_showVolumeHud)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _currentVolume == 0
                        ? Icons.volume_off_rounded
                        : _currentVolume < 0.5
                            ? Icons.volume_down_rounded
                            : Icons.volume_up_rounded,
                    color: ThalabTheme.foxOrange,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 110,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _currentVolume,
                        minHeight: 6,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation(ThalabTheme.foxOrange),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${(_currentVolume * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

          if (_seekHudText.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.72),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                _seekHudText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          if (widget.chromeVisible && !widget.isLocked)
            Positioned(
              left: 14,
              right: 14,
              bottom: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _PillChip(
                        icon: Icons.content_cut_rounded,
                        label: 'قص وتحرير',
                        onTap: widget.onOpenEditor,
                      ),
                      const SizedBox(width: 8),
                      _PillChip(
                        icon: Icons.speed_rounded,
                        label: '${_playbackSpeed}x',
                        onTap: () {
                          final speeds = [0.5, 1.0, 1.25, 1.5, 2.0];
                          final next = speeds[
                              (speeds.indexOf(_playbackSpeed) + 1) % speeds.length];
                          setState(() => _playbackSpeed = next);
                          _controller!.setPlaybackSpeed(next);
                        },
                      ),
                      const SizedBox(width: 8),
                      _PillChip(
                        icon: _isZoomFill
                            ? Icons.fit_screen_rounded
                            : Icons.aspect_ratio_rounded,
                        label: _isZoomFill ? 'احتواء' : 'ملء',
                        onTap: () => setState(() => _isZoomFill = !_isZoomFill),
                      ),
                      const SizedBox(width: 8),
                      _PillChip(
                        icon: Icons.lock_outline_rounded,
                        label: 'قفل',
                        onTap: widget.onToggleLock,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Text(
                        _fmt(val.position),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2.5,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                          ),
                          child: Slider(
                            value: posMs,
                            min: 0,
                            max: maxMs,
                            activeColor: Colors.white,
                            inactiveColor: Colors.white30,
                            onChanged: (v) {
                              _controller!.seekTo(Duration(milliseconds: v.toInt()));
                            },
                          ),
                        ),
                      ),
                      Text(
                        _fmt(val.duration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'تدوير الشاشة',
                        icon: const Icon(Icons.screen_rotation_rounded,
                            color: Colors.white, size: 22),
                        onPressed: _toggleOrientation,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        iconSize: 30,
                        color: Colors.white,
                        tooltip: 'تراجع 10 ثوانٍ',
                        icon: const Icon(Icons.replay_10_rounded),
                        onPressed: () => _seekRelative(-10),
                      ),
                      IconButton(
                        iconSize: 32,
                        color: widget.hasPrevious ? Colors.white : Colors.white30,
                        tooltip: 'السابق',
                        icon: const Icon(Icons.skip_previous_outlined),
                        onPressed: widget.hasPrevious ? widget.onPrevious : null,
                      ),
                      GestureDetector(
                        onTap: () {
                          val.isPlaying ? _controller!.pause() : _controller!.play();
                        },
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black38,
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            val.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.black,
                            size: 38,
                          ),
                        ),
                      ),
                      IconButton(
                        iconSize: 32,
                        color: widget.hasNext ? Colors.white : Colors.white30,
                        tooltip: 'التالي',
                        icon: const Icon(Icons.skip_next_outlined),
                        onPressed: widget.hasNext ? widget.onNext : null,
                      ),
                      IconButton(
                        iconSize: 30,
                        color: Colors.white,
                        tooltip: 'تقديم 10 ثوانٍ',
                        icon: const Icon(Icons.forward_10_rounded),
                        onPressed: () => _seekRelative(10),
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

class _PillChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PillChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// إطار القص التفاعلي ذو الـ 8 مقابض
// =========================================================================
class _InteractiveCropFrame extends StatefulWidget {
  final Widget child;
  final Rect normalizedRect;
  final double? lockedAspectRatio;
  final ValueChanged<Rect> onRectChanged;

  const _InteractiveCropFrame({
    required this.child,
    required this.normalizedRect,
    required this.lockedAspectRatio,
    required this.onRectChanged,
  });

  @override
  State<_InteractiveCropFrame> createState() => _InteractiveCropFrameState();
}

class _InteractiveCropFrameState extends State<_InteractiveCropFrame> {
  static const double _minSpan = 0.14;

  void _updateEdge({
    double dLeft = 0,
    double dTop = 0,
    double dRight = 0,
    double dBottom = 0,
  }) {
    Rect r = widget.normalizedRect;
    double l = (r.left + dLeft).clamp(0.0, r.right - _minSpan);
    double t = (r.top + dTop).clamp(0.0, r.bottom - _minSpan);
    double ri = (r.right + dRight).clamp(l + _minSpan, 1.0);
    double b = (r.bottom + dBottom).clamp(t + _minSpan, 1.0);

    if (widget.lockedAspectRatio != null) {
      final target = widget.lockedAspectRatio!;
      double w = ri - l;
      double h = w / target;
      if (t + h > 1.0) {
        h = 1.0 - t;
        w = h * target;
      }
      if (l + w > 1.0) {
        w = 1.0 - l;
        h = w / target;
      }
      ri = (l + w).clamp(l + _minSpan, 1.0);
      b = (t + h).clamp(t + _minSpan, 1.0);
    }

    widget.onRectChanged(Rect.fromLTRB(l, t, ri, b));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final rect = Rect.fromLTRB(
          widget.normalizedRect.left * w,
          widget.normalizedRect.top * h,
          widget.normalizedRect.right * w,
          widget.normalizedRect.bottom * h,
        );

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: widget.child),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CropMaskPainter(cropRect: rect),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: rect,
              child: GestureDetector(
                onPanUpdate: (d) {
                  final dx = d.delta.dx / w;
                  final dy = d.delta.dy / h;
                  final r = widget.normalizedRect;
                  final cw = r.width;
                  final ch = r.height;
                  final nl = (r.left + dx).clamp(0.0, 1.0 - cw);
                  final nt = (r.top + dy).clamp(0.0, 1.0 - ch);
                  widget.onRectChanged(Rect.fromLTWH(nl, nt, cw, ch));
                },
                child: Container(color: Colors.transparent),
              ),
            ),
            _buildHandle(rect.left, rect.top, (d) => _updateEdge(dLeft: d.dx / w, dTop: d.dy / h)),
            _buildHandle(rect.right, rect.top, (d) => _updateEdge(dRight: d.dx / w, dTop: d.dy / h)),
            _buildHandle(rect.left, rect.bottom, (d) => _updateEdge(dLeft: d.dx / w, dBottom: d.dy / h)),
            _buildHandle(rect.right, rect.bottom, (d) => _updateEdge(dRight: d.dx / w, dBottom: d.dy / h)),
            _buildHandle(rect.center.dx, rect.top, (d) => _updateEdge(dTop: d.dy / h)),
            _buildHandle(rect.center.dx, rect.bottom, (d) => _updateEdge(dBottom: d.dy / h)),
            _buildHandle(rect.left, rect.center.dy, (d) => _updateEdge(dLeft: d.dx / w)),
            _buildHandle(rect.right, rect.center.dy, (d) => _updateEdge(dRight: d.dx / w)),
          ],
        );
      },
    );
  }

  Widget _buildHandle(double x, double y, ValueChanged<Offset> onDrag) {
    return Positioned(
      left: x - 20,
      top: y - 20,
      width: 40,
      height: 40,
      child: GestureDetector(
        onPanUpdate: (details) => onDrag(details.delta),
        child: Center(
          child: Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: ThalabTheme.foxOrange, width: 2.5),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
            ),
          ),
        ),
      ),
    );
  }
}

class _CropMaskPainter extends CustomPainter {
  final Rect cropRect;
  _CropMaskPainter({required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    final dimPaint = Paint()..color = Colors.black.withOpacity(0.58);
    final outer = Path()..addRect(Offset.zero & size);
    final inner = Path()..addRect(cropRect);
    final mask = Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath(mask, dimPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(cropRect, borderPaint);

    final gridPaint = Paint()
      ..color = Colors.white38
      ..strokeWidth = 0.8;
    final thirdW = cropRect.width / 3;
    final thirdH = cropRect.height / 3;
    for (int i = 1; i <= 2; i++) {
      canvas.drawLine(
        Offset(cropRect.left + thirdW * i, cropRect.top),
        Offset(cropRect.left + thirdW * i, cropRect.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(cropRect.left, cropRect.top + thirdH * i),
        Offset(cropRect.right, cropRect.top + thirdH * i),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CropMaskPainter oldDelegate) =>
      oldDelegate.cropRect != cropRect;
}

// =========================================================================
// استوديو تحرير الصور المتكامل
// =========================================================================
class _ProPhotoEditorScreen extends StatefulWidget {
  final File imageFile;
  const _ProPhotoEditorScreen({required this.imageFile});

  @override
  State<_ProPhotoEditorScreen> createState() => _ProPhotoEditorScreenState();
}

class _ProPhotoEditorScreenState extends State<_ProPhotoEditorScreen> {
  final GlobalKey _captureKey = GlobalKey();
  int _activeToolTab = 0;
  Rect _cropRect = const Rect.fromLTWH(0, 0, 1, 1);
  int _aspectIndex = 0;
  double _fineAngleDeg = 0.0;
  int _quarterTurns = 0;
  bool _flipH = false;

  double _brightness = 0.0;
  double _contrast = 1.0;
  double _saturation = 1.0;
  int _filterIdx = 0;
  bool _isSaving = false;

  static const List<String> _aspectLabels = ['حر', 'أصلي', '1:1', '4:3', '3:4', '16:9'];
  static const List<double?> _aspectValues = [null, null, 1.0, 4 / 3, 3 / 4, 16 / 9];
  static const List<String> _filterNames = ['أصلي', 'دافئ', 'سينمائي', 'أبيض وأسود', 'حيوي'];

  void _resetAll() {
    setState(() {
      _cropRect = const Rect.fromLTWH(0, 0, 1, 1);
      _aspectIndex = 0;
      _fineAngleDeg = 0.0;
      _quarterTurns = 0;
      _flipH = false;
      _brightness = 0.0;
      _contrast = 1.0;
      _saturation = 1.0;
      _filterIdx = 0;
    });
  }

  List<double> _buildCombinedMatrix() {
    final b = _brightness * 255.0;
    final c = _contrast;
    final t = (1.0 - c) * 128.0 + b;
    final s = _saturation;
    final sr = (1 - s) * 0.3086;
    final sg = (1 - s) * 0.6094;
    final sb = (1 - s) * 0.0820;

    double rWarm = 1.0, bWarm = 1.0;
    if (_filterIdx == 1) {
      rWarm = 1.12;
      bWarm = 0.88;
    } else if (_filterIdx == 2) {
      rWarm = 0.94;
      bWarm = 1.15;
    }

    if (_filterIdx == 3) {
      return [
        0.33 * c, 0.59 * c, 0.11 * c, 0, t,
        0.33 * c, 0.59 * c, 0.11 * c, 0, t,
        0.33 * c, 0.59 * c, 0.11 * c, 0, t,
        0, 0, 0, 1, 0,
      ];
    }

    final extraC = _filterIdx == 4 ? c * 1.18 : c;
    return [
      (sr + s) * extraC * rWarm, sg * extraC, sb * extraC, 0, t,
      sr * extraC, (sg + s) * extraC, sb * extraC, 0, t,
      sr * extraC, sg * extraC, (sb + s) * extraC * bWarm, 0, t,
      0, 0, 0, 1, 0,
    ];
  }

  Future<void> _saveCroppedAndEdited() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final boundary =
          _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final ui.Image fullImg = await boundary.toImage(pixelRatio: 2.5);
        final srcRect = Rect.fromLTWH(
          _cropRect.left * fullImg.width,
          _cropRect.top * fullImg.height,
          (_cropRect.width * fullImg.width).clamp(10.0, fullImg.width.toDouble()),
          (_cropRect.height * fullImg.height).clamp(10.0, fullImg.height.toDouble()),
        );

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final dstRect = Rect.fromLTWH(0, 0, srcRect.width, srcRect.height);
        canvas.drawImageRect(fullImg, srcRect, dstRect, Paint());
        final croppedImg = await recorder
            .endRecording()
            .toImage(srcRect.width.round(), srcRect.height.round());
        final byteData = await croppedImg.toByteData(format: ui.ImageByteFormat.png);

        if (byteData != null) {
          final saved = await PhotoManager.editor.saveImage(
            byteData.buffer.asUint8List(),
            filename: 'Thalab_Photo_${DateTime.now().millisecondsSinceEpoch}.png',
          );
          if (saved != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم حفظ الصورة المقصوصة والمعدلة في المعرض ✓')),
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
    final rad = _fineAngleDeg * math.pi / 180.0;
    final scaleFix = 1.0 + (_fineAngleDeg.abs() / 45.0) * 0.42;

    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101010),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('استوديو تحرير الصورة',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          IconButton(
            tooltip: 'إعادة ضبط',
            icon: const Icon(Icons.restore_rounded, color: Colors.white70),
            onPressed: _resetAll,
          ),
          TextButton.icon(
            onPressed: _isSaving ? null : _saveCroppedAndEdited,
            icon: const Icon(Icons.check_rounded, color: ThalabTheme.foxOrange),
            label: Text(
              _isSaving ? 'جاري الحفظ...' : 'حفظ',
              style: const TextStyle(
                color: ThalabTheme.foxOrange,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Center(
                child: _InteractiveCropFrame(
                  normalizedRect: _cropRect,
                  lockedAspectRatio: _aspectValues[_aspectIndex],
                  onRectChanged: (r) => setState(() => _cropRect = r),
                  child: RepaintBoundary(
                    key: _captureKey,
                    child: ClipRect(
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..scale(_flipH ? -scaleFix : scaleFix, scaleFix)
                          ..rotateZ(rad),
                        child: RotatedBox(
                          quarterTurns: _quarterTurns,
                          child: ColorFiltered(
                            colorFilter: ColorFilter.matrix(_buildCombinedMatrix()),
                            child: Image.file(widget.imageFile, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_activeToolTab == 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: 'تدوير 90°',
                        icon: const Icon(Icons.rotate_right_rounded, color: Colors.white),
                        onPressed: () => setState(() => _quarterTurns = (_quarterTurns + 1) % 4),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${_fineAngleDeg.round()}°',
                          style: const TextStyle(
                            color: ThalabTheme.foxOrange,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'قلب أفقي',
                        icon: const Icon(Icons.flip_rounded, color: Colors.white),
                        onPressed: () => setState(() => _flipH = !_flipH),
                      ),
                    ],
                  ),
                  Slider(
                    value: _fineAngleDeg,
                    min: -45,
                    max: 45,
                    activeColor: ThalabTheme.foxOrange,
                    inactiveColor: Colors.white24,
                    onChanged: (v) => setState(() => _fineAngleDeg = v),
                  ),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _aspectLabels.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, idx) {
                        final active = _aspectIndex == idx;
                        return ChoiceChip(
                          label: Text(
                            _aspectLabels[idx],
                            style: TextStyle(
                              color: active ? Colors.white : Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          selected: active,
                          selectedColor: ThalabTheme.foxOrange,
                          backgroundColor: const Color(0xFF282828),
                          onSelected: (_) {
                            setState(() {
                              _aspectIndex = idx;
                              if (idx == 0 || idx == 1) {
                                _cropRect = const Rect.fromLTWH(0, 0, 1, 1);
                              } else {
                                _cropRect = const Rect.fromLTWH(0.1, 0.1, 0.8, 0.8);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ] else if (_activeToolTab == 1) ...[
                  _SliderRow(
                    label: 'السطوع',
                    value: _brightness,
                    min: -0.4,
                    max: 0.4,
                    onChanged: (v) => setState(() => _brightness = v),
                  ),
                  _SliderRow(
                    label: 'التباين',
                    value: _contrast,
                    min: 0.6,
                    max: 1.5,
                    onChanged: (v) => setState(() => _contrast = v),
                  ),
                  _SliderRow(
                    label: 'التشبع',
                    value: _saturation,
                    min: 0.0,
                    max: 1.8,
                    onChanged: (v) => setState(() => _saturation = v),
                  ),
                ] else ...[
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filterNames.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, idx) {
                        final active = _filterIdx == idx;
                        return ChoiceChip(
                          label: Text(
                            _filterNames[idx],
                            style: TextStyle(
                              color: active ? Colors.white : Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          selected: active,
                          selectedColor: ThalabTheme.foxOrange,
                          backgroundColor: const Color(0xFF282828),
                          onSelected: (_) => setState(() => _filterIdx = idx),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ToolTabBtn(
                      icon: Icons.crop_rotate_rounded,
                      label: 'قص وتدوير',
                      selected: _activeToolTab == 0,
                      onTap: () => setState(() => _activeToolTab = 0),
                    ),
                    _ToolTabBtn(
                      icon: Icons.tune_rounded,
                      label: 'الإضاءة',
                      selected: _activeToolTab == 1,
                      onTap: () => setState(() => _activeToolTab = 1),
                    ),
                    _ToolTabBtn(
                      icon: Icons.auto_awesome_rounded,
                      label: 'فلاتر',
                      selected: _activeToolTab == 2,
                      onTap: () => setState(() => _activeToolTab = 2),
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

// =========================================================================
// استوديو تحرير الفيديو المتكامل
// =========================================================================
class _ProVideoStudioScreen extends StatefulWidget {
  final File videoFile;
  const _ProVideoStudioScreen({required this.videoFile});

  @override
  State<_ProVideoStudioScreen> createState() => _ProVideoStudioScreenState();
}

class _ProVideoStudioScreenState extends State<_ProVideoStudioScreen> {
  late VideoPlayerController _controller;
  bool _ready = false;
  int _studioTab = 0;
  double _startSec = 0.0;
  double _endSec = 10.0;
  double _totalSec = 10.0;

  Rect _videoCropRect = const Rect.fromLTWH(0, 0, 1, 1);
  int _aspectIdx = 0;
  double _videoAngleDeg = 0.0;
  bool _flipVideoH = false;

  static const List<String> _aspectLabels = ['حر', 'أصلي', '1:1', '4:3', '3:4', '9:16'];
  static const List<double?> _aspectValues = [null, null, 1.0, 4 / 3, 3 / 4, 9 / 16];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _controller = VideoPlayerController.file(widget.videoFile);
    await _controller.initialize();
    final secs = (_controller.value.duration.inMilliseconds / 1000.0)
        .clamp(1.0, double.infinity);
    await _controller.play();
    _controller.addListener(() {
      if (!mounted) return;
      final cur = _controller.value.position.inMilliseconds / 1000.0;
      if (cur >= _endSec) {
        _controller.seekTo(Duration(milliseconds: (_startSec * 1000).toInt()));
      }
      setState(() {});
    });
    if (mounted) {
      setState(() {
        _totalSec = secs;
        _endSec = secs;
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

  Future<void> _exportAudio() async {
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
        const SnackBar(content: Text('تم استخراج الصوت وحفظه في مكتبة صوتيات الثعلب ✓')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPosSec = _ready
        ? (_controller.value.position.inMilliseconds / 1000.0).clamp(0.0, _totalSec)
        : 0.0;
    final rad = _videoAngleDeg * math.pi / 180.0;
    final scaleFix = 1.0 + (_videoAngleDeg.abs() / 45.0) * 0.42;

    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101010),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('استوديو تحرير الفيديو',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          TextButton.icon(
            onPressed: () {
              final cropPctW = (_videoCropRect.width * 100).round();
              final cropPctH = (_videoCropRect.height * 100).round();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'تم حفظ إعدادات الفيديو: المدة (${_fmtSec(_startSec)} - ${_fmtSec(_endSec)}) • الإطار ($cropPctW%×$cropPctH%) ✓',
                  ),
                ),
              );
              Navigator.pop(context);
            },
            icon: const Icon(Icons.check_rounded, color: ThalabTheme.foxOrange),
            label: const Text(
              'تم',
              style: TextStyle(
                color: ThalabTheme.foxOrange,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator(color: ThalabTheme.foxOrange))
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: _controller.value.aspectRatio == 0
                            ? 16 / 9
                            : _controller.value.aspectRatio,
                        child: _studioTab == 1
                            ? _InteractiveCropFrame(
                                normalizedRect: _videoCropRect,
                                lockedAspectRatio: _aspectValues[_aspectIdx],
                                onRectChanged: (r) => setState(() => _videoCropRect = r),
                                child: ClipRect(
                                  child: Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()
                                      ..scale(_flipVideoH ? -scaleFix : scaleFix, scaleFix)
                                      ..rotateZ(rad),
                                    child: VideoPlayer(_controller),
                                  ),
                                ),
                              )
                            : ClipRect(
                                child: Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()
                                    ..scale(_flipVideoH ? -scaleFix : scaleFix, scaleFix)
                                    ..rotateZ(rad),
                                  child: VideoPlayer(_controller),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_fmtSec(currentPosSec)} / ${_fmtSec(_totalSec)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      IconButton(
                        icon: Icon(
                          _controller.value.isPlaying
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_filled_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                        onPressed: () {
                          _controller.value.isPlaying
                              ? _controller.pause()
                              : _controller.play();
                        },
                      ),
                      IconButton(
                        tooltip: 'إعادة من بداية التحديد',
                        icon: const Icon(Icons.replay_rounded, color: Colors.white70, size: 22),
                        onPressed: () {
                          _controller.seekTo(Duration(milliseconds: (_startSec * 1000).toInt()));
                          _controller.play();
                        },
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_studioTab == 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _TimeBadge(label: 'البداية', time: _fmtSec(_startSec)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: ThalabTheme.foxOrange.withOpacity(0.16),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'المدة: ${_fmtSec(_endSec - _startSec)}',
                                style: const TextStyle(
                                  color: ThalabTheme.foxOrange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            _TimeBadge(label: 'النهاية', time: _fmtSec(_endSec)),
                          ],
                        ),
                        const SizedBox(height: 12),

                        _FilmstripTimelineTrimmer(
                          totalSeconds: _totalSec,
                          startSeconds: _startSec,
                          endSeconds: _endSec,
                          currentSeconds: currentPosSec,
                          onChanged: (newStart, newEnd) {
                            setState(() {
                              _startSec = newStart;
                              _endSec = newEnd;
                            });
                            _controller.seekTo(Duration(milliseconds: (newStart * 1000).toInt()));
                          },
                        ),
                        const SizedBox(height: 14),

                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                              minimumSize: const Size(0, 44),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: _exportAudio,
                            icon: const Icon(Icons.audiotrack_rounded,
                                color: ThalabTheme.foxOrange, size: 19),
                            label: const Text('استخراج الصوت كملف مستقل (M4A)'),
                          ),
                        ),
                      ] else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              tooltip: 'إعادة الإطار',
                              icon: const Icon(Icons.crop_free_rounded, color: Colors.white),
                              onPressed: () => setState(() {
                                _videoCropRect = const Rect.fromLTWH(0, 0, 1, 1);
                                _videoAngleDeg = 0;
                                _flipVideoH = false;
                              }),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                '${_videoAngleDeg.round()}°',
                                style: const TextStyle(
                                  color: ThalabTheme.foxOrange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'قلب أفقي',
                              icon: const Icon(Icons.flip_rounded, color: Colors.white),
                              onPressed: () => setState(() => _flipVideoH = !_flipVideoH),
                            ),
                          ],
                        ),
                        Slider(
                          value: _videoAngleDeg,
                          min: -45,
                          max: 45,
                          activeColor: ThalabTheme.foxOrange,
                          inactiveColor: Colors.white24,
                          onChanged: (v) => setState(() => _videoAngleDeg = v),
                        ),
                        SizedBox(
                          height: 36,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _aspectLabels.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, idx) {
                              final active = _aspectIdx == idx;
                              return ChoiceChip(
                                label: Text(
                                  _aspectLabels[idx],
                                  style: TextStyle(
                                    color: active ? Colors.white : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                selected: active,
                                selectedColor: ThalabTheme.foxOrange,
                                backgroundColor: const Color(0xFF282828),
                                onSelected: (_) {
                                  setState(() {
                                    _aspectIdx = idx;
                                    if (idx == 0 || idx == 1) {
                                      _videoCropRect = const Rect.fromLTWH(0, 0, 1, 1);
                                    } else {
                                      _videoCropRect = const Rect.fromLTWH(0.12, 0.12, 0.76, 0.76);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _ToolTabBtn(
                            icon: Icons.content_cut_rounded,
                            label: 'قص المدة (Timeline)',
                            selected: _studioTab == 0,
                            onTap: () => setState(() => _studioTab = 0),
                          ),
                          _ToolTabBtn(
                            icon: Icons.crop_rounded,
                            label: 'قص أطراف الفيديو',
                            selected: _studioTab == 1,
                            onTap: () => setState(() => _studioTab = 1),
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

class _FilmstripTimelineTrimmer extends StatelessWidget {
  final double totalSeconds;
  final double startSeconds;
  final double endSeconds;
  final double currentSeconds;
  final void Function(double start, double end) onChanged;

  const _FilmstripTimelineTrimmer({
    required this.totalSeconds,
    required this.startSeconds,
    required this.endSeconds,
    required this.currentSeconds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        const handleW = 18.0;
        final usableW = (w - handleW * 2).clamp(1.0, double.infinity);

        final startX = (startSeconds / totalSeconds) * usableW;
        final endX = (endSeconds / totalSeconds) * usableW;
        final playheadX = handleW + (currentSeconds / totalSeconds) * usableW;

        return SizedBox(
          height: 54,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: handleW),
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    18,
                    (_) => Container(width: 1.5, height: 22, color: Colors.white12),
                  ),
                ),
              ),

              Positioned(
                left: startX,
                width: (endX - startX + handleW * 2).clamp(handleW * 2, w),
                height: 50,
                child: Container(
                  decoration: BoxDecoration(
                    color: ThalabTheme.foxOrange.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ThalabTheme.foxOrange, width: 2.5),
                  ),
                ),
              ),

              Positioned(
                left: playheadX.clamp(handleW, w - handleW),
                child: Container(
                  width: 2.5,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 3)],
                  ),
                ),
              ),

              Positioned(
                left: startX,
                width: handleW + 8,
                height: 50,
                child: GestureDetector(
                  onHorizontalDragUpdate: (d) {
                    final deltaSec = (d.delta.dx / usableW) * totalSeconds;
                    final nextStart = (startSeconds + deltaSec).clamp(0.0, endSeconds - 1.0);
                    onChanged(nextStart, endSeconds);
                  },
                  child: Container(
                    decoration: const BoxDecoration(
                      color: ThalabTheme.foxOrange,
                      borderRadius: BorderRadius.horizontal(left: Radius.circular(10)),
                    ),
                    child: const Icon(Icons.drag_indicator_rounded,
                        color: Colors.white, size: 15),
                  ),
                ),
              ),

              Positioned(
                left: endX + handleW - 8,
                width: handleW + 8,
                height: 50,
                child: GestureDetector(
                  onHorizontalDragUpdate: (d) {
                    final deltaSec = (d.delta.dx / usableW) * totalSeconds;
                    final nextEnd = (endSeconds + deltaSec).clamp(startSeconds + 1.0, totalSeconds);
                    onChanged(startSeconds, nextEnd);
                  },
                  child: Container(
                    decoration: const BoxDecoration(
                      color: ThalabTheme.foxOrange,
                      borderRadius: BorderRadius.horizontal(right: Radius.circular(10)),
                    ),
                    child: const Icon(Icons.drag_indicator_rounded,
                        color: Colors.white, size: 15),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TimeBadge extends StatelessWidget {
  final String label;
  final String time;
  const _TimeBadge({required this.label, required this.time});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label: ', style: const TextStyle(color: Colors.white60, fontSize: 12)),
        Text(time,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}

class _ToolTabBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToolTabBtn({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = selected ? ThalabTheme.foxOrange : Colors.white60;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: c, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            activeColor: ThalabTheme.foxOrange,
            inactiveColor: Colors.white24,
            onChanged: onChanged,
          ),
        ),
      ],
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
