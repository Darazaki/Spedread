#!/bin/sh
set -e
echo '/!\ Make sure that po/_base.pot has been updated with the new translations!' 2>&1

for po_file in po/*.po
do
    printf "$po_file: "
    msgmerge "$po_file" po/_base.pot -U
    rm -f "$po_file~"
done
