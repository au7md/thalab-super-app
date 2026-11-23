import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
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
  final int initialTabIndex;
  const MusicStudioScreen({super.key, this.initialTabIndex = 0});

  @override
  State<MusicStudioScreen> createState() => _MusicStudioScreenState();
}

class _MusicStudioScreenState extends State<MusicStudioScreen>
    with SingleTickerProviderStateMixin {
  static const MethodChannel _studioChannel =
      MethodChannel('com.au7md.thalab_app/audio_studio');

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

    // 1. التسجيلات الصوتية المحلية
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

    // 2. الصوتيات المستخرجة من الفيديوهات
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

    // 3. جلب كل صوتيات وموسيقى الجهاز مباشرة من MediaStore
    try {
      final rawList = await _studioChannel.invokeMethod<List<dynamic>>('getDeviceAudios');
      if (rawList != null) {
        for (final item in rawList) {
          if (item is Map) {
            final path = item['path']?.toString() ?? '';
            if (path.isEmpty) continue;
            collected.add(
              ThalabAudioTrack(
                id: item['id']?.toString() ?? path,
                title: item['title']?.toString() ?? 'ملف صوتي',
                subtitle: item['artist']?.toString() ?? 'مكتبة الجهاز',
                path: path,
                durationSeconds: (item['durationSec'] as int?) ?? 0,
                sourceType: 'device',
              ),
            );
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

  Future<void> _openAudioEditor(ThalabAudioTrack track) async {
    if (_isPlaying) await _player.pause();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AudioTrimmerStudioScreen(
          filePath: track.path,
          initialTitle: track.title,
        ),
      ),
    );
    await _loadAudioLibrary();
  }

  Future<void> _renameTrack(ThalabAudioTrack track) async {
    final ctrl = TextEditingController(text: track.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThalabTheme.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('إعادة تسمية الملف',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
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
            ),
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty) {
                try {
                  final f = File(track.path);
                  final ext = track.path.contains('.')
                      ? track.path.substring(track.path.lastIndexOf('.'))
                      : '.m4a';
                  final newPath = '${f.parent.path}/$newName$ext';
                  await f.rename(newPath);
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadAudioLibrary();
                } catch (_) {
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTrack(ThalabAudioTrack track) async {
    try {
      final f = File(track.path);
      if (await f.exists()) {
        await f.delete();
      }
      if (_currentIndex >= 0 &&
          _currentIndex < _allTracks.length &&
          _allTracks[_currentIndex].id == track.id) {
        await _player.stop();
        setState(() => _currentIndex = -1);
      }
      await _loadAudioLibrary();
    } catch (_) {}
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
                const SizedBox(height: 14),
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
                      tooltip: 'قص وتحرير المقطع الصوتي',
                      icon: const Icon(Icons.content_cut_rounded,
                          color: ThalabTheme.foxOrange),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openAudioEditor(track);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                RotationTransition(
                  turns: _discController,
                  child: Container(
                    width: 185,
                    height: 185,
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
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: ThalabTheme.creamBackground,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.music_note_rounded,
                            color: ThalabTheme.foxOrange, size: 30),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

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
                            style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            track.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: ThalabTheme.mutedSlate, fontSize: 12),
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
                const SizedBox(height: 10),

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
                const SizedBox(height: 14),

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
              : 'الموسيقى والصوتيات (${_allTracks.length})',
        ),
        actions: [
          IconButton(
            tooltip: 'تحديث المكتبة',
            icon: const Icon(Icons.refresh_rounded, color: ThalabTheme.foxOrange),
            onPressed: _loadAudioLibrary,
          ),
          IconButton(
            tooltip: 'مؤقت النوم',
            icon: Icon(
              Icons.bedtime_rounded,
              color: _sleepMinutesLeft > 0 ? ThalabTheme.foxOrange : ThalabTheme.mutedSlate,
            ),
            onPressed: _openSleepTimerSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: ThalabTheme.foxOrange))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TopAudioActionCard(
                          title: 'مسجل الصوت',
                          subtitle: 'تسجيل وقص وتحرير',
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

                Expanded(
                  child: (_selectedTab == 2 && _selectedPlaylistName == null)
                      ? _buildPlaylistsView()
                      : visibleTracks.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'لا توجد ملفات صوتية مطابقة',
                                    style: TextStyle(color: ThalabTheme.mutedSlate),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: _loadAudioLibrary,
                                    icon: const Icon(Icons.refresh_rounded,
                                        color: ThalabTheme.foxOrange),
                                    label: const Text('إعادة فحص صوتيات الجهاز',
                                        style: TextStyle(color: ThalabTheme.foxOrange)),
                                  ),
                                ],
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
                                        horizontal: 12, vertical: 10),
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
                                        PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert_rounded,
                                              size: 20, color: ThalabTheme.mutedSlate),
                                          onSelected: (val) {
                                            if (val == 'trim') _openAudioEditor(track);
                                            if (val == 'playlist') _openAddToPlaylistSheet(track);
                                            if (val == 'rename') _renameTrack(track);
                                            if (val == 'share') Share.shareXFiles([XFile(track.path)]);
                                            if (val == 'delete') _deleteTrack(track);
                                          },
                                          itemBuilder: (_) => [
                                            const PopupMenuItem(
                                              value: 'trim',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.content_cut_rounded,
                                                      color: ThalabTheme.foxOrange, size: 19),
                                                  SizedBox(width: 8),
                                                  Text('قص وتحرير المقطع'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'playlist',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.playlist_add_rounded, size: 19),
                                                  SizedBox(width: 8),
                                                  Text('إضافة لقائمة تشغيل'),
                                                ],
                                              ),
                                            ),
                                            if (track.sourceType != 'device')
                                              const PopupMenuItem(
                                                value: 'rename',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.edit_rounded, size: 19),
                                                    SizedBox(width: 8),
                                                    Text('إعادة تسمية'),
                                                  ],
                                                ),
                                              ),
                                            const PopupMenuItem(
                                              value: 'share',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.share_rounded, size: 19),
                                                  SizedBox(width: 8),
                                                  Text('مشاركة'),
                                                ],
                                              ),
                                            ),
                                            if (track.sourceType != 'device')
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.delete_outline_rounded,
                                                        color: Colors.redAccent, size: 19),
                                                    SizedBox(width: 8),
                                                    Text('حذف',
                                                        style: TextStyle(color: Colors.redAccent)),
                                                  ],
                                                ),
                                              ),
                                          ],
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
// استوديو مسجل الصوت المتكامل (موجات حية + علامات مرجعية + قائمة التسجيلات + القص الفوري)
// =========================================================================
class _ProVoiceRecorderScreen extends StatefulWidget {
  const _ProVoiceRecorderScreen();

