# Hy-MT2 Q4TP on iPhone 16 — reproducible short-task report

* **Date:** 2026-10-01
* **Device:** iPhone 16 (A18)
* **App:** Cortiq Mobile TestFlight `1.3.0 (47)`
* **Model:** `hy-mt2-1.8b-q4tp.cmf` from [infosave/Hy-MT2-cmf](https://huggingface.co/infosave/Hy-MT2-cmf)
* **Model card shown by the app:** about 906 MiB on disk, about 1.5 GiB estimated RAM
**Settings observed before loading:** CPU worker pool `Auto (5)`; the app’s GPU switch was off. The status API reports whether a GPU backend is linked, not a per-request hardware trace, so this report does not label the run a CPU or GPU benchmark.

> Scope: seven short, deterministic translation requests after a fresh model load. This is a smoke test for responsiveness and basic format preservation, **not** a thermal, battery, long-context, or translation-quality benchmark.

## Method

- The model was downloaded and loaded locally in the TestFlight app.
- Requests went from a client to the bearer-protected phone API over local Wi-Fi; model execution remained on the phone. Consequently, `total_roundtrip_s` includes client, Wi-Fi, prompt processing, and generation.
- Sampling: `temperature: 0`, `top_p: 1`, `max_tokens: 192`.
- The first request is marked `cold`; the following six are `warm` in the same loaded-model session.
- `native_tokens_per_second` is the native rate supplied by the application. It is reported separately from end-to-end time.
- Ambient temperature, battery state, charger state, and long-run thermal behaviour were not controlled or measured.

## Inputs and results

| Case | Source → target | Result (shortened only for table layout) | Completion tokens | Native tok/s | End-to-end s |
|---|---|---|---:|---:|---:|
| cold RU→EN | «Посылка прибудет завтра после 15:00. Пожалуйста, позвоните перед доставкой.» | “The package will arrive tomorrow after 15:00. Please call before delivery.” | 17 | 15.0 | 1.144 |
| warm EN→RU | “Your verification code expires in 10 minutes. Do not share it with anyone.” | «Ваш код проверки истекает через 10 минут. Не передавайте его никому.» | 29 | 21.8 | 1.340 |
| warm DE→RU | “Die Lieferung verspätet sich um zwei Tage. Die Sendungsnummer bleibt unverändert.” | «Доставка задерживается на два дня. Номер отправки остается неизменным.» | 27 | 18.4 | 1.501 |
| warm TR→RU | “Toplantı yarın saat 10.00'da başlayacak.” | «Встреча начнется завтра в 10:00.» | 16 | 16.1 | 1.000 |
| warm ZH→EN | “请在周五之前发送发票，并保留订单编号 AB-123。” | “Please send the invoice by Friday and keep the order number AB-123.” | 16 | 16.2 | 0.996 |
| warm idiom EN→RU | “The report is due Friday, but the team is still ironing out a few issues.” | «Отчет должен быть представлен до пятницы, но команда все еще решает некоторые проблемы.» | 32 | 19.6 | 1.642 |
| warm JSON EN→DE | `{"message":"Hello, {user_name}. Your order {order_id} is ready.","count":3}` | `{"message":"Hallo, {user_name}. Ihr Auftrag {order_id} ist fertig.","count":3}` | 29 | 14.4 | 2.015 |

The JSON response parsed successfully; its keys, `count`, and both placeholders were preserved.

## Aggregates used in the article

| Metric | Value |
|---|---:|
| Non-empty completed responses | 7 / 7 (`finish_reason: stop`) |
| Warm native rate | 14.4–21.8 tok/s |
| Mean warm native rate | **17.75 tok/s** |
| Warm full round-trip | 0.996–2.015 s |
| Mean warm full round-trip | **1.416 s** |

The companion machine-readable record, including full returned text, token counts and unrounded timings, is [`iphone-hymt2-q4tp-20261001.json`](iphone-hymt2-q4tp-20261001.json).

## Limits

The file size is not the whole memory cost; the runtime and KV cache are additional. These figures are specific to this device, app build, loaded model, request set and local network. Do not use them to infer performance on another iPhone, on Android, with Metal/GPU enabled, or for long prompts. Translation of legal, medical, financial, terminology-heavy, or structured production text still needs task-specific validation and human review.
