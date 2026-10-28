#!/usr/bin/env bash
# يتحقّق أن كل حلقة متاحة على نفس الرابط الذي يبنيه التطبيق،
# وأن حجمها على الخادم يطابق الملف المحلي.
#
#   bash tools/verify-audio.sh

set -u

BASE="https://github.com/taha-majdlawi/qwaed_feqhia_app/releases/download/audio-v1"
AUDIO_DIR="audio"

cd "$(dirname "$0")/.." || exit 1

ok=0
bad=()

for f in "$AUDIO_DIR"/ep*.m4a; do
  name=$(basename "$f")
  local_size=$(wc -c < "$f" | tr -d ' ')

  # -L لتتبّع إعادة التوجيه إلى objects.githubusercontent.com
  headers=$(curl -sIL "$BASE/$name")
  code=$(printf '%s' "$headers" | grep -E '^HTTP/' | tail -1 | awk '{print $2}')
  remote_size=$(printf '%s' "$headers" | grep -i '^content-length:' | tail -1 \
                | awk '{print $2}' | tr -d '\r')

  if [ "$code" = "200" ] && [ "$remote_size" = "$local_size" ]; then
    ok=$((ok + 1))
  else
    bad+=("$name (رمز=$code، الخادم=${remote_size:-?}، المحلي=$local_size)")
  fi
done

echo "متاحة وسليمة: $ok"
if [ ${#bad[@]} -gt 0 ]; then
  echo "بها مشكلة: ${#bad[@]}"
  printf '  - %s\n' "${bad[@]}"
  exit 1
fi
echo "كل الحلقات متاحة على الرابط الذي يقرأ منه التطبيق."
