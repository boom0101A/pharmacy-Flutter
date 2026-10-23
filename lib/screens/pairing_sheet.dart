import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../services/pharmacy_service.dart';
import '../state/medicine_store.dart';
import '../theme.dart';
import '../widgets/glass.dart';

/// الجهاز الذي يملك المخزون فعلاً يفتح هذه الشاشة لتوليد رمز اقتران
/// والموافقة على طلب انضمام جهاز آخر.
Future<void> showSharePairingSheet(BuildContext context) {
  return showGlassSheet(
    context: context,
    builder: (_) => const _SharePairingSheet(),
  );
}

/// الجهاز الجديد يفتح هذه الشاشة ويُدخل رمزاً ظاهراً على الجهاز الآخر.
Future<void> showJoinPairingSheet(BuildContext context, MedicineStore store) {
  return showGlassSheet(
    context: context,
    builder: (_) => _JoinPairingSheet(store: store),
  );
}

class _SharePairingSheet extends StatefulWidget {
  const _SharePairingSheet();

  @override
  State<_SharePairingSheet> createState() => _SharePairingSheetState();
}

class _SharePairingSheetState extends State<_SharePairingSheet> {
  String? _code;
  bool _loading = true;
  String? _error;
  bool _responding = false;

  /// آخر حالة رآها البث — رمز لم ينضمّ به أحد يُلغى عند إغلاق الشاشة.
  PairingStatus? _lastStatus;

  /// يعيد بناء الشاشة لحظة انتهاء الرمز: البث لا يصدر حدثاً عند الانتهاء،
  /// فكانت «بانتظار الجهاز الآخر…» تبقى بعد موت الرمز.
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    final code = _code;
    // رمز مفتوح بعد إغلاق الشاشة يبقى صالحاً لدقائق ولا أحد يراقب طلباته
    if (code != null && _lastStatus != PairingStatus.joined) {
      unawaited(
        PharmacyService.instance
            .cancelPairingCode(code)
            .catchError((Object _) {}),
      );
    }
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
      _code = null;
    });

    final pid = await PharmacyService.instance.ensureOwnPharmacy();
    if (pid == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذّر التحضير — تحقق من الاتصال بالإنترنت.';
      });
      return;
    }

    final code = await PharmacyService.instance.createPairingCode(pid);
    if (!mounted) return;
    _expiryTimer?.cancel();
    if (code != null) {
      _expiryTimer = Timer(
        PharmacyService.pairingTtl + const Duration(seconds: 1),
        () {
          if (mounted) setState(() {});
        },
      );
    }
    setState(() {
      _loading = false;
      _code = code;
      _error = code == null ? 'تعذّر توليد رمز — حاول مرة أخرى.' : null;
    });
  }

  Future<void> _respond(String code, bool approve) async {
    setState(() => _responding = true);
    try {
      if (approve) {
        await PharmacyService.instance.approveJoin(code);
      } else {
        await PharmacyService.instance.declineJoin(code);
      }
      if (mounted) setState(() => _error = null);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'تعذّر إتمام الطلب — حاول مرة أخرى.');
      }
    } finally {
      if (mounted) setState(() => _responding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔗 مشاركة المخزون مع جهاز آخر',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'أعطِ هذا الرمز للجهاز الآخر — صالح لمدة 10 دقائق. بعد إدخاله '
              'هناك، وافِق على الطلب هنا ليصبح المخزون مشتركاً بين الجهازين.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_code != null)
              _buildCodeAndListener(_code!)
            else
              _buildError(),
          ],
        ),
      ),
    );
  }

  Widget _buildError() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _error ?? 'خطأ غير معروف',
        style: const TextStyle(color: AppColors.danger, fontSize: 13),
      ),
      const SizedBox(height: 12),
      FilledButton(onPressed: _generate, child: const Text('حاول مرة أخرى')),
    ],
  );

  Widget _buildCodeAndListener(String code) {
    return StreamBuilder<DocumentSnapshot<Map<String, Object?>>>(
      stream: PharmacyService.instance.watchPairing(code),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final status = data == null
            ? PairingStatus.open
            : PharmacyService.statusOf(data, DateTime.now());
        _lastStatus = status;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 24,
                ),
                // صندوق الرمز: زجاج متدرّج تيل/أزرق بحدّ تيل (.code في التصميم)
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Color(0x2E2DD4BF), Color(0x1438BDF8)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0x662DD4BF)),
                ),
                child: SelectableText(
                  code,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                    color: Color(0xFFCCFBF1),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            switch (status) {
              PairingStatus.requested => _buildApproval(
                code,
                data?['joinerUid'] as String?,
              ),
              PairingStatus.joined => _buildJoined(),
              PairingStatus.expired => _buildExpired(),
              _ => _buildWaiting(),
            },
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildWaiting() => const Row(
    children: [
      SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      SizedBox(width: 10),
      Text(
        'بانتظار الجهاز الآخر…',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
    ],
  );

  Widget _buildApproval(String code, String? joinerUid) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        approvalPrompt(joinerUid),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
      const Text(
        'وافق فقط إن كان الجهاز أمامك الآن وأنت من أعطاه الرمز.',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: _responding ? null : () => _respond(code, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.success),
              child: const Text('موافقة'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: _responding ? null : () => _respond(code, false),
              child: const Text('رفض'),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _buildJoined() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'تم! المخزون مشترك الآن.',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('تم'),
        ),
      ),
    ],
  );

  Widget _buildExpired() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'انتهت صلاحية الرمز.',
        style: TextStyle(color: AppColors.warning, fontSize: 13),
      ),
      const SizedBox(height: 10),
      FilledButton(onPressed: _generate, child: const Text('توليد رمز جديد')),
    ],
  );
}

