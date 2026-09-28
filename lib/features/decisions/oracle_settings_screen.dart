import 'package:flutter/material.dart';
import '../../data/services/decision_oracle.dart';
import '../../l10n/app_localizations.dart';
import 'oracle_error_message.dart';

class OracleSettingsScreen extends StatefulWidget {
  const OracleSettingsScreen({super.key});
  @override
  State<OracleSettingsScreen> createState() => _OracleSettingsScreenState();
}

class _OracleSettingsScreenState extends State<OracleSettingsScreen> {
  final _url = TextEditingController(),
      _model = TextEditingController(),
      _key = TextEditingController();
  bool _enabled = false, _loading = true, _saving = false;
  String? _error;
  final _store = const OracleSettingsStore();
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await _store.read();
      if (!mounted) return;
      setState(() {
        _url.text = s.baseUrl;
        _model.text = s.model;
        _key.text = s.apiKey;
        _enabled = s.enabled;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = AppLocalizations.of(context).oracleStorageError;
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _store.save(
        OracleSettings(
          enabled: _enabled,
          baseUrl: _url.text.trim(),
          model: _model.text.trim(),
          apiKey: _key.text.trim(),
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is OracleValidationException
              ? oracleErrorMessage(e, AppLocalizations.of(context))
              : AppLocalizations.of(context).oracleStorageError,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _store.clear();
      if (!mounted) return;
      _key.clear();
      await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = AppLocalizations.of(context).oracleStorageError,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _url.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.oracleTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(l.oracleDescription),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.oracleEnabled),
                  value: _enabled,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _enabled = v),
                ),
                TextField(
                  controller: _url,
                  enabled: !_saving,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l.oracleApiUrl,
                    hintText: 'https://openrouter.ai/api/v1',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _model,
                  enabled: !_saving,
                  autocorrect: false,
                  decoration: InputDecoration(labelText: l.oracleModel),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _key,
                  enabled: !_saving,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(labelText: l.oracleApiKey),
                ),
                const SizedBox(height: 12),
                Text(
                  l.oracleKeyHelp,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(l.oracleSave),
                ),
                TextButton(
                  onPressed: _saving ? null : _clear,
                  child: Text(l.oracleDelete),
                ),
              ],
            ),
    );
  }
}
