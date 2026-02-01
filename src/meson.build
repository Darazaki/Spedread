add_project_arguments(
    '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
    language: 'c',
)

# Suppress annoying warnings originating from Vala generated code
add_project_arguments(
    ['-w'],
    language: 'c',
)

# key = vala preprocessor definition; value = message to show on meson setup
preprocessor_definitions = {}

# libadwaita_dependency
if get_option('adw_1_2')
    libadwaita_dependency = dependency('libadwaita-1', version: '>=1.2.0')
    preprocessor_definitions += { 'ADW_1_2': 'libadwaita >=1.2.0 features enabled' }
else
    libadwaita_dependency = dependency('libadwaita-1')
endif
libadwaita_version = libadwaita_dependency.version()

gtk4_dependency = dependency('gtk4')
gtk4_version = gtk4_dependency.version()

if not get_option('force_legacy_libs')
    if libadwaita_version.version_compare('>=1.2.0')
        preprocessor_definitions += {
            'ADW_1_2': 'libadwaita >=1.2.0 detected, extra features enabled',
        }
    endif

    if libadwaita_version.version_compare('>=1.5.0')
        preprocessor_definitions += {
            'ADW_1_5': 'libadwaita >=1.5.0 detected, extra features enabled',
        }
    endif

    if gtk4_version.version_compare('>=4.10.0')
        preprocessor_definitions += {
            'GTK_4_10': 'gtk4 >=4.10.0 detected, extra features enabled',
        }
    endif
endif

foreach definition, msg : preprocessor_definitions
    message(msg)
    add_project_arguments(
        ['-D', definition],
        language: 'vala',
    )
endforeach

spedread_dependencies = [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    gtk4_dependency,
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
    gresource_target,
    dependencies: spedread_dependencies,
    vala_args: ['--target-glib=2.50'],
    install: true,
)
