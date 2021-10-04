project('Spedread', 'vala', 'c')

dependencies = [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('gtk4'),
]

sources = files('src/SpedreadApp.vala', 'src/SpedreadWindow.vala')

executable('spedread', sources, dependencies: dependencies)
