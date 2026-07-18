import 'package:cmf_mobile/features/models/import_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ready Bonsai models stay pinned in mobile-first order', () {
    expect(featuredRepos, [
      'infosave/Bonsai-1.7Bcmf',
      'infosave/Bonsai-27Bcmf',
    ]);
  });
}
