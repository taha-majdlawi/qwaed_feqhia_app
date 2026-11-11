# النشر على App Store عبر Codemagic

لا تحتاج جهاز ماك. Codemagic يبني على أجهزة ماك سحابية، ويوقّع، ويرفع إلى
TestFlight تلقائياً. ملف الإعداد [codemagic.yaml](../codemagic.yaml) جاهز في
جذر المستودع.

---

## ما جُهّز في المشروع (تمّ)

| | |
|---|---|
| مُعرّف الحزمة (Bundle ID) | `com.qawaid.qawaidFiqhiyya` |
| اسم التطبيق على الجهاز | القواعد الفقهية |
| لغة التطبيق | `ar` أساسية، و`en` مدعومة |
| الصوت في الخلفية | `UIBackgroundModes: audio` |
| امتثال التصدير | `ITSAppUsesNonExemptEncryption = false` — يلغي السؤال مع كل رفع |
| الأيقونات | ٢١ مقاساً بينها ١٠٢٤×١٠٢٤ بلا شفافية (Apple ترفض الشفافية) |
| شاشة الإقلاع | مولَّدة |
| ملف Codemagic | `codemagic.yaml` بمسارَي عمل: iOS و Android |

> المشروع في مجلد `app/` لا في جذر المستودع، وملف Codemagic يراعي ذلك
> (`working_directory: app` في كل خطوة).

---

## ما عليك عمله — بالترتيب

### ١. اشتراك Apple Developer — ٩٩ دولاراً سنوياً

<https://developer.apple.com/programs/enroll/>

- اختر **Individual** إن كان باسمك، أو **Organization** إن كان باسم جهة
  (الأخير يحتاج رقم D-U-N-S ويستغرق أسابيع).
- التفعيل يأخذ من ساعات إلى يومين.

> هذه الخطوة لا بديل عنها ولا يمكن تجاوزها؛ كل ما بعدها يتوقّف عليها.

### ٢. سجّل مُعرّف التطبيق

في <https://developer.apple.com/account> ← **Identifiers** ← `+`:

- Description: `Qawaid Fiqhiyya`
- Bundle ID: **Explicit** → `com.qawaid.qawaidFiqhiyya`
- Capabilities: لا تفعّل شيئاً (الصوت في الخلفية لا يحتاج تفعيلاً هنا)

### ٣. أنشئ التطبيق في App Store Connect

<https://appstoreconnect.apple.com> ← **My Apps** ← `+` ← **New App**:

| الحقل | القيمة |
|---|---|
| Platforms | iOS |
| Name | القواعد الفقهية وتطبيقاتها |
| Primary Language | Arabic |
| Bundle ID | com.qawaid.qawaidFiqhiyya |
| SKU | qawaid-fiqhiyya |

بعد الإنشاء، افتح **App Information** وانسخ **Apple ID** (رقم من ١٠ خانات)
— ستحتاجه في الخطوة ٥.

### ٤. أنشئ مفتاح App Store Connect API

<https://appstoreconnect.apple.com/access/integrations/api> ← **Team Keys** ← `+`:

- Name: `Codemagic`
- Access: **App Manager**

نزّل ملف `.p8` (**يُنزَّل مرة واحدة فقط — احفظه مع مفتاح أندرويد**)، وسجّل:
- **Issuer ID** (أعلى الصفحة)
- **Key ID**

### ٥. اربط Codemagic

<https://codemagic.io> ← سجّل بحساب GitHub ← أضف المستودع
`taha-majdlawi/qwaed_feqhia_app`.

**أ. تكامل App Store Connect**
`Teams ← Integrations ← Apple Developer Portal ← Add key`:
- Name: **`qawaid_asc`** ← الاسم مهم، هو المكتوب في `codemagic.yaml`
- الصق Issuer ID و Key ID وارفع ملف `.p8`

**ب. متغيّرات البيئة**
في إعدادات التطبيق ← **Environment variables**:

| الاسم | القيمة | المجموعة | Secure |
|---|---|---|---|
| `APP_STORE_APPLE_ID` | رقم Apple ID من الخطوة ٣ | `appstore` | لا |

**ج. (لأندرويد، اختياري)** في **Code signing identities ← Android keystores**
ارفع `C:\Users\hp\keystores\qawaid-upload.jks` باسم **`qawaid_keystore`**،
وكلمة السرّ والاسم المستعار من `app/android/key.properties`.

### ٦. شغّل البناء

في Codemagic ← **Start new build** ← اختر `ios-testflight`.

البناء يأخذ نحو ١٥–٢٥ دقيقة، وينتهي برفع البناء إلى **TestFlight** تلقائياً.
`codemagic.yaml` مضبوط على **عدم** الإرسال للمراجعة تلقائياً، كي تجرّب
البناء على جهازك أولاً (`submit_to_app_store: false`).

### ٧. بعد ظهور البناء في TestFlight

1. App Store Connect ← **TestFlight** — البناء يحتاج ١٠–٣٠ دقيقة للمعالجة.
2. أضف نفسك كمختبر داخلي وجرّب التطبيق على iPhone.
3. املأ بطاقة المتجر: النصوص من `store/store-listing.txt`،
   ورابط سياسة الخصوصية، ولقطات شاشة **بمقاسات iPhone**
   (انظر التحذير أدناه).
4. **Submit for Review**.

---

## تنبيهات تكلّف وقتاً إن فاتتك

**لقطات الشاشة التي عندنا لأندرويد ولا تصلح لـ iOS.** Apple تطلب
١٢٩٠×٢٧٩٦ (iPhone 6.7") أو ١٢٨٤×٢٧٧٨ (6.5"). بعد وصول البناء إلى
TestFlight، شغّله على محاكي iPhone في Codemagic أو على جهاز حقيقي والتقط
لقطات جديدة. لا تُقبل لقطات أندرويد.

**رقم البناء يجب أن يزيد مع كل رفع.** `codemagic.yaml` يقرأ آخر رقم من
App Store Connect ويزيده تلقائياً، فلا تعدّله يدوياً.

**المراجعة الأولى لـ Apple تستغرق ١–٣ أيام** وقد تُرفض لأسباب شكلية.
ما يخصّ تطبيقنا:
- التطبيق يعرض محتوى دينياً — مسموح، لكن احرص أن يكون وصف المتجر دقيقاً
  وغير دعائي.
- ليس فيه تسجيل دخول ولا مشتريات، فلن يُسأل عن حساب تجريبي.
- أضف في **App Review Information ← Notes** سطراً:
  «التطبيق يشغّل تسجيلات إذاعية لسلسلة علمية، بإذن صاحبها الشيخ عدنان الرشيدي.»

**حقوق المحتوى.** Apple قد تطلب إثبات حقّك في نشر التسجيلات. جهّز رسالة
خطّية من الشيخ أو الجهة تأذن بالنشر، ليُرفع عند الطلب.

**الصوتيات تُنزَّل من GitHub.** يجب أن يبقى المستودع **عامّاً** وإلا توقّف
الصوت على كل الأجهزة، أندرويد و iOS معاً.

---

## لماذا لا يعمل Codemagic من جهازك مباشرة

Codemagic يبني من **المستودع على GitHub**، لا من مجلدك المحلي. فأي تعديل
تريده في بناء iOS يجب أن يُدفع إلى `main` أولاً.
