class Spedread.ReadTab : Gtk.Grid {
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

    static string _default_text = _ ("Go to \"Text\" and paste your read!");

    Gtk.ToggleButton _play;
    Gtk.Button _previous;
    Gtk.Button _next;
    Gtk.Label _time_left;
    PivotLabel _word;
    bool _is_default_text_shown = true;
    bool _user_enabled_pivot = false;

    /** The text shown on screen */
    public string word {
        get { return _word.text; }
        set {
            _word.text = normalize_whitespace (value.strip ());
            _word.pivot_enabled = _user_enabled_pivot;
            _is_default_text_shown = false;
        }
    }

    /** The font used to show the current word */
    public string font {
        set { _word.font_desc = Pango.FontDescription.from_string (value); }
    }

    /** Whether the user enabled the pivot in the app settings or not */
    public bool user_enabled_pivot {
        set {
            _user_enabled_pivot = value;
            _word.pivot_enabled = value && !_is_default_text_shown;
        }
    }

    /** Controls the state shown by the UI */
    public bool is_playing {
        get { return _play.active; }
        set {
            _play.active = value;
            _play.icon_name = value ? STOP_ICON : PLAY_ICON;
            value = !value;
            _previous.visible = value;
            _next.visible = value;
            _time_left.visible = value;
        }
    }

    /** Controls whether the next word button should be enabled */
    public bool has_next_word {
        set { _next.sensitive = value; }
        get { return _next.sensitive; }
    }

    /** Controls whether the previous word button should be enabled */
    public bool has_previous_word {
        set { _previous.sensitive = value; }
        get { return _previous.sensitive; }
    }

    /** Controls the text shown by the time left label */
    public string time_left {
        get { return _time_left.label; }
        set { _time_left.label = value; }
    }

    /** Controls whether the play button should be enabled */
    public bool allow_playing {
        get { return _play.sensitive; }
        set { _play.sensitive = value; }
    }

    public ReadTab () {
        Object (
            column_spacing: App.MARGIN
        );

        _word = new PivotLabel () {
            vexpand = true,
            hexpand = true,
            text = _default_text,
            pivot_enabled = false,
        };

        _time_left = new Gtk.Label (null) {
            valign = Gtk.Align.END,
            margin_bottom = App.MARGIN,
        };

        var overlay = new Gtk.Overlay ();
        overlay.child = _word;
        overlay.add_overlay (_time_left);

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

        attach (overlay, 0, 0, 3, 1);
        attach (_previous, 0, 1, 1, 1);
        attach (_play, 1, 1, 1, 1);
        attach (_next, 2, 1, 1, 1);

        var scroll_controller = new Gtk.EventControllerScroll (
            Gtk.EventControllerScrollFlags.VERTICAL | Gtk.EventControllerScrollFlags.DISCRETE
        );
        scroll_controller.scroll.connect ((_, dy) => {
            if (dy > 0)
                next_word ();
            else if (dy < 0)
                previous_word ();
            return true;
        });
        add_controller (scroll_controller);
    }

    /** Focus the play button so that the space key plays/pauses */
    public void focus_play_button () {
        _play.grab_focus ();
    }

    /** Show default text */
    public void reset_text () {
        _word.text = _default_text;
        _word.pivot_enabled = false;
        _is_default_text_shown = true;
    }

    void play_toggled () {
        // The play button has just been toggled so its state is the opposite
        // of what's expected
        if (_play.active)
            start_reading ();
        else
            stop_reading ();
    }

    /** Replace all consecutive whitespaces by a single space */
    static string normalize_whitespace (string word) {
        int index;
        unichar character;

        // Find if there are whitespaces in that word
        bool found_a_whitespace = false;
        for (index = 0; word.get_next_char (ref index, out character);) {
            found_a_whitespace = character.isspace ();
            if (found_a_whitespace)
                break;
        }

        // No extra allocations
        if (!found_a_whitespace)
            return word;

        // Replace all single/repeated whitespaces by one single space
        var result = new StringBuilder ();
        for (index = 0; word.get_next_char (ref index, out character);) {
            if (character.isspace ()) {
                result.append_unichar (' ');
                var end_not_reached = false;
                do {
                    end_not_reached = word.get_next_char (ref index, out character);
                } while (end_not_reached && character.isspace ());
                if (end_not_reached)
                    result.append_unichar (character);
            } else {
                result.append_unichar (character);
            }
        }

        return result.str;
    }
}
