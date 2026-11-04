# Source provenance

`src/lib.rs` is the C ABI from `infosave2007/cmf` tag `v0.8.56`
(commit `e22ab021`, crates.io `cortiq-ffi` 0.8.56), with two module declarations
added at the end, for `decision.rs` and `transcribe.rs`. 0.8.56 brings the
lookup-record router into `cortiq_chat*` (Embryo answers from its records) and
`cortiq_last_route`. Upstream Apache-2.0 license is retained in `LICENSE`.

`transcribe.rs` is the mobile speech-to-text adapter: `cortiq_stt_load`,
`cortiq_stt_transcribe` and `cortiq_stt_free` over the published
**cortiq-engine =0.8.56** Whisper path (`cortiq_engine::whisper::transcribe`,
the same code `cortiq transcribe` runs). A Whisper file needs this handle
type because `cortiq_load` builds the text pipeline, which that layout has
no place in.

`decision.rs` is the mobile adapter. Core parsing, encoder, reconstruction,
confidence gates, skill rubrics and typed decision protocol come from the
published **cortiq-decision =0.8.56** crate, not a reimplementation or a text
classification prompt. The adapter disables native cloud calls and learning.

A single static/shared Rust library contains both ABIs. Linking two Rust
static libraries independently would duplicate runtime symbols. Cargo.lock
pins transitive dependencies; Rust 1.96.0, Flutter 3.44.1 and NDK 28.2.13676358
are selected by the build pipelines. Generated binaries are not committed.
