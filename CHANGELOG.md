# Changelog

All notable changes to CMF Mobile are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versions follow [SemVer](https://semver.org/).


## [1.2.9] - 2026-08-21

### Fixed
- **The ready-CMF catalog shows every quantization a repo ships, not one card
  per repo.** Several featured repos carry the same model in two or three
  quantizations. Folding them into a single card hid the choice, and the size
  on that card was the SUM of all of them — a repo whose largest file is 24 GB
  advertised 57. Each `.cmf` is now its own card, with its own size, its own
  quantization chip and the file name under the title, and the list is ordered
  by real file size, smallest first.
- **Tapping a card downloads that file.** The direct-download path sorted a
  repo's `.cmf` files by size and always took the largest, so choosing a 2-bit
  variant still fetched the heaviest one. The job now carries the exact path
  the user picked; largest-wins remains only as the fallback for callers that
  cannot offer a choice.
- **Two quantizations of one repo no longer overwrite each other.** The output
  file was named after the repository, so a second variant landed on the same
  `<repo>.cmf` and replaced the first. The name now comes from the downloaded
  file.

## [1.2.8] - 2026-08-19

### Added
- **Increased memory limit entitlement.** The app never asked iOS for more than
  a default process budget, so on an 8 GB iPhone `os_proc_available_memory`
  reported about 3 GB and the load dialog offered ~2.5 GB usable — every model
  above that was unloadable no matter how empty the phone was. Weights are
  mmapped, so that ceiling is what decides which CMF files can run at all.
- **The conversion tab says why the phone will not sleep**, matching the note
  the server screen already carried, and only while a job is actually running.

### Fixed
- **A conversion no longer dies when the screen goes dark.** The server, a
  companion worker and reply generation each held the screen and foreground
  scheduling priority; an import job held neither, so iOS backgrounded and then
  suspended the app and a multi-gigabyte download simply stopped part-way. Note
  the remaining iOS limit: this covers the automatic screen timeout, not a
  manual side-button lock, which suspends the app regardless.
- **Keep-awake is reference-counted.** Stopping the server used to switch the
  screen off under a conversion that was still downloading.
- **One starved connection no longer throws away the whole download.** Hugging
  Face throttles concurrent ranges, and a worker that sat at zero bytes past
  the outage window aborted every sibling — discarding gigabytes already on
  disk. Leftover ranges are now finished one connection at a time, which is the
  shape that survives throttling. A resumed range also writes at the offset it
  stopped on rather than at the range start.
- **The ready-CMF catalog can report a failure.** It keyed on an empty list, so
  a failed load, an empty account and "still loading" all rendered the same
  spinner, forever, with no retry — the load runs once from initState.
- **The catalog measures against the memory a process may actually use**, not
  the device's total RAM. The two disagreed by more than a factor of two, so it
  offered a 4.75 GB model that the load dialog then refused — after the
  download had finished.
- **Debug builds run on a physical device again.** Xcode 16+ moves the code of
  a debug device build into `Runner.debug.dylib` and leaves a stub that looks
  up the entry point in it; the linker flags that export the engine's C ABI are
  an allow-list, so the entry point was filtered out and the stub aborted
  before the first frame — which looked like the app hanging on the splash.

## [1.2.7] - 2026-08-17

### Fixed
- **A finished download lands in the library even after you walk away.** The
  refresh listener lived in the import screen's own state, so closing that
  screen mid-download orphaned it: the model arrived on disk but stayed
  invisible until the app was restarted. The library owns the subscription
  now — the models controller watches converter updates and refreshes on every
  job-done transition, for the whole life of the app.

## [1.2.6] - 2026-08-17

### Added
- **On-device conversion to `q4tp` and `q2tp`** — the formats the engine's
  current work actually targets, ported bit-faithfully from the reference
  converter: three-plane layout, per-row f16 scale ladder, round-half-to-even,
  and both encoder searches (the per-group rung probe, and q2tp's row-level
  ladder-top search). Q4TP leads the list as the recommended profile; Q2TP is
  the 2/4 MoE split — gate/up experts at 2-bit, everything else q4tp — and
  degenerates to plain q4tp on a dense model, which its description says.
  Acceptance was the runtime itself: a Dart-converted q4tp file loads and
  generates through the real engine.
- **Estimated sizes before anything downloads.** The conversion sheet shows
  the download size and, next to every quantization option, the approximate
  output size — the number that used to be discoverable only by running the
  whole job. Marked ≈, because embeddings and norms stay f16 in every
  profile.
- **The featured list is the account, not a snapshot of it.** Every repo
  tagged `cmf` on huggingface.co/infosave appears with its file size —
  fifteen today where the hardcoded list showed three — and publishing a new
  one needs no app release. Search results carry a READY CMF badge on
  cmf-tagged repos.

### Fixed
- **Ready .cmf repos are downloads, not conversions.** Tapping one used to
  open the quantization sheet — offering to convert a file that needs no
  conversion (the job would have downloaded directly anyway, but nothing on
  screen said so). The sheet now checks what the repo ships first and offers
  a plain Download with the file's name and size.
- Downloaded `q4tp`/`q2tp` files showed as `dtype#15`/`dtype#16` in the model
  library — the dtype table stopped at 14.

## [1.2.5] - 2026-08-16

(1.2.4's Android half never shipped: a leftover `applicationIdSuffix =
".devtest"` — a deliberately temporary side-by-side test setting, marked
"revert before committing" and then committed anyway by an undiscriminating
`git add -A` — renamed the release package, and Play refused the bundle with
"APK has the wrong package name", twice, because a rerun rebuilds the same
source. The iOS 1.2.4 build was unaffected and is superseded by this one.)

### Fixed
- The release build type carries no `applicationIdSuffix` again, with a
  comment explaining why it must not: the store upload is built from it.

### Changed
- **The GPU switch says what the first answer will cost.** Enabling it on
  this app's own test device produced a 204-second first reply — the Vulkan
  driver compiling every shader, once, while the screen showed nothing but a
  spinner — and read as "the GPU is broken". It is not: the engine caches
  the compiled pipelines beside the model (2.1 MB), the arbitration then
  correctly kept compute on the CPU for this GPU, and the next launch
  answered in 5 seconds. The toggle's caption now warns about the one-time
  minutes-long compile in all seven languages.

## [1.2.4] - 2026-08-16

### Changed
- Engine updated to **v0.5.70 → v0.5.82** — twelve releases, no change to the
  C ABI, so the binding and the split protocol are untouched. What reaches a
  phone:
  - **Enabling the GPU stopped costing three minutes, measured on this app's
    own test device.** On a Snapdragon 778G the first answer with the GPU
    switch on took 256.8 s — the Vulkan driver recompiling every shader on
    every launch — against 10.5 s on the CPU path. The engine now keeps a
    pipeline cache on disk, and keeps it where an Android app can actually
    write: both caches silently failed before, because they aimed at a
    `/tmp` that does not exist inside an app sandbox. First GPU answer in a
    fresh process: 256.8 → 49 s; steady decode with the switch on matches
    the CPU path instead of trailing it.
  - **The KV cache's silent 8192-token default is 32768 now**, and eviction
    warns instead of quietly wiping half the conversation's context — on
    long chats that boundary read as a model losing its mind mid-reply.
  - **Metal correctness fixes** for Apple silicon: a q4tp GEMM read an
    unbound weight-scale constant (every batched prefill on that path was
    noise), and the fused RoPE kernel skipped the K heads' norm on models
    whose head count is not a multiple of 8.

## [1.2.3] - 2026-08-12

### Fixed
- **A desktop that went away turned the chat into a wall of `Bad state`.**
  Stopping the worker mid-conversation left the split switched on and every
  later message failing with
  `Bad state: generate: peer generate: wire write: Broken pipe (os error 32)`
  — three layers of wrapper around one clause, in English, with no way out of
  the chat. Now the bubble names the cause in the user's language and carries
  **Compute here**, which clears the peer and retries the turn. The runtime's
  own words stay, demoted to a caption: they hold the address and the errno,
  which is what a bug report needs.

  Three causes are told apart, because the remedy differs: the desktop is not
  answering (stopped, or the cable went), the two sides run different engine
  versions, or they hold different model files.

  The fallback is never automatic. The desktop was chosen on purpose — often
  because the model is only usable that way — so moving a conversation back
  onto the phone changes both where the data goes and how fast it returns.
  That is a decision, and it stays the user's.

### Added
- **The Companion screen says what is happening and offers a plain
  Disconnect.** Until now the only way out was the role selector, which reads
  as a preference rather than as the switch deciding where every reply comes
  from. There is a status line — *Computing on 127.0.0.1:9911*, *set but not
  checked yet*, or *Desktop unavailable* with the reason — and a Disconnect
  next to it. A failure anywhere in the app (chat included) marks that state,
  so the screen stops looking healthy while replies are failing.

## [1.2.2] - 2026-08-12

### Fixed
- **The empty chat overflowed once the keyboard was up.** The starter screen
  was a `Center` around a fixed column, so when the keyboard took half the
  height there was nowhere for the suggestion chips to go — they were clipped
  with no way to scroll to them, which on a debug build is the striped
  "BOTTOM OVERFLOWED BY 46 PIXELS" banner and in release is silent. It now
  centres while there is room and scrolls when there is not.
- A literal NUL byte sat in `chat_screen.dart`, inside the string that detects
  binary attachments. Valid Dart, but it made `file` report the source as
  data, and `grep` skip it without a word — the file was invisible to a
  plain search of the repository. Written as `'\x00'` now.

## [1.2.1] - 2026-08-12

Both of these were found by running 1.2.0 on a real phone, and neither is
visible to the analyzer or to a test that does not render.

### Fixed
- **The bottom bar broke its own labels.** A fifth destination leaves about
  78dp a tab, and at the system's 1.25 font scale a nine-letter word wrapped
  mid-word — "Компаньо/н" stacked over "Настройк/и". The tab is now called
  Split (Сплит / 拆分 / Bölme), the bar clamps how far it will scale its
  labels while the rest of the app still follows the user's setting, and
  German's "Einstellungen" — thirteen letters, which would not have fit at
  any scale — is "Optionen".
- **A refusal appeared in English inside a Russian screen.** The companion
  controller wrote its own error sentences, and a controller has no
  localizations. It now reports a `CompanionFault`, and the screen turns that
  into words. Text that comes from the runtime itself (`wire version 4 ≠ 5`,
  `address in use`) is still shown verbatim: it names the thing that went
  wrong, and translating it would only make it harder to search for.

### Note
iOS was not verified at runtime for this release. Flutter's debug launcher
aborts in `getDebugDylibEntryPoint` before any Dart runs, on both the iOS
27.0 and 26.5 simulators, after a clean rebuild — a toolchain incompatibility
with Xcode 26.6, not something in the app. The release path is unaffected and
was checked: the IPA links, exports all 18 engine entry points, and the
release workflow's guard passes.

## [1.2.0] - 2026-08-12

### Added
- **Companion — this phone and a desktop as one runtime.** A new tab pairs
  the device with a desktop running `cortiq worker` (engine 0.5.70's
  `cortiq_set_peer` / `cortiq_worker_start` / `cortiq_peer_stats`), in either
  direction:
  - **Compute on the desktop.** It holds the layers, the `lm_head` and the
    sampler; the phone keeps the tokenizer and draws the reply. This is what
    puts a 34.7B MoE on a phone with 2 GB free at 16.3 tok/s. The head always
    travels with the layers, because the head does not shrink as layers move
    away — leaving it here capped a phone at its own 29 ms out of a 73 ms
    token, and moving it measured 12.6 → 26.0 tok/s on Bonsai 1.7B.
  - **Serve layers to a desktop**, so the desktop can run a model larger than
    its own memory. It holds the foreground service and the wake lock, for
    the same reason the server does: a background worker that computes for a
    few milliseconds and then blocks on a socket never convinces the governor
    to raise the clock, which measured as half the throughput.

  The screen offers roles rather than a load percentage, and declines to
  offer the one thing users would ask for first. A token walks the layers in
  order, so splitting a model that already fits is *slower* than the faster
  side alone — measured in both directions and on both transports. What a
  split buys is a model that would not otherwise run at all.

  It is also honest about the wire. The address bar labels the transport, and
  Wi-Fi carries a warning: one round trip per token means the tail is what
  the user sees, and that tail is 94.8 ms at p99 against 2.9 ms on a cable.
  The peer readout shows a field the platform does not expose as *not
  reported*, never as zero — a scheduler that reads a missing clock as 0 MHz
  parks a node that is running perfectly well.

  Two limits the screen states rather than hides: the runtime has no call to
  stop a started worker, so it listens until the app closes; and the shared
  token travels in clear text, so this belongs on a cable or a network you
  trust.

### Changed
- Engine updated to **v0.5.69 → v0.5.70**, which is where the split ABI
  lives. Both sides must run it: the handshake compares a wire version and
  refuses a mismatch with a message rather than producing garbage.
- The Android build recipe in `native/README.md` is now per-ABI, because the
  two differences are silent. Vulkan on the 64-bit ABIs is behind a
  non-default cargo feature, and a library built without it loads, runs and
  reports the right version with the GPU quietly gone; armeabi-v7a needs its
  page size forced to 16 KB, which NDK 28 does by itself only for 64-bit
  output. Both are now checked on the artifact before it is committed.

## [1.1.26] - 2026-08-12

(v1.1.25 carries the same engine update but was never shipped — the iOS
defect below was found while verifying its build, and it made the iOS half of
that release meaningless.)

### Fixed
- **On iOS the app was never actually running the engine.** The runtime's code
  was in the binary; its entry points were not in the export trie, and that is
  the table `dlsym` reads. `DynamicLibrary.process().lookup('cortiq_load')`
  therefore returned nothing, `isAvailable` came back false, and the app fell
  back to the demo engine — silently, because the Dart side looks the ABI up
  at runtime, so a missing symbol is a fallback and not a build error. The
  shipped 1.1.24 binary exports five symbols in total, none of them cortiq's.
  Three things had to change together in `ios/Flutter/Cortiq.xcconfig`:
  `-force_load` does not export anything, so `-Wl,-exported_symbol,_cortiq_*`
  now makes the entry points roots; making them roots keeps code that calls
  `cblas_sgemm` alive, which the link had never needed before and which wants
  `-framework Accelerate`; and Xcode's default strip style for an app ("all")
  emptied the trie again on the way into the IPA, so `STRIP_STYLE` is
  `non-global`. The release workflow now fails if the built binary does not
  export the ABI, since nothing else reports it. Android was never affected —
  it `dlopen`s a real `.so`.

### Changed
- Engine updated to **v0.5.45 → v0.5.69** — 24 releases and 402 commits, with
  no change to the C ABI, so the binding is untouched. The ones that matter on
  a phone:
  - **Hybrid GatedDeltaNet models decode about twice as fast on the CPU.** A
    k=1 MTP speculation was default-on for every CPU decode with an MTP head,
    and on a GDN hybrid the pair lane cannot parallelize the sequential
    recurrence while the draft still pays the full-vocab head on top — the
    engine's bench reads 16.1 tok/s with it against 32.6 without. Every phone
    on the CPU path paid that tax. The gate is architectural now, and dense
    models keep their speculation.
  - **The ARM `q4tp` batch kernel stopped stalling on a cross-lane reduction**
    once per group per column — 288 stalls a row at the shape it was measured
    on — and reduces four times a row instead. An Android and Linux-ARM win
    by scope: iOS takes the Accelerate path for these shapes and never called
    the kernel.
  - **2-bit `q2tp` decode gained its NEON integer path**, so ready `.cmf`
    files in that format stop falling back to the scalar holdout.
  - **The sampler stopped allocating a second whole-vocab copy every token** —
    a megabyte a token at a 248k vocabulary, on the decode hot path.
  - **Chat templates stopped failing silently.** minijinja was built without
    its `json` feature, so any template branch touching tools errored into a
    toolless ChatML fallback rather than rendering.

  The release's headline work — speculative decode, the video pipeline, the
  wgpu and Metal kernels — is GPU-side and desktop-shaped, and the
  Apple-silicon efficiency-core pool change is `target_os = "macos"` only, so
  none of it reaches the app.
- The iOS simulator slice is now built from the same release tag as the device
  slice instead of lagging it, so the simulator runs the same ABI a phone does.

## [1.1.24] - 2026-08-11

### Changed
- **The app is called Cortiq on the Home Screen too.** The store listing says
  "Cortiq: Local AI Models" while the icon said "CMF Mobile" — two names for
  one app, and no way for someone who just installed it to connect them
  (App Store Guideline 2.3.8). The display name is now `Cortiq` on both iOS
  and Android; the bundle identifier and package name are untouched.

## [1.1.23] - 2026-08-04

### Changed
- Engine updated to **v0.5.34 → v0.5.45**. Eleven engine releases, the ones
  that matter on a phone: a tokenizer fix for `Metaspace` prepend living in
  the pre-tokenizer (raw/completion prompts encoded the first word without
  the leading `▁` on affected models — chat prompts were already bit-exact),
  a worker-pool fix in 0.5.44 where a short job went to one worker while the
  rest were woken for nothing, substantial Metal/wgpu kernel work (batched
  prefill, MoE experts on the GPU), and the new `q4tp`/`q2tp` quantized
  formats, so ready `.cmf` files in those formats now load.
- iOS purpose strings rewritten to state the truth: the app never requests
  the camera, microphone, photo library or location at runtime — the
  declarations exist only because bundled components reference those APIs
  (ITMS-90683). The only runtime permission prompt remains Local Network,
  when the server starts.

## [1.1.22] - 2026-07-28

### Changed
- Engine updated to **v0.5.34**.
- The app no longer second-guesses the runtime about the GPU. A guard added
  in 1.1.20 withheld the flag for `VBIT` weights, on the strength of a 14×
  slowdown — but that slowdown was the whole-token graph racing on an
  integrated adapter (fixed engine-side in v0.5.32), and the field it keyed
  on is informational: this model's tensors are 58 % `q8_2f` and 42 % `q1`,
  so the guard never applied to it anyway. The runtime times each op class
  against the CPU and keeps the winner, which is the decision the app was
  duplicating badly.

## [1.1.21] - 2026-07-28

### Fixed
- **Settings → About told the truth about one thread out of four.** The line
  was assembled here from a pool size read straight after the model load,
  where the workers are still registering — usually only the first had
  arrived. The same wrong list was handed to the Android performance-hint
  session, so those hints covered a single worker instead of the pool. The
  app now re-reads the pool before generating, and engine v0.5.33 makes the
  load wait for every registration.

### Changed
- Engine updated to **v0.5.32 → v0.5.33**, and About now quotes the runtime
  instead of assembling the line itself: `cortiq-native 0.5.33 · 4 threads ·
  neon · gpu`, straight from `cortiq_execution_info()`.

## [1.1.20] - 2026-07-28

Everything below came out of measuring 1.1.19 on a real phone
(Snapdragon 778G+, Android 14) — the numbers and the method are in
`native/TUNING.md`.

### Fixed
- **Stop now works during prefill.** It was wired to a flag the token
  callback checks, so it could only take effect once tokens were flowing —
  and a long prompt spends its first minute in prefill emitting nothing. Every
  press of Stop during that minute did nothing at all. Engine v0.5.32 adds
  `cortiq_cancel()`, checked on each prefill chunk too.
- **Turning the GPU on no longer costs 14× on decode.** Measured with every
  variable held: 13.30 tok/s with the switch off, 0.94 with it on. The cause
  was the runtime's whole-token graph racing the CPU path on an adapter it is
  documented to skip — ~300 barriered dispatches a token, which a tiled mobile
  GPU drains its pipeline on. Fixed in the engine for v0.5.32; the app also
  withholds the flag entirely for quantizations with no GPU kernel (VBIT),
  where it can only add cost.

### Changed
- Engine updated to **v0.5.32** — the graph default, an honest thread count in
  `/v1/cortiq/status`, and `cortiq_cancel()`.

## [1.1.19] - 2026-07-28

### Added
- **GPU execution on mobile.** Bundled `libcortiq_ffi` upgraded to **v0.5.31**,
  which ships the wgpu backend — Vulkan on arm64-v8a and x86_64, Metal on
  iOS (armeabi-v7a stays CPU-only); `ios/Flutter/Cortiq.xcconfig` links the
  Metal frameworks it needs. The **Use GPU** switch asks
  `cortiq_gpu_available()` whether the backend is linked in *and* an adapter
  comes up, so it only claims to work when it does.
- **KV-cache reuse between turns** (engine v0.5.31): a turn that continues the
  history prefills the new message instead of the whole session. `CMF_KV_REUSE=0`
  in Engine flags turns it off.
- The notification permission is now requested the first time a foreground
  task starts, so the "Generating a reply" / "Serving models" notification is
  actually visible — a foreground service whose notification is suppressed
  leaves the work invisible, which is the one thing it must not be.
- **Performance hints (ADPF).** The pool's worker threads
  (`cortiq_worker_tids`) get a `PerformanceHintManager` session on Android 12+
  for the length of a reply, so the governor raises clocks for the threads
  doing the work instead of guessing — and drops them when the reply ends.

- **Right-sized worker pool.** The runtime's own default put ~7 workers on the
  ~4 big cores it pins them to, so every per-layer barrier waited twice. The
  app now sets the pool through `cortiq_set_threads` (falling back to the
  `CMF_THREADS` environment variable on older runtimes), and the **CPU
  threads** setting finally reaches inference at all — it used to be accepted
  and dropped. 0 = auto; installs sitting on the old default of 4 are
  migrated to auto.
- **Foreground service** (`dataSync`) with a partial wake lock while a reply
  is generated and while the server runs: a backgrounded process is confined
  to the little cores, and that cpuset overrides the engine's own affinity.
- Settings → Engine → **Engine flags**: advanced `CMF_KEY=value` lines passed
  to the runtime at load time, for the knobs listed in `native/TUNING.md`.

### Changed
- Generation runs on one long-lived worker isolate instead of a fresh one per
  reply, keeping the thread the engine pinned to the big cores.
- Settings → About reports the pool size the engine actually built.

### Removed
- Stray duplicate `libcortiq_ffi 2.so` / `3.so` copies in `jniLibs` that were
  being packaged alongside the real library (~17 MB per ABI).

## [1.1.17] - 2026-07-25

### Changed
- **Engine update**: bundled `libcortiq_ffi` upgraded to **v0.5.20** on all
  platforms (Android arm64-v8a / armeabi-v7a / x86_64 and the iOS static
  library), checksums verified against the cmf release assets.

## [1.1.16] - 2026-07-25

### Changed
- **Engine update**: bundled `libcortiq_ffi` upgraded to **v0.5.19** on all
  platforms (Android arm64-v8a / armeabi-v7a / x86_64 and the iOS static
  library), checksums verified against the cmf release assets.

## [1.1.15] - 2026-07-25

### Changed
- **Engine update**: bundled `libcortiq_ffi` upgraded to **v0.5.18** on all
  platforms — Android arm64-v8a / armeabi-v7a / x86_64 and the iOS static
  library — with checksums verified against the cmf release assets.

### Fixed
- Releases 1.1.10–1.1.13 bumped the engine version in their notes only:
  the binaries committed to the repo were still v0.5.6. The bundled
  runtime now actually matches the stated engine version.

## [1.1.14] - 2026-07-24

### Added
- **Cortiq branding**: new app icon and logo (hexagon-C mark), full iOS icon
  set, Android adaptive icons with a monochrome layer for themed icons.
- **OpenAI `stop` parameter** on `/v1/chat/completions` and
  `/v1/completions` — a string or up to 4 sequences; output is trimmed
  OpenAI-style with a hold-back buffer so SSE never leaks a partial match.
- **Local crash log**: uncaught Flutter/platform errors append to
  `documents/crash.log` (size-capped, fully offline — no third-party SDK).
- **Release signing**: `android/key.properties` (or `KEYSTORE_*` env vars in
  CI) with a debug-key fallback so local `flutter run --release` still works.

### Fixed
- **Engine concurrency**: chat and the embedded server share one native
  handle — generations are now serialized inside `NativeCortiqEngine`
  (previously simultaneous chat + HTTP requests could issue concurrent FFI
  calls on one handle). `unload()` waits for the in-flight generation,
  fixing a potential use-after-free when switching models mid-generation;
  per-generation cancel flags no longer leak.
- **Atomic model files**: conversion streams into `<name>.cmf.tmp` and
  direct downloads into `<name>.cmf.part`, renamed only on success — a
  crash or an OOM kill mid-job can no longer leave a truncated model in
  the library. Failed/cancelled jobs clean up their staging files.
- **Download integrity**: safetensors shards are validated (offsets vs file
  size, shape×dtype vs byte count) before quantization, and downloaded
  sizes are checked against the repo listing — truncated downloads fail
  fast instead of producing corrupt models.
- **Server hardening**: 8 MB request-body limit (413), decode-queue cap
  (429), generation is cancelled when a streaming client disconnects,
  5-minute stall timeout, constant-time bearer-token comparison, graceful
  stop that lets an in-flight decode finish.

### Changed
- **Chat streaming performance**: per-token updates repaint only the active
  bubble (plain text while streaming; markdown is parsed once, on
  completion) instead of rebuilding the whole screen and re-parsing every
  message on each token. The message list uses stable keys, the user turn
  is persisted immediately, and session saves are serialized per file.
- **Converter performance**: removed a redundant full-buffer copy per slab
  in every quantization path and hoisted per-row allocations out of the
  Q1T hot loop (reused quickselect/mask/codes scratch, slab-level overlay
  buffer).

## [1.1.10] - 2026-07-22

### Fixed
- **Engine hotfix**: Upgraded `cortiq-engine` to v0.5.10 — fixes Q4Block Metal
  GPU nibble order bug (garbage output on whole-token graph path, broken since
  v0.5.7 ILP refactor).

## [1.1.9] - 2026-07-22

### Changed
- **Engine update**: Upgraded `cortiq-engine` to v0.5.9 — Looped Transformer
  support (Nanbeige 4.2: 22 layers × 2 loops = 44 virtual layers, 4.17B
  effective params from 2.1B weights), Metal GPU whole-token graph for looped
  models, O(1) Nyström attention benchmarks (×3.7 speedup at ctx=2048).

## [1.1.5] - 2026-07-21

### Changed
- **Massive Performance Boost on Mobile**: Integrated `cortiq-engine` v0.5.5 optimizations.
  - Eliminated severe memory allocation bottlenecks (`Vec` churn) on CPU inference paths, resolving the 0.2 tok/s degradation on big.LITTLE Android devices like Snapdragon 778G.
  - Dramatically accelerated cross-platform GPU inference (WGPU) by replacing expensive integer divisions with a branchless lookup table (LUT).

## [1.1.4] - 2026-07-21

### Fixed
- Upgraded `cmfpublic` to 0.5.3 to fix the GPU toggle. The backend now correctly switches to Vulkan/Metal instead of silently falling back to CPU when the toggle is activated.

## [1.1.3] - 2026-07-21

### Fixed
- Fixed a Dart compilation error in `NativeCortiqEngine` casting and interface implementation.

## [1.1.2] - 2026-07-21

### Added
- **GPU Toggle**: Added a UI setting under Generation to explicitly use the Vulkan/Metal GPU execution graph (applies on the next model load).
- **Localization**: Added full translation support for the GPU toggle setting across 7 languages.

## [1.1.1] - 2026-07-21

### Changed
- **Engine update**: Upgraded `libcortiq_ffi` to v0.5.1, incorporating Metal `TokenGraph` Q8 support and CPU `add_rmsnorm` fusion optimizations.

## [1.1.0] - 2026-07-19

### Added
- **On-device q1t conversion** — training-free ternary quantization
  (`{−s, 0, +s}` packed base-3, ~2.25–3 bit/param, below q4) with a per-row
  sparse f16 outlier overlay. Outliers are the top-|w| per row (the two-field
  mask without an activation Hessian) and a per-row α rescale folds into the
  group scales; the embedding, LM head and down-projection stay q8_2f. The
  output is byte-identical to the cortiq q1t reader.
- **Disable thinking** setting — reasoning models (Qwen3/3.5) answer directly
  instead of emitting a `<think>` block. Applied to every generation through the
  new `enable_thinking` option of the cortiq FFI.

### Changed
- Bundled cortiq runtime updated to **0.4.1** (Android arm64-v8a / armeabi-v7a /
  x86_64 and iOS arm64) — adds q1t decode and the `enable_thinking` sampler
  option.
- The conversion picker disables on-device-unsupported quantizations
  (Q4_BLOCK, VBIT) instead of letting a safetensors conversion start and then
  fail. Repos that already ship `.cmf` still download directly with any
  selection.

### Fixed
- Downloads now survive minutes-long network / DNS outages. Transient failures
  (`Failed host lookup`, connection reset, TLS, timeouts) retry within a
  5-minute no-progress window with capped exponential backoff, resuming from the
  last written byte; a 30-second idle timeout breaks a silently stalled socket
  instead of hanging forever. The single-connection fallback resumes too, and
  the range-support probe retries rather than silently dropping to one
  connection — the common "returned N bytes, expected M (Failed host lookup)"
  failure no longer aborts a large download after a brief blip.

### Tests
- Added a q1t round-trip: convert a synthetic model to q1t, decode the tensor
  through the reference q1t byte format, and verify the outlier overlay and
  ternary base reconstruct exactly.

## [1.0.8] - 2026-07-18

### Fixed
- Parallel Hugging Face downloads now resume large byte ranges from the exact
  last written byte after interrupted streams and temporary DNS failures.
- Useful partial progress resets the retry budget, so a multi-gigabyte range is
  no longer aborted merely because it required more than three connections.
- Range responses are bounded and their `Content-Range` is validated before
  writing, preventing malformed CDN responses from corrupting the destination.

### Tests
- Added a regression that downloads part of a range, survives three consecutive
  DNS failures, resumes at the next byte, and verifies the complete file.

## [1.0.7] - 2026-07-18

### Fixed
- Restored the standard Qwen2/Qwen3/Qwen3.5 MoE conversion path that was
  already supported by `cortiq convert` but remained blocked by the mobile
  architecture guard. Router and shared-expert gates remain F16 while expert
  matrices use the selected quantization.
- Added complete on-device `LiquidAI/LFM2.5-8B-A1B` conversion: all 2,302
  vendor tensor names map collision-free to the canonical CMF layout,
  ShortConv schedules and kernel geometry are preserved, and the header carries
  sigmoid routing, expert-selection bias semantics, top-k normalization, and
  per-expert dimensions.
- `chat_template.jinja` sidecars are now embedded into the CMF tokenizer bundle
  instead of silently falling back to an incorrect default chat template.
- Structural validation checks every routed expert's gate/up/down tensors before
  native loading. Unsupported `num_local_experts` layouts remain blocked rather
  than being mislabeled as supported.

### Tests
- Added independent end-to-end synthetic conversions for canonical Qwen MoE and
  LFM2 ShortConv+MoE, plus the exact public LFM2.5-8B-A1B config and tokenizer
  sidecar regression coverage. Existing Qwen3.5, Gemma, dense, downloader, and
  API tests remain unchanged and passing.

## [1.0.6] - 2026-07-18

### Changed
- Bundled cortiq runtime updated to **v0.3.12** for arm64-v8a,
  armeabi-v7a, x86_64, and iOS. The update adds LFM2-MoE inference with
  ShortConv mixers and sigmoid-routed experts, uses every core on all-A55
  devices, and includes Vulkan support in the 64-bit Android libraries.

### Fixed
- The mobile CMF structural validator now recognizes `ShortConv` layers and
  verifies their three canonical tensors instead of treating them as Qwen
  GatedDeltaNet layers and rejecting valid v0.3.12 models.

### Verified
- All downloaded runtime archives match the SHA-256 digests published in the
  cmf v0.3.12 GitHub Release and export the C ABI used by the app.

## [1.0.5] - 2026-07-18

### Added
- Added the ready-to-run
  [`infosave/Bonsai-1.7Bcmf`](https://huggingface.co/infosave/Bonsai-1.7Bcmf)
  Q1 model as the first featured download, above Bonsai 27B. Its 319 MiB CMF
  file downloads directly with the parallel downloader and needs no conversion.

### Verified
- All bundled Android ABIs and the iOS static library remain on cortiq runtime
  v0.3.11, which is required by the ready Bonsai CMF models.

## [1.0.4] - 2026-07-18

### Fixed
- OpenAI-compatible API validation now returns structured `400`/`404`
  responses for malformed JSON, empty or invalid messages and prompts,
  bad parameter types, unknown task masks, and model-name mismatches.
- Server responses no longer expose Dart exceptions or native runtime details;
  unexpected generation failures return a stable `internal_error` response.
- Token-limit completions now report `finish_reason: length`, including the
  final SSE chunk; streaming chat finishes with an empty delta and `[DONE]`.
- CORS preflight responses advertise `GET`, `POST`, and `OPTIONS`, while the
  request log and error counters retain the actual response status.

### Tests
- Added real loopback HTTP tests covering completions, error schemas, model
  and task validation, CORS, status accounting, and exception redaction.

## [1.0.3] - 2026-07-18

### Added
- **On-device Qwen3.5 GatedDeltaNet conversion**: nested `text_config`,
  hybrid layer schedules, faithful vendor GDN tensors, linear-core geometry,
  RoPE and Gemma-style norm semantics are preserved in the CMF header.
- **On-device Gemma conversion** matching the reference `cortiq convert`:
  Gemma 1 and Gemma 3 scaling/GeGLU/sliding-window fields, plus dense
  Gemma 4 12B/31B dual attention, global/local RoPE, V=K materialization,
  V-norm and final-logit soft-capping. Gemma 2 soft-capping and unsupported
  Gemma 4 MoE/E-series/KV-sharing fail before downloading model weights.
- **Parallel ready-CMF downloads** with 2–8 concurrent HTTP range requests
  and an automatic single-stream fallback for servers without range support.
- Safetensors shards use the same segmented downloader; interrupted CDN
  streams resume from the last received byte with three automatic retries.

### Fixed
- Ready `.cmf` jobs no longer claim to be converting to the placeholder
  Q8_2F quantization; the completed file reports its real per-tensor dtype.
- Structural validation now verifies all Q/K/V/O or all nine GatedDeltaNet
  tensors per layer before native inference.

## [1.0.2] - 2026-07-18

### Fixed
- **Honest quantization labels**: model cards and finished jobs now show
  the dominant tensor dtype read from the file's directory — a q1 file
  shows Q1 (not the header's informational VBIT, and not the quant that
  happened to be selected in the UI for a direct .cmf download).
- **Chat crash with on-device-converted hybrid models** (qwen3.5-style
  GatedDeltaNet): the converter labeled every layer FullAttention and
  passed linear-attention tensors through unfolded, which crashed the
  engine at generate. The converter now refuses hybrid/MoE architectures
  before downloading weights with a clear message (use desktop
  `cortiq convert` or a ready .cmf); dense models are unaffected.
- **Load-time structural validation**: the engine pre-checks the file
  (embed/lm_head presence, per-layer attention tensors vs layer_types)
  and reports a readable error instead of dying natively.
- Memory fit check now uses the platform's live available-RAM figure
  (ActivityManager / os_proc_available_memory) instead of a heuristic.

Verified on desktop through the app's own binding: bonsai-27b-q1.cmf
(27B hybrid, ready .cmf) loads in 0.7 s and generates at 6.2 tok/s.

## [1.0.1] - 2026-07-18

### Added
- **Q8_2F on-device conversion** — the recommended two-field quantization
  now converts right on the phone (f16-RMS column field + per-row
  residual scale, reference-exact).
- **Featured models**: ready-to-run `.cmf` repos pinned above the search
  results (infosave/Bonsai-27Bcmf — 27B at 1-bit in 4.8 GB); one tap
  starts the direct download.
- Engine load failures now surface as a snackbar with the error text.

### Changed
- Conversion is **multi-threaded**: quantization runs on an isolate pool
  sized by the CPU-threads setting (Qwen3-0.6B → Q8_2F in 143 s on 8
  threads), and no longer blocks the UI.
- Bundled cortiq runtime updated to **v0.3.11** (q1 speed batch) on all
  ABIs: arm64-v8a, armeabi-v7a, x86_64, iOS static lib.

### Fixed
- Converted files are now byte-exact against the reference converter:
  f16-rounded scales (previous output degraded inference), `quant_type`
  Q1→VBIT, q1 width guard with per-tensor q8_2f fallback, tensor-name
  canonicalization, f16 for noise-sensitive projections, QUANT_2F
  feature bit. Files converted by 1.0.0 should be re-converted.
- End-to-end verified: an app-converted Q8_2F model loads through the
  cortiq runtime and generates at 100 tok/s (`tool/convert_smoke.dart`).

## [1.0.0] - 2026-07-18

### Added
- **Chat** with streaming replies, per-message token stats (latency, ↑/↓
  tokens, tok/s), markdown, copy/regenerate/stop, and persistent chat
  topics with full context (GPT-style history).
- **Document attachments** (txt/md/code/json/…) inlined into the prompt,
  gated on model capability.
- **Model library**: CMF v2 metadata parsing (arch, quant, layers, context,
  task masks), import from device, load/unload, RAM fit check before load.
- **Hugging Face converter**: hub search, quantization picker, job queue
  with phases/progress/logs/cancel. On-device conversion of safetensors to
  CMF v2 in Q8_ROW, Q1 (1-bit-trained models) and F16; direct download of
  repos that ship `.cmf` files.
- **On-device CMF protocol server** (OpenAI-compatible):
  `/v1/chat/completions` (JSON + SSE), `/v1/completions`, `/v1/models`,
  `/v1/cortiq/status|masks|switch`, `/healthz`; QR code, LAN addresses,
  request log, live stats, optional Bearer-token auth, keep-awake.
- **Settings**: theme, 7 languages (en/ru/de/fr/es/zh/tr), generation
  params (temperature, top-p, max tokens, threads), server port, HF token,
  storage usage.
- **Native runtime**: `dart:ffi` binding to the `cortiq-ffi` C ABI
  (blocking generate in a worker isolate, streamed tokens, cancel via a
  shared native flag); `libcortiq_ffi.so` (arm64-v8a, cmf v0.3.9) bundled
  in the Android APK — real on-device inference out of the box, verified
  end-to-end with qwen3-5-4b Q8_2F (`tool/ffi_smoke.dart`). Demo engine
  remains as the clearly-labeled fallback where the library is absent.
- **CI/CD**: analyze+test+debug-APK on push; tag `v*` builds release APKs
  (universal + per-ABI) and an unsigned iOS archive into GitHub Releases.
- Unit tests: CMF envelope/header/directory round-trip, streaming hash64,
  f16 conversion, safetensors parsing.
