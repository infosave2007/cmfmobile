# NPU module (prebuilt)

`prebuilt/arm64-v8a` holds the two halves of Cortiq's Hexagon module, built
from infosave2007/cmf `crates/cortiq-engine/npu/hvx` at tag `v0.9.4` (the
module's source is unchanged there since commit `65742ae3`, where these were built):

| file | runs on | size |
|---|---|---|
| `libcortiq_npu.so` | Android, arm64 (FastRPC client, loaded by the runtime with dlopen) | 15048 B |
| `libcortiq_hvx_skel.so` | the Hexagon cDSP, unsigned PD, built for v68 (Snapdragon 778G/888 and every newer Hexagon) | 18448 B |

They are committed because building them needs the Qualcomm Hexagon SDK
(behind a Qualcomm ID login), which CI does not have. `scripts/build_native.sh
android-arm64` copies them next to `libcortiq_ffi.so`. To rebuild, see the
engine's `npu/hvx/README.md` and replace both files together.

The app's NPU switch (Settings) turns the lane on; the runtime measures it
against the CPU on a long prompt and keeps it only where it is faster.
Snapdragon 778G, LFM3-1.7B q4tp, a 256-token prompt: 22.7 tokens/s on the
CPU, 30.9 with the NPU; the answer's speed is unchanged.
