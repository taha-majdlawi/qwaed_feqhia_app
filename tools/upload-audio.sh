#!/usr/bin/env bash
# رفع الملفات الصوتية إلى إصدار GitHub الذي يقرأ منه التطبيق.
#
#   bash tools/upload-audio.sh
#
# يتطلّب تسجيل الدخول مرة واحدة:  gh auth login
# آمن للتكرار: يُنشئ الإصدار إن لم يكن موجوداً، ويستبدل المرفقات الموجودة.

set -u

REPO="taha-majdlawi/qwaed_feqhia_app"
TAG="audio-v1"
AUDIO_DIR="audio"

# gh قد لا يكون في PATH مباشرة بعد التثبيت على ويندوز
if command -v gh >/dev/null 2>&1; then
  GH=gh
elif [ -x "/c/Program Files/GitHub CLI/gh.exe" ]; then
  GH="/c/Program Files/GitHub CLI/gh.exe"
else
  echo "لم يُعثر على gh. ثبّته بـ:  winget install --id GitHub.cli -e"
  exit 1
fi

cd "$(dirname "$0")/.." || exit 1

if ! "$GH" auth status >/dev/null 2>&1; then
  echo "لست مسجّل الدخول. شغّل أولاً:  gh auth login"
  exit 1
fi

files=("$AUDIO_DIR"/ep*.m4a)
if [ ! -e "${files[0]}" ]; then
  echo "لا توجد ملفات صوتية في $AUDIO_DIR/"
  exit 1
fi
echo "عدد الملفات: ${#files[@]}"

# أنشئ الإصدار إن لم يكن موجوداً
if "$GH" release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  echo "الإصدار $TAG موجود — سنضيف/نستبدل المرفقات."
else
  echo "إنشاء الإصدار $TAG…"
  "$GH" release create "$TAG" \
    --repo "$REPO" \
    --title "ملفات الصوت — الحلقات ١–٤٢" \
    --notes "صوت سلسلة القواعد الفقهية وتطبيقاتها، يقرأ منه التطبيق مباشرة." \
    || exit 1
fi

# ارفع ملفاً ملفاً كي يُستأنف ما بقي لو انقطع الرفع
failed=()
for f in "${files[@]}"; do
  name=$(basename "$f")
  printf 'رفع %s … ' "$name"
  if "$GH" release upload "$TAG" "$f" --repo "$REPO" --clobber >/dev/null 2>&1; then
    echo "تم"
  else
    echo "فشل"
    failed+=("$name")
  fi
done

if [ ${#failed[@]} -gt 0 ]; then
  echo
  echo "فشل رفع ${#failed[@]} ملف: ${failed[*]}"
  echo "أعد تشغيل السكربت — سيتخطّى ما رُفع ويعيد المحاولة."
  exit 1
fi

echo
echo "اكتمل الرفع. التحقق من الروابط:"
bash tools/verify-audio.sh
