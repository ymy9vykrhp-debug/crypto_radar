import 'package:flutter/services.dart';

abstract interface class NotificationSoundPlayer {
  Future<void> playStrongAlert();
}

class SystemNotificationSoundPlayer implements NotificationSoundPlayer {
  const SystemNotificationSoundPlayer();

  @override
  Future<void> playStrongAlert() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
    } on Object {
      // Browser/platform sound restrictions must never break monitoring.
    }
  }
}
