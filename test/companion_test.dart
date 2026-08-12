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
