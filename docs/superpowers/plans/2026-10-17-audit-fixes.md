# إصلاحات فحص 2026-10-17 — خطة التنفيذ

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** إصلاح عطلين حقيقيين يُفقدان البيانات بصمت لم يلتقطهما الفحص السابق، وحماية المشروع من تكرار حادثة الضياع.

**Architecture:** يُحلّ تعارض الباركود داخل `MedicineDb` (طبقة واحدة تمر بها كل الكتابات الجماعية)، بنفس القاعدة الموجودة أصلاً في `repairGs1Barcodes`: يبقى الأحدث ويُحذف الأقدم مع إدراجه في `pending_deletes` لينتشر الحذف للسحابة. تحليل الأرقام يُجمع في دالة صِرفة واحدة تستعملها شاشتا النموذج والفاتورة.

**Tech Stack:** Flutter 3.44 / Dart 3.12، `sqflite` + `sqflite_common_ffi` للاختبار، `flutter_test`.

**Spec:** لا يوجد مستند مواصفات منفصل؛ الطلب «افحص التطبيق واكتشف الأعطال مع الإصلاحات والاختبارات». الأدلة لكل عطل مذكورة داخل مهمته بأرقام الأسطر.

## ما تحقّقتُ منه قبل الخطة

- الإصلاحات العشرة من فحص سبتمبر **كلها موجودة** في النسخة المسترجَعة (تحققت سطرياً: `findByBarcode` في النموذج، `updatedAt: remote.updatedAt` في المزامنة، `_handled`+`mounted` في الماسح، `catch` الحفظ، `_refreshInFlight`، مهلة الصور اليتيمة ساعة، `addPostFrameCallback` للإتلاف، `_initFuture`، إزالة الإشعار الفوري، السنة ذات الرقمين وتقييد اليوم).
- `flutter analyze` نظيف و`flutter test` 215/215 قبل هذه الخطة.

## Global Constraints

- السعر = سعر الشراء/الكلفة فقط (قاعدة المخزون).
- لا تُغيَّر قيمة النموذج `gemini-3.6-flash` — اختُبرت حيّاً وهي الصحيحة.
- لا تُغيَّر إعدادات `android/gradle.properties` (`-Xmx2G`، `parallel=false`، `workers.max=2`).
- لا بناء APK إلا بطلب صريح من المستخدم.
- كل حذف ملفات يكون بمسار حرفي محدد — ممنوع `rm -rf` على متغيرات أو حلقات تحت جذر المشروع.
- نصوص الواجهة بالعربية، بنفس أسلوب الرسائل الحالية.

## Review Focus

1. جهازان في نفس الصيدلية يضيفان نفس الباركود قبل المزامنة → بعد مزامنتين يجب أن يبقى سجل واحد ثابت، لا تناوب. (مُغطّى في Task 2، اختبار «لا تناوب»).
2. كتابة السعر بأرقام عربية-هندية `١٢٥٠` على لوحة مفاتيح سامسونج العربية → يُحفظ 1250 لا 0. (Task 3).
3. تعديل مادة موجودة وحقل السعر يحوي نصاً غير صالح → لا يُدهس السعر القديم بصفر. (Task 3، اختبار الرفض).
4. استرجاع نسخة احتياطية تحوي مادة حُذفت لاحقاً ولم تُرفع حذفها بعد → لا تعود للحياة. (Task 2، اختبار `pending_deletes`).
5. سجلان بنفس الباركود ونفس `updatedAt` تماماً → قرار حتمي (المعرّف الأصغر يفوز) فلا يختلف الجهازان في اختيار الفائز. (Task 2).

---

### Task 1: وضع المشروع تحت git ونسخة احتياطية خارج القرص

السبب: ضياع `F:\pharmacy-app\app` في سبتمبر لم يكن قابلاً للاسترجاع لأنه لم يكن هناك git ولا نسخة. هذه المهمة شرط لكل ما بعدها (الخطوات اللاحقة تعتمد على commits).

