# CMF Decision on your phone

Cortiq Mobile 1.3 uses **Cortiq 0.8.0**. Chat models still generate text;
Decision models choose from a skill's labels using reconstruction error.

## Three steps

1. **Models → Hugging Face → Ready CMF → infosave/cmf-decision.**
   Download the CMF, then load it. You can also import your own `.cmf` file.
2. The first tab becomes **Decisions**. Choose a skill, enter a request or tap
   **Use example**, then **Decide**. A low-confidence result is an abstention,
   not a successful answer.
3. **Server → Start** exposes the same loaded model on your trusted LAN.
   Set a bearer token before sharing the phone API. HTTP is not encrypted;
   do not expose it to the public internet.

```bash
curl http://PHONE_IP:8080/v1/decide \
  -H 'Authorization: Bearer YOUR_PHONE_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{"skill":"banking77","text":"Where is my card?","profile":"balanced"}'
```

`choice` is null when `accepted` is false. `candidate` is not an accepted
answer. `timings_us.total` is the native request time; `resonance` is only the
reconstruction stage, not end-to-end latency or network time.

- `GET /v1/skills` and `/v1/skills/{id}` discover labels and rubrics.
- `POST /v1/decisions` (alias `/api/alpha/decisions`) uses the Cortiq typed
  `state` + `questions` contract. Read a skill's rubric instead of inventing one.
- `GET /v1/models` returns the loaded decision model's identity.
- Chat endpoints return 409 while a decision model is loaded. Load a chat
  model to resume `/v1/chat/completions`; the two operations are not interchangeable.

## Oracle — optional, explicit, private

**Settings → Oracle** (also the cloud icon in Decisions): set an HTTPS API
base URL, model ID and API key. The default suggestion is MiMo-V2.6-Flash
through OpenRouter. The oracle is **off by default**.

When a local decision abstains, **Ask oracle** asks for confirmation before
sending the original request and the skill's rubric. This is a potentially
paid external call, clearly labelled separately. Keys live in Android
Keystore-backed encrypted storage / iOS Keychain, never in CMF files or logs.
Requests have a 30-second timeout, a 256-token output limit, no redirects and
no automatic retries. Invalid or out-of-taxonomy answers are refused.

The phone's HTTP API stays local-only: a LAN caller cannot spend your oracle
key. Oracle answers do not automatically train the model. Import a new CMF
version to add trained skills; existing chat-model task masks are a different
feature. The native service checks manifests, tensor hashes and encoder goldens
before accepting a Decision file.

## Device and build support

Decision evaluation currently uses **CPU on Android/iOS**. The existing GPU
setting still controls generative chat. The desktop Decision Metal backend
is macOS-only in upstream 0.8.0; it is not advertised as an iPhone GPU backend.
Measured stages are shown separately, without fixed speed claims.

All native libraries are built from pinned source in GitHub Actions. Apple
builds/signing/uploads run in `ios-release.yml`; no local Apple release build
is needed. The workflow checks exported Decision symbols and waits for App
Store Connect processing. Google Play uses the `internal` track by default.

## Developer checks

```bash
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
cargo test --manifest-path native/runtime/Cargo.toml --locked --lib
scripts/build_native.sh android-arm64
flutter build apk --debug --target-platform android-arm64
```

Debug Android uses `ai.cortiq.cmf_mobile.dev`: installation and testing do not
replace or erase the store app. For real-device tests, install the debug APK,
then stream the verified release CMF into its private test directory:

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell run-as ai.cortiq.cmf_mobile.dev mkdir -p app_flutter
adb shell 'run-as ai.cortiq.cmf_mobile.dev sh -c "cat > app_flutter/decision-test.cmf"' < /path/to/cortiq-decision.cmf
flutter test integration_test/decision_test.dart -d DEVICE_ID
```

Fixture SHA-256: `ed9b8ec2bbfe9e9fd30f14a5eaf82314f38bc7e7510a39772baa2de3801d79b1`.
The test asserts three known labels, abstention, bearer authentication, typed
API, wrong-model rejection, native ABI availability, secure-storage round trip
and the real decision screen. It makes **no paid oracle calls**.
