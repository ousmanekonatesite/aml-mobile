/// Horodatage unifié pour toute l'application (messages, notifications, communauté).
/// Affiche toujours la date ET l'heure locales : « Aujourd’hui à 14:32 »,
/// « Hier à 09:05 » ou « 12/10/2026 à 18:40 ».
String amlFormatDateTime(dynamic value) {
  final dt = DateTime.tryParse((value ?? '').toString())?.toLocal();
  if (dt == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(day).inDays;
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  if (diff == 0) return 'Aujourd’hui à $hh:$mm';
  if (diff == 1) return 'Hier à $hh:$mm';
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');
  return '$d/$m/${dt.year} à $hh:$mm';
}

const _amlMonths = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

/// Date longue sans heure : « 12 oct. 2026 ».
String amlFormatDate(dynamic value) {
  final dt = DateTime.tryParse((value ?? '').toString())?.toLocal();
  if (dt == null) return '';
  return '${dt.day} ${_amlMonths[dt.month - 1]} ${dt.year}';
}
