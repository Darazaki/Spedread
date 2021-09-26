desktop_file = i18n.merge_file(
  input: 'n.darazaki.Spedread.desktop.in',
  output: 'n.darazaki.Spedread.desktop',
  type: 'desktop',
  po_dir: '../po',
  install: true,
  install_dir: join_paths(get_option('datadir'), 'applications')
)

desktop_utils = find_program('desktop-file-validate', required: false)
if desktop_utils.found()
  test('Validate desktop file', desktop_utils,
    args: [desktop_file]
  )
endif

icondir = join_paths(get_option('datadir'), 'icons/hicolor')
install_data('icons/n.darazaki.Spedread.svg',
    install_dir: join_paths(icondir, 'scalable/apps')
)


appstream_file = i18n.merge_file(
  input: 'n.darazaki.Spedread.appdata.xml.in',
  output: 'n.darazaki.Spedread.appdata.xml',
  po_dir: '../po',
  install: true,
  install_dir: join_paths(get_option('datadir'), 'appdata')
)

appstream_util = find_program('appstream-util', required: false)
if appstream_util.found()
  test('Validate appstream file', appstream_util,
    args: ['validate', appstream_file]
  )
endif

install_data('n.darazaki.Spedread.gschema.xml',
  install_dir: join_paths(get_option('datadir'), 'glib-2.0/schemas')
)

compile_schemas = find_program('glib-compile-schemas', required: false)
if compile_schemas.found()
  test('Validate schema file', compile_schemas,
    args: ['--strict', '--dry-run', meson.current_source_dir()]
  )
endif
