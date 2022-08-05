#!/bin/sh
set -e

printf "%s" "Which language do you want to generate the translation for? (jp, fr, etc.) : "
read -r lang

if [ -e po/"$lang".po ]
then
    echo "po/$lang.po already exists"
    echo "You can use it as a starting point to add any missing translations or correct any mistakes"
    echo "Creation of a new translation file cancelled"
    exit
fi

creation_date="$(date -u +'%Y-%m-%d %H:%M%z')"
creation_year="$(date -u +'%Y')"
author_name="$(git config user.name)"
author_email="$(git config user.email)"
author="$author_name <$author_email>"


cp po/_base.pot po/"$lang".po

echo "Using $author as value for %AUTHOR%"
sed -i "s*%AUTHOR%*$author*g"      po/"$lang".po
sed -i "s*%LANG%*$lang*g"          po/"$lang".po
sed -i "s*%YEAR%*$creation_year*g" po/"$lang".po
sed -i "s*%DATE%*$creation_date*g" po/"$lang".po

echo "$lang" >> po/LINGUAS
sort < po/LINGUAS | uniq > po/LINGUAS_
mv -f po/LINGUAS_ po/LINGUAS

echo "Added $lang to po/LINGUAS"
echo
echo "File created inside po/$lang.po, feel free to edit it with any code editor and submit it as a PR!"
echo "If it's your first time editing a translation, you can use po/fr.po as an example and/or open an issue with your questions"
