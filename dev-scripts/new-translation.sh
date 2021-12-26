#!/bin/sh
set -e

read -p "Which language do you want to generate the translation for? (jp, fr, etc.) : " lang

creation_date="$(date -u +'%Y-%m-%d %H:%M%z')"
creation_year="$(date -u +'%Y')"
author_name="$(git config user.name)"
author_email="$(git config user.email)"
author="$author_name <$author_email>"


cp po/_base.po po/"$lang".po

echo "Using $author as value for %AUTHOR%"
sed -i "s*%AUTHOR%*$author*g"      po/"$lang".po
sed -i "s*%LANG%*$lang*g"          po/"$lang".po
sed -i "s*%YEAR%*$creation_year*g" po/"$lang".po
sed -i "s*%DATE%*$creation_date*g" po/"$lang".po

echo "$lang" >> po/LINGUAS
echo "Added $lang to po/LINGUAS, please make sure it appears only once"
echo
echo "File created inside po/$lang.po, feel free to edit it with any code editor and submit it as a PR!"
echo "If it's your first time editing a translation, you can use po/fr.po as an example and/or open an issue with your questions"
