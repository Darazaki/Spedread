public abstract class Spedread.App {
    const ApplicationFlags APP_FLAGS = ApplicationFlags.NON_UNIQUE;

    public static int main (string[] args) {
        AppSettings.init ();

        Gtk.Application app;
        if (AppSettings.is_using_libadwaita) {
            app = new Adw.Application (APP_ID, APP_FLAGS);
        } else {
            app = new Gtk.Application (APP_ID, APP_FLAGS);
        }

        app.activate.connect (() => {
            var main_window = new MainWindow (app);
            main_window.present ();
        });

        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        return app.run (args);
    }
}
