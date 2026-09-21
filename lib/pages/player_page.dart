import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/reciter.dart';
import '../services/audio_service.dart';
import '../services/quran_api.dart';
import '../services/storage_service.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({Key? key}) : super(key: key);

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _stateSub;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = false;
  Reciter? _reciter;

  @override
  void initState() {
    super.initState();
    _reciter = AudioService.currentReciter;
    _setupListeners();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  void _setupListeners() {
    _positionSub = AudioService.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _durationSub = AudioService.durationStream.listen((dur) {
      if (mounted) setState(() => _duration = dur ?? Duration.zero);
    });
    _playingSub = AudioService.playingStream.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });
    _stateSub = AudioService.processingStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isLoading = state == ProcessingState.loading ||
              state == ProcessingState.buffering;
        });
      }
    });
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await AudioService.pause();
    } else {
      await AudioService.resume();
    }
  }

  Future<void> _seekTo(double seconds) async {
    await AudioService.seek(Duration(seconds: seconds.round()));
  }

  Future<void> _skip(int seconds) async {
    final target = _position.inSeconds + seconds;
    final max = _duration.inSeconds;
    await _seekTo((target < 0 ? 0 : (target > max ? max : target)).toDouble());
  }

  void _showRecitersDialog() {
    final reciters = QuranApi.getReciters();
    final currentId = _reciter?.identifier;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant.withOpacity(.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'اختر القارئ',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: reciters.length,
                itemBuilder: (_, i) {
                  final r = reciters[i];
                  final isSelected = r.identifier == currentId;
                  return ListTile(
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: isSelected
                          ? Theme.of(ctx).colorScheme.primary
                          : Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      r.name,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(r.englishName),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _changeReciter(r);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeReciter(Reciter newReciter) async {
    setState(() {
      _reciter = newReciter;
      _isLoading = true;
    });

    // احفظ التفضيل
    await StorageService.setPreferredReciter(newReciter.identifier);

    // غيّر القارئ مع نفس السورة
    final ok = await AudioService.changeReciter(newReciter);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تغيير القارئ')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final surahName = AudioService.currentSurahName.isNotEmpty
        ? AudioService.currentSurahName
        : 'قيد التشغيل';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'المشغل',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
          tooltip: 'إغلاق',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // ============ صورة السورة (رمزية) ============
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            scheme.primary,
                            scheme.primary.withOpacity(.6),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withOpacity(.3),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.menu_book_rounded,
                          size: 100,
                          color: scheme.onPrimary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ============ اسم السورة ============
                    Text(
                      'سورة $surahName',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: scheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 8),

                    // ============ اسم القارئ ============
                    GestureDetector(
                      onTap: _showRecitersDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.mic_rounded,
                              size: 18,
                              color: scheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _reciter?.name ?? 'غير معروف',
                              style: TextStyle(
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.expand_more_rounded,
                              size: 18,
                              color: scheme.onPrimaryContainer,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // ============ شريط التقدم ============
                    Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 6,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 8),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 18),
                          ),
                          child: Slider(
                            value: _duration.inSeconds > 0
                                ? _position.inSeconds
                                    .clamp(0, _duration.inSeconds)
                                    .toDouble()
                                : 0,
                            max: _duration.inSeconds > 0
                                ? _duration.inSeconds.toDouble()
                                : 1,
                            onChanged: _duration.inSeconds > 0
                                ? (v) => _seekTo(v)
                                : null,
                          ),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                AudioService.formatDuration(_position),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                AudioService.formatDuration(_duration),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // ============ أزرار التحكم الرئيسية ============
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // ⏪ 10 ثواني
                        IconButton(
                          iconSize: 40,
                          icon: const Icon(Icons.replay_10_rounded),
                          onPressed: _isLoading ? null : () => _skip(-10),
                        ),
                        const SizedBox(width: 20),

                        // ▶️ / ⏸️
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: scheme.primary.withOpacity(.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Material(
                            color: scheme.primary,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _isLoading ? null : _togglePlayPause,
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: _isLoading
                                    ? SizedBox(
                                        width: 40,
                                        height: 40,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 3,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            scheme.onPrimary,
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        _isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        size: 40,
                                        color: scheme.onPrimary,
                                      ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),

                        // ⏩ 10 ثواني
                        IconButton(
                          iconSize: 40,
                          icon: const Icon(Icons.forward_10_rounded),
                          onPressed: _isLoading ? null : () => _skip(10),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // ============ شريط سفلي: تغيير القارئ + فتح خارجي ============
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: scheme.surfaceVariant.withOpacity(.5),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showRecitersDialog,
                      icon: const Icon(Icons.person_rounded, size: 20),
                      label: const Text('تغيير القارئ'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        if (_reciter == null) return;
                        final ok = await AudioService.openExternal(
                          _reciter!,
                          AudioService.currentSurahNumber,
                        );
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('تعذر فتح المشغل الخارجي')),
                          );
                        }
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 20),
                      label: const Text('فتح خارجي'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
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