**Files:**
- Modify: `.gitignore` (موجود ويغطي `.env` و`key.properties` و`google-services.json` و`/build/`)

- [ ] **Step 1:** من `D:\pharmacy-app\app`: `git init` ثم `git add .` ثم `git status` — تأكد أن `.env` و`android/app/google-services.json` و`build/` **ليست** ضمن الملفات المضافة.
- [ ] **Step 2:** `git commit -m "chore: baseline of project reconstructed from session transcript"`
- [ ] **Step 3:** نسخة احتياطية إلى F بلا مجلد البناء:
  `robocopy D:\pharmacy-app F:\pharmacy-app-backup /E /XD build .dart_tool .gradle`
  ثم انسخ يدوياً `.env` و`google-services.json` إلى مكان آمن منفصل (فلاش أو بريد) لأنهما خارج git عمداً.
  Expected: robocopy ينهي بكود ≤ 3 (نجاح).

---

### Task 2: حلّ تعارض الباركود في الكتابات الجماعية (المزامنة والاسترجاع)

**العطل (مؤكَّد بقراءة الكود):** `MedicineDb.upsert` و`upsertAll` (`lib/db/medicine_db.dart:219-241`) يستعملان `ConflictAlgorithm.replace` على جدول بفهرس فريد جزئي على `barcode`، فأي إدراج بباركود موجود تحت معرّف آخر **يحذف الصف الآخر بصمت** ولا يسجّله في `pending_deletes`. إصلاح سبتمبر سدّ هذا في النموذج فقط؛ مساران آخران ما زالا مفتوحين:

- **المزامنة** (`lib/services/sync_service.dart:271-303`): جهازا الصيدلية يضيفان نفس الدواء قبل المزامنة (معرّفان مختلفان، باركود واحد). جهاز A ينزّل سجل B ← `upsert` يحذف سجل A محلياً. السحابة تبقى تحمل الاثنين، فالمزامنة التالية تنزّل سجل A ← يحذف سجل B. **تناوب لا ينتهي**: الكمية والسعر يتبدّلان بين القيمتين كل مزامنة.
- **استرجاع النسخة** (`lib/state/medicine_store.dart:301-330`): نفس الحذف الصامت، وزيادة: لا يستشير `pending_deletes`، فمادة حُذفت ولم يُرفع حذفها تعود.

**القرار:** نفس قاعدة `repairGs1Barcodes` الموجودة (`medicine_db.dart:331-380`): يفوز الأحدث `updatedAt`؛ عند التساوي يفوز المعرّف الأصغر نصياً (حتمي على الجهازين). الخاسر يُحذف محلياً ويُدرج في `pending_deletes` فيُحذف من السحابة في المزامنة التالية وينتهي التناوب. **لا تُجمع الكميات**: السجلان على جهازين يعدّان غالباً نفس الرف، والجمع يضاعف المخزون.

**Files:**
- Modify: `lib/db/medicine_db.dart` — دالة جديدة بجانب `upsertAll`
- Modify: `lib/services/sync_service.dart:271-303` — استبدال استدعاءي `upsert` في حلقة النزول
- Modify: `lib/state/medicine_store.dart:301-330` — `importBackup`
- Test: `test/barcode_conflict_resolution_test.dart` (جديد، على SQLite حقيقية بنمط `test/barcode_duplicate_test.dart:55-77`: `databaseFactory = databaseFactoryFfi` + `MedicineDb.instance.attachForTest(db)`)

**Interfaces:**
- Produces: `Future<List<String>> MedicineDb.upsertAllResolvingBarcodes(List<Medicine> items)` — يكتب العناصر في معاملة واحدة، ويعيد معرّفات **الخاسرين** (سواء كان الخاسر سجلاً محلياً حُذف أو عنصراً وارداً تُخطّي). كل خاسر مُدرج في `pending_deletes`. الباركود الفارغ لا يتعارض أبداً.

