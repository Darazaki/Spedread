desktop_file = i18n.merge_file(
  input: '@0@.desktop.in'.format(application_id),
  output: '@0@.desktop'.format(application_id),
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

config_appstream = configuration_data()
config_appstream.set('VERSION', meson.project_version())
pre_appstream_file = configure_file(
  input: '@0@.appdata.xml.in'.format(application_id),
  output: '@0@.appdata.xml.in'.format(application_id),
  configuration: config_appstream
)

appstream_file = i18n.merge_file(
  input: pre_appstream_file,
  output: '@0@.appdata.xml'.format(application_id),
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

install_data('@0@.gschema.xml'.format(application_id),
  install_dir: join_paths(get_option('datadir'), 'glib-2.0/schemas')
)

compile_schemas = find_program('glib-compile-schemas', required: false)
if compile_schemas.found()
  test('Validate schema file', compile_schemas,
    args: ['--strict', '--dry-run', meson.current_source_dir()]
  )
endif

gresource_target = gnome.compile_resources(
  'SpedreadGResource', # generated .c file name
  '@0@.gresource.xml'.format(application_id),
  c_name: 'spedread_g', # prefix used for identifier within the .c file
  source_dir: meson.current_build_dir(),
  dependencies: [appstream_file]
) 

subdir('icons')
