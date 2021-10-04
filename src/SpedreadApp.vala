public class SpedreadApp : Gtk.Application {
    public SpedreadApp () {
        Object (
            application_id: "n.darazaki.Spedread",
            flags: ApplicationFlags.NON_UNIQUE
        );
    }

    protected override void activate () {
        var main_window = new SpedreadWindow (this);;
        main_window.present ();
    }

    public static int main (string[] args) {
        return new SpedreadApp ().run (args);
    }
}