- [ ] **Step 1: الاختبارات الفاشلة** في `test/barcode_conflict_resolution_test.dart`:

```dart
test('وارد أحدث بنفس الباركود يحلّ محل المحلي ويُسجَّل المحلي للحذف', () async {
  await MedicineDb.instance.upsert(med(id: 'a1', barcode: '123', qty: 200, updatedAt: 100));
  final losers = await MedicineDb.instance.upsertAllResolvingBarcodes(
      [med(id: 'b1', barcode: '123', qty: 5, updatedAt: 200)]);
  expect(losers, ['a1']);
  final all = await MedicineDb.instance.getAll();
  expect(all.map((m) => m.id), ['b1']);
  expect(await MedicineDb.instance.peekPendingDeletes(), contains('a1'));
});

test('وارد أقدم بنفس الباركود يُتخطّى ولا يمس المحلي', () async {
  await MedicineDb.instance.upsert(med(id: 'a1', barcode: '123', qty: 200, updatedAt: 300));
  final losers = await MedicineDb.instance.upsertAllResolvingBarcodes(
      [med(id: 'b1', barcode: '123', qty: 5, updatedAt: 200)]);
  expect(losers, ['b1']);
  final all = await MedicineDb.instance.getAll();
  expect(all.single.id, 'a1');
  expect(all.single.quantity, 200);
});

test('تساوي الختم: المعرّف الأصغر يفوز على الجهازين', () async {
  await MedicineDb.instance.upsert(med(id: 'b1', barcode: '123', updatedAt: 100));
  final losers = await MedicineDb.instance.upsertAllResolvingBarcodes(
      [med(id: 'a1', barcode: '123', updatedAt: 100)]);
  expect(losers, ['b1']);
});

test('لا تناوب: تطبيق نفس الدفعة مرتين يعطي نفس النتيجة', () async {
  final batch = [med(id: 'a1', barcode: '123', updatedAt: 100),
                 med(id: 'b1', barcode: '123', updatedAt: 200)];
  await MedicineDb.instance.upsertAllResolvingBarcodes(batch);
  await MedicineDb.instance.upsertAllResolvingBarcodes(batch.reversed.toList());
  expect((await MedicineDb.instance.getAll()).map((m) => m.id), ['b1']);
});

test('باركود فارغ لا يتعارض', () async {
  await MedicineDb.instance.upsertAllResolvingBarcodes(
      [med(id: 'a1', barcode: ''), med(id: 'b1', barcode: '')]);
  expect((await MedicineDb.instance.getAll()).length, 2);
});

test('importBackup لا يُحيي مادة في طابور الحذف', () async {
  await MedicineDb.instance.enqueuePendingDelete('gone');
  final store = MedicineStore();  // load() يقرأ من القاعدة المرفقة
  await store.load();
  final r = await store.importBackup([med(id: 'gone', barcode: '', updatedAt: 999)]);
  expect(r.added, 0);
  expect((await MedicineDb.instance.getAll()).any((m) => m.id == 'gone'), isFalse);
});
```

`med(...)` مساعد محلي في ملف الاختبار يبني `Medicine` بقيم افتراضية (`name: 'x'`, `price: 0`, `type: ItemType.medicine`, `createdAt: updatedAt`).
إن احتاج `MedicineStore().load()` خدمات غير متاحة في الاختبار (Firebase)، اتبع نمط `_TestStore` في `test/invoice_scan_test.dart` بتجاوز `refreshFromCloud` فقط.

- [ ] **Step 2:** `flutter test test/barcode_conflict_resolution_test.dart` — Expected: FAIL (`upsertAllResolvingBarcodes` غير معرَّفة).

