import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/medicine.dart';
import '../services/alerts.dart';
import '../services/pharmacy_prefs.dart';
import '../state/medicine_store.dart';
import '../theme.dart';
import '../widgets/glass.dart';

/// عدد التنبيهات التي تستحق الانتباه الآن (الجرس): كل شيء عدا «قريبة».
int criticalAlertCount(
  Iterable<Medicine> all, {
  required Set<String> dismissed,
}) => computeAlerts(
  all,
  now: DateTime.now(),
  dismissed: dismissed,
).where((a) => a.isCritical).length;

/// مركز التنبيهات: المنتهية، والعاجلة، والنافدة، والمنخفضة، والقريبة —
/// بأسماء المواد. الضغط يفتح المادة، و«تمّ» يخفي التنبيه على كل أجهزة
/// الصيدلية حتى يتغيّر نوعه أو تنحلّ المشكلة.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key, required this.store, required this.onOpen});

  final MedicineStore store;

  /// يفتح صفحة المادة (من الرئيسية، بأزرار التعديل والحذف نفسها).
  final void Function(Medicine m) onOpen;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _prefs = PharmacyPrefs.instance;
  bool _showHidden = false;

  @override
  void initState() {
    super.initState();
    // مفاتيح «تمّ» لتنبيهات انحلّت (عُدّلت المادة أو حُذفت) لا داعي لها
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final active = {
        for (final a in computeAlerts(widget.store.all, now: DateTime.now()))
          a.key,
      };
      _prefs.prune(active);
    });
  }

  Future<void> _dismiss(StockAlert a) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    await _prefs.dismiss(a.key);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l.alertHidden),
          action: SnackBarAction(
            label: l.undo,
            onPressed: () => _prefs.restore([a.key]),
          ),
        ),
      );
  }

  String _detail(AppLocalizations l, StockAlert a) => switch (a.kind) {
    AlertKind.expired => l.expiredDaysAgo(
      (a.daysLeft ?? 0).abs() < 1 ? 1 : a.daysLeft!.abs(),
    ),
    AlertKind.urgent || AlertKind.soon =>
      a.daysLeft == 0 ? l.expiresToday : l.daysLeft(a.daysLeft ?? 0),
    AlertKind.out => l.alertOutDetail,
    AlertKind.low => l.alertLowDetail(
      a.item.quantity,
      a.item.lowStockThreshold,
    ),
  };

  String _section(AppLocalizations l, AlertKind kind, int n) => switch (kind) {
    AlertKind.expired => l.alertsSecExpired(n),
    AlertKind.urgent => l.alertsSecUrgent(n),
    AlertKind.out => l.alertsSecOut(n),
    AlertKind.low => l.alertsSecLow(n),
    AlertKind.soon => l.alertsSecSoon(n),
  };

  static Color _color(AlertKind kind) => switch (kind) {
    AlertKind.expired || AlertKind.out => AppColors.danger,
    AlertKind.urgent || AlertKind.low => AppColors.warning,
    AlertKind.soon => AppColors.primary2,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: GlassAppBar(title: Text(l.alertsTitle)),
      body: ListenableBuilder(
        listenable: Listenable.merge([widget.store, _prefs]),
        builder: (context, _) {
          final dismissed = _prefs.alertDismissals;
          final all = computeAlerts(widget.store.all, now: DateTime.now());
          final hidden = all.where((a) => dismissed.contains(a.key)).length;
          final shown = _showHidden
              ? all
              : all.where((a) => !dismissed.contains(a.key)).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
            children: [
              if (shown.isEmpty) _empty(l),
              for (final kind in AlertKind.values)
                ..._group(l, kind, [
                  for (final a in shown)
                    if (a.kind == kind) a,
                ], dismissed),
              if (hidden > 0 || _showHidden)
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _showHidden = !_showHidden),
                    child: Text(
                      _showHidden
                          ? l.alertsHideHidden
                          : l.alertsShowHidden(hidden),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _empty(AppLocalizations l) => Padding(
    padding: const EdgeInsets.only(top: 80, bottom: 24),
    child: Column(
      children: [
        Text(
          l.alertsEmpty,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          l.alertsEmptySub,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    ),
  );

  List<Widget> _group(
    AppLocalizations l,
    AlertKind kind,
    List<StockAlert> alerts,
    Set<String> dismissed,
  ) {
    if (alerts.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Text(
          _section(l, kind, alerts.length),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: _color(kind),
          ),
        ),
      ),
      for (final a in alerts) _row(l, a, dismissed.contains(a.key)),
    ];
  }

  Widget _row(AppLocalizations l, StockAlert a, bool isHidden) {
    final color = _color(a.kind);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: isHidden ? .55 : 1,
        child: GlassSurface(
          radius: 18,
          shadow: false,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => widget.onOpen(a.item),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 6, 10),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _detail(l, a),
                          style: TextStyle(fontSize: 12, color: color),
                        ),
                      ],
                    ),
                  ),
                  isHidden
                      ? TextButton(
                          key: Key('alertRestore_${a.key}'),
                          onPressed: () => _prefs.restore([a.key]),
                          child: Text(l.alertRestore),
                        )
                      : TextButton(
                          key: Key('alertDone_${a.key}'),
                          onPressed: () => _dismiss(a),
                          child: Text(l.alertDone),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
