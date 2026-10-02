/// Policy versions use three numeric segments, not lexical comparison.
bool isBelowMinimum(String current, String minimum) {
  List<int> parts(String value) {
    if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(value)) {
      throw const FormatException('Invalid policy version');
    }
    return value.split('.').map(int.parse).toList();
  }

  final a = parts(current);
  final b = parts(minimum);
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] < b[i];
  }
  return false;
}
