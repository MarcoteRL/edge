// Hevy connection: paste a Hevy Pro API key, sync, disconnect. What a sync
// does is in import/hevy_import.dart.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../import/hevy_import.dart';
import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import '../../state/clock_format.dart' show formatClockOf;
import '../screens/journal_compose.dart' show OsTextField;
import '../ui2.dart';

class HevyScreen extends StatefulWidget {
  const HevyScreen({super.key});

  @override
  State<HevyScreen> createState() => _HevyScreenState();
}

class _HevyScreenState extends State<HevyScreen> {
  final _key = TextEditingController();
  bool _connected = false;
  bool _busy = false;
  DateTime? _last;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final k = await HevyStore.key();
    final last = await HevyStore.lastSync();
    if (!mounted) return;
    setState(() {
      _connected = k != null;
      _last = last;
    });
  }

  Future<void> _sync({bool saveKey = false}) async {
    final l = AppLocalizations.of(context);
    final app = context.read<AppState>();
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      if (saveKey && _key.text.trim().isNotEmpty) {
        await HevyStore.setKey(_key.text);
        _key.clear();
      }
      final r = await app.hevySyncNow();
      if (r != null) {
        _msg = l?.hevyResult(r.created, r.attached, r.updated, r.sets) ??
            'New: ${r.created} · Matched to band sessions: ${r.attached} · '
                'Updated: ${r.updated} · ${r.sets} sets';
      }
    } catch (e) {
      _msg = l?.hevyError('$e') ?? "Couldn't sync: $e";
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refresh();
    }
  }

  Future<void> _disconnect() async {
    await HevyStore.setKey(null);
    await _refresh();
  }

  String _stamp(DateTime t) {
    final now = DateTime.now();
    final sameDay =
        t.year == now.year && t.month == now.month && t.day == now.day;
    final clock = formatClockOf(t);
    return sameDay ? clock : '${t.day}/${t.month} $clock';
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final when = _last == null ? (l?.dataNever ?? 'Never') : _stamp(_last!);
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: S.x4),
            child: NavBar(l?.hevyTitle ?? 'Hevy'),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(S.x4, 0, S.x4, S.x10),
              children: [
                Text(
                  l?.hevyIntro ??
                      'Paste your Hevy API key (Hevy Pro, at '
                          'hevy.com/settings?developer). Workouts are read, '
                          'never changed. Each one is matched to the band '
                          'session it happened in, or logged as a new weight '
                          'training session scored from the band.',
                  style: F.body.copyWith(color: p.ink2, height: 1.45),
                ),
                const SizedBox(height: S.x5),
                if (_connected) ...[
                  Surface(
                    child: Row(children: [
                      Icon(LucideIcons.circleCheck,
                          size: 18, color: p.on(C.green)),
                      const SizedBox(width: S.x3),
                      Expanded(
                        child: Text(
                          l?.hevyConnected(when) ??
                              'Connected · last sync $when',
                          style: F.body.copyWith(color: p.ink),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: S.x4),
                  BigButton(
                    l?.hevySyncNow ?? 'Sync now',
                    icon: LucideIcons.refreshCw,
                    color: C.blue,
                    busy: _busy,
                    onTap: _busy ? null : () => _sync(),
                  ),
                  const SizedBox(height: S.x3),
                  BigButton(
                    l?.hevyDisconnect ?? 'Disconnect',
                    icon: LucideIcons.unlink,
                    color: C.red,
                    soft: true,
                    onTap: _busy ? null : _disconnect,
                  ),
                ] else ...[
                  OsTextField(
                    controller: _key,
                    label: l?.hevyKeyLabel ?? 'API key',
                    hint: l?.hevyKeyHint ?? 'from hevy.com/settings?developer',
                  ),
                  const SizedBox(height: S.x4),
                  BigButton(
                    l?.hevySaveSync ?? 'Save and sync',
                    icon: LucideIcons.check,
                    color: C.blue,
                    busy: _busy,
                    onTap: _busy ? null : () => _sync(saveKey: true),
                  ),
                ],
                if (_msg != null) ...[
                  const SizedBox(height: S.x4),
                  Text(_msg!, style: F.cap.copyWith(color: p.ink3)),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
