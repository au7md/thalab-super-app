// lib/features/music/music_studio_screen.dart

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
  final String folder;
  final String path;
  final int durationSeconds;
  final int dateAdded;
  final String sourceType;

  const ThalabAudioTrack({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.folder,
    required this.path,
    required this.durationSeconds,
    required this.dateAdded,
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
  String _sortBy = 'newest';
  bool _isLoading = true;

  List<ThalabAudioTrack> _allTracks = [];
  Set<String> _favoriteIds = {};
  Map<String, List<String>> _playlists = {};
  String? _selectedPlaylistName;
  String? _selectedFolderName;

  final Set<String> _selectedTrackIds = {};
  bool get _isSelectionMode => _selectedTrackIds.isNotEmpty;

  int _currentIndex = -1;
  bool _isPlaying = false;
  bool _isShuffle = false;
  LoopMode _loopMode = LoopMode.off;
  double _playbackSpeed = 1.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  int _lastPersistedSec = -1;

  Timer? _sleepTimer;
  int _sleepSecondsLeft = 0;
  String _activeRelaxLabel = '';

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _cardBg => Theme.of(context).cardColor;
  Color get _innerBg => Theme.of(context).scaffoldBackgroundColor;
  Color get _borderColor => _isDark ? ThalabTheme.darkBorder : ThalabTheme.softBorder;
  Color get _textColor => _isDark ? ThalabTheme.darkTextPrimary : ThalabTheme.darkSlate;

  static const List<String> _tabs = [
    'كل الصوتيات',
    'المجلدات',
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
    _studioChannel.setMethodCallHandler((call) async {
      if (call.method == 'onMediaAction') {
        if (call.arguments is Map) {
          final map = call.arguments as Map;
          final action = map['action']?.toString() ?? '';
          if (action == 'seekTo') {
            final posMs = (map['positionMs'] as num?)?.toInt() ?? 0;
            await _player.seek(Duration(milliseconds: posMs));
            _pushMediaNotification();
          }
          return;
        }
        final action = call.arguments?.toString() ?? '';
        if (action == 'play_pause') {
          _isPlaying ? _player.pause() : _player.play();
        } else if (action == 'next') {
          _playNext();
        } else if (action == 'prev') {
          _playPrevious();
        } else if (action == 'rewind_10') {
          final target = (_position.inSeconds - 10).clamp(0, 99999);
          await _player.seek(Duration(seconds: target));
          _pushMediaNotification();
        } else if (action == 'forward_10') {
          await _player.seek(Duration(seconds: _position.inSeconds + 10));
          _pushMediaNotification();
        }
      }
    });
    _bindPlayerStreams();
    _loadAudioLibrary(restoreLastSession: true);
  }

  void _pushMediaNotification() {
    if (_currentIndex < 0 || _currentIndex >= _allTracks.length) return;
    final track = _allTracks[_currentIndex];
    _studioChannel.invokeMethod('updateMediaNotification', {
      'title': track.title,
      'subtitle': track.subtitle,
      'isPlaying': _isPlaying,
      'durationMs': _duration.inMilliseconds,
      'positionMs': _position.inMilliseconds,
    });
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
        _savePlaybackCheckpoint();
      }
      _pushMediaNotification();
      if (state.processingState == ProcessingState.completed) {
        _handleTrackCompleted();
      }
    });

    _player.positionStream.listen((pos) {
      if (!mounted) return;
      setState(() => _position = pos);
      if (pos.inSeconds != _lastPersistedSec && pos.inSeconds % 5 == 0) {
        _lastPersistedSec = pos.inSeconds;
        _savePlaybackCheckpoint();
      }
    });

    _player.durationStream.listen((dur) {
      if (mounted && dur != null) setState(() => _duration = dur);
    });
  }

  @override
  void dispose() {
    _savePlaybackCheckpoint();
    _sleepTimer?.cancel();
    _discController.dispose();
    _searchController.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _savePlaybackCheckpoint() async {
    if (_currentIndex < 0 || _currentIndex >= _allTracks.length) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_audio_path', _allTracks[_currentIndex].path);
    await prefs.setInt('last_audio_pos_ms', _position.inMilliseconds);
  }

  Future<void> _restoreLastPlaybackSession() async {
    final prefs = await SharedPreferences.getInstance();
    final lastPath = prefs.getString('last_audio_path');
    final lastPosMs = prefs.getInt('last_audio_pos_ms') ?? 0;
    if (lastPath == null || lastPath.isEmpty || _allTracks.isEmpty) return;

    final idx = _allTracks.indexWhere((t) => t.path == lastPath);
    if (idx != -1 && mounted) {
      setState(() {
        _currentIndex = idx;
        _position = Duration(milliseconds: lastPosMs);
      });
      try {
        await _player.setFilePath(_allTracks[idx].path);
        await _player.seek(Duration(milliseconds: lastPosMs));
      } catch (_) {}
    }
  }

  Future<void> _loadAudioLibrary({bool restoreLastSession = false}) async {
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
    final Set<String> seenPaths = {};
    final dir = await getApplicationDocumentsDirectory();

    final recDir = Directory('${dir.path}/voice_recordings');
    if (await recDir.exists()) {
      final files = recDir.listSync().whereType<File>().toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      for (final f in files) {
        if (!seenPaths.add(f.path)) continue;
        final name = f.path.split('/').last.replaceAll('.m4a', '');
        collected.add(
          ThalabAudioTrack(
            id: f.path,
            title: name,
            subtitle: 'تسجيل صوتي • استوديو الثعلب',
            folder: 'Thalab Recordings',
            path: f.path,
            durationSeconds: 0,
            dateAdded: f.lastModifiedSync().millisecondsSinceEpoch ~/ 1000,
            sourceType: 'recording',
          ),
        );
      }
    }

    final extDir = Directory('${dir.path}/extracted_audios');
    if (await extDir.exists()) {
      final files = extDir.listSync().whereType<File>().toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      for (final f in files) {
        if (!seenPaths.add(f.path)) continue;
        final name = f.path.split('/').last.replaceAll('.m4a', '');
        collected.add(
          ThalabAudioTrack(
            id: f.path,
            title: name,
            subtitle: 'مستخرج من فيديو • المعرض',
            folder: 'Thalab Extracted',
            path: f.path,
            durationSeconds: 0,
            dateAdded: f.lastModifiedSync().millisecondsSinceEpoch ~/ 1000,
            sourceType: 'extracted',
          ),
        );
      }
    }

    try {
      final rawList = await _studioChannel.invokeMethod<List<dynamic>>('getDeviceAudios');
      if (rawList != null) {
        for (final item in rawList) {
          if (item is Map) {
            final path = item['path']?.toString() ?? '';
            if (path.isEmpty || !seenPaths.add(path)) continue;
            final folder = item['folder']?.toString() ?? 'ملفات صوتية';
            final isThalabRec = folder == 'Thalab Recordings';
            collected.add(
              ThalabAudioTrack(
                id: item['id']?.toString() ?? path,
                title: item['title']?.toString() ?? 'ملف صوتي',
                subtitle: isThalabRec
                    ? 'تسجيلات الثعلب • Music'
                    : (item['artist']?.toString() ?? folder),
                folder: folder,
                path: path,
                durationSeconds: (item['durationSec'] as int?) ?? 0,
                dateAdded: (item['dateAdded'] as int?) ?? 0,
                sourceType: isThalabRec ? 'recording' : 'device',
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
      if (restoreLastSession) {
        await _restoreLastPlaybackSession();
      }
    }
  }

  Map<String, List<ThalabAudioTrack>> get _folderGroups {
    final Map<String, List<ThalabAudioTrack>> groups = {};
    for (final t in _allTracks) {
      groups.putIfAbsent(t.folder, () => []).add(t);
    }
    return groups;
  }

  List<ThalabAudioTrack> get _filteredTracks {
    List<ThalabAudioTrack> base;
    if (_selectedTab == 1 && _selectedFolderName != null) {
      base = _allTracks.where((t) => t.folder == _selectedFolderName).toList();
    } else if (_selectedTab == 2) {
      base = _allTracks.where((t) => _favoriteIds.contains(t.id)).toList();
    } else if (_selectedTab == 3 && _selectedPlaylistName != null) {
      final ids = _playlists[_selectedPlaylistName!] ?? [];
      base = _allTracks.where((t) => ids.contains(t.id)).toList();
    } else if (_selectedTab == 4) {
      base = _allTracks
          .where((t) => t.sourceType == 'recording' || t.sourceType == 'extracted')
          .toList();
    } else {
      base = List<ThalabAudioTrack>.from(_allTracks);
    }

    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      base = base
          .where((t) =>
              t.title.toLowerCase().contains(q) ||
              t.subtitle.toLowerCase().contains(q) ||
              t.folder.toLowerCase().contains(q))
          .toList();
    }

    if (_sortBy == 'name') {
      base.sort((a, b) => a.title.compareTo(b.title));
    } else if (_sortBy == 'duration') {
      base.sort((a, b) => b.durationSeconds.compareTo(a.durationSeconds));
    } else {
      base.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    }
    return base;
  }

  Future<void> _playTrackAt(int indexInAll) async {
    if (indexInAll < 0 || indexInAll >= _allTracks.length) return;
    final track = _allTracks[indexInAll];
    try {
      setState(() => _currentIndex = indexInAll);
      await _player.setFilePath(track.path);
      await _player.setSpeed(_playbackSpeed);
      await _player.play();
      _savePlaybackCheckpoint();
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

  void _toggleSelection(String id) {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_selectedTrackIds.contains(id)) {
        _selectedTrackIds.remove(id);
      } else {
        _selectedTrackIds.add(id);
      }
    });
  }

  Future<void> _shareSelectedTracks() async {
    final files = _allTracks
        .where((t) => _selectedTrackIds.contains(t.id))
        .map((t) => XFile(t.path))
        .toList();
    if (files.isEmpty) return;
    await Share.shareXFiles(files);
    setState(() => _selectedTrackIds.clear());
  }

  Future<void> _exportSelectedToMusicFolder() async {
    final targets = _allTracks.where((t) => _selectedTrackIds.contains(t.id)).toList();
    for (final t in targets) {
      await _studioChannel.invokeMethod('exportToMusicFolder', {
        'srcPath': t.path,
        'title': t.title,
        'subFolder': 'Thalab Recordings',
      });
    }
    setState(() => _selectedTrackIds.clear());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حفظ ${targets.length} ملف في مجلد Music/Thalab Recordings ✓')),
      );
    }
    await _loadAudioLibrary();
  }

  void _addSelectedToPlaylist() {
    final ids = _selectedTrackIds.toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
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
                Text('إضافة (${ids.length}) مقطع لقائمة تشغيل',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
            ..._playlists.keys.map((plName) => ListTile(
                  leading: const Icon(Icons.queue_music_rounded, color: ThalabTheme.foxOrange),
                  title: Text(plName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () async {
                    setState(() {
                      for (final id in ids) {
                        if (!_playlists[plName]!.contains(id)) {
                          _playlists[plName]!.add(id);
                        }
                      }
                      _selectedTrackIds.clear();
                    });
                    await _savePlaylists();
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
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
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('إعادة تسمية الملف',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            filled: true,
            fillColor: _innerBg,
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
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('قائمة تشغيل جديدة',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: 'مثال: تلاوات خاشعة، تركيز، سفر...',
            filled: true,
            fillColor: _innerBg,
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
      backgroundColor: _cardBg,
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

  void _startRelaxOrSleepSession(int minutes, String label, {bool autoPlay = true}) {
    _sleepTimer?.cancel();
    if (minutes <= 0) {
      setState(() {
        _sleepSecondsLeft = 0;
        _activeRelaxLabel = '';
      });
      return;
    }

    setState(() {
      _sleepSecondsLeft = minutes * 60;
      _activeRelaxLabel = label;
    });

    if (autoPlay && !_isPlaying && _allTracks.isNotEmpty) {
      final targetIdx = _currentIndex >= 0 ? _currentIndex : 0;
      _playTrackAt(targetIdx);
    }

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _sleepSecondsLeft--);
      if (_sleepSecondsLeft <= 0) {
        timer.cancel();
        _activeRelaxLabel = '';
        _player.pause();
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تفعيل "$label" ($minutes دقيقة) بنجاح ✓')),
      );
    }
  }

  void _openSleepTimerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
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
                final active = (_sleepSecondsLeft / 60).ceil() == mins &&
                    (mins == 0 ? _sleepSecondsLeft == 0 : _sleepSecondsLeft > 0);
                return ChoiceChip(
                  label: Text(
                    mins == 0 ? 'إيقاف المؤقت' : '$mins دقيقة',
                    style: TextStyle(
                      color: active ? Colors.white : _textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  selected: active,
                  selectedColor: ThalabTheme.foxOrange,
                  backgroundColor: _innerBg,
                  onSelected: (_) {
                    _startRelaxOrSleepSession(mins, 'مؤقت النوم', autoPlay: false);
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
      backgroundColor: _innerBg,
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
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _borderColor,
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
                    Column(
                      children: [
                        const Text('استوديو الصوت • الثعلب',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        Text(track.folder,
                            style: const TextStyle(
                                color: ThalabTheme.foxOrange, fontSize: 11)),
                      ],
                    ),
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
                const SizedBox(height: 18),

                RotationTransition(
                  turns: _discController,
                  child: Container(
                    width: 205,
                    height: 205,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ThalabTheme.foxOrange.withOpacity(0.12),
                      border: Border.all(
                          color: ThalabTheme.foxOrange.withOpacity(0.35), width: 2),
                    ),
                    child: Container(
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
                            blurRadius: 22,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            color: _innerBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.music_note_rounded,
                              color: ThalabTheme.foxOrange, size: 30),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),

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
                  inactiveColor: _borderColor,
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
                      if (_sleepSecondsLeft > 0)
                        Text('مؤقت نشط: ${_fmtSec(_sleepSecondsLeft)}',
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
                      iconSize: 30,
                      icon: const Icon(Icons.replay_10_rounded),
                      onPressed: () {
                        final target = (_position.inSeconds - 10).clamp(0, 99999);
                        _player.seek(Duration(seconds: target));
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
                        width: 68,
                        height: 68,
                        decoration: const BoxDecoration(
                          color: ThalabTheme.foxOrange,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 40,
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
                      iconSize: 30,
                      icon: const Icon(Icons.forward_10_rounded),
                      onPressed: () {
                        _player.seek(Duration(seconds: _position.inSeconds + 10));
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
                            color: active ? Colors.white : _textColor,
                          ),
                        ),
                        selected: active,
                        selectedColor: ThalabTheme.foxOrange,
                        backgroundColor: _cardBg,
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
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.spa_rounded, color: ThalabTheme.foxOrange),
                    SizedBox(width: 8),
                    Text('وضع التركيز والاسترخاء السريع',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  ],
                ),
                if (_sleepSecondsLeft > 0)
                  TextButton(
                    onPressed: () {
                      _startRelaxOrSleepSession(0, '');
                      Navigator.pop(ctx);
                    },
                    child: const Text('إيقاف المؤقت',
                        style: TextStyle(color: Colors.redAccent)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'يبدأ تشغيل صوتياتك تلقائياً مع مؤقت عد تنازلي لإيقاف الصوت بهدوء:',
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
                  isSelected: _sleepSecondsLeft > 0 && _activeRelaxLabel == 'جلسة تركيز',
                  onTap: () {
                    _startRelaxOrSleepSession(25, 'جلسة تركيز');
                    Navigator.pop(ctx);
                  },
                ),
                _RelaxPresetCard(
                  title: 'استماع قبل النوم (30 د)',
                  icon: Icons.nights_stay_rounded,
                  isSelected: _sleepSecondsLeft > 0 && _activeRelaxLabel == 'استماع قبل النوم',
                  onTap: () {
                    _startRelaxOrSleepSession(30, 'استماع قبل النوم');
                    Navigator.pop(ctx);
                  },
                ),
                _RelaxPresetCard(
                  title: 'قراءة هادئة (45 د)',
                  icon: Icons.menu_book_rounded,
                  isSelected: _sleepSecondsLeft > 0 && _activeRelaxLabel == 'قراءة هادئة',
                  onTap: () {
                    _startRelaxOrSleepSession(45, 'قراءة هادئة');
                    Navigator.pop(ctx);
                  },
                ),
                _RelaxPresetCard(
                  title: 'تشغيل عشوائي مستمر',
                  icon: Icons.shuffle_rounded,
                  isSelected: _isShuffle && _loopMode == LoopMode.all,
                  onTap: () {
                    setState(() {
                      _isShuffle = true;
                      _loopMode = LoopMode.all;
                    });
                    if (_allTracks.isNotEmpty) {
                      _playTrackAt(math.Random().nextInt(_allTracks.length));
                    }
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
      appBar: _isSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() => _selectedTrackIds.clear()),
              ),
              title: Text('تم تحديد ${_selectedTrackIds.length}'),
              actions: [
                IconButton(
                  tooltip: 'نقل/حفظ في مجلد Music',
                  icon: const Icon(Icons.drive_file_move_rounded,
                      color: ThalabTheme.foxOrange),
                  onPressed: _exportSelectedToMusicFolder,
                ),
                IconButton(
                  tooltip: 'إضافة لقائمة تشغيل',
                  icon: const Icon(Icons.playlist_add_rounded,
                      color: ThalabTheme.foxOrange),
                  onPressed: _addSelectedToPlaylist,
                ),
                IconButton(
                  tooltip: 'مشاركة المحدد',
                  icon: const Icon(Icons.share_rounded, color: ThalabTheme.foxOrange),
                  onPressed: _shareSelectedTracks,
                ),
              ],
            )
          : AppBar(
              leading: ((_selectedTab == 1 && _selectedFolderName != null) ||
                      (_selectedTab == 3 && _selectedPlaylistName != null))
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => setState(() {
                        _selectedFolderName = null;
                        _selectedPlaylistName = null;
                      }),
                    )
                  : null,
              title: Text(
                (_selectedTab == 1 && _selectedFolderName != null)
                    ? _selectedFolderName!
                    : (_selectedTab == 3 && _selectedPlaylistName != null)
                        ? _selectedPlaylistName!
                        : 'الموسيقى والصوتيات (${_allTracks.length})',
              ),
              actions: [
                PopupMenuButton<String>(
                  tooltip: 'ترتيب الصوتيات',
                  icon: const Icon(Icons.sort_rounded, color: ThalabTheme.foxOrange),
                  color: _cardBg,
                  onSelected: (v) => setState(() => _sortBy = v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'newest', child: Text('الترتيب: الأحدث إضافة')),
                    PopupMenuItem(value: 'name', child: Text('الترتيب: أبجدياً (أ - ي)')),
                    PopupMenuItem(value: 'duration', child: Text('الترتيب: الأطول مدة')),
                  ],
                ),
                IconButton(
                  tooltip: 'تحديث المكتبة',
                  icon: const Icon(Icons.refresh_rounded, color: ThalabTheme.foxOrange),
                  onPressed: _loadAudioLibrary,
                ),
                IconButton(
                  tooltip: 'مؤقت النوم',
                  icon: Icon(
                    Icons.bedtime_rounded,
                    color: _sleepSecondsLeft > 0
                        ? ThalabTheme.foxOrange
                        : ThalabTheme.mutedSlate,
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
                          subtitle: _sleepSecondsLeft > 0
                              ? '$_activeRelaxLabel • ${_fmtSec(_sleepSecondsLeft)}'
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
                      hintText: 'ابحث بالاسم أو المجلد أو التسجيل...',
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
                      fillColor: _cardBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: _borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: _borderColor),
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
                            color: active ? Colors.white : _textColor,
                          ),
                        ),
                        selected: active,
                        selectedColor: ThalabTheme.foxOrange,
                        backgroundColor: _cardBg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                            color: active ? ThalabTheme.foxOrange : _borderColor,
                          ),
                        ),
                        onSelected: (_) {
                          setState(() {
                            _selectedTab = idx;
                            _selectedFolderName = null;
                            _selectedPlaylistName = null;
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: (_selectedTab == 1 && _selectedFolderName == null)
                      ? _buildFoldersView()
                      : (_selectedTab == 3 && _selectedPlaylistName == null)
                          ? _buildPlaylistsView()
                          : visibleTracks.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'لا توجد ملفات صوتية في هذا القسم',
                                        style: TextStyle(color: ThalabTheme.mutedSlate),
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        onPressed: _loadAudioLibrary,
                                        icon: const Icon(Icons.refresh_rounded,
                                            color: ThalabTheme.foxOrange),
                                        label: const Text('إعادة فحص صوتيات الجهاز',
                                            style:
                                                TextStyle(color: ThalabTheme.foxOrange)),
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
                                    final isSelected = _selectedTrackIds.contains(track.id);

                                    return InkWell(
                                      borderRadius: BorderRadius.circular(18),
                                      onLongPress: () => _toggleSelection(track.id),
                                      onTap: () {
                                        if (_isSelectionMode) {
                                          _toggleSelection(track.id);
                                        } else {
                                          _playTrackAt(indexInAll);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? ThalabTheme.foxOrange.withOpacity(0.18)
                                              : isCurrent
                                                  ? ThalabTheme.foxOrange.withOpacity(0.1)
                                                  : _cardBg,
                                          borderRadius: BorderRadius.circular(18),
                                          border: Border.all(
                                            color: (isSelected || isCurrent)
                                                ? ThalabTheme.foxOrange
                                                : _borderColor,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color:
                                                    ThalabTheme.foxOrange.withOpacity(0.14),
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              child: Icon(
                                                isSelected
                                                    ? Icons.check_circle_rounded
                                                    : (isCurrent && _isPlaying)
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
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
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
                                                          : _textColor,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '${track.folder} • ${_fmtSec(track.durationSeconds)}',
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
                                                  size: 20,
                                                  color: ThalabTheme.mutedSlate),
                                              color: _cardBg,
                                              onSelected: (val) async {
                                                if (val == 'trim') _openAudioEditor(track);
                                                if (val == 'playlist') {
                                                  _openAddToPlaylistSheet(track);
                                                }
                                                if (val == 'export') {
                                                  await _studioChannel.invokeMethod(
                                                      'exportToMusicFolder', {
                                                    'srcPath': track.path,
                                                    'title': track.title,
                                                    'subFolder': 'Thalab Recordings',
                                                  });
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context)
                                                        .showSnackBar(
                                                      const SnackBar(
                                                          content: Text(
                                                              'تم الحفظ في Music/Thalab Recordings ✓')),
                                                    );
                                                  }
                                                }
                                                if (val == 'rename') _renameTrack(track);
                                                if (val == 'share') {
                                                  Share.shareXFiles([XFile(track.path)]);
                                                }
                                                if (val == 'delete') _deleteTrack(track);
                                              },
                                              itemBuilder: (_) => [
                                                const PopupMenuItem(
                                                  value: 'trim',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.content_cut_rounded,
                                                          color: ThalabTheme.foxOrange,
                                                          size: 19),
                                                      SizedBox(width: 8),
                                                      Text('قص وتحرير المقطع'),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'export',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.drive_file_move_rounded,
                                                          color: ThalabTheme.foxOrange,
                                                          size: 19),
                                                      SizedBox(width: 8),
                                                      Text('حفظ في مجلد Music'),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'playlist',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.playlist_add_rounded,
                                                          size: 19),
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
                                                            color: Colors.redAccent,
                                                            size: 19),
                                                        SizedBox(width: 8),
                                                        Text('حذف',
                                                            style: TextStyle(
                                                                color: Colors.redAccent)),
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
                  color: _isDark ? ThalabTheme.darkCardSurface : ThalabTheme.darkSlate,
                  borderRadius: BorderRadius.circular(22),
                  border: _isDark ? Border.all(color: ThalabTheme.darkBorder) : null,
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

  Widget _buildFoldersView() {
    final folders = _folderGroups.keys.toList();
    if (folders.isEmpty) {
      return const Center(
        child: Text('لا توجد مجلدات صوتية', style: TextStyle(color: ThalabTheme.mutedSlate)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 130),
      itemCount: folders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final folder = folders[idx];
        final count = _folderGroups[folder]!.length;
        return Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _borderColor),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ThalabTheme.foxOrange.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.folder_rounded, color: ThalabTheme.foxOrange),
            ),
            title: Text(folder, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('$count ملف صوتي'),
            trailing: const Icon(Icons.chevron_right_rounded, color: ThalabTheme.mutedSlate),
            onTap: () => setState(() => _selectedFolderName = folder),
          ),
        );
      },
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
                color: _cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _borderColor),
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
// المسجل الصوتي الاحترافي
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
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _uiTimer;
  Timer? _ampTimer;
  final List<double> _waveBars = List<double>.filled(32, 0.16);
  final List<int> _bookmarksSec = [];
  List<File> _savedRecordings = [];

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _cardBg => Theme.of(context).cardColor;
  Color get _borderColor => _isDark ? ThalabTheme.darkBorder : ThalabTheme.softBorder;
  Color get _textColor => _isDark ? ThalabTheme.darkTextPrimary : ThalabTheme.darkSlate;

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
    _uiTimer?.cancel();
    _ampTimer?.cancel();
    _stopwatch.stop();
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

    final ok = await _studioChannel.invokeMethod<bool>('startRecord', {
          'path': path,
          'title': label,
        }) ??
        false;

    if (ok && mounted) {
      _stopwatch.reset();
      _stopwatch.start();
      setState(() {
        _isRecording = true;
        _isPaused = false;
        _bookmarksSec.clear();
      });

      _uiTimer?.cancel();
      _uiTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (mounted && _isRecording && !_isPaused) {
          setState(() {});
        }
      });

      _ampTimer?.cancel();
      _ampTimer = Timer.periodic(const Duration(milliseconds: 120), (_) async {
        if (!mounted || !_isRecording || _isPaused) return;
        double amp = 0.25;
        try {
          amp = await _studioChannel.invokeMethod<double>('getAmplitude') ?? 0.25;
        } catch (_) {}
        if (mounted && _isRecording && !_isPaused) {
          setState(() {
            _waveBars.removeAt(0);
            _waveBars.add(amp.clamp(0.12, 1.0));
          });
        }
      });
    }
  }

  Future<void> _togglePause() async {
    if (!_isRecording) return;
    if (_isPaused) {
      await _studioChannel.invokeMethod('resumeRecord');
      _stopwatch.start();
      setState(() => _isPaused = false);
    } else {
      await _studioChannel.invokeMethod('pauseRecord');
      _stopwatch.stop();
      setState(() => _isPaused = true);
    }
  }

  Future<void> _stopAndSave() async {
    _uiTimer?.cancel();
    _ampTimer?.cancel();
    _stopwatch.stop();
    final savedPath = await _studioChannel.invokeMethod<String>('stopRecord');
    _stopwatch.reset();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isPaused = false;
      });
      await _loadSavedRecordings();
      if (savedPath != null && savedPath.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ التسجيل في مجلد الهاتف Music/Thalab Recordings ✓'),
          ),
        );
      }
    }
  }

  Future<void> _discardCurrentRecording() async {
    _uiTimer?.cancel();
    _ampTimer?.cancel();
    _stopwatch.stop();
    _stopwatch.reset();
    await _studioChannel.invokeMethod('cancelRecord');
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isPaused = false;
        _bookmarksSec.clear();
      });
    }
  }

  String _fmtStopwatch() {
    final ms = _stopwatch.elapsedMilliseconds;
    final totalSec = ms ~/ 1000;
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    final tenths = (ms % 1000) ~/ 100;
    return '$m:$s.$tenths';
  }

  String _formatFileDate(File f) {
    final dt = f.lastModifiedSync();
    final d =
        '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
    final t =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$d • $t';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استوديو التسجيل وتحرير الصوت')),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _borderColor, width: 1.5),
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
                        ? (_isPaused ? 'متوقف مؤقتاً' : '● جاري التسجيل والحفظ في Music')
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
                  _fmtStopwatch(),
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 54,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _waveBars.map((val) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 90),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: 4,
                        height:
                            _isRecording && !_isPaused ? (52 * val).clamp(8.0, 52.0) : 10,
                        decoration: BoxDecoration(
                          color: _isRecording ? ThalabTheme.foxOrange : _borderColor,
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
                              label: Text(
                                  '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 11)),
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 18),
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
                          color: _textColor,
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
                          setState(() => _bookmarksSec.add(_stopwatch.elapsed.inSeconds));
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.folder_special_rounded,
                        size: 18, color: ThalabTheme.foxOrange),
                    const SizedBox(width: 6),
                    Text(
                      'التسجيلات المحفوظة (${_savedRecordings.length})',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14.5),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'تُحفظ تلقائياً في مجلد الهاتف: Music/Thalab Recordings',
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: _cardBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _borderColor),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                isThisPlaying
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_filled_rounded,
                                color: ThalabTheme.foxOrange,
                                size: 36,
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatFileDate(file),
                                    style: const TextStyle(
                                        color: ThalabTheme.mutedSlate, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'استوديو القص والتحرير',
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
// استوديو التحرير المطور
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

  late String _workingPath;
  bool _hasEdits = false;

  double _totalSec = 10.0;
  double _startSec = 0.0;
  double _endSec = 10.0;
  double _currentSec = 0.0;
  String? _draggingHandle;

  late List<double> _waveHeights;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _cardBg => Theme.of(context).cardColor;
  Color get _borderColor => _isDark ? ThalabTheme.darkBorder : ThalabTheme.softBorder;

  @override
  void initState() {
    super.initState();
    _workingPath = widget.filePath;
    _generateWave();
    _initAudio(_workingPath);
  }

  void _generateWave() {
    final rng = math.Random(_workingPath.hashCode);
    _waveHeights = List<double>.generate(52, (_) => 0.18 + rng.nextDouble() * 0.82);
  }

  Future<void> _initAudio(String path) async {
    await _player.setFilePath(path);
    final dur = _player.duration ?? const Duration(seconds: 10);
    final secs = (dur.inMilliseconds / 1000.0).clamp(0.5, double.infinity);

    _player.playerStateStream.listen((st) {
      if (mounted) setState(() => _isPlaying = st.playing);
    });
    _player.positionStream.listen((pos) {
      if (!mounted) return;
      final cur = pos.inMilliseconds / 1000.0;
      if (cur >= _endSec && _isPlaying) {
        _player.seek(Duration(milliseconds: (_startSec * 1000).toInt()));
      }
      setState(() => _currentSec = cur.clamp(0.0, _totalSec));
    });

    if (mounted) {
      setState(() {
        _totalSec = secs;
        _startSec = 0.0;
        _endSec = secs;
        _currentSec = 0.0;
        _isReady = true;
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmtPrecise(double s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final rem = (s.toInt() % 60).toString().padLeft(2, '0');
    final hundredths = ((s * 100).toInt() % 100).toString().padLeft(2, '0');
    return '$m:$rem.$hundredths';
  }

  Future<void> _applyInstantEdit(String mode) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await _player.stop();
      final tempDir = await getTemporaryDirectory();
      final nextTemp =
          '${tempDir.path}/edit_${DateTime.now().millisecondsSinceEpoch}.m4a';

      final ok = await _studioChannel.invokeMethod<bool>('processAudioEdit', {
            'srcPath': _workingPath,
            'dstPath': nextTemp,
            'mode': mode,
            'startMs': (_startSec * 1000).toInt(),
            'endMs': (_endSec * 1000).toInt(),
          }) ??
          false;

      if (ok && mounted) {
        _workingPath = nextTemp;
        _hasEdits = true;
        _generateWave();
        await _initAudio(_workingPath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(mode == 'keep'
                  ? 'تم قص الأطراف للمعاينة — اضغط حفظ عند الانتهاء'
                  : 'تم حذف الجزء المحدد للمعاينة — اضغط حفظ عند الانتهاء'),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تنفيذ التعديل على هذا التنسيق')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveFinalFile() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await _player.stop();
      final dir = await getApplicationDocumentsDirectory();
      final outDir = Directory('${dir.path}/voice_recordings');
      if (!await outDir.exists()) await outDir.create(recursive: true);

      final outTitle =
          '${widget.initialTitle}_معدل_${DateTime.now().millisecondsSinceEpoch}';
      final finalPath = '${outDir.path}/$outTitle.m4a';
      await File(_workingPath).copy(finalPath);

      await _studioChannel.invokeMethod('exportToMusicFolder', {
        'srcPath': finalPath,
        'title': outTitle,
        'subFolder': 'Thalab Recordings',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم حفظ الملف النهائي في Music/Thalab Recordings ✓')),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final startRatio = (_startSec / _totalSec).clamp(0.0, 1.0);
    final endRatio = (_endSec / _totalSec).clamp(0.0, 1.0);
    final progressRatio = (_currentSec / _totalSec).clamp(0.0, 1.0);
    final selectedDuration = (_endSec - _startSec).clamp(0.0, _totalSec);

    return Scaffold(
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        ),
        leadingWidth: 70,
        title: const Text('تحرير وقص الصوت'),
        actions: [
          IconButton(
            tooltip: 'إعادة ضبط التحديد',
            icon: const Icon(Icons.restore_rounded, color: ThalabTheme.mutedSlate),
            onPressed: () {
              setState(() {
                _startSec = 0.0;
                _endSec = _totalSec;
              });
              _player.seek(Duration.zero);
            },
          ),
          TextButton(
            onPressed: _isProcessing ? null : _saveFinalFile,
            child: Text(
              _hasEdits ? 'حفظ ✓' : 'حفظ',
              style: const TextStyle(
                  color: ThalabTheme.foxOrange,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
          ),
        ],
      ),
      body: !_isReady
          ? const Center(child: CircularProgressIndicator(color: ThalabTheme.foxOrange))
          : Column(
              children: [
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TrimmerTimeBox(
                          label: 'البداية',
                          time: _fmtPrecise(_startSec),
                          cardBg: _cardBg,
                          borderColor: _borderColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _TrimmerTimeBox(
                          label: 'المحدد',
                          time: _fmtPrecise(selectedDuration),
                          cardBg: ThalabTheme.foxOrange.withOpacity(0.12),
                          borderColor: ThalabTheme.foxOrange,
                          highlight: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _TrimmerTimeBox(
                          label: 'النهاية',
                          time: _fmtPrecise(_endSec),
                          cardBg: _cardBg,
                          borderColor: _borderColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth - 32;
                    return GestureDetector(
                      onHorizontalDragStart: (d) {
                        final ratio = (d.localPosition.dx / width).clamp(0.0, 1.0);
                        final distStart = (ratio - startRatio).abs();
                        final distEnd = (ratio - endRatio).abs();
                        _draggingHandle = distStart <= distEnd ? 'start' : 'end';
                      },
                      onHorizontalDragUpdate: (d) {
                        final ratio = (d.localPosition.dx / width).clamp(0.0, 1.0);
                        final sec = ratio * _totalSec;
                        setState(() {
                          if (_draggingHandle == 'start') {
                            _startSec = sec.clamp(0.0, _endSec - 0.3);
                          } else if (_draggingHandle == 'end') {
                            _endSec = sec.clamp(_startSec + 0.3, _totalSec);
                          }
                        });
                      },
                      onHorizontalDragEnd: (_) {
                        _draggingHandle = null;
                        _player.seek(Duration(milliseconds: (_startSec * 1000).toInt()));
                      },
                      child: Container(
                        height: 205,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                        decoration: BoxDecoration(
                          color: _isDark ? const Color(0xFF14181E) : ThalabTheme.darkSlate,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: _borderColor, width: 1.5),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(_waveHeights.length, (i) {
                                final barRatio = i / _waveHeights.length;
                                final inRange =
                                    barRatio >= startRatio && barRatio <= endRatio;
                                return Container(
                                  width: 3.5,
                                  height: 120 * _waveHeights[i],
                                  decoration: BoxDecoration(
                                    color: inRange
                                        ? ThalabTheme.foxOrange
                                        : Colors.white24,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                );
                              }),
                            ),
                            Align(
                              alignment: Alignment(-1.0 + (startRatio * 2.0), 0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: ThalabTheme.foxOrange, width: 3),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(width: 3, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            Align(
                              alignment: Alignment(-1.0 + (endRatio * 2.0), 0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Container(width: 3, color: Colors.white),
                                  ),
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: ThalabTheme.foxOrange, width: 3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Align(
                              alignment: Alignment(-1.0 + (progressRatio * 2.0), 0),
                              child: Container(
                                width: 2.5,
                                height: 170,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 22),
                Text(
                  _fmtPrecise(_currentSec),
                  style: const TextStyle(
                      fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                ),
                const SizedBox(height: 4),
                Text(
                  'إجمالي المدة: ${_fmtPrecise(_totalSec)}',
                  style: const TextStyle(color: ThalabTheme.mutedSlate, fontSize: 13),
                ),
                const Spacer(),
                if (_isProcessing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: CircularProgressIndicator(color: ThalabTheme.foxOrange),
                  )
                else
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 26),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StudioBottomAction(
                          icon: Icons.delete_sweep_rounded,
                          label: 'حذف المحدد',
                          active: true,
                          activeColor: Colors.redAccent,
                          onTap: () => _applyInstantEdit('cut'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.replay_5_rounded, size: 28),
                          onPressed: () {
                            final t = (_currentSec - 3).clamp(0.0, _totalSec);
                            _player.seek(Duration(milliseconds: (t * 1000).toInt()));
                          },
                        ),
                        GestureDetector(
                          onTap: () {
                            if (_isPlaying) {
                              _player.pause();
                            } else {
                              _player.seek(
                                  Duration(milliseconds: (_startSec * 1000).toInt()));
                              _player.play();
                            }
                          },
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.forward_5_rounded, size: 28),
                          onPressed: () {
                            final t = (_currentSec + 3).clamp(0.0, _totalSec);
                            _player.seek(Duration(milliseconds: (t * 1000).toInt()));
                          },
                        ),
                        _StudioBottomAction(
                          icon: Icons.content_cut_rounded,
                          label: 'قص الأطراف',
                          active: true,
                          activeColor: ThalabTheme.foxOrange,
                          onTap: () => _applyInstantEdit('keep'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _TrimmerTimeBox extends StatelessWidget {
  final String label;
  final String time;
  final Color cardBg;
  final Color borderColor;
  final bool highlight;

  const _TrimmerTimeBox({
    required this.label,
    required this.time,
    required this.cardBg,
    required this.borderColor,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: highlight ? ThalabTheme.foxOrange : ThalabTheme.mutedSlate,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            time,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: highlight ? ThalabTheme.foxOrange : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioBottomAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _StudioBottomAction({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? activeColor.withOpacity(0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active
                ? activeColor
                : (isDark ? ThalabTheme.darkBorder : ThalabTheme.softBorder),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? activeColor : ThalabTheme.mutedSlate, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: active ? activeColor : ThalabTheme.mutedSlate,
              ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? ThalabTheme.darkBorder : ThalabTheme.softBorder,
          ),
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
  final bool isSelected;
  final VoidCallback onTap;

  const _RelaxPresetCard({
    required this.title,
    required this.icon,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? ThalabTheme.foxOrange.withOpacity(0.14)
              : Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? ThalabTheme.foxOrange
                : (isDark ? ThalabTheme.darkBorder : ThalabTheme.softBorder),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: ThalabTheme.foxOrange, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isSelected
                      ? ThalabTheme.foxOrange
                      : (isDark ? ThalabTheme.darkTextPrimary : ThalabTheme.darkSlate),
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: ThalabTheme.foxOrange, size: 16),
          ],
        ),
      ),
    );
  }
}
