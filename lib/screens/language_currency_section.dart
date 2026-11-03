import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/app_settings.dart';
import '../theme.dart';
import '../util/number_parse.dart';
import '../widgets/glass.dart';

/// قسم «اللغة والعملة» في الإعدادات.
///
/// كلاهما محلي لهذا الجهاز: لا يُزامَن ولا يغيّر البيانات. الدولار عملة عرض
/// وإدخال بسعر صرف يضبطه المستخدم، والأسعار تبقى مخزّنة بالدينار.
class LanguageCurrencySection extends StatelessWidget {
  const LanguageCurrencySection({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = AppSettings.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.settingsLanguageCurrency,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _Segmented(
            label: l.languageLabel,
            options: const [('ar', 'العربية'), ('en', 'English')],
            keys: const [Key('langAr'), Key('langEn')],
            value: s.language,
            onChanged: s.setLanguage,
          ),
          const SizedBox(height: 8),
          _Segmented(
            label: l.currencyLabel,
            options: [('IQD', l.currencyIqd), ('USD', l.currencyUsd)],
            keys: const [Key('currencyIqd'), Key('currencyUsd')],
            value: s.currency,
            onChanged: (v) => _setCurrency(context, v),
          ),
          if (s.usdRate != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.usdRateLine(formatPriceInput(s.usdRate!)),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('usdRateEditButton'),
                  onPressed: () => askUsdRate(context),
                  child: Text(l.usdRateEdit),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Text(
            l.currencyNote,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// الدولار أول مرة بلا سعر صرف: يُطلب السعر أولاً، والإلغاء يبقي الدينار.
  static Future<void> _setCurrency(BuildContext context, String value) async {
    final s = AppSettings.instance;
    if (value == 'USD' && s.usdRate == null) {
      final rate = await askUsdRate(context);
      if (rate == null) return;
    }
    await s.setCurrency(value);
  }
}

/// حوار سعر الصرف «1 دولار = … دينار». يحفظه ويعيده، أو `null` عند الإلغاء.
Future<double?> askUsdRate(BuildContext context) {
  return showGlassDialog<double>(
    context: context,
    builder: (_) => const _UsdRateDialog(),
  );
}

class _UsdRateDialog extends StatefulWidget {
  const _UsdRateDialog();

  @override
  State<_UsdRateDialog> createState() => _UsdRateDialogState();
}

class _UsdRateDialogState extends State<_UsdRateDialog> {
  late final _field = TextEditingController(
    text: AppSettings.instance.usdRate == null
        ? ''
        : formatPriceInput(AppSettings.instance.usdRate!),
  );
  String? _error;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final rate = parseLocalizedNumber(_field.text);
    if (rate == null || !await AppSettings.instance.setUsdRate(rate)) {
      setState(() => _error = context.l10n.usdRateInvalid);
      return;
    }
    if (mounted) Navigator.pop(context, rate);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      backgroundColor: AppColors.bgCard,
      title: Text(l.usdRateTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.usdRateHint,
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('usdRateField'),
            controller: _field,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [ThousandsSeparatorInputFormatter()],
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: l.usdRateField,
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('usdRateCancel'),
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const Key('usdRateSave'),
          onPressed: _save,
          child: Text(l.save),
        ),
      ],
    );
  }
}

/// خياران متجاوران بأسلوب التبويبات الزجاجية.
class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.label,
    required this.options,
    required this.keys,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<(String, String)> options;
  final List<Key> keys;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: GlassSurface(
            radius: 16,
            shadow: false,
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                for (var i = 0; i < options.length; i++)
                  Expanded(
                    child: GestureDetector(
                      key: keys[i],
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(options[i].$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          gradient: options[i].$1 == value
                              ? AppGradients.brand
                              : null,
                        ),
                        child: Text(
                          options[i].$2,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: options[i].$1 == value
                                ? AppColors.onGradient
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