- [ ] **Step 3: نفّذ `upsertAllResolvingBarcodes`** في `medicine_db.dart` داخل `db.transaction`: لكل عنصر بباركود غير فارغ، `query` عن صفوف بنفس الباركود ومعرّف مختلف؛ قارن بقاعدة القرار أعلاه؛ احذف الخاسر المحلي أو تخطَّ الوارد الخاسر؛ أدرج الخاسر في `pending_deletes` (`ConflictAlgorithm.ignore` كالموجود في `:116-120`)؛ ثم `insert` بـ`replace` (آمن الآن لأن التعارض الوحيد المتبقي هو نفس المعرّف). داخل الدفعة نفسها يجب أن يرى العنصر اللاحق نتيجة السابق — لذلك `query` داخل المعاملة لا قبلها.

- [ ] **Step 4: اربط المستدعين:**
  - `sync_service.dart` حلقة النزول: اجمع العناصر المنزّلة (بعد تجهيز الصورة/`copyWith` كما هي الآن) في قائمة واحدة، واستدعِ `upsertAllResolvingBarcodes` مرة واحدة بعد الحلقة بدل `upsert` لكل عنصر. أضف المعرّفات الخاسرة إلى `deletedIds` **قبل** حلقة الصعود حتى لا يُعاد رفع الخاسر في نفس الدورة.
  - `medicine_store.dart` `importBackup`: قبل الحلقة اقرأ `peekPendingDeletes()` وتخطَّ أي عنصر معرّفه فيها (يُحسب `skipped`). استبدل `upsertAll(toWrite)` بـ`upsertAllResolvingBarcodes(toWrite)`، واطرح عدد الخاسرين الواردين من `added`/`updated` وأضفه إلى `skipped`، ولا تدفع للسحابة إلا غير الخاسرين.
  - `saveAll` (`:340`) يبقى على `upsertAll`: أسطر الفواتير بلا باركود.

- [ ] **Step 5:** `flutter test` — Expected: الجديدة + الـ215 القائمة كلها PASS. ثم `flutter analyze` نظيف.

- [ ] **Step 6:** `git commit -m "fix: resolve barcode collisions in sync and backup import instead of silent replace"`

---

### Task 3: تحليل الأرقام العربية والفواصل في السعر والكمية

**العطل (مؤكَّد):** `form_screen.dart:329,333` و`invoice_scan_screen.dart:126-127` تستعمل `double.tryParse`/`int.tryParse` مباشرة، ولا يوجد أي `inputFormatters` على الحقول (`form_screen.dart:496,641,661`، `invoice_scan_screen.dart:385,397,415`). لوحات المفاتيح العربية (سامسونج مثلاً) تكتب `١٢٥٠`، وأسعار الدينار تُكتب كثيراً `1,250` — كلاهما يعطي `null` ← **يُحفظ 0 بصمت**. وفي التعديل يُدهس السعر الحقيقي القديم بصفر.

**Files:**
- Create: `lib/util/number_parse.dart`
- Modify: `lib/screens/form_screen.dart:329-336` و`:245,254,263` (حوار «+» للكمية)
- Modify: `lib/screens/invoice_scan_screen.dart:126-127`
- Test: `test/number_parse_test.dart` (جديد)، وتوسيع `test/form_flow_test.dart`

**Interfaces:**
- Produces: `double? parseLocalizedNumber(String input)` و`int? parseLocalizedInt(String input)` — `null` للنص الفارغ أو غير الصالح.

- [ ] **Step 1: الاختبار الفاشل** `test/number_parse_test.dart`:

```dart
expect(parseLocalizedNumber('١٢٥٠'), 1250);     // عربية-هندية
expect(parseLocalizedNumber('۱۲۵۰'), 1250);     // فارسية
expect(parseLocalizedNumber('1,250'), 1250);    // فاصل آلاف
expect(parseLocalizedNumber('١٬٢٥٠'), 1250);    // فاصل آلاف عربي U+066C
expect(parseLocalizedNumber('12٫5'), 12.5);     // فاصلة عشرية عربية U+066B
expect(parseLocalizedNumber(' 750 '), 750);
expect(parseLocalizedNumber(''), isNull);
expect(parseLocalizedNumber('abc'), isNull);
expect(parseLocalizedInt('٣'), 3);
expect(parseLocalizedInt('2.5'), isNull);       // الكمية عدد صحيح
```

