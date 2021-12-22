spedread_dependencies = [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('gtk4'),
]

spedread_sources = files('SpedreadApp.vala', 'SpedreadWindow.vala', 'SpedreadTextTab.vala', 'SpedreadReadTab.vala')

executable('spedread', spedread_sources,
    dependencies: spedread_dependencies,
    vala_args: '--target-glib=2.50',
    install: true,
)

