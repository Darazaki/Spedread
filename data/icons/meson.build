application_id = 'com.github.Darazaki.Spedread'

scalable_dir = join_paths('hicolor', 'scalable', 'apps')
install_data(
  'normal.svg',
  rename: [('@0@.svg').format(application_id)],
  install_dir: join_paths(get_option('datadir'), 'icons', scalable_dir),
)

symbolic_dir = join_paths('hicolor', 'symbolic', 'apps')
install_data(
  'symbolic.svg',
  rename: [('@0@-symbolic.svg').format(application_id)],
  install_dir: join_paths(get_option('datadir'), 'icons', symbolic_dir),
)
