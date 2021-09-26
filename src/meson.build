spedread_sources = [
  'main.c',
  'spedread-window.c',
]

spedread_deps = [
  dependency('gio-2.0', version: '>= 2.50'),
  dependency('gtk+-3.0', version: '>= 3.22'),
  dependency('gmodule-2.0'),
]

gnome = import('gnome')

spedread_sources += gnome.compile_resources('spedread-resources',
  'spedread.gresource.xml',
  c_name: 'spedread'
)

executable('spedread', spedread_sources,
  dependencies: spedread_deps,
  install: true,
)
