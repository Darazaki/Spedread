class SpedreadWindow : Gtk.ApplicationWindow {
    const bool SHOW_PREVIOUS_BUTTON = true;

    Gtk.ToggleButton _play;
    Gtk.SpinButton _ms_per_word;
    Gtk.TextView _input;
    Gtk.Button _previous;
    Gtk.Button _next;
    Gtk.Stack _stack;
    Gtk.Label _word;

    Gtk.TextIter _input_iter;
    Settings _settings;
    uint _timeout_id = 0;
    uint _word_index = 0;

    public SpedreadWindow (Gtk.Application app) {
        Object (
            application: app,
            default_height: 400,
            default_width: 600,
            title: "Spedread"
        );

        _settings = new Settings ("n.darazaki.Spedread");

        _stack = build_main_stack ();
        _stack.notify["visible-child"].connect (view_switched);

        _input.buffer.get_start_iter (out _input_iter);
        _input.buffer.changed.connect (text_changed);

        var switcher = new Gtk.StackSwitcher () {
            stack = _stack
        };

        var titlebar = new Gtk.HeaderBar () {
            title_widget = switcher,
            show_title_buttons = true
        };

        titlebar.pack_end (build_menu_button ());

        set_titlebar (titlebar);
        set_child (_stack);
    }

    protected override void dispose () {
        remove_timeout ();
        base.dispose ();
    }

    void remove_timeout () {
        if (_timeout_id != 0) {
            GLib.Source.remove (_timeout_id);
            _timeout_id = 0;
        }
    }

    void skip_trailing_characters (ref Gtk.TextIter iter) {
        for (;;) {
            unichar current_char = iter.get_char ();

            if (current_char == (unichar)'\n')
                break;
            else if (current_char.isspace () || current_char.ispunct ())
                iter.forward_char ();
            else
                break;
        }
    }

    void skip_whitespaces (ref Gtk.TextIter iter) {
        for (;;) {
            unichar current_char = iter.get_char ();

            if (current_char.isspace ())
                iter.forward_char ();
            else
                break;
        }
    }

    void next_word (ref Gtk.TextIter iter) {
        iter.forward_word_end ();
        skip_trailing_characters (ref iter);
    }

    void previous_word_and_tick () {
        // TODO: Improve performance by not going through every word again

        _input.buffer.get_start_iter (out _input_iter);
        --_word_index;
        for (uint i = 0; i < _word_index; ++i) {
            fast_forced_tick ();
        }

        tick ();
        --_word_index;
    }

    bool has_previous_word (Gtk.TextIter iter) {
        return _word_index != 0;
    }

    void view_switched () {
        var current_view = _stack.visible_child;
        var input_view = _input.parent;

        if (current_view == input_view) {
            // "Text" view: focus on the text view
            stop_reading ();
            current_view.grab_focus ();
        } else {
            // "Read" view: focus on the play/pause button 
            _play.grab_focus ();
        }
    }

    void text_changed () {
        var buffer = _input.buffer;
        var iter = Gtk.TextIter ();

        buffer.get_start_iter (out iter);
        skip_whitespaces (ref iter);
        
        var next_iter = iter;

        if (iter.is_end ()) {
            _word.set_text ("Go to \"Text\" and paste your read!");
            _play.sensitive = false;
            _next.sensitive = false;
            _previous.sensitive = has_previous_word (next_iter);
        } else {
            next_word (ref next_iter);

            var word = buffer.get_text (iter, next_iter, true);
            _word.set_text (word);
            
            var has_next = has_next_word (next_iter);
            _play.sensitive = has_next;
            _next.sensitive = has_next;
            _previous.sensitive = false;
        }

        _input_iter = next_iter;
        _word_index = 0;
    }

    void popover_shown () {
        stop_reading ();
    }

    bool tick () {
        var buffer = _input.buffer;

        skip_whitespaces (ref _input_iter);

        var iter = _input_iter;
        var next_iter = iter;

        if (iter.is_end ()) {
            _timeout_id = 0;
            _play.active = false;
            _play.icon_name = "media-playback-start-symbolic";
            _next.sensitive = false;
            set_show_movement_buttons (true);

            // Stop ticking
            return false;
        } else {
            next_word (ref next_iter);
            var word = buffer.get_text (iter, next_iter, true);
            _word.set_text (word);
            ++_word_index;
        }

        _input_iter = next_iter;

        // Keep ticking
        return true;
    }

    void fast_forced_tick () {
        skip_whitespaces (ref _input_iter);

        var iter = _input_iter;
        var next_iter = iter;

        next_word (ref next_iter);

        _input_iter = next_iter;
    }

    bool has_next_word (Gtk.TextIter iter) {
        skip_whitespaces (ref iter);
        return !iter.is_end ();
    }

    void start_reading () {
        if (_input_iter.is_end ())
            text_changed ();
        
        uint ms_per_word = (uint)_ms_per_word.value;

        _timeout_id = Timeout.add (ms_per_word, tick, Priority.HIGH);

        _play.icon_name = "media-playback-stop-symbolic";
        set_show_movement_buttons (false);
    }

    void stop_reading () {
        remove_timeout ();

        _play.active = false;
        _play.icon_name = "media-playback-start-symbolic";

        _next.sensitive = has_next_word (_input_iter);
        _previous.sensitive = has_previous_word (_input_iter);
        set_show_movement_buttons (true);
    }

    void play_toggled () {
        var start_playing = _play.active;

        if (start_playing)
            start_reading ();
        else
            stop_reading ();
    }

    void set_show_movement_buttons (bool shown) {
        _previous.visible = shown && SHOW_PREVIOUS_BUTTON;
        _next.visible = shown;
    }

    Gtk.Stack build_main_stack () {
        var stack = new Gtk.Stack () {
            transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT,
            margin_bottom = 18,
            margin_top = 18,
            margin_start = 18,
            margin_end = 18
        };

        stack.add_titled (build_text_tab (), "Text", "Text");
        stack.add_titled (build_read_tab (), "Read", "Read");

        return stack;
    }

    Gtk.Widget build_read_tab () {
        var contents = new Gtk.Grid () {
            column_spacing = 12
        };

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

        _play.clicked.connect (play_toggled);

        _previous = new Gtk.Button () {
            icon_name = "go-next-symbolic-rtl",
            visible = SHOW_PREVIOUS_BUTTON,
            sensitive = false
        };

        _previous.clicked.connect (() => {
            previous_word_and_tick ();
            _next.sensitive = has_next_word (_input_iter);
            _previous.sensitive = has_previous_word (_input_iter);
        });

        _next = new Gtk.Button () {
            icon_name = "go-next-symbolic",
            sensitive = false
        };

        _next.clicked.connect (() => {
            tick ();
            _next.sensitive = has_next_word (_input_iter);
            _previous.sensitive = has_previous_word (_input_iter);
        });

        contents.attach (_word, 0, 0, 3, 1);
        contents.attach (_previous, 0, 1, 1, 1);
        contents.attach (_play, 1, 1, 1, 1);
        contents.attach (_next, 2, 1, 1, 1);

        return contents;
    }

    Gtk.Widget build_text_tab () {
        _input = new Gtk.TextView () {
            wrap_mode = Gtk.WrapMode.WORD,
            bottom_margin = 12,
            top_margin = 12,
            right_margin = 12,
            left_margin = 12
        };

        var scroll = new Gtk.ScrolledWindow () {
            child = _input
        };

        return scroll;
    }

    Gtk.MenuButton build_menu_button () {
        var contents = new Gtk.Grid () {
            column_spacing = 12,
            margin_start = 6,
            margin_end = 6
        };

        _ms_per_word = new Gtk.SpinButton (null, 25, 0);
        _ms_per_word.set_increments (25, 50);
        _ms_per_word.set_range (50, 2000);
        _settings.bind ("milliseconds-per-word",
            _ms_per_word, "value",
            GLib.SettingsBindFlags.DEFAULT
        );

        var about_button = new Gtk.Button.with_label ("About Spedread...");
        about_button.clicked.connect (() => {
            var authors = new string[] {
                "Naqua Darazaki <n.darazaki@gmail.com>"
            };

            Gtk.show_about_dialog (this,
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
        contents.attach (_ms_per_word, 1, 0, 1, 1);
        contents.attach (about_button, 0, 1, 2, 1);

        var popover = new Gtk.Popover () {
            child = contents
        };

        var button = new Gtk.MenuButton () {
            icon_name = "open-menu-symbolic",
            popover = popover
        };

        popover.show.connect (popover_shown);

        return button;
    }
}
