# How to contribute...

## ...a translation

Translations are located inside the `po/` directory

After forking the repository on Github and optionally creating a new branch,
you can create a new translation file through
`dev-scripts/new-translation.sh`:

```sh
git clone git@github.com:<you>/Spedread.git spedread
cd spedread
dev-scripts/new-translation.sh
```

By default, this script will create a new translation inside the file
`po/<language>.po` with the name and email you set inside the `git` CLI but
feel free to change your name/email afterward

You can then edit the `po/<language>.po` file either through a code editor or
through something like [Gtranslator](https://flathub.org/apps/details/org.gnome.Gtranslator)

If you decide to use a code editor but aren't sure about the syntax, you can
always take a look at `po/fr.po` or open an issue to ask a question

After that simply commit your changes, push them and open a PR

## ...a bug fix

TODO: Write bug fix contribution guide

## ...a new feature

TODO: Write new feature contribution guide
