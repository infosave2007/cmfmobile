/// Where user reports about AI replies are delivered.
///
/// A Google Form's `formResponse` endpoint: reports land in the developer's
/// own form (and its sheet), no key ships in the app, and nothing else is
/// sent anywhere. Each field is the form's `entry.<id>` for that question.
/// While [formUrl] is empty, reports are kept in the outbox and nothing is
/// sent.
class ContentReportEndpoint {
  const ContentReportEndpoint({
    required this.formUrl,
    required this.fields,
  });

  final String formUrl;

  /// Report field (`id`, `createdAt`, `reason`, `reply`, `prompt`, `comment`,
  /// `model`, `app`) -> the form's `entry.NNN` name.
  final Map<String, String> fields;

  bool get configured => formUrl.isNotEmpty && fields.isNotEmpty;
}

/// The developer's form "Cortiq — жалобы на ответы ИИ" (urevich55@gmail.com),
/// edit link https://docs.google.com/forms/d/1cnb8CKVFrqmCT11Ns2BpeN-Cc2a7aHm-Xcbmb5DoV8k/edit;
/// responses also go to the linked Google Sheet. Every question is a
/// paragraph named after its report field; renaming them in the form is
/// harmless, deleting one breaks that field.
const contentReportEndpoint = ContentReportEndpoint(
  formUrl:
      'https://docs.google.com/forms/d/e/1FAIpQLScOoY6DGCRxNPEAnrluBSaIme4GsyV6mJUWJ74CA-3wVrI6gA/formResponse',
  fields: {
    'reason': 'entry.2138883010',
    'reply': 'entry.552128351',
    'prompt': 'entry.883841879',
    'comment': 'entry.1320764930',
    'model': 'entry.1731669352',
    'app': 'entry.2146796397',
    'createdAt': 'entry.442131661',
    'id': 'entry.1976512959',
  },
);
