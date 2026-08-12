import 'package:cmf_mobile/data/models/companion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CompanionConfig.validate', () {
    test('accepts host:port and keeps it verbatim', () {
      expect(CompanionConfig.validate('192.168.1.5:9911'), '192.168.1.5:9911');
      expect(CompanionConfig.validate('  127.0.0.1:9911 '), '127.0.0.1:9911');
      expect(CompanionConfig.validate('desktop.local:1'), 'desktop.local:1');
    });

    test('rejects what the runtime would only fail on later', () {
      // A missing port is the common paste error, and the runtime would not
      // complain until the first generation — far from where it was typed.
      expect(CompanionConfig.validate('192.168.1.5'), isNull);
      expect(CompanionConfig.validate('192.168.1.5:'), isNull);
      expect(CompanionConfig.validate(':9911'), isNull);
      expect(CompanionConfig.validate('192.168.1.5:port'), isNull);
      expect(CompanionConfig.validate('192.168.1.5:0'), isNull);
      expect(CompanionConfig.validate('192.168.1.5:65536'), isNull);
      expect(CompanionConfig.validate(''), isNull);
    });
  });

  group('CompanionConfig.isLoopback', () {
    test('recognises the addresses a cable actually uses', () {
      // USB tethering and `adb reverse` both land on loopback, which is the
      // transport the split measures well on.
      expect(CompanionConfig.isLoopback('127.0.0.1:9911'), isTrue);
      expect(CompanionConfig.isLoopback('localhost:9911'), isTrue);
      expect(CompanionConfig.isLoopback('LOCALHOST:9911'), isTrue);
    });

    test('a LAN address is not a cable', () {
      expect(CompanionConfig.isLoopback('192.168.1.5:9911'), isFalse);
      expect(CompanionConfig.isLoopback('10.0.0.2:9911'), isFalse);
      expect(CompanionConfig.isLoopback(''), isFalse);
    });

    test('overCable follows the address', () {
      expect(const CompanionConfig(address: '127.0.0.1:9911').overCable, isTrue);
      expect(
          const CompanionConfig(address: '192.168.1.5:9911').overCable, isFalse);
    });
  });

  group('classifyPeerFailure', () {
    // Both of these were copied off a phone, not invented: the desktop worker
    // was killed mid-session and then dialled again.
    const brokenPipe =
        'Bad state: generate: peer generate: wire write: Broken pipe (os error 32)';
    const refused =
        'Bad state: generate: peer generate: connect 127.0.0.1:9911: '
        'Connection refused (os error 111)';

    test('a desktop that died and one that was never there both read as gone',
        () {
      expect(classifyPeerFailure(brokenPipe), PeerFailure.unreachable);
      expect(classifyPeerFailure(refused), PeerFailure.unreachable);
      // The runtime does not always hand back an errno: when the far side
      // closes mid-generation it says this, and the phone read it as an
      // unknown fault and printed a vaguer sentence than it had to.
      expect(
        classifyPeerFailure(
            'Bad state: generate: peer generate: worker 127.0.0.1:9911 hung up'),
        PeerFailure.unreachable,
      );
    });

    test('the two failures worth a different sentence are separated', () {
      expect(
        classifyPeerFailure('peer generate: wire version 4 != 5 — upgrade one side'),
        PeerFailure.wireVersion,
      );
      expect(
        classifyPeerFailure('peer handshake: dir_hash mismatch'),
        PeerFailure.modelMismatch,
      );
    });

    test('an unrecognised peer failure is still a peer failure', () {
      expect(classifyPeerFailure('peer generate: something new'),
          PeerFailure.other);
    });

    test('a local failure is not blamed on the desktop', () {
      // The split being on does not make every failure the split's fault.
      expect(classifyPeerFailure('Bad state: model file is truncated'), isNull);
      expect(classifyPeerFailure('cortiq_load: no such file'), isNull);
      expect(classifyPeerFailure(''), isNull);
    });
  });

  group('cleanEngineError', () {
    test('strips the wrappers and keeps the clause that means something', () {
      expect(
        cleanEngineError(
            'Bad state: generate: peer generate: connect 127.0.0.1:9911: '
            'Connection refused (os error 111)'),
        'connect 127.0.0.1:9911: Connection refused (os error 111)',
      );
      expect(
        cleanEngineError(
            'Bad state: generate: peer generate: wire write: Broken pipe (os error 32)'),
        'wire write: Broken pipe (os error 32)',
      );
    });

    test('leaves a message that has no wrappers alone', () {
      expect(cleanEngineError('cortiq_load: no such file'),
          'cortiq_load: no such file');
    });

    test('never hands the UI an empty string', () {
      // Peeling everything off would leave a bubble with an error icon and no
      // words; the raw text is worse to read but better than nothing.
      expect(cleanEngineError('Bad state: '), isNotEmpty);
      expect(cleanEngineError('generate: '), isNotEmpty);
      expect(cleanEngineError('   '), isNotEmpty);
    });
  });

  group('PeerStats', () {
    test('reads the runtime\'s shape', () {
      final stats = PeerStats.fromJson(const {
        'thermal_mc': 34300,
        'powered': null,
        'cpu_khz_cur': 691200,
        'cpu_khz_max': 2400000,
        'mem_avail_kb': 1467000,
        'threads': 4,
        'platform': 'android/aarch64',
      });
      expect(stats.temperatureC, closeTo(34.3, 0.001));
      expect(stats.threads, 4);
      expect(stats.platform, 'android/aarch64');
      expect(stats.isEmpty, isFalse);
    });

    test('a field the platform does not expose stays null, never zero', () {
      // The distinction is the whole point: a scheduler reading a missing
      // clock as 0 MHz parks a node that is running perfectly well.
      final stats = PeerStats.fromJson(const {'threads': 4});
      expect(stats.cpuKhzCurrent, isNull);
      expect(stats.cpuKhzMax, isNull);
      expect(stats.thermalMilliC, isNull);
      expect(stats.temperatureC, isNull);
      expect(stats.clockFraction, isNull);
      expect(stats.powered, isNull);
    });

    test('an explicit null is not a value either', () {
      final stats = PeerStats.fromJson(const {
        'powered': null,
        'cpu_khz_cur': null,
        'threads': 4,
      });
      expect(stats.powered, isNull);
      expect(stats.cpuKhzCurrent, isNull);
    });

    test('clockFraction needs both ends and a sane maximum', () {
      expect(
        PeerStats.fromJson(
                const {'cpu_khz_cur': 691200, 'cpu_khz_max': 2400000})
            .clockFraction,
        closeTo(0.288, 0.001),
      );
      expect(
        PeerStats.fromJson(const {'cpu_khz_cur': 691200}).clockFraction,
        isNull,
      );
      expect(
        PeerStats.fromJson(const {'cpu_khz_cur': 691200, 'cpu_khz_max': 0})
            .clockFraction,
        isNull,
      );
    });

    test('an empty object is empty, not a peer reporting zeros', () {
      expect(PeerStats.fromJson(const {}).isEmpty, isTrue);
      expect(PeerStats.empty.isEmpty, isTrue);
    });
  });
}
