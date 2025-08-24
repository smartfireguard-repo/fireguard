enum NotificationType {
  flameDetected('FLAME DETECTED'),
  smokeDetected('SMOKE DETECTED'),
  emergency('EMERGENCY'),
  defaultNotification('OTHER');

  final String value;
  const NotificationType(this.value);
}