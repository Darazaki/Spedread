class SpedreadMenuButton : Gtk.MenuButton {
    public signal void popover_shown();

    public SpedreadMenuButton (SpedreadWindow window, out Gtk.SpinButton ms_per_word) {
        var contents = new Gtk.Grid () {
            column_spacing = 12,
            margin_start = 6,
            margin_end = 6
        };

        ms_per_word = new Gtk.SpinButton (null, 25, 0);
        ms_per_word.set_increments (25, 50);
        ms_per_word.set_range (50, 2000);
        window.app.settings.bind ("milliseconds-per-word",
            ms_per_word, "value",
            GLib.SettingsBindFlags.DEFAULT
        );

        var about_button = new Gtk.Button.with_label ("About Spedread...");
        about_button.clicked.connect (() => {
            var authors = new string[] {
                "Naqua Darazaki <n.darazaki@gmail.com>"
            };

            Gtk.show_about_dialog (window,
                "program-name", "Spedread",
                "website", "https://github.com/Darazaki/Spedread",
                "license-type", Gtk.License.GPL_3_0,
                "logo-icon-name", "n.darazaki.Spedread",
                "comments", "Read like a spedrunner",
                "version", "2.0.0",
                "authors", authors
            );
        });

        contents.attach (new Gtk.Label ("Milliseconds per Word"), 0, 0, 1, 1);
        contents.attach (ms_per_word, 1, 0, 1, 1);
        contents.attach (about_button, 0, 1, 2, 1);

        var popover = new Gtk.Popover () {
            child = contents
        };

        Object (
            icon_name: "open-menu-symbolic",
            popover: popover
        );

        popover.show.connect (() => popover_shown());
    }
}