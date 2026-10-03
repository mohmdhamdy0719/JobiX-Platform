String? validatePersonalField(String field, String value) {
  final text = value.trim();
  if (text.isEmpty) {
    return null; // Export requirements never block partial saves.
  }
  if (field == 'email' &&
      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
    return 'email';
  }
  if (field == 'phone') {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^\+?[0-9 ()-]+$').hasMatch(text) ||
        digits.length < 7 ||
        digits.length > 15) {
      return 'phone';
    }
  }
  if (field.endsWith('_url')) {
    final uri = Uri.tryParse(text);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        text.contains(RegExp(r'\s'))) {
      return 'link';
    }
  }
  return null;
}
