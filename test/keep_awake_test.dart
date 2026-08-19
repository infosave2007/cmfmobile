import 'package:cmf_mobile/core/util/keep_awake.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('cmf/keep_awake');
  late List<bool> calls;

  setUp(() {
    calls = [];
    KeepAwake.resetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'setKeepAwake') calls.add(call.arguments as bool);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    KeepAwake.resetForTest();
  });

  test('the screen is held once, however many holders there are', () async {
    await KeepAwake.acquire(KeepAwake.server);
    await KeepAwake.acquire(KeepAwake.conversion);
    expect(calls, [true], reason: 'the second holder must not re-arm it');
  });

  test('one holder finishing does not switch the screen off under another',
      () async {
    // The bug this guards: stopping the server used to drop keep-awake while
    // a conversion was still downloading, so the display slept and iOS
    // suspended the app mid-transfer.
    await KeepAwake.acquire(KeepAwake.conversion);
    await KeepAwake.acquire(KeepAwake.server);
    await KeepAwake.release(KeepAwake.server);
    expect(calls, [true], reason: 'conversion still holds it');

    await KeepAwake.release(KeepAwake.conversion);
    expect(calls, [true, false], reason: 'the last holder releases it');
  });

  test('releasing something never acquired changes nothing', () async {
    await KeepAwake.release(KeepAwake.server);
    expect(calls, isEmpty);
  });
}
