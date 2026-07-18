import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/local_model.dart';
import 'cmf_format.dart';

/// Manages the on-device .cmf model library
/// (documents/models, same role as gateway's models_dir).
class ModelRepository {
  Directory? _dir;

  Future<Directory> modelsDir() async {
    if (_dir != null) return _dir!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/models');
    await dir.create(recursive: true);
    _dir = dir;
    return dir;
  }

  Future<List<LocalModel>> list() async {
    final dir = await modelsDir();
    final files = await dir
        .list()
        .where((e) => e is File && e.path.toLowerCase().endsWith('.cmf'))
        .cast<File>()
        .toList();
    final models = <LocalModel>[];
    for (final f in files) {
      models.add(await _describe(f));
    }
    models.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return models;
  }

  Future<LocalModel> _describe(File f) async {
    final stat = await f.stat();
    final id = f.uri.pathSegments.last.replaceAll(RegExp(r'\.cmf$'), '');
    try {
      final meta = await CmfReader.readMetadata(f.path);
      return LocalModel(
        id: id,
        filePath: f.path,
        sizeBytes: stat.size,
        modifiedAt: stat.modified,
        meta: meta,
      );
    } catch (e) {
      return LocalModel(
        id: id,
        filePath: f.path,
        sizeBytes: stat.size,
        modifiedAt: stat.modified,
        metaError: e.toString(),
      );
    }
  }

  /// Copies an external .cmf file into the library.
  Future<LocalModel> importFile(String sourcePath) async {
    final dir = await modelsDir();
    final name = File(sourcePath).uri.pathSegments.last;
    final dest = File('${dir.path}/$name');
    await File(sourcePath).copy(dest.path);
    return _describe(dest);
  }

  Future<void> delete(LocalModel model) async {
    final f = File(model.filePath);
    if (await f.exists()) await f.delete();
  }

  Future<int> totalSizeBytes() async {
    final models = await list();
    return models.fold<int>(0, (sum, m) => sum + m.sizeBytes);
  }
}
