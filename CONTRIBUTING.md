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

## ...a bugfix

You can just open a PR with your bugfix

Please explain steps to reproduce the bug in your PR message so I can
understand what you're fixing and make sure this bug doesn't reappear
in the future

## ...a new feature

I don't always merge new features so it's probably a good idea for you to open
an issue explaining what you'd like to add first to avoid working for nothing

If you think that your feature will get merged anyway, feel free to open a PR
directly

## On LLM contributions

- LLM for code is allowed, as long as you can explain why *this* code yourself
- LLM for translations and user facing documentation is strictly forbidden
  except for proofreading
- LLM for PR/commit messages is discouraged but allowed

While I think modern LLMs are impressive and I do use them myself, I'd like to
keep Spedread as a mostly *made for humans by humans* project

I also want to encourage people to learn and take it slow when it comes to
developing this kind of nonprofit small software. Nobody's company is going out
of business if a feature isn't implemented by tomorrow :)
