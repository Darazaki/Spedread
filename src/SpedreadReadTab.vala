class SpedreadReadTab : Gtk.Grid {
    /** On play button pressed */
    public signal void start_reading ();
    /** On pause button pressed */
    public signal void stop_reading ();
    /** On previous word button pressed */
    public signal void previous_word ();
    /** On next word button pressed */
    public signal void next_word ();

    const string PLAY_ICON = "media-playback-start-symbolic";
    const string STOP_ICON = "media-playback-stop-symbolic";

    Gtk.ToggleButton _play;
    Gtk.Button _previous;
    Gtk.Button _next;
    Gtk.Label _word;

    /** The text shown on screen */
    public string word {
        get { return _word.get_text (); }
        set { _word.set_text (value); }
    }

    /** The font used to show the current word */
    public string font {
        set {
            var font_attribute = build_font_attribute (value);
            var attributes = _word.attributes;
            attributes.change (font_attribute.copy ());
        }
    }

    /** Controls the state of the play and movement buttons */
    public bool is_playing {
        get { return _play.active; }
        set {
            _play.active = value;
            _play.icon_name = value ? STOP_ICON : PLAY_ICON;
            value = !value;
            _previous.visible = value;
            _next.visible = value;
        }
    }

    /** Controls whether the next word button should be enabled */
    public bool has_next_word {
        set { _next.sensitive = value; }
    }

    /** Controls whether the previous word button should be enabled */
    public bool has_previous_word {
        set { _previous.sensitive = value; }
    }

    /** Controls whether the play button should be enabled */
    public bool allow_playing {
        get { return _play.sensitive; }
        set { _play.sensitive = value; }
    }

    public SpedreadReadTab () {
        Object (
            column_spacing: 12
        );

        var word_attributes = new Pango.AttrList ();
        word_attributes.insert (Pango.attr_scale_new (2));
        word_attributes.insert (Pango.attr_weight_new (Pango.Weight.BOLD));

        _word = new Gtk.Label (_("Go to \"Text\" and paste your read!")) {
            vexpand = true,
            attributes = word_attributes
        };

        _play = new Gtk.ToggleButton () {
            icon_name = PLAY_ICON,
            hexpand = true,
            sensitive = false
        };

        _play.clicked.connect (play_toggled);

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

    /** Focus the play button so that the space key plays/pauses */
    public void focus_play_button () {
        _play.grab_focus ();
    }

    void play_toggled () {
        // The play button has just been toggled so its state is the opposite
        // of what's expected
        var start_playing = _play.active;

        if (start_playing)
            start_reading ();
        else
            stop_reading ();
    }

    Pango.AttrFontDesc build_font_attribute (string font) {
        var description = Pango.FontDescription.from_string (font);
        var attribute = new Pango.AttrFontDesc (description);

        return attribute;
    }
}
