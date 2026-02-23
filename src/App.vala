public abstract class Spedread.App {
    /** The default margin and spacing used in this app */
    public const int MARGIN = 12;

    const ApplicationFlags APP_FLAGS = ApplicationFlags.NON_UNIQUE;

    public static int main (string[] args) {
        AppSettings.init ();

        // Apply Adwaita styling if user chose it
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

        // Recommended GNU way to initialize gettext
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        return app.run (args);
    }
}
