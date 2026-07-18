import 'cmf_metadata.dart';

/// A .cmf model stored on the device.
class LocalModel {
  const LocalModel({
    required this.id,
    required this.filePath,
    required this.sizeBytes,
    required this.modifiedAt,
    this.meta,
    this.metaError,
  });

  /// File basename without extension; unique within the models directory.
  final String id;
  final String filePath;
  final int sizeBytes;
  final DateTime modifiedAt;
  final CmfMetadata? meta;

  /// Non-null when the file could not be parsed as CMF v2.
  final String? metaError;

  bool get isValid => meta != null;
}
