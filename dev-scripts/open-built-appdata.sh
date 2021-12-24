#!/bin/sh
set -e
gunzip -c build/fltpk/files/share/app-info/xmls/com.github.Darazaki.Spedread.xml.gz | "$EDITOR"
