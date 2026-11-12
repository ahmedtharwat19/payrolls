import 'package:flutter_test/flutter_test.dart';
import 'package:puresip_payrolls/core/security/password_hasher.dart';

void main() {
  group('PBKDF2-HMAC-SHA256', () {
    // متجهات اختبار محسوبة بـ Python hashlib.pbkdf2_hmac (32 بايت).
    const vectors = [
    ('password', 'salt', 1, '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b'),
    ('password', 'salt', 2, 'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43'),
    ('password', 'salt', 4096, 'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a'),
    ('pässwörd', 's@lt', 1000, 'fc3e09839c90c80e5dce4d0640db7ac0997e41683616ec74a2d2bc7acd0e1dcd'),
    ];
    for (final (p, s, i, expected) in vectors) {
      test('vector $p/$s/$i', () {
        expect(pbkdf2HexForTest(p, s, i), expected);
      });
    }
  });

  group('PasswordHasher', () {
    test('hash/verify roundtrip', () async {
      final salt = PasswordHasher.generateSalt();
      final h = await PasswordHasher.hash('Str0ngPass', salt, iterations: 1000);
      expect(await PasswordHasher.verify('Str0ngPass', salt, h), isTrue);
      expect(await PasswordHasher.verify('wrong', salt, h), isFalse);
    });

    test('salt is random', () {
      expect(PasswordHasher.generateSalt(),
          isNot(PasswordHasher.generateSalt()));
    });

    test('constantTimeEquals', () {
      expect(PasswordHasher.constantTimeEquals('abc', 'abc'), isTrue);
      expect(PasswordHasher.constantTimeEquals('abc', 'abd'), isFalse);
      expect(PasswordHasher.constantTimeEquals('abc', 'abcd'), isFalse);
    });

    test('password policy', () {
      expect(PasswordHasher.validatePolicy('short1'), isNotNull);
      expect(PasswordHasher.validatePolicy('onlyletters'), isNotNull);
      expect(PasswordHasher.validatePolicy('12345678'), isNotNull);
      expect(PasswordHasher.validatePolicy('admin123'), isNotNull);
      expect(PasswordHasher.validatePolicy('Good1Passw0rd'), isNull);
      expect(PasswordHasher.validatePolicy('bob12345x', username: 'bob'),
          isNotNull);
    });
  });
}
