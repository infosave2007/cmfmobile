import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../data/services/decision_oracle.dart';
import 'oracle_settings_screen.dart';
import '../../l10n/app_localizations.dart';
import '../chat/model_picker_sheet.dart';

/// A decision is a label (or an abstention), not a generated chat reply.
class DecisionScreen extends ConsumerStatefulWidget {
  const DecisionScreen({super.key});
  @override
  ConsumerState<DecisionScreen> createState() => _DecisionScreenState();
}

class _DecisionScreenState extends ConsumerState<DecisionScreen> {
  final _input = TextEditingController();
  List<String> _skills = [];
  String? _skill;
  String _profile = 'balanced';
  bool _loading = true, _busy = false;
  String? _error;
  Map<String, dynamic>? _result;
  Map<String, dynamic>? _oracleResult;
  String _decidedText = '', _decidedSkill = '';

  Future<void> _askOracle() async {
    if (_busy || _result == null || _result!['accepted'] == true) return;
    try {
      final settings = await const OracleSettingsStore().read();
      if (!mounted) return;
      if (!settings.enabled) {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const OracleSettingsScreen()),
        );
        return;
      }
      final l = AppLocalizations.of(context);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.oracleAsk),
          content: Text(
            '${l.oracleConfirm}\n\n${settings.endpoint.host} · ${settings.model}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.oracleAsk),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() {
        _busy = true;
        _error = null;
        _oracleResult = null;
      });
      final skill = await ref
          .read(engineProvider)
          .decisionRequest('GET', '/v1/skills/$_decidedSkill');
      if (skill['status'] != 200) throw StateError('Skill is no longer loaded');
      final result = await DecisionOracle().ask(
        settings,
        skill['body'] as Map<String, dynamic>,
        _decidedText,
      );
      if (mounted) setState(() => _oracleResult = result);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static const examples = {
    'banking77': 'I still have not received my new card',
    'clinc150': 'What is the weather forecast for tomorrow?',
    'massive': 'Play some jazz music',
  };

  @override
  void initState() {
    super.initState();
    _loadSkills();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _loadSkills() async {
    try {
      final response = await ref
          .read(engineProvider)
          .decisionRequest('GET', '/v1/skills');
      if (response['status'] != 200) throw StateError('${response['body']}');
      final skills = (response['body']['skills'] as List)
          .map((s) => s['id'] as String)
          .toList();
      if (!mounted) return;
      setState(() {
        _skills = skills;
        _skill = skills.firstOrNull;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _decide() async {
    if (_skill == null || _input.text.trim().isEmpty || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _oracleResult = null;
      _decidedText = _input.text.trim();
      _decidedSkill = _skill!;
    });
    try {
      final response = await ref.read(engineProvider).decisionRequest(
        'POST',
        '/v1/decide',
        {'text': _input.text.trim(), 'skill': _skill, 'profile': _profile},
      );
      if (response['status'] != 200) {
        throw StateError('${response['body']['error']['message']}');
      }
      if (mounted) {
        setState(() => _result = response['body'] as Map<String, dynamic>);
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final result = _result;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.decisionTitle),
        actions: [
          IconButton(
            tooltip: l.oracleTitle,
            icon: const Icon(Icons.cloud_outlined),
            onPressed: _busy
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const OracleSettingsScreen(),
                    ),
                  ),
          ),
          IconButton(
            tooltip: l.navModels,
            icon: const Icon(Icons.layers_outlined),
            onPressed: _busy ? null : () => showModelPickerSheet(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            l.decisionSubtitle,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          if (_loading) const LinearProgressIndicator(),
          if (_skills.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              key: const Key('decision-skill'),
              initialValue: _skill,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.decisionSkill),
              items: [
                for (final skill in _skills)
                  DropdownMenuItem(value: skill, child: Text(skill)),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() {
                      _skill = value;
                      _result = null;
                    }),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('decision-input'),
              controller: _input,
              minLines: 3,
              maxLines: 7,
              maxLength: 2000,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: l.decisionInput,
                alignLabelWithHint: true,
              ),
            ),
            if (examples.containsKey(_skill))
              Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  label: Text(l.decisionExample),
                  avatar: const Icon(Icons.bolt, size: 18),
                  onPressed: _busy
                      ? null
                      : () {
                          _input.text = examples[_skill]!;
                          setState(() => _result = null);
                        },
                ),
              ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _profile,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.decisionPolicy),
              items: [
                DropdownMenuItem(
                  value: 'balanced',
                  child: Text(l.decisionBalanced),
                ),
                DropdownMenuItem(
                  value: 'quality-first',
                  child: Text(l.decisionCareful),
                ),
                DropdownMenuItem(
                  value: 'cost-saver',
                  child: Text(l.decisionBestEffort),
                ),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() {
                      _profile = value!;
                      _result = null;
                    }),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('decision-run'),
              onPressed: _busy ? null : _decide,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(l.decisionRun),
              ),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: TextStyle(color: scheme.error)),
            ),
          if (result != null) ...[
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          result['accepted'] == true
                              ? Icons.verified_outlined
                              : Icons.help_outline,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            result['accepted'] == true
                                ? l.decisionAccepted
                                : l.decisionAbstained,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      result['accepted'] == true
                          ? '${result['choice']}'
                          : l.decisionAbstainBody,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${l.decisionConfidence}: ${((result['confidence'] as num).clamp(0, 1) * 100).toStringAsFixed(1)}%',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${l.decisionTotal}: ${((result['timings_us']['total'] as num) / 1000).toStringAsFixed(2)} ms'
                      ' · ${result['device']}',
                    ),
                    Text(
                      '${l.decisionResonance}: ${((result['timings_us']['resonance'] as num) / 1000).toStringAsFixed(3)} ms',
                    ),
                  ],
                ),
              ),
            ),
            if (result['accepted'] != true)
              OutlinedButton.icon(
                onPressed: _busy ? null : _askOracle,
                icon: const Icon(Icons.cloud_outlined),
                label: Text(l.oracleAsk),
              ),
            if (_oracleResult != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.oracleAnswer,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        _oracleResult!['label'] as String? ??
                            l.decisionAbstained,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${_oracleResult!['model']} · ${_oracleResult!['latency_ms']} ms',
                      ),
                      if (_oracleResult!['cost_usd'] != null)
                        Text('USD ${_oracleResult!['cost_usd']}'),
                      Text(
                        l.oracleNotTraining,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ExpansionTile(
              title: Text(l.decisionExplain),
              childrenPadding: const EdgeInsets.all(16),
              children: [
                Text(l.decisionErrorHelp),
                const SizedBox(height: 12),
                for (final item in result['errors'] as List)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item['label']}  ·  ${(item['error'] as num).toStringAsFixed(4)}',
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value:
                              ((item['error'] as num) /
                                      math.max(
                                        0.000001,
                                        (result['errors'] as List)
                                            .map(
                                              (e) => (e['error'] as num)
                                                  .toDouble(),
                                            )
                                            .reduce(math.max),
                                      ))
                                  .clamp(0, 1)
                                  .toDouble(),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            ExpansionTile(
              title: Text('JSON / API'),
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.copy),
                  label: Text(l.decisionCopy),
                  onPressed: () => Clipboard.setData(
                    ClipboardData(
                      text: const JsonEncoder.withIndent('  ').convert(result),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ').convert(result),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(l.decisionOffline, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
