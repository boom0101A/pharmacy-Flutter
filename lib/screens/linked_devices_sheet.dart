import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/pharmacy_service.dart';
import '../theme.dart';

/// الأجهزة المرتبطة بالمخزون المشترك — وصاحبه وحده يُخرج منها ما لا يعرفه.
///
/// بلا هذه الشاشة لم يكن ممكناً حتى *رؤية* من انضمّ، فجهاز انضمّ برمز
/// مشارَك يبقى يقرأ الأسعار والكميات للأبد.
Future<void> showLinkedDevicesSheet(
  BuildContext context, {
  Future<PharmacyMembers?> Function()? loadMembers,
  Future<void> Function(String uid)? removeMember,
  String? myUid,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.bgCard,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => LinkedDevicesSheet(
      loadMembers: loadMembers ?? PharmacyService.instance.fetchMembers,
      removeMember: removeMember ?? PharmacyService.instance.removeMember,
      myUid: myUid ?? AuthService.instance.uid,
    ),
  );
}

class LinkedDevicesSheet extends StatefulWidget {
  const LinkedDevicesSheet({
    super.key,
    required this.loadMembers,
    required this.removeMember,
    required this.myUid,
  });

  final Future<PharmacyMembers?> Function() loadMembers;
  final Future<void> Function(String uid) removeMember;
  final String? myUid;

  @override
  State<LinkedDevicesSheet> createState() => _LinkedDevicesSheetState();
}

class _LinkedDevicesSheetState extends State<LinkedDevicesSheet> {
  bool _loading = true;
  String? _error;
  PharmacyMembers? _members;
  String? _removing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final members = await widget.loadMembers();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _members = members;
      _error = members == null ? 'تعذّر التحميل — تحقق من الإنترنت.' : null;
    });
  }

  Future<void> _remove(String uid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('إخراج الجهاز؟'),
        content: Text(
          'الجهاز ${PharmacyService.shortId(uid)} لن يرى المخزون ولن يعدّله '
          'بعد الآن. ما على هاتفه من نسخة محلية يبقى عنده.',
          style: const TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('إخراج'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _removing = uid);
    try {
      await widget.removeMember(uid);
      if (!mounted) return;
      setState(() {
        _removing = null;
        final m = _members!;
        _members = PharmacyMembers(
          ownerUid: m.ownerUid,
          memberUids: [...m.memberUids]..remove(uid),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _removing = null;
        _error = 'تعذّر الإخراج: $e';
      });
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
              '📱 الأجهزة المرتبطة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'كل جهاز هنا يرى المخزون بأسعاره وكمياته ويعدّله. أخرج أي جهاز '
              'لا تعرفه.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_members != null)
              ..._rows(_members!),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _rows(PharmacyMembers m) {
    final iAmOwner = widget.myUid != null && widget.myUid == m.ownerUid;
    return [
      for (final uid in m.memberUids)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            uid == m.ownerUid
                ? Icons.verified_user_rounded
                : Icons.smartphone_rounded,
            color: uid == m.ownerUid ? AppColors.success : AppColors.primary,
          ),
          title: Text(
            'جهاز ${PharmacyService.shortId(uid)}',
            textDirection: TextDirection.rtl,
          ),
          subtitle: Text(
            [
              if (uid == m.ownerUid) 'صاحب المخزون',
              if (uid == widget.myUid) 'هذا الهاتف',
            ].join(' · '),
            style: const TextStyle(fontSize: 12),
          ),
          trailing: iAmOwner && uid != m.ownerUid
              ? (_removing == uid
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton(
                        onPressed: _removing == null
                            ? () => _remove(uid)
                            : null,
                        child: const Text(
                          'إخراج',
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ))
              : null,
        ),
    ];
  }
}
