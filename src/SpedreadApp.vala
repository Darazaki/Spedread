public class SpedreadApp : Gtk.Application {
    /** The application's global settings */
    public GLib.Settings settings;

    public SpedreadApp () {
        Object (
            application_id: "n.darazaki.Spedread",
            flags: ApplicationFlags.NON_UNIQUE
        );

        settings = new Settings ("n.darazaki.Spedread");
    }

    protected override void activate () {
        var main_window = new SpedreadWindow (this);;
        main_window.present ();
    }

    public static int main (string[] args) {
        return new SpedreadApp ().run (args);
    }
}
