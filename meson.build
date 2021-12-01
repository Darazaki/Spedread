project('Spedread', 'vala', 'c')

dependencies = [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('gtk4'),
]

sources = files('src/SpedreadApp.vala', 'src/SpedreadWindow.vala', 'src/SpedreadTextTab.vala', 'src/SpedreadReadTab.vala', 'src/SpedreadMenuButton.vala')

executable('spedread', sources, dependencies: dependencies)
