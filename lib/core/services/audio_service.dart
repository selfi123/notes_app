import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';

class AudioService {
  static final AudioRecorder _recorder = AudioRecorder();
  static final AudioPlayer _player = AudioPlayer();

  // ─── Recording ────────────────────────────────────────────

  static Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  /// Start recording. Returns the file path where audio is being saved.
  static Future<String> startRecording({required String noteId}) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/audio/$noteId.m4a';

    // Ensure directory exists
    await Directory('${dir.path}/audio').create(recursive: true);

    final config = RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 128000,
      sampleRate: 44100,
    );

    await _recorder.start(config, path: path);
    return path;
  }

  /// Stop recording. Returns duration in seconds.
  static Future<({String path, int duration})> stopRecording(
      String path) async {
    await _recorder.stop();

    // Estimate duration by checking file modification time
    // (just_audio can give accurate duration on play)
    final file = File(path);
    int durationSec = 0;
    if (await file.exists()) {
      // We'll set proper duration when playing back
      durationSec = 0;
    }

    return (path: path, duration: durationSec);
  }

  /// Stream of amplitude values (0.0 to 1.0) for waveform visualization.
  static Stream<double> amplitudeStream() {
    return _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 80))
        .map((amp) {
      // Normalize dBFS to 0.0–1.0
      final db = amp.current;
      if (db == double.negativeInfinity || db < -60) return 0.0;
      return ((db + 60) / 60).clamp(0.0, 1.0);
    });
  }

  // ─── Playback ────────────────────────────────────────────

  static Future<Duration?> play(String path) async {
    await _player.stop();

    final source = AudioSource.file(path);
    await _player.setAudioSource(source);
    await _player.play();

    return _player.duration;
  }

  static Future<void> pause() async {
    await _player.pause();
  }

  static Future<void> resume() async {
    await _player.play();
  }

  static Future<void> stop() async {
    await _player.stop();
  }

  static Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  static Stream<Duration> get positionStream => _player.positionStream;

  static Duration? get duration => _player.duration;

  static Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  static Future<void> dispose() async {
    await _recorder.dispose();
    await _player.dispose();
  }
}
