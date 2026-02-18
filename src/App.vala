public class Spedread.App {
    Gtk.Application real_app = null;

    public App () {
        AppSettings.init ();

        if (AppSettings.is_using_libadwaita) {
            real_app = new Adw.Application ("com.github.Darazaki.Spedread", ApplicationFlags.NON_UNIQUE);
        } else {
            real_app = new Gtk.Application ("com.github.Darazaki.Spedread", ApplicationFlags.NON_UNIQUE);
        }

        real_app.activate.connect (() => {
            var main_window = new MainWindow (real_app);
            main_window.present ();
        });

        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);
    }

    public static int main (string[] args) {
        return new App ().real_app.run (args);
    }
}
