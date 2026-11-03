import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme.dart';
import '../l10n/l10n.dart';

/// شاشة مسح الباركود — كاميرا ملء الشاشة.
/// ترجع نص الباركود عبر Navigator.pop، أو null إذا ألغى المستخدم.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.itf14,
      BarcodeFormat.dataMatrix,
      BarcodeFormat.qrCode,
    ],
  );

  bool _handled = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    // `mounted` ضروري بجانب `_handled`: الكشف يصل من تدفّق المنصة، فقد يصل
    // بعد إغلاق الشاشة فيرمي «deactivated widget's ancestor».
    if (_handled || !mounted) return;
    final code = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere(
          (v) => v != null && v.trim().isNotEmpty,
          orElse: () => null,
        );
    if (code == null) return;

    _handled = true;
    HapticFeedback.heavyImpact();
    Navigator.of(context).pop(code.trim());
  }

  /// إغلاق يدوي — يرفع `_handled` أولاً.
  ///
  /// بدونه: كشف يصل في نفس لحظة الضغط على ✕ يجد `_handled == false` فينفّذ
  /// `pop` ثانياً، فتُغلق الشاشة التي تحت الماسح أيضاً — أي نموذج الإضافة بكل
  /// ما كتبه المستخدم فيه.
  void _closeManually() {
    if (_handled || !mounted) return;
    _handled = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _ErrorView(error: error),
          ),
          const _ScanOverlay(),
          SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      style: _glassCircle,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                      iconSize: 30,
                      onPressed: _closeManually,
                    ),
                    const Spacer(),
                    IconButton(
                      style: _glassCircle,
                      icon: Icon(
                        _torchOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        color: _torchOn ? AppColors.warning : Colors.white,
                      ),
                      iconSize: 28,
                      onPressed: () async {
                        await _controller.toggleTorch();
                        // إغلاق الشاشة فور الضغط (قبل اكتمال toggleTorch)
                        // كان يستدعي setState على State مُتلَف.
                        if (mounted) setState(() => _torchOn = !_torchOn);
                      },
                    ),
                    IconButton(
                      style: _glassCircle,
                      icon: const Icon(
                        Icons.cameraswitch_rounded,
                        color: Colors.white,
                      ),
                      iconSize: 28,
                      onPressed: () => _controller.switchCamera(),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    context.l10n.scanAim,
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// إطار المسح مع تعتيم ما حوله.
/// أزرار الماسح العلوية: دوائر زجاجية فوق صورة الكاميرا.
final _glassCircle = IconButton.styleFrom(
  backgroundColor: const Color(0x33000000),
  side: const BorderSide(color: Color(0x33FFFFFF)),
);

class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 270,
          height: 190,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary, width: 3),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final message = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied => context.l10n.camDenied,
      MobileScannerErrorCode.unsupported => context.l10n.camUnsupported,
      _ => context.l10n.camFailed(error.errorDetails?.message ?? ''),
    };

    return Container(
      color: AppColors.bgDark,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.no_photography_rounded,
            size: 64,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