  @override
  State<_ProVoiceRecorderScreen> createState() => _ProVoiceRecorderScreenState();
}

class _ProVoiceRecorderScreenState extends State<_ProVoiceRecorderScreen> {
  static const MethodChannel _studioChannel =
      MethodChannel('com.au7md.thalab_app/audio_studio');

  final AudioPlayer _previewPlayer = AudioPlayer();
  String? _playingRecPath;
  bool _isPreviewPlaying = false;

  bool _isRecording = false;
  bool _isPaused = false;
  int _elapsedMs = 0;
  Timer? _timer;
  final List<double> _waveBars = List<double>.filled(30, 0.18);
  final List<int> _bookmarksSec = [];
  List<File> _savedRecordings = [];

  @override
  void initState() {
    super.initState();
    _loadSavedRecordings();
    _previewPlayer.playerStateStream.listen((st) {
      if (mounted) {
        setState(() {
          _isPreviewPlaying = st.playing;
          if (st.processingState == ProcessingState.completed) {
            _playingRecPath = null;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _previewPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadSavedRecordings() async {
    final dir = await getApplicationDocumentsDirectory();
    final recDir = Directory('${dir.path}/voice_recordings');
    if (await recDir.exists()) {
      final list = recDir.listSync().whereType<File>().toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      if (mounted) setState(() => _savedRecordings = list);
    }
  }

  Future<void> _startRecording() async {
    if (_isPreviewPlaying) await _previewPlayer.stop();
    final granted =
        await _studioChannel.invokeMethod<bool>('hasRecordPermission') ?? false;
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

    final ok = await _studioChannel.invokeMethod<bool>('startRecord', {'path': path}) ?? false;
    if (ok && mounted) {
      setState(() {
        _isRecording = true;
        _isPaused = false;
        _elapsedMs = 0;
        _bookmarksSec.clear();
      });
      _timer = Timer.periodic(const Duration(milliseconds: 120), (t) async {
        if (!mounted || _isPaused) return;
        final amp = await _studioChannel.invokeMethod<double>('getAmplitude') ?? 0.2;
        if (!mounted) return;
        setState(() {
          _elapsedMs += 120;
          _waveBars.removeAt(0);
          _waveBars.add(amp);
        });
      });
    }
  }

  Future<void> _togglePause() async {
    if (!_isRecording) return;
    if (_isPaused) {
      await _studioChannel.invokeMethod('resumeRecord');
      setState(() => _isPaused = false);
    } else {
      await _studioChannel.invokeMethod('pauseRecord');
      setState(() => _isPaused = true);
    }
  }

  Future<void> _stopAndSave() async {
    _timer?.cancel();
    final savedPath = await _studioChannel.invokeMethod<String>('stopRecord');
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isPaused = false;
      });
      await _loadSavedRecordings();
      if (savedPath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ التسجيل بنجاح — يمكنك قصّه أو مشاركته بالأسفل ✓')),
        );
      }
    }
  }

  Future<void> _discardCurrentRecording() async {
    _timer?.cancel();
    final path = await _studioChannel.invokeMethod<String>('stopRecord');
    if (path != null) {
      final f = File(path);
      if (await f.exists()) await f.delete();
    }
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isPaused = false;
        _elapsedMs = 0;
        _bookmarksSec.clear();
      });
    }
  }

