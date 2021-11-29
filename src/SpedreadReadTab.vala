class SpedreadReadTab : Gtk.Grid {
    public signal void play_toggled ();
    public signal void previous_word ();
    public signal void next_word ();

    Gtk.ToggleButton _play;
    Gtk.Button _previous;
    Gtk.Button _next;
    Gtk.Label _word;

    public string word {
        get { return _word.get_text (); }
        set { _word.set_text (value); }
    }

    public bool is_playing {
        get { return _play.active; }
        set {
            _play.active = value;
            _previous.visible = !value;
            _next.visible = !value;
        }
    }

    public bool has_next_word {
        set { _next.sensitive = value; }
    }

    public bool has_previous_word {
        set { _previous.sensitive = value; }
    }

    public bool allow_playing {
        get { return _play.sensitive; }
        set { _play.sensitive = value; }
    }

    public SpedreadReadTab () {
        Object (
            column_spacing = 12
        );

        var word_attributes = new Pango.AttrList ();
        word_attributes.insert (Pango.attr_scale_new (2));
        word_attributes.insert (Pango.attr_weight_new (Pango.Weight.BOLD));

        _word = new Gtk.Label ("Go to \"Text\" and paste your read!") {
            vexpand = true,
            attributes = word_attributes
        };

        _play = new Gtk.ToggleButton () {
            icon_name = "media-playback-start-symbolic",
            hexpand = true,
            sensitive = false
        };

        _play.clicked.connect (() => play_toggled ());

        _previous = new Gtk.Button () {
            icon_name = "go-next-symbolic-rtl",
            sensitive = false
        };

        _previous.clicked.connect (() => previous_word ());

        _next = new Gtk.Button () {
            icon_name = "go-next-symbolic",
            sensitive = false
        };

        _next.clicked.connect (() => next_word ());

        attach (_word, 0, 0, 3, 1);
        attach (_previous, 0, 1, 1, 1);
        attach (_play, 1, 1, 1, 1);
        attach (_next, 2, 1, 1, 1);
    }
}
