# Privacy Policy — Cortiq: Local AI Models

**Effective date: November 26, 2026**

Cortiq runs chat and CMF Decision models on your device by default. Network
features are optional and described below; enabling them can send data off
your phone.

## Analytics and accounts

The app has no developer-operated account system, advertising identifiers,
analytics or automatic conversation uploads. Your API credentials belong to
the providers you choose, not to a Cortiq account.

## Local models and conversations

Chat history, attached documents, model files and settings are stored on your
device. Local decisions do not require a cloud API. Choosing a local model does
not automatically enable an oracle or train a model on your requests.

## Connections you choose

- **Hugging Face.** Searching, downloading and converting models connects directly
  to huggingface.co. Requests include your search or repository identifier,
  network metadata such as your IP address, and your Hugging Face token if
  configured. The [Hugging Face privacy policy](https://huggingface.co/privacy)
  applies to those connections.
- **Phone API server.** When enabled, this serves the loaded model to connected
  clients. Clients send requests and receive results. Use bearer authentication
  and a trusted network: the phone's HTTP API is not encrypted and should not
  be exposed to the public internet. It cannot spend your oracle API key.
- **Companion.** If you connect your own computer, model computation and related
  data are exchanged with that computer. This is not an entirely on-device
  session. Use a cable or trusted network and the shared access token.
- **Optional oracle.** The oracle is off by default. When a local decision is
  uncertain, you can explicitly confirm sending the request text and skill
  criteria to the HTTPS API provider and model configured in **Settings → Oracle**.
  The API key is sent to that provider for authentication. The provider can
  charge for the call and handles the submitted data under its own policies.
  No call is made merely by saving settings or opening the screen. Oracle
  responses are identified separately and do not automatically retrain a model.

## Reporting AI replies

Every reply written by a model has a **Report** button (the flag under the
reply). Nothing is sent unless you press **Send** in that form. A report goes
to the developer of Cortiq over HTTPS (a Google Form owned by the developer,
so Google processes it under its own policies) and contains only: the text of
the reported reply, the reason you chose, your comment if you wrote one, your
previous message if you left that box ticked, the model's file name, the app
version and the platform (Android or iOS). No account, device identifier,
other messages, attachments or files are included. A report made offline is
kept on the device and sent when you are online. Reports are used to find
models that produce harmful content, remove or flag them in the in-app
catalog and improve filtering; they are kept for up to two years. To have a
report deleted, write to urevich55@gmail.com with the date you sent it.

## Oracle credentials

Oracle settings and API keys are stored using Android Keystore-backed encrypted
storage or iOS Keychain. They are not included in CMF model files, phone API
responses or application request logs. Oracle credential storage is excluded
from Android backup. No other client can retrieve the key through the phone API.

## Deletion

You can delete local conversations and downloaded models in the app. Use
**Settings → Oracle → Delete key and reset** to remove oracle credentials before
uninstalling the app. Removing local data does not delete anything a provider
may already have received; contact that provider for its retention and deletion
options.

## Children

The app does not add child-specific tracking or analytics. If an external
provider is configured, its terms and age restrictions also apply.

## Changes and contact

Updates are published at this URL with a revised date. Questions: open an issue
at [github.com/infosave2007/cmfmobile](https://github.com/infosave2007/cmfmobile/issues)
or email urevich55@gmail.com. Do not post API keys or private requests in issues.