  String _fmtMs(int ms) {
    final totalSec = ms ~/ 1000;
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    final tenths = (ms % 1000) ~/ 100;
    return '$m:$s.$tenths';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استوديو التسجيل وتحرير الصوت')),
      body: Column(
        children: [
          // لوحة التسجيل العلوية
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ThalabTheme.cardSurface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: ThalabTheme.softBorder, width: 1.5),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: ThalabTheme.foxOrange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _isRecording
                        ? (_isPaused ? 'متوقف مؤقتاً' : '● جاري التسجيل الصوتي الحي')
                        : 'جاهز للتسجيل بجودة عالية (AAC / M4A)',
                    style: const TextStyle(
                      color: ThalabTheme.foxOrange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _fmtMs(_elapsedMs),
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 14),

                // الموجات الصوتية التفاعلية الحقيقية
                SizedBox(
                  height: 54,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _waveBars.map((val) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: 4,
                        height: _isRecording && !_isPaused ? (52 * val).clamp(8.0, 52.0) : 10,
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

                if (_bookmarksSec.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    children: _bookmarksSec
                        .map((s) => Chip(
                              avatar: const Icon(Icons.flag_rounded,
                                  size: 14, color: ThalabTheme.foxOrange),
                              label: Text('${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 11)),
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 18),

                // أزرار التحكم بالتسجيل (إلغاء | إيقاف مؤقت | تسجيل/حفظ | علامة مرجعية)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (_isRecording)
                      IconButton(
                        tooltip: 'إلغاء وحذف التسجيل الحالي',
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: Colors.redAccent, size: 28),
                        onPressed: _discardCurrentRecording,
                      ),
                    if (_isRecording)
                      IconButton(
                        tooltip: _isPaused ? 'استئناف' : 'إيقاف مؤقت',
                        icon: Icon(
                          _isPaused
                              ? Icons.play_circle_filled_rounded
                              : Icons.pause_circle_filled_rounded,
                          color: ThalabTheme.darkSlate,
                          size: 38,
                        ),
                        onPressed: _togglePause,
                      ),
                    GestureDetector(
                      onTap: _isRecording ? _stopAndSave : _startRecording,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: _isRecording ? Colors.redAccent : ThalabTheme.foxOrange,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (_isRecording ? Colors.redAccent : ThalabTheme.foxOrange)
                                  .withOpacity(0.32),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isRecording ? Icons.check_rounded : Icons.mic_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                    if (_isRecording)
                      IconButton(
                        tooltip: 'إضافة علامة مرجعية',
                        icon: const Icon(Icons.flag_rounded,
                            color: ThalabTheme.foxOrange, size: 28),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() => _bookmarksSec.add(_elapsedMs ~/ 1000));
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),

          // قائمة التسجيلات المحفوظة مع أزرار القص الفوري والحذف والمشاركة
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'التسجيلات المحفوظة (${_savedRecordings.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
                const Text(
                  'اضغط مقص للتحرير وقص الأطراف',
                  style: TextStyle(color: ThalabTheme.mutedSlate, fontSize: 11),
                ),
              ],
            ),
          ),
          Expanded(
            child: _savedRecordings.isEmpty
                ? const Center(
                    child: Text('لا توجد تسجيلات محفوظة بعد',
                        style: TextStyle(color: ThalabTheme.mutedSlate)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                    itemCount: _savedRecordings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final file = _savedRecordings[idx];
                      final title = file.path.split('/').last.replaceAll('.m4a', '');
                      final isThisPlaying =
                          _playingRecPath == file.path && _isPreviewPlaying;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: ThalabTheme.cardSurface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: ThalabTheme.softBorder),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                isThisPlaying
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_filled_rounded,
                                color: ThalabTheme.foxOrange,
                                size: 34,
                              ),
                              onPressed: () async {
                                if (isThisPlaying) {
                                  await _previewPlayer.pause();
                                } else {
                                  setState(() => _playingRecPath = file.path);
                                  await _previewPlayer.setFilePath(file.path);
                                  await _previewPlayer.play();
                                }
                              },
                            ),
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            IconButton(
                              tooltip: 'قص أطراف أو حذف مقطع',
                              icon: const Icon(Icons.content_cut_rounded,
                                  color: ThalabTheme.foxOrange, size: 21),
                              onPressed: () async {
                                if (_isPreviewPlaying) await _previewPlayer.stop();
                                if (!context.mounted) return;
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AudioTrimmerStudioScreen(
                                      filePath: file.path,
                                      initialTitle: title,
                                    ),
                                  ),
                                );
                                await _loadSavedRecordings();
                              },
                            ),
                            IconButton(
                              tooltip: 'مشاركة',
                              icon: const Icon(Icons.share_rounded,
                                  color: ThalabTheme.mutedSlate, size: 20),
                              onPressed: () => Share.shareXFiles([XFile(file.path)]),
                            ),
                            IconButton(
                              tooltip: 'حذف',
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: Colors.redAccent, size: 20),
                              onPressed: () async {
                                if (await file.exists()) await file.delete();
                                await _loadSavedRecordings();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// استوديو قص وتحرير الصوتيات (قص الأطراف + حذف/استبعاد مقطع من المنتصف)
// =========================================================================
class AudioTrimmerStudioScreen extends StatefulWidget {
  final String filePath;
  final String initialTitle;

  const AudioTrimmerStudioScreen({
    super.key,
    required this.filePath,
    required this.initialTitle,
  });

  @override
  State<AudioTrimmerStudioScreen> createState() => _AudioTrimmerStudioScreenState();
}

class _AudioTrimmerStudioScreenState extends State<AudioTrimmerStudioScreen> {
  static const MethodChannel _studioChannel =
      MethodChannel('com.au7md.thalab_app/audio_studio');

  final AudioPlayer _player = AudioPlayer();
  bool _isReady = false;
  bool _isPlaying = false;
  bool _isProcessing = false;
  String _editMode = 'keep'; // 'keep' = قص الأطراف (الإبقاء على المحدد), 'cut' = حذف المقطع المحدد من المنتصف

  double _totalSec = 10.0;
  double _startSec = 0.0;
  double _endSec = 10.0;
  double _currentSec = 0.0;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    await _player.setFilePath(widget.filePath);
    final dur = _player.duration ?? const Duration(seconds: 10);
    final secs = (dur.inMilliseconds / 1000.0).clamp(1.0, double.infinity);

    _player.playerStateStream.listen((st) {
      if (mounted) setState(() => _isPlaying = st.playing);
    });
    _player.positionStream.listen((pos) {
      if (!mounted) return;
      final cur = pos.inMilliseconds / 1000.0;
      if (_editMode == 'keep' && cur >= _endSec && _isPlaying) {
        _player.seek(Duration(milliseconds: (_startSec * 1000).toInt()));
      }
      setState(() => _currentSec = cur.clamp(0.0, _totalSec));
    });

    if (mounted) {
      setState(() {
        _totalSec = secs;
        _endSec = secs;
        _isReady = true;
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(double s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final rem = (s.toInt() % 60).toString().padLeft(2, '0');
    return '$m:$rem';
  }

  Future<void> _applyAudioEdit({required bool overwriteOriginal}) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await _player.stop();
      final srcFile = File(widget.filePath);
      final dir = await getApplicationDocumentsDirectory();
      final outDir = Directory('${dir.path}/voice_recordings');
      if (!await outDir.exists()) await outDir.create(recursive: true);

      final tempOut =
          '${outDir.path}/${widget.initialTitle}_معدل_${DateTime.now().millisecondsSinceEpoch}.m4a';

      final ok = await _studioChannel.invokeMethod<bool>('processAudioEdit', {
            'srcPath': widget.filePath,
            'dstPath': tempOut,
            'mode': _editMode,
            'startMs': (_startSec * 1000).toInt(),
            'endMs': (_endSec * 1000).toInt(),
          }) ??
          false;

      if (ok) {
        if (overwriteOriginal && await srcFile.exists()) {
          await srcFile.delete();
          await File(tempOut).rename(widget.filePath);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _editMode == 'keep'
                    ? 'تم قص أطراف الصوت وحفظه بنجاح ✓'
                    : 'تم حذف المقطع المحدد ودمج الصوت بنجاح ✓',
              ),
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر معالجة هذا التنسيق، جرب ملف M4A أو MP3')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('قص وتحرير المقطع الصوتي')),
      body: !_isReady
          ? const Center(child: CircularProgressIndicator(color: ThalabTheme.foxOrange))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: ThalabTheme.cardSurface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: ThalabTheme.softBorder),
                    ),
                    child: Column(
                      children: [
                        Text(
                          widget.initialTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 14),

                        // اختيار وضع القص: قص الأطراف أو حذف مقطع من المنتصف
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(
                                  child: Text('قص الأطراف (إبقاء المحدد)',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                ),
                                selected: _editMode == 'keep',
                                selectedColor: ThalabTheme.foxOrange,
                                labelStyle: TextStyle(
                                  color: _editMode == 'keep' ? Colors.white : ThalabTheme.darkSlate,
                                ),
                                onSelected: (_) => setState(() => _editMode = 'keep'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(
                                  child: Text('حذف المقطع المحدد',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                ),
                                selected: _editMode == 'cut',
                                selectedColor: Colors.redAccent,
                                labelStyle: TextStyle(
                                  color: _editMode == 'cut' ? Colors.white : ThalabTheme.darkSlate,
                                ),
                                onSelected: (_) => setState(() => _editMode = 'cut'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('البداية: ${_fmt(_startSec)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                            Text(
                              _editMode == 'keep'
                                  ? 'المتبقي: ${_fmt(_endSec - _startSec)}'
                                  : 'المحذوف: ${_fmt(_endSec - _startSec)}',
                              style: TextStyle(
                                color: _editMode == 'keep'
                                    ? ThalabTheme.foxOrange
                                    : Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                            Text('النهاية: ${_fmt(_endSec)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                          ],
                        ),
                        RangeSlider(
                          values: RangeValues(_startSec, _endSec),
                          min: 0.0,
                          max: _totalSec,
                          activeColor: _editMode == 'keep'
                              ? ThalabTheme.foxOrange
                              : Colors.redAccent,
                          onChanged: (vals) {
                            setState(() {
                              _startSec = vals.start;
                              _endSec = vals.end;
                            });
                            _player.seek(Duration(milliseconds: (vals.start * 1000).toInt()));
                          },
                        ),
                        const SizedBox(height: 8),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              iconSize: 44,
                              icon: Icon(
                                _isPlaying
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_filled_rounded,
                                color: ThalabTheme.foxOrange,
                              ),
                              onPressed: () {
                                if (_isPlaying) {
                                  _player.pause();
                                } else {
                                  _player.seek(
                                      Duration(milliseconds: (_startSec * 1000).toInt()));
                                  _player.play();
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'معاينة (${_fmt(_currentSec)})',
                              style: const TextStyle(color: ThalabTheme.mutedSlate, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (_isProcessing)
                    const CircularProgressIndicator(color: ThalabTheme.foxOrange)
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ThalabTheme.foxOrange,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 50),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () => _applyAudioEdit(overwriteOriginal: false),
                          icon: const Icon(Icons.save_as_rounded),
                          label: const Text('حفظ كنسخة جديدة في المكتبة',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        if (widget.filePath.contains('voice_recordings')) ...[
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              side: const BorderSide(color: ThalabTheme.foxOrange),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () => _applyAudioEdit(overwriteOriginal: true),
                            icon: const Icon(Icons.check_circle_outline_rounded,
                                color: ThalabTheme.foxOrange),
                            label: const Text('تطبيق التعديل واستبدال الأصلي',
                                style: TextStyle(
                                    color: ThalabTheme.foxOrange,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
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
