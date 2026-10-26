void redactExternalFighterPhoto(Map<String, dynamic> fighter) {
  final status = fighter['rights_status']?.toString();
  final expires = DateTime.tryParse(fighter['rights_expires_at']?.toString() ?? '');
  if (status != 'authorized' || (expires != null && expires.isBefore(DateTime.now().toUtc()))) {
    fighter['photo_url'] = null;
  }
}
