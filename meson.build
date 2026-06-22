project(
    'spedread',
    ['c', 'vala'],
    version: '2.8.1',
    meson_version: '>= 0.50.0',
    default_options: [
        'warning_level=2',
    ],
)

application_id = 'com.github.Darazaki.Spedread'

gnome = import('gnome')
i18n = import('i18n')

subdir('data')
subdir('src')
subdir('po')

meson.add_install_script('build-aux/meson/postinstall.py')