class _JoinPairingSheet extends StatefulWidget {
  const _JoinPairingSheet({required this.store});

  final MedicineStore store;

  @override
  State<_JoinPairingSheet> createState() => _JoinPairingSheetState();
}

class _JoinPairingSheetState extends State<_JoinPairingSheet> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  /// الرمز الذي أُرسل طلب انضمام باسمه — بمجرد ضبطه تنتقل الشاشة لوضع
  /// الانتظار وتستمع لرد صاحب الصيدلية.
  String? _pendingCode;

  /// يمنع تكرار استدعاء [_onJoined] عند كل إعادة بناء ناتجة عن نفس الحدث.
  bool _handledJoin = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.length != 6 || int.tryParse(code) == null) {
      setState(() => _error = 'أدخل الرمز المكوّن من 6 أرقام.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await PharmacyService.instance.requestJoin(code);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _pendingCode = code;
      });
    } on PairingJoinException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = switch (e.reason) {
          PairingJoinError.notFound => 'الرمز غير صحيح.',
          PairingJoinError.expired => 'انتهت صلاحية الرمز، اطلب رمزاً جديداً.',
          PairingJoinError.notOpen => 'هذا الرمز استُخدم من قبل.',
        };
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'تعذّر الاتصال — تحقق من الإنترنت وحاول مرة أخرى.';
      });
    }
  }

  Future<void> _onJoined(String pharmacyId) async {
    await AppSettings.instance.setPharmacyId(pharmacyId);
    await widget.store.refreshFromCloud(manual: true);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('تم الانضمام! جاري تنزيل المخزون…')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final code = _pendingCode;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔗 الانضمام إلى مخزون موجود',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'أدخل الرمز الظاهر على الجهاز الذي يملك المخزون حالياً.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            if (code == null) _buildForm() else _buildWaitingForApproval(code),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        key: const Key('pairing_code_field'),
        controller: _controller,
        keyboardType: TextInputType.number,
        maxLength: 6,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: 6,
        ),
        decoration: const InputDecoration(counterText: '', hintText: '000000'),
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(
          _error!,
          style: const TextStyle(color: AppColors.danger, fontSize: 13),
        ),
      ],
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('انضمام'),
        ),
      ),
    ],
  );

  Widget _buildWaitingForApproval(String code) {
    return StreamBuilder<DocumentSnapshot<Map<String, Object?>>>(
      stream: PharmacyService.instance.watchPairing(code),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final status = data == null
            ? PairingStatus.requested
            : PharmacyService.statusOf(data, DateTime.now());

        if (status == PairingStatus.joined) {
          final pharmacyId = data?['pharmacyId'] as String?;
          if (pharmacyId != null && !_handledJoin) {
            _handledJoin = true;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _onJoined(pharmacyId),
            );
          }
          return const Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تمت الموافقة! جاري تنزيل المخزون…',
                  style: TextStyle(color: AppColors.success),
                ),
              ),
            ],
          );
        }
        if (status == PairingStatus.declined) {
          return const Text(
            'تم رفض الطلب من الجهاز الآخر.',
            style: TextStyle(color: AppColors.danger),
          );
        }
        if (status == PairingStatus.expired) {
          return const Text(
            'انتهت صلاحية الرمز قبل أن يوافق الجهاز الآخر.',
            style: TextStyle(color: AppColors.warning),
          );
        }
        return const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'تم الإرسال — بانتظار موافقة الجهاز الآخر…',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// نص طلب الموافقة — يسمّي الجهاز بمعرّفه القصير ليطابقه المستخدم مع ما يظهر
/// في «الأجهزة المرتبطة» لاحقاً.
@visibleForTesting
String approvalPrompt(String? joinerUid) => joinerUid == null
    ? 'جهاز آخر يطلب الانضمام — هل توافق؟'
    : 'الجهاز ${PharmacyService.shortId(joinerUid)} يطلب الانضمام — هل توافق؟';
