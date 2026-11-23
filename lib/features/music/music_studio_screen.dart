import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme.dart';

class ThalabAudioTrack {
  final String id;
  final String title;
  final String subtitle;
  final String path;
  final int durationSeconds;
  final String sourceType; // 'device', 'extracted', 'recording'

  const ThalabAudioTrack({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.path,
    required this.durationSeconds,
    required this.sourceType,
  });
}

class MusicStudioScreen extends StatefulWidget {
  final int initialTabIndex; // 0: الكل, 1: المفضلة, 2: قوائم التشغيل, 3: التسجيلات والمستخرج
  const MusicStudioScreen({super.key, this.initialTabIndex = 0});

  @override
  State<MusicStudioScreen> createState() => _MusicStudioScreenState();
}

class _MusicStudioScreenState extends State<MusicStudioScreen>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();
  late AnimationController _discController;
  final TextEditingController _searchController = TextEditingController();

  int _selectedTab = 0;
  String _searchQuery = '';
  bool _isLoading = true;

  List<ThalabAudioTrack> _allTracks = [];
  Set<String> _favoriteIds = {};
  Map<String, List<String>> _playlists = {};
  String? _selectedPlaylistName;

  int _currentIndex = -1;
  bool _isPlaying = false;
  bool _isShuffle = false;
  LoopMode _loopMode = LoopMode.off;
  double _playbackSpeed = 1.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  Timer? _sleepTimer;
  int _sleepMinutesLeft = 0;

  static const List<String> _tabs = [
    'كل الصوتيات',
    'المفضلة',
    'قوائم التشغيل',
    'التسجيلات والمستخرج',
  ];

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTabIndex.clamp(0, _tabs.length - 1);
    _discController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
    _bindPlayerStreams();
    _loadAudioLibrary();
  }

  void _bindPlayerStreams() {
    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      final playing = state.playing;
      setState(() => _isPlaying = playing);
      if (playing) {
        _discController.repeat();
      } else {
        _discController.stop();
      }
      if (state.processingState == ProcessingState.completed) {
        _handleTrackCompleted();
      }
    });

    _player.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });

    _player.durationStream.listen((dur) {
      if (mounted && dur != null) setState(() => _duration = dur);
    });
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _discController.dispose();
    _searchController.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadAudioLibrary() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final savedFavs = prefs.getStringList('audio_favorite_ids') ?? [];
    final rawPlaylists = prefs.getString('audio_custom_playlists');
    final Map<String, List<String>> decodedPlaylists = {};
    if (rawPlaylists != null && rawPlaylists.isNotEmpty) {
      try {
        final map = jsonDecode(rawPlaylists) as Map<String, dynamic>;
        map.forEach((k, v) {
          decodedPlaylists[k] = List<String>.from(v as List);
        });
      } catch (_) {}
    }

    final List<ThalabAudioTrack> collected = [];
    final dir = await getApplicationDocumentsDirectory();

    // 1. جلب التسجيلات الصوتية المحلية
    final recDir = Directory('${dir.path}/voice_recordings');
    if (await recDir.exists()) {
      final files = recDir.listSync().whereType<File>().toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      for (final f in files) {
        final name = f.path.split('/').last.replaceAll('.m4a', '');
        collected.add(
          ThalabAudioTrack(
            id: f.path,
            title: name,
            subtitle: 'تسجيل صوتي • استوديو الثعلب',
            path: f.path,
            durationSeconds: 0,
            sourceType: 'recording',
          ),
        );
      }
    }

    // 2. جلب الصوتيات المستخرجة من الفيديوهات
    final extDir = Directory('${dir.path}/extracted_audios');
    if (await extDir.exists()) {
      final files = extDir.listSync().whereType<File>().toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      for (final f in files) {
        final name = f.path.split('/').last.replaceAll('.m4a', '');
        collected.add(
          ThalabAudioTrack(
            id: f.path,
            title: name,
            subtitle: 'مستخرج من فيديو • المعرض',
            path: f.path,
            durationSeconds: 0,
            sourceType: 'extracted',
          ),
        );
      }
    }

    // 3. جلب صوتيات وموسيقى الجهاز
    try {
      final ps = await PhotoManager.requestPermissionExtend();
      if (ps.isAuth || ps.hasAccess) {
        final paths = await PhotoManager.getAssetPathList(
          type: RequestType.audio,
          filterOption: FilterOptionGroup(
            orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
          ),
        );
        if (paths.isNotEmpty) {
          final total = await paths.first.assetCountAsync;
          final count = total > 400 ? 400 : total;
          if (count > 0) {
            final assets = await paths.first.getAssetListRange(start: 0, end: count);
            for (final asset in assets) {
              final f = await asset.file;
              if (f != null) {
                final rawTitle = (asset.title ?? f.path.split('/').last)
                    .replaceAll(RegExp(r'\.(mp3|m4a|wav|aac|ogg|flac)$', caseSensitive: false), '');
                collected.add(
                  ThalabAudioTrack(
                    id: asset.id,
                    title: rawTitle,
                    subtitle: asset.relativePath ?? 'مكتبة الجهاز الصوتية',
                    path: f.path,
                    durationSeconds: asset.duration,
                    sourceType: 'device',
                  ),
                );
              }
            }
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _favoriteIds = savedFavs.toSet();
        _playlists = decodedPlaylists;
        _allTracks = collected;
        _isLoading = false;
      });
    }
  }

  List<ThalabAudioTrack> get _filteredTracks {
    List<ThalabAudioTrack> base;
    if (_selectedTab == 1) {
      base = _allTracks.where((t) => _favoriteIds.contains(t.id)).toList();
    } else if (_selectedTab == 2 && _selectedPlaylistName != null) {
      final ids = _playlists[_selectedPlaylistName!] ?? [];
      base = _allTracks.where((t) => ids.contains(t.id)).toList();
    } else if (_selectedTab == 3) {
      base = _allTracks
          .where((t) => t.sourceType == 'recording' || t.sourceType == 'extracted')
          .toList();
    } else {
      base = _allTracks;
    }

    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return base;
    return base
        .where((t) =>
            t.title.toLowerCase().contains(q) || t.subtitle.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _playTrackAt(int indexInAll) async {
    if (indexInAll < 0 || indexInAll >= _allTracks.length) return;
    final track = _allTracks[indexInAll];
    try {
      setState(() => _currentIndex = indexInAll);
      await _player.setFilePath(track.path);
      await _player.setSpeed(_playbackSpeed);
      await _player.play();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تشغيل هذا الملف الصوتي')),
        );
      }
    }
  }

  void _handleTrackCompleted() {
    if (_loopMode == LoopMode.one) {
      _player.seek(Duration.zero);
      _player.play();
      return;
    }
    _playNext();
  }

  void _playNext() {
    if (_allTracks.isEmpty) return;
    if (_isShuffle) {
      final next = math.Random().nextInt(_allTracks.length);
      _playTrackAt(next);
      return;
    }
    if (_currentIndex + 1 < _allTracks.length) {
      _playTrackAt(_currentIndex + 1);
    } else if (_loopMode == LoopMode.all) {
      _playTrackAt(0);
    }
  }

  void _playPrevious() {
    if (_allTracks.isEmpty) return;
    if (_position.inSeconds > 4) {
      _player.seek(Duration.zero);
      return;
    }
    if (_currentIndex > 0) {
      _playTrackAt(_currentIndex - 1);
    }
  }

  Future<void> _toggleFavorite(String id) async {
    HapticFeedback.selectionClick();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favoriteIds.contains(id)) {
        _favoriteIds.remove(id);
      } else {
        _favoriteIds.add(id);
      }
    });
    await prefs.setStringList('audio_favorite_ids', _favoriteIds.toList());
  }

  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('audio_custom_playlists', jsonEncode(_playlists));
  }

  void _openCreatePlaylistDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThalabTheme.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('قائمة تشغيل جديدة',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: 'مثال: تلاوات خاشعة، تركيز، سفر...',
            filled: true,
            fillColor: ThalabTheme.creamBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: ThalabTheme.mutedSlate)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ThalabTheme.foxOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                setState(() => _playlists.putIfAbsent(name, () => []));
                await _savePlaylists();
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
  }

  void _openAddToPlaylistSheet(ThalabAudioTrack track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ThalabTheme.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('إضافة إلى قائمة تشغيل',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openCreatePlaylistDialog();
                  },
                  icon: const Icon(Icons.add_rounded, color: ThalabTheme.foxOrange),
                  label: const Text('جديدة', style: TextStyle(color: ThalabTheme.foxOrange)),
                ),
              ],
            ),
            if (_playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('لا توجد قوائم تشغيل بعد — أنشئ قائمة جديدة الآن',
                    style: TextStyle(color: ThalabTheme.mutedSlate)),
              )
            else
              ..._playlists.keys.map((plName) {
                final exists = _playlists[plName]!.contains(track.id);
                return ListTile(
                  leading: Icon(
                    exists ? Icons.check_circle_rounded : Icons.queue_music_rounded,
                    color: ThalabTheme.foxOrange,
                  ),
                  title: Text(plName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${_playlists[plName]!.length} مقطع'),
                  onTap: () async {
                    setState(() {
                      if (exists) {
                        _playlists[plName]!.remove(track.id);
                      } else {
                        _playlists[plName]!.add(track.id);
                      }
                    });
                    await _savePlaylists();
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                );
              }),
          ],
        ),
      ),
    );
  }

  void _startSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    if (minutes <= 0) {
      setState(() => _sleepMinutesLeft = 0);
      return;
    }
    setState(() => _sleepMinutesLeft = minutes);
    _sleepTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _sleepMinutesLeft--);
      if (_sleepMinutesLeft <= 0) {
        timer.cancel();
        _player.pause();
      }
    });
  }

  void _openSleepTimerSheet() {
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
          children: [
            const Text('مؤقت النوم التلقائي',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('إيقاف التشغيل تلقائياً بعد المدة المحددة',
                style: TextStyle(color: ThalabTheme.mutedSlate, fontSize: 12.5)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [0, 15, 30, 45, 60].map((mins) {
                final active = _sleepMinutesLeft == mins;
                return ChoiceChip(
                  label: Text(
                    mins == 0 ? 'إيقاف المؤقت' : '$mins دقيقة',
                    style: TextStyle(
                      color: active ? Colors.white : ThalabTheme.darkSlate,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  selected: active,
                  selectedColor: ThalabTheme.foxOrange,
                  onSelected: (_) {
                    _startSleepTimer(mins);
                    Navigator.pop(ctx);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullPlayerSheet() {
    if (_currentIndex < 0 || _currentIndex >= _allTracks.length) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThalabTheme.creamBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final track = _allTracks[_currentIndex];
          final isFav = _favoriteIds.contains(track.id);
          final maxMs = _duration.inMilliseconds.toDouble().clamp(1.0, double.infinity);
          final posMs = _position.inMilliseconds.toDouble().clamp(0.0, maxMs);

          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 34),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ThalabTheme.softBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    const Text('استوديو الصوت • الثعلب',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    IconButton(
                      tooltip: 'مؤقت النوم',
                      icon: Icon(
                        Icons.bedtime_rounded,
                        color: _sleepMinutesLeft > 0
                            ? ThalabTheme.foxOrange
                            : ThalabTheme.mutedSlate,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openSleepTimerSheet();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // الأسطوانة الصوتية الدوارة
                RotationTransition(
                  turns: _discController,
                  child: Container(
                    width: 195,
                    height: 195,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [ThalabTheme.foxOrange, ThalabTheme.foxOrangeLight],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ThalabTheme.foxOrange.withOpacity(0.32),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: ThalabTheme.creamBackground,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.music_note_rounded,
                            color: ThalabTheme.foxOrange, size: 32),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // عنوان المقطع وأزرار المفضلة والقائمة والمشاركة
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            track.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: ThalabTheme.mutedSlate, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isFav ? Colors.redAccent : ThalabTheme.mutedSlate,
                      ),
                      onPressed: () async {
                        await _toggleFavorite(track.id);
                        setSheetState(() {});
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.playlist_add_rounded,
                          color: ThalabTheme.foxOrange),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openAddToPlaylistSheet(track);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: ThalabTheme.mutedSlate),
                      onPressed: () => Share.shareXFiles([XFile(track.path)]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // شريط التقدم الزمني
                Slider(
                  value: posMs,
                  min: 0,
                  max: maxMs,
                  activeColor: ThalabTheme.foxOrange,
                  inactiveColor: ThalabTheme.softBorder,
                  onChanged: (v) {
                    _player.seek(Duration(milliseconds: v.toInt()));
                    setSheetState(() {});
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmtDur(_position),
                          style: const TextStyle(fontSize: 11.5, color: ThalabTheme.mutedSlate)),
                      if (_sleepMinutesLeft > 0)
                        Text('مؤقت النوم: $_sleepMinutesLeft د',
                            style: const TextStyle(
                                fontSize: 11,
                                color: ThalabTheme.foxOrange,
                                fontWeight: FontWeight.bold)),
                      Text(_fmtDur(_duration),
                          style: const TextStyle(fontSize: 11.5, color: ThalabTheme.mutedSlate)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // أزرار التحكم الرئيسية
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.shuffle_rounded,
                        color: _isShuffle ? ThalabTheme.foxOrange : ThalabTheme.mutedSlate,
                      ),
                      onPressed: () {
                        setState(() => _isShuffle = !_isShuffle);
                        setSheetState(() {});
                      },
                    ),
                    IconButton(
                      iconSize: 34,
                      icon: const Icon(Icons.skip_previous_rounded),
                      onPressed: () {
                        _playPrevious();
                        setSheetState(() {});
                      },
                    ),
                    GestureDetector(
                      onTap: () {
                        _isPlaying ? _player.pause() : _player.play();
                        setSheetState(() {});
                      },
                      child: Container(
                        width: 66,
                        height: 66,
                        decoration: const BoxDecoration(
                          color: ThalabTheme.foxOrange,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),
                    IconButton(
                      iconSize: 34,
                      icon: const Icon(Icons.skip_next_rounded),
                      onPressed: () {
                        _playNext();
                        setSheetState(() {});
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        _loopMode == LoopMode.one
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        color: _loopMode != LoopMode.off
                            ? ThalabTheme.foxOrange
                            : ThalabTheme.mutedSlate,
                      ),
                      onPressed: () {
                        setState(() {
                          if (_loopMode == LoopMode.off) {
                            _loopMode = LoopMode.all;
                          } else if (_loopMode == LoopMode.all) {
                            _loopMode = LoopMode.one;
                          } else {
                            _loopMode = LoopMode.off;
                          }
                        });
                        setSheetState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // شريط السرعة السريع
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [0.75, 1.0, 1.25, 1.5, 2.0].map((sp) {
                    final active = _playbackSpeed == sp;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(
                          '${sp}x',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: active ? Colors.white : ThalabTheme.darkSlate,
                          ),
                        ),
                        selected: active,
                        selectedColor: ThalabTheme.foxOrange,
                        onSelected: (_) async {
                          setState(() => _playbackSpeed = sp);
                          await _player.setSpeed(sp);
                          setSheetState(() {});
                        },
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openVoiceRecorder() async {
    if (_isPlaying) await _player.pause();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _ProVoiceRecorderScreen()),
    );
    await _loadAudioLibrary();
  }

  void _openFocusRelaxSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ThalabTheme.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.spa_rounded, color: ThalabTheme.foxOrange),
                SizedBox(width: 8),
                Text('وضع التركيز والاسترخاء السريع',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'اختر وضعاً لتشغيل مؤقت تركيز هادئ مع إيقاف تلقائي للصوتيات:',
              style: TextStyle(fontSize: 12.5, color: ThalabTheme.mutedSlate),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.1,
              children: [
                _RelaxPresetCard(
                  title: 'جلسة تركيز (25 د)',
                  icon: Icons.bolt_rounded,
                  onTap: () {
                    _startSleepTimer(25);
                    Navigator.pop(ctx);
                  },
                ),
                _RelaxPresetCard(
                  title: 'استماع قبل النوم (30 د)',
                  icon: Icons.nights_stay_rounded,
                  onTap: () {
                    _startSleepTimer(30);
                    Navigator.pop(ctx);
                  },
                ),
                _RelaxPresetCard(
                  title: 'قراءة هادئة (45 د)',
                  icon: Icons.menu_book_rounded,
                  onTap: () {
                    _startSleepTimer(45);
                    Navigator.pop(ctx);
                  },
                ),
                _RelaxPresetCard(
                  title: 'تشغيل عشوائي مستمر',
                  icon: Icons.shuffle_rounded,
                  onTap: () {
                    setState(() {
                      _isShuffle = true;
                      _loopMode = LoopMode.all;
                    });
                    if (_allTracks.isNotEmpty) _playTrackAt(0);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDur(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _fmtSec(int sec) {
    if (sec <= 0) return 'M4A';
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final visibleTracks = _filteredTracks;
    final hasActiveTrack = _currentIndex >= 0 && _currentIndex < _allTracks.length;

    return Scaffold(
      appBar: AppBar(
        leading: (_selectedTab == 2 && _selectedPlaylistName != null)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _selectedPlaylistName = null),
              )
            : null,
        title: Text(
          (_selectedTab == 2 && _selectedPlaylistName != null)
              ? _selectedPlaylistName!
              : 'الموسيقى والصوتيات',
        ),
        actions: [
          IconButton(
            tooltip: 'مؤقت النوم',
            icon: Icon(
              Icons.bedtime_rounded,
              color: _sleepMinutesLeft > 0 ? ThalabTheme.foxOrange : ThalabTheme.mutedSlate,
            ),
            onPressed: _openSleepTimerSheet,
          ),
          IconButton(
            tooltip: 'مسجل الصوت الاحترافي',
            icon: const Icon(Icons.mic_rounded, color: ThalabTheme.foxOrange),
            onPressed: _openVoiceRecorder,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: ThalabTheme.foxOrange))
          : Column(
              children: [
                // بطاقتا الاختصار العلويتان (مسجل الصوت + وضع الاسترخاء والتركيز)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TopAudioActionCard(
                          title: 'مسجل الصوت',
                          subtitle: 'تسجيل M4A نقي',
                          icon: Icons.mic_rounded,
                          onTap: _openVoiceRecorder,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TopAudioActionCard(
                          title: 'وضع الاسترخاء',
                          subtitle: _sleepMinutesLeft > 0
                              ? 'مؤقت نشط: $_sleepMinutesLeft د'
                              : 'مؤقت النوم والتركيز',
                          icon: Icons.spa_rounded,
                          onTap: _openFocusRelaxSheet,
                        ),
                      ),
                    ],
                  ),
                ),

                // شريط البحث الفوري
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'ابحث في الصوتيات والتسجيلات...',
                      hintStyle:
                          const TextStyle(fontSize: 12.5, color: ThalabTheme.mutedSlate),
                      prefixIcon:
                          const Icon(Icons.search_rounded, color: ThalabTheme.foxOrange),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: ThalabTheme.cardSurface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: ThalabTheme.softBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: ThalabTheme.softBorder),
                      ),
                    ),
                  ),
                ),

                // شريط التبويبات
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _tabs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final active = _selectedTab == idx;
                      return ChoiceChip(
                        label: Text(
                          _tabs[idx],
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: active ? Colors.white : ThalabTheme.darkSlate,
                          ),
                        ),
                        selected: active,
                        selectedColor: ThalabTheme.foxOrange,
                        backgroundColor: ThalabTheme.cardSurface,
                        onSelected: (_) {
                          setState(() {
                            _selectedTab = idx;
                            _selectedPlaylistName = null;
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // محتوى التبويب (قوائم التشغيل أو قائمة المقاطع)
                Expanded(
                  child: (_selectedTab == 2 && _selectedPlaylistName == null)
                      ? _buildPlaylistsView()
                      : visibleTracks.isEmpty
                          ? Center(
                              child: Text(
                                _selectedTab == 1
                                    ? 'لا توجد مقاطع في المفضلة بعد'
                                    : 'لا توجد ملفات صوتية مطابقة',
                                style: const TextStyle(color: ThalabTheme.mutedSlate),
                              ),
                            )
                          : ListView.separated(
                              padding: EdgeInsets.fromLTRB(
                                  16, 4, 16, hasActiveTrack ? 175 : 115),
                              itemCount: visibleTracks.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, idx) {
                                final track = visibleTracks[idx];
                                final indexInAll =
                                    _allTracks.indexWhere((t) => t.id == track.id);
                                final isCurrent = indexInAll == _currentIndex;
                                final isFav = _favoriteIds.contains(track.id);

                                return InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () => _playTrackAt(indexInAll),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 11),
                                    decoration: BoxDecoration(
                                      color: isCurrent
                                          ? ThalabTheme.foxOrange.withOpacity(0.1)
                                          : ThalabTheme.cardSurface,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: isCurrent
                                            ? ThalabTheme.foxOrange
                                            : ThalabTheme.softBorder,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: ThalabTheme.foxOrange.withOpacity(0.14),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Icon(
                                            isCurrent && _isPlaying
                                                ? Icons.graphic_eq_rounded
                                                : track.sourceType == 'recording'
                                                    ? Icons.mic_rounded
                                                    : Icons.music_note_rounded,
                                            color: ThalabTheme.foxOrange,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                track.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13.5,
                                                  color: isCurrent
                                                      ? ThalabTheme.foxOrange
                                                      : ThalabTheme.darkSlate,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${track.subtitle} • ${_fmtSec(track.durationSeconds)}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: ThalabTheme.mutedSlate,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            isFav
                                                ? Icons.favorite_rounded
                                                : Icons.favorite_border_rounded,
                                            size: 20,
                                            color: isFav
                                                ? Colors.redAccent
                                                : ThalabTheme.mutedSlate,
                                          ),
                                          onPressed: () => _toggleFavorite(track.id),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.playlist_add_rounded,
                                              size: 20, color: ThalabTheme.mutedSlate),
                                          onPressed: () => _openAddToPlaylistSheet(track),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
      // المشغل المصغر العائم فوق شريط التنقل السفلي
      bottomSheet: hasActiveTrack
          ? GestureDetector(
              onTap: _openFullPlayerSheet,
              child: Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 92),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: ThalabTheme.darkSlate,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ThalabTheme.foxOrange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.music_note_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _allTracks[_currentIndex].title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '${_fmtDur(_position)} / ${_fmtDur(_duration)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () => _isPlaying ? _player.pause() : _player.play(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded,
                          color: Colors.white, size: 26),
                      onPressed: _playNext,
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildPlaylistsView() {
    final names = _playlists.keys.toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            side: const BorderSide(color: ThalabTheme.foxOrange),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _openCreatePlaylistDialog,
          icon: const Icon(Icons.add_rounded, color: ThalabTheme.foxOrange),
          label: const Text(
            'إنشاء قائمة تشغيل مخصصة جديدة',
            style: TextStyle(color: ThalabTheme.foxOrange, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        if (names.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Text('لا توجد قوائم تشغيل بعد',
                  style: TextStyle(color: ThalabTheme.mutedSlate)),
            ),
          )
        else
          ...names.map((name) {
            final count = _playlists[name]!.length;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: ThalabTheme.cardSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: ThalabTheme.softBorder),
              ),
              child: ListTile(
                leading: const Icon(Icons.queue_music_rounded,
                    color: ThalabTheme.foxOrange, size: 28),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('$count مقطع صوتي'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  onPressed: () async {
                    setState(() => _playlists.remove(name));
                    await _savePlaylists();
                  },
                ),
                onTap: () => setState(() => _selectedPlaylistName = name),
              ),
            );
          }),
      ],
    );
  }
}

// =========================================================================
// شاشة مسجل الصوت الاحترافي (Native Android MediaRecorder + الموجات الحية)
// =========================================================================
class _ProVoiceRecorderScreen extends StatefulWidget {
  const _ProVoiceRecorderScreen();

  @override
  State<_ProVoiceRecorderScreen> createState() => _ProVoiceRecorderScreenState();
}

class _ProVoiceRecorderScreenState extends State<_ProVoiceRecorderScreen> {
  static const MethodChannel _recChannel =
      MethodChannel('com.au7md.thalab_app/voice_recorder');

  bool _isRecording = false;
  bool _isPaused = false;
  int _elapsedSeconds = 0;
  Timer? _timer;
  String? _currentFilePath;
  final List<double> _waveBars = List<double>.filled(28, 0.2);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final granted = await _recChannel.invokeMethod<bool>('hasPermission') ?? false;
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى السماح بصلاحية الميكروفون ثم الضغط مرة أخرى')),
        );
      }
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final recDir = Directory('${dir.path}/voice_recordings');
    if (!await recDir.exists()) {
      await recDir.create(recursive: true);
    }
    final now = DateTime.now();
    final label =
        'تسجيل_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}';
    final path = '${recDir.path}/$label.m4a';

    final ok = await _recChannel.invokeMethod<bool>('start', {'path': path}) ?? false;
    if (ok && mounted) {
      setState(() {
        _isRecording = true;
        _isPaused = false;
        _elapsedSeconds = 0;
        _currentFilePath = path;
      });
      _timer = Timer.periodic(const Duration(milliseconds: 250), (t) {
        if (!mounted || _isPaused) return;
        setState(() {
          if (t.tick % 4 == 0) _elapsedSeconds++;
          _waveBars.removeAt(0);
          _waveBars.add(0.2 + math.Random().nextDouble() * 0.8);
        });
      });
    }
  }

  Future<void> _togglePause() async {
    if (!_isRecording) return;
    if (_isPaused) {
      await _recChannel.invokeMethod('resume');
      setState(() => _isPaused = false);
    } else {
      await _recChannel.invokeMethod('pause');
      setState(() => _isPaused = true);
    }
  }

  Future<void> _stopAndSave() async {
    _timer?.cancel();
    await _recChannel.invokeMethod('stop');
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isPaused = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حفظ التسجيل الصوتي بنجاح (${_fmt(_elapsedSeconds)}) ✓'),
        ),
      );
      Navigator.pop(context);
    }
  }

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final rem = (s % 60).toString().padLeft(2, '0');
    return '$m:$rem';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مسجل الصوت الاحترافي')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: ThalabTheme.foxOrange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                _isRecording
                    ? (_isPaused ? 'التسجيل متوقف مؤقتاً' : 'جاري التسجيل الصوتي...')
                    : 'جاهز للتسجيل بجودة عالية (AAC / M4A)',
                style: const TextStyle(
                  color: ThalabTheme.foxOrange,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              _fmt(_elapsedSeconds),
              style: const TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 28),

            // مؤشر الموجات الصوتية الحية
            SizedBox(
              height: 68,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _waveBars.map((val) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    width: 4.5,
                    height: _isRecording && !_isPaused ? 64 * val : 14,
                    decoration: BoxDecoration(
                      color: _isRecording
                          ? ThalabTheme.foxOrange
                          : ThalabTheme.softBorder,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 44),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (_isRecording)
                  FloatingActionButton(
                    heroTag: 'pause_rec',
                    backgroundColor: ThalabTheme.cardSurface,
                    onPressed: _togglePause,
                    child: Icon(
                      _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      color: ThalabTheme.foxOrange,
                      size: 30,
                    ),
                  ),
                GestureDetector(
                  onTap: _isRecording ? _stopAndSave : _startRecording,
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.redAccent : ThalabTheme.foxOrange,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isRecording ? Colors.redAccent : ThalabTheme.foxOrange)
                              .withOpacity(0.32),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ],
            ),
            if (_currentFilePath != null && _isRecording) ...[
              const SizedBox(height: 20),
              const Text(
                'اضغط زر الإيقاف الأحمر لحفظ التسجيل في مكتبتك',
                style: TextStyle(color: ThalabTheme.mutedSlate, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopAudioActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _TopAudioActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: ThalabTheme.cardSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ThalabTheme.softBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: ThalabTheme.foxOrange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: ThalabTheme.foxOrange, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: ThalabTheme.mutedSlate, fontSize: 10.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RelaxPresetCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _RelaxPresetCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ThalabTheme.creamBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ThalabTheme.softBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: ThalabTheme.foxOrange, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
