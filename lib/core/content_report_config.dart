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

const contentReportEndpoint = ContentReportEndpoint(
  formUrl: '',
  fields: {},
);