- [ ] **Step 2:** `flutter test test/number_parse_test.dart` — FAIL (الملف غير موجود).
- [ ] **Step 3:** نفّذ الدالتين: حوّل `٠-٩` (U+0660–0669) و`۰-۹` (U+06F0–06F9) إلى ASCII، احذف `,` و`٬` والمسافات، حوّل `٫` إلى `.`، ثم `double.tryParse`/`int.tryParse`.
- [ ] **Step 4:** في `form_screen._save()`: استعمل الدالتين. إن كان حقل السعر أو الكمية **غير فارغ** والنتيجة `null` → أوقف الحفظ واعرض SnackBar «السعر غير صالح — اكتب أرقاماً فقط» (أو «الكمية…») ولا تُغلق النموذج. الحقل الفارغ يبقى صفراً كالسلوك الحالي. طبّق نفس التحويل في حوار «+» وفي `invoice_scan_screen.dart:126-127`.
- [ ] **Step 5:** وسّع `test/form_flow_test.dart` باختبارين: (أ) كتابة `١٥٠٠` في السعر ثم حفظ ← المادة المحفوظة `price == 1500`؛ (ب) تعديل مادة سعرها 900 وكتابة `abc` ← لا حفظ، ورسالة الخطأ ظاهرة، والمادة في المخزن ما زالت 900.
- [ ] **Step 6:** `flutter test` كاملاً + `flutter analyze` — كله PASS/نظيف.
- [ ] **Step 7:** `git commit -m "fix: parse Arabic-Indic digits and separators in price/quantity instead of saving 0"`

---

### Task 4: تقييد مفتاح Gemini (إجراء يدوي، بلا كود)

**المشكلة:** `.env` مُدرج في `pubspec.yaml` كـ asset، فالمفتاح داخل الـ APK ويمكن لأي شخص استخراجه بفك الملف واستهلاك حصتك أو حسابك. لا يُحل برمجياً بلا خادم وسيط؛ الحل العملي تقييد المفتاح.

- [ ] **Step 1:** في Google Cloud Console ← APIs & Services ← Credentials ← المفتاح المستخدم: **Application restrictions = Android apps**، أضف الحزمة `com.pharmacy.saydaliyati` وبصمة SHA-1 لشهادة التوقيع (من `cd android; ./gradlew signingReport`، سطر `debug` لأن البناء الحالي موقَّع بمفتاح التصحيح).
- [ ] **Step 2:** **API restrictions = Generative Language API** فقط.
- [ ] **Step 3:** بعد البناء التالي (بطلب المستخدم) جرّب قراءة فاتورة واحدة على الهاتف للتأكد أن التقييد لم يكسرها. ملاحظة: إن أُنشئ لاحقاً مفتاح توقيع إصدار حقيقي، يجب إضافة بصمته هنا أيضاً.

---

## خارج النطاق (عيوب معروفة، تُركت عمداً)

- `gs1_parser`: معرّفات `31xx–36xx` ثابتة الطول غير مدعومة (`_fixedLength` في `:55-67`). نادرة في علب الأدوية، وتعديل المفكك قد يكسر مسحاً يعمل.
- `drug_lookup`: نافذة `_graceWindow` 1.5 ثانية قد تسجّل باركوداً كمجهول مؤقتاً؛ السحب للتحديث يمحو ذاكرة الفشل.
- `Medicine.fromMap`: `imagePath`/`category` تحويل مباشر `as String?` (`:135,138`)؛ أي مستند تالف يُحسب ضمن `skipped` في المزامنة.
- توقيع الإصدار: لا `key.properties`، والبناء موقَّع بمفتاح التصحيح. يكفي للتثبيت المباشر، لا لـ Google Play.
- `_pushAllLocal` يرفع كل المحلي بلا مقارنة ختم (`sync_service.dart:359-369`) — يُستدعى فقط عند الانضمام لصيدلية لأول مرة.
