# Source provenance

`src/lib.rs` is the C ABI from `infosave2007/cmf` tag `v0.8.12`
(commit `746df3c3943dc4b4a2a2183937a598e840a14add`), with one module declaration
added for `decision.rs`. Upstream Apache-2.0 license is retained in `LICENSE`.

`decision.rs` is the mobile adapter. Core parsing, encoder, reconstruction,
confidence gates, skill rubrics and typed decision protocol come from the
published **cortiq-decision =0.8.12** crate, not a reimplementation or a text
classification prompt. The adapter disables native cloud calls and learning.

A single static/shared Rust library contains both ABIs. Linking two Rust
static libraries independently would duplicate runtime symbols. Cargo.lock
pins transitive dependencies; Rust 1.96.0, Flutter 3.44.1 and NDK 28.2.13676358
are selected by the build pipelines. Generated binaries are not committed.
