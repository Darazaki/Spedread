#!/bin/sh
set -e

appid=com.github.Darazaki.Spedread

for x in \
    "data/$appid.desktop.in" \
    src/*.vala
do
    echo "$x"
done | sort > po/POTFILES
echo "Regenerated po/POTFILES."

printf "po/_base.pot: "
# Generate "appdata.po"
dev-scripts/extract-appdata-translation.py
# Generate "messages.po"
xgettext \
    --from-code=UTF-8 \
    -f po/POTFILES \
    -x po/_excluded.pot \
    -cTR: \
    --omit-header
# Merge both into "base.pot"
msgcat appdata.po messages.po -o base.pot
# Update "po/_base.pot" + cleanup
msgmerge -UN po/_base.pot base.pot
rm -f messages.po appdata.po base.pot 'po/_base.pot~'

for po_file in po/*.po
do
    printf "$po_file: "
    msgmerge -UN "$po_file" po/_base.pot
    rm -f "$po_file~"
done

sed -E 's/POT-Creation-Date: [0-9]{4}(-[0-9]{2}){2} [0-9]{2}:[0-9]{2}\+[0-9]{4}/'"POT-Creation-Date: $(date "+%Y-%m-%d %H:%M%z")"'/g' -i po/_base.pot po/*.po
