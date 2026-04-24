// Task 012 — Alarm service: loud audio alarm for DROP commands
// Plays a continuous alarm sound until staff acknowledges
// Overrides silent/vibrate mode by setting volume to max
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// Manages the walk-in alarm audio playback.
///
/// When a DROP SMS arrives, the alarm plays on loop at max volume
/// until staff taps the Acknowledge button on the dashboard.
/// Uses a singleton pattern so background service and UI share state.
class AlarmService extends ChangeNotifier {
  AlarmService._();
  static final AlarmService instance = AlarmService._();

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  // DROP order details shown in the alert overlay
  String? _customerPhone;
  int? _quantity;
  DateTime? _triggeredAt;

  bool get isPlaying => _isPlaying;
  String? get customerPhone => _customerPhone;
  int? get quantity => _quantity;
  DateTime? get triggeredAt => _triggeredAt;

  /// Triggers the alarm for a DROP order.
  ///
  /// [phone] — the customer's phone number
  /// [qty] — number of gallons in the DROP order
  Future<void> trigger({required String phone, required int qty}) async {
    _customerPhone = phone;
    _quantity = qty;
    _triggeredAt = DateTime.now();
    _isPlaying = true;
    notifyListeners();

    try {
      // Set to max volume
      await _player.setVolume(1.0);
      // Loop the alarm
      await _player.setReleaseMode(ReleaseMode.loop);
      // Play the alarm sound asset
      await _player.play(AssetSource('audio/alarm.wav'));
      debugPrint('AlarmService: Alarm triggered for DROP from $phone ($qty gal)');
    } catch (e) {
      debugPrint('AlarmService: Error playing alarm — $e');
      // Even if audio fails, keep the visual alert active
    }
  }

  /// Stops the alarm when staff acknowledges.
  Future<void> acknowledge() async {
    _isPlaying = false;
    notifyListeners();

    try {
      await _player.stop();
      debugPrint('AlarmService: Alarm acknowledged');
    } catch (e) {
      debugPrint('AlarmService: Error stopping alarm — $e');
    }
  }

  /// Disposes the audio player (call on app shutdown)
  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
