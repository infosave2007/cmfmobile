import '../../data/services/decision_oracle.dart';
import '../../l10n/app_localizations.dart';

String oracleErrorMessage(Object error, AppLocalizations l) => switch (error) {
  OracleValidationException(:final issue) => switch (issue) {
    OracleValidationIssue.url => l.oracleUrlError,
    OracleValidationIssue.model => l.oracleModelError,
    OracleValidationIssue.key => l.oracleKeyError,
  },
  OracleResponseException(:final statusCode) =>
    statusCode == null
        ? l.oracleInvalidResponse
        : l.oracleHttpError(statusCode),
  _ => l.oracleRequestError,
};
