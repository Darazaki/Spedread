#!/bin/sh
set -e

printf "po/_base.pot: "
xgettext \
    -f po/POTFILES \
    -x po/_excluded.pot \
    -cTR: \
    --omit-header
msgmerge -UN po/_base.pot messages.po
rm -f messages.po 'po/_base.pot~'

for po_file in po/*.po
do
    printf "$po_file: "
    msgmerge -UN "$po_file" po/_base.pot
    rm -f "$po_file~"
done

sed -E 's/POT-Creation-Date: [0-9]{4}(-[0-9]{2}){2} [0-9]{2}:[0-9]{2}\+[0-9]{4}/'"POT-Creation-Date: $(date "+%Y-%m-%d %H:%M%z")"'/g' -i po/_base.pot po/*.po
