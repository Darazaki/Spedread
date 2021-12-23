public class SpedreadApp : Gtk.Application {
    /** The application's global settings */
    public GLib.Settings settings;

    public SpedreadApp () {
        Object (
            application_id: "com.github.Darazaki.Spedread",
            flags: ApplicationFlags.NON_UNIQUE
        );

        Intl.setlocale (LocaleCategory.ALL, "");
        GLib.Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        GLib.Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        GLib.Intl.textdomain (GETTEXT_PACKAGE);

        settings = new Settings ("com.github.Darazaki.Spedread");
    }

    protected override void activate () {
        var main_window = new SpedreadWindow (this);
        main_window.present ();
    }

    public static int main (string[] args) {
        return new SpedreadApp ().run (args);
    }
}
