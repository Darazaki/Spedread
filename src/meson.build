add_project_arguments(
    '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
    language: 'c',
)

if get_option('adw_1_2')
    add_project_arguments(
        ['-D', 'ADW_1_2'],
        language: 'vala',
    )

    libadwaita_dependency = dependency('libadwaita-1', version: '>=1.2.0')
else
    libadwaita_dependency = dependency('libadwaita-1')
endif

spedread_dependencies = [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('gtk4'),
    libadwaita_dependency,
]

config_data = configuration_data()
config_data.set_quoted(
    'LOCALEDIR',
    get_option('prefix') / get_option('localedir'),
)
config_data.set_quoted('GETTEXT_PACKAGE', meson.project_name())
config_data.set_quoted('VERSION', meson.project_version())
config_file = configure_file(
    input: 'SpedreadConfig.vala.in',
    output: '@BASENAME@',
    configuration: config_data,
)

spedread_sources = files(
    'SpedreadApp.vala',
    'SpedreadDictionary.vala',
    'SpedreadIterHistory.vala',
    'SpedreadReadTab.vala',
    'SpedreadSettings.vala',
    'SpedreadTextTab.vala',
    'SpedreadWindow.vala',
)

executable(
    'spedread',
    spedread_sources,
    config_file,
    dependencies: spedread_dependencies,
    vala_args: ['--target-glib=2.50'],
    install: true,
)

