import 'package:flutter_test/flutter_test.dart';
import 'package:jobix/features/resume/resume_export_service.dart';

void main() {
  test('download filename uses a bounded sanitized display name', () {
    expect(resumePdfFilename('Hamdy Hassan'), 'Hamdy Hassan Resume.pdf');
    expect(resumePdfFilename('سارة خالد'), 'سارة خالد Resume.pdf');
    expect(resumePdfFilename('../../'), 'Resume.pdf');
    expect(resumePdfFilename(null), 'Resume.pdf');
    expect(resumePdfFilename('A' * 80), '${'A' * 64} Resume.pdf');
    expect(
      resumePdfFilename('  Mohamed / Hamdy:*  '),
      'Mohamed Hamdy Resume.pdf',
    );
  });
}
