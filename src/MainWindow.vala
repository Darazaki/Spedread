class Spedread.MainWindow : Gtk.ApplicationWindow {
    ReadTab _read;
    TextTab _text;

    Gtk.ShortcutController _shortcut_controller;
    Gtk.SpinButton _ms_per_word;
    Gtk.SpinButton _words_at_a_time;
    Gtk.Stack _stack;

#if GTK_4_10
    Gtk.FontDialogButton _font_chooser;
#else
    Gtk.FontButton _font_chooser;
#endif

    WordIndex _word_index = new WordIndex ();
    int _current_word = -1;
    uint _timeout_id = 0;

    /** The type of lambdas that are passed to the `add_new_shortcut` method */
    delegate void ShortcutFunc ();

    /** Used by `add_new_shortcut` to determine if the shortcut should run */
    delegate bool ShouldRunFunc ();
    static bool should_always_run () { return true; }
    bool is_tab_read () { return _stack.visible_child == _read; }
    bool is_tab_text () { return _stack.visible_child == _text; }

    public MainWindow (Gtk.Application app) {
        Object (
            application: app,
            default_height: 400,
            default_width: 600,
            title: "Spedread"
        );

        _stack = build_main_stack ();
        _stack.notify["visible-child"].connect (view_switched);

        _text.input.buffer.changed.connect (text_changed);

        var switcher = new Gtk.StackSwitcher () {
            stack = _stack,
        };

        var titlebar = new Gtk.HeaderBar () {
            show_title_buttons = true,
            title_widget = switcher,
        };

        titlebar.pack_start (build_new_window_button ());
        titlebar.pack_start (build_quick_paste_button ());
        titlebar.pack_end (build_menu_button ());

        _shortcut_controller = new Gtk.ShortcutController () {
            propagation_phase = Gtk.PropagationPhase.CAPTURE,
            scope = Gtk.ShortcutScope.GLOBAL,
        };

        _stack.add_controller (_shortcut_controller);
        define_shortcuts ();

        set_titlebar (titlebar);
        set_child (_stack);
    }

    protected override void dispose () {
        remove_timeout ();
        base.dispose ();
    }

    void add_new_shortcut (
        Gdk.ModifierType modifiers,
        uint keyval,
        owned ShortcutFunc action,
        owned ShouldRunFunc should_run = should_always_run
    ) {
        var shortcut_trigger = new Gtk.KeyvalTrigger (keyval, modifiers);
        var shortcut_action = new Gtk.CallbackAction (() => {
            var should_run_result = should_run ();
            if (should_run_result) {
                action ();
            }

            return should_run_result;
        });

        var shortcut = new Gtk.Shortcut (shortcut_trigger, shortcut_action);
        _shortcut_controller.add_shortcut (shortcut);
    }

    bool can_click_next_word () {
        return is_tab_read () && !_read.is_playing && _read.has_next_word;
    }

    bool can_click_previous_word () {
        return is_tab_read () && !_read.is_playing && _read.has_previous_word;
    }

    /** Stop iterating every word automatically */
    void remove_timeout () {
        if (_timeout_id != 0) {
            Source.remove (_timeout_id);
            _timeout_id = 0;
        }
    }

    /** Build the word index if needed. Return false when there is no text. */
    bool ensure_word_index () {
        if (!_word_index.is_valid) {
            _word_index.rebuild (
                _text.input.buffer,
                (int) _words_at_a_time.value
            );
        }

        return !_word_index.is_empty;
    }

    /** Reset the reading position to the start and show the first word */
    void refresh_read_tab () {
        if (!ensure_word_index ()) {
            _current_word = -1;
            _read.reset_text ();
            _read.allow_playing = false;
            _read.has_next_word = false;
            _read.has_previous_word = false;
            update_time_left ();
            return;
        }

        _current_word = 0;
        show_word (_current_word);
        _read.allow_playing = _word_index.length > 1;
        update_word_navigation ();
        update_time_left ();
    }

    /** Show the word at `index` in the "Read" tab */
    void show_word (int index) {
        var buffer = _text.input.buffer;
        Gtk.TextIter start, end;

        buffer.get_iter_at_offset (out start, _word_index.start (index));
        buffer.get_iter_at_offset (out end, _word_index.end (index));
        _read.word = buffer.get_text (start, end, false);
    }

    /** Update the "next"/"previous" button states */
    void update_word_navigation () {
        _read.has_next_word = _word_index.is_valid
            && _current_word + 1 < _word_index.length;
        _read.has_previous_word = _word_index.is_valid && _current_word > 0;
    }

    void view_switched () {
        var current_view = _stack.visible_child;
        var input_view = _text;

        if (current_view == input_view) {
            // "Text" view: focus on the text view
            stop_reading ();
            _text.input.grab_focus ();
        } else {
            // "Read" view: focus on the play/pause button
            if (!_word_index.is_valid)
                refresh_read_tab ();
            else
                update_time_left ();

            _read.focus_play_button ();
        }
    }

    /** Update the "Read" view's time left label */
    void update_time_left () {
        if (!_word_index.is_valid)
            return;

        if (_word_index.is_empty) {
            _read.time_left = "";
            return;
        }

        int remaining_words = _word_index.length - (_current_word + 1);

        if (remaining_words <= 0) {
            _read.time_left = _ ("End reached");
            return;
        }

        var ms_per_word = (ulong) _ms_per_word.value;
        var time_left_in_ms = ms_per_word * (ulong) remaining_words;
        var time_left_in_s = time_left_in_ms / 1000;

        // Always round up
        if (time_left_in_ms % 1000 != 0) {
            time_left_in_s++;
        }

        var seconds_left = (uint) (time_left_in_s % 60);
        var minutes_left = (uint) (time_left_in_s / 60);

        // TR: If plural is an issue, you can translate it as "Time left: %u min %u s"
        _read.time_left = _ ("%u min %u s left").printf (
            minutes_left,
            seconds_left
        );
    }

    /** Reset the reading position to the start and show the first word if any */
    void text_changed () {
        _word_index.invalidate ();
        _current_word = -1;
        _read.allow_playing = false;
        _read.has_next_word = false;
        _read.has_previous_word = false;

        // The highlight may refer to a word that no longer exists
        _text.clear_word_highlight ();

        if (_stack.visible_child == _read) {
            refresh_read_tab ();
        }
    }

    /** When the main menu is shown */
    void popover_shown () {
        stop_reading ();
    }

    /** Shows the next word if any and update the UI, returning if there's a
        next word */
    bool tick () {
        if (!ensure_word_index ()) {
            // No text: update the UI and stop trying to read more
            _timeout_id = 0;
            _read.is_playing = false;
            _read.has_next_word = false;
            _read.has_previous_word = false;
            update_text_position ();
            update_time_left ();

            return false;
        }

        if (_current_word + 1 >= _word_index.length) {
            // Nothing left to read, update the UI and stop trying to read more
            _timeout_id = 0;
            _read.is_playing = false;
            _read.has_next_word = false;
            _read.has_previous_word = _current_word > 0;
            update_text_position ();
            update_time_left ();

            return false;
        }

        // A new word has been read! Update the UI to reflect that
        _current_word++;
        show_word (_current_word);

        // Keep ticking
        return true;
    }

    /** Scroll to the current word and highlight it inside the "Text" tab */
    void update_text_position () {
        // Only the visible Text tab needs to be scrolled and highlighted.
        // When switching to it, `stop_reading` calls this method again.
        if (!is_tab_text ()) {
            return;
        }

        if (!_word_index.is_valid || _current_word < 0
            || _current_word >= _word_index.length) {
            return;
        }

        var buffer = _text.input.buffer;
        Gtk.TextIter start, end;

        buffer.get_iter_at_offset (out start, _word_index.start (_current_word));
        buffer.get_iter_at_offset (out end, _word_index.end (_current_word));
        _text.scroll_to_position (end);
        _text.highlight_current_word (TextBounds (start, end));
    }

    void start_reading () {
        if (!_word_index.is_valid || _current_word < 0
            || _current_word + 1 >= _word_index.length) {
            refresh_read_tab ();
        }

        uint ms_per_word = (uint) _ms_per_word.value;

        _timeout_id = Timeout.add (ms_per_word, tick, Priority.HIGH);

        _read.is_playing = true;
    }

    void stop_reading () {
        remove_timeout ();

        if (_word_index.is_valid) {
            update_word_navigation ();
            update_text_position ();
            update_time_left ();
        } else {
            _read.has_next_word = false;
            _read.has_previous_word = false;
        }

        _read.is_playing = false;
    }

    Gtk.Stack build_main_stack () {
        var stack = new Gtk.Stack () {
            transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT,
            margin_bottom = 18,
            margin_top = 18,
            margin_start = 18,
            margin_end = 18
        };

        build_text_tab ();
        build_read_tab ();

        stack.add_titled (_text, "Text", _ ("Text"));
        stack.add_titled (_read, "Read", _ ("Read"));

        return stack;
    }

    void build_read_tab () {
        _read = new ReadTab ();

        _read.start_reading.connect (start_reading);
        _read.stop_reading.connect (stop_reading);

        _read.previous_word.connect (() => {
            if (can_click_previous_word ()) {
                _current_word--;
                show_word (_current_word);
                update_word_navigation ();
                update_text_position ();
                update_time_left ();
            }
        });

        _read.next_word.connect (() => {
            if (can_click_next_word ()) {
                tick ();
                update_word_navigation ();
                update_text_position ();
                update_time_left ();
            }
        });
    }

    void build_text_tab () {
        _text = new TextTab ();
    }

    Gtk.Button build_new_window_button () {
        var button = new Gtk.Button () {
            icon_name = "window-new-symbolic",
            tooltip_text = _ ("New Window (Ctrl+N)"),
        };

        button.clicked.connect (() => {
            new MainWindow (application).present ();
        });

        return button;
    }

    Gtk.MenuButton build_menu_button () {
        var settings = AppSettings.settings;
        var is_using_libadwaita = AppSettings.is_using_libadwaita;

        var contents = new Gtk.Grid () {
            column_spacing = App.MARGIN,
            row_spacing = is_using_libadwaita ? App.MARGIN : 0,
            margin_start = App.MARGIN / 2,
            margin_end = App.MARGIN / 2,
            margin_top = is_using_libadwaita ? App.MARGIN / 2 : 0,
            margin_bottom = is_using_libadwaita ? App.MARGIN / 2 : 0,
        };

        var popover = new Gtk.Popover () {
            child = contents,
        };

        var button = new Gtk.MenuButton () {
            icon_name = "open-menu-symbolic",
            popover = popover,
            tooltip_text = _ ("Main Menu"),
        };

        _ms_per_word = new Gtk.SpinButton (null, 25, 0);
        _ms_per_word.set_increments (25, 50);
        _ms_per_word.set_range (25, 2000);
        _ms_per_word.value_changed.connect (() => {
            if (!_read.is_playing) {
                update_time_left ();
            }
        });
        settings.bind (
            "milliseconds-per-word",
            _ms_per_word, "value",
            SettingsBindFlags.DEFAULT
        );

        _words_at_a_time = new Gtk.SpinButton (null, 25, 0);
        _words_at_a_time.set_increments (1, 2);
        _words_at_a_time.set_range (1, 10);

        settings.bind (
            "words-at-a-time",
            _words_at_a_time, "value",
            SettingsBindFlags.DEFAULT
        );

        _words_at_a_time.value_changed.connect (() => {
            text_changed ();
        });

#if GTK_4_10
        var font_dialog = new Gtk.FontDialog ();
        _font_chooser = new Gtk.FontDialogButton (font_dialog);
        settings.bind_with_mapping (
            "reading-font",
            _font_chooser, "font-desc",
            SettingsBindFlags.DEFAULT,
            (target, gotten) => { // get from settings
                var font_string = gotten.get_string ();
                var font = Pango.FontDescription.from_string (font_string);
                target.set_boxed (font);
                return true;
            },
            value => { // set to settings
                var font = (Pango.FontDescription) value;
                return font.to_string ();
            },
            null, null
        );
#else
        _font_chooser = new Gtk.FontButton ();
        settings.bind (
            "reading-font",
            _font_chooser, "font",
            SettingsBindFlags.DEFAULT
        );
#endif
        var font_chooser_button = (Gtk.Button) _font_chooser.get_first_child ();
        font_chooser_button.clicked.connect (() => {
            popover.popdown ();
        });

        settings.bind (
            "reading-font",
            _read, "font",
            SettingsBindFlags.GET
        );

        var pivot_enabled = new Gtk.Switch () {
            halign = Gtk.Align.END,
        };
        settings.bind (
            "pivot-enabled",
            pivot_enabled, "active",
            SettingsBindFlags.DEFAULT
        );
        pivot_enabled.state_set.connect (new_state => {
            _read.user_enabled_pivot = new_state;
            return false;
        });
        _read.user_enabled_pivot = settings.get_boolean ("pivot-enabled");

        var use_libadwaita = new Gtk.Switch () {
            halign = Gtk.Align.END,
        };
        settings.bind (
            "use-libadwaita",
            use_libadwaita, "active",
            SettingsBindFlags.DEFAULT
        );
        use_libadwaita.state_set.connect (new_state => {
            // Warn the user that the change will only be applied after an app
            // restart. `is_active` is there to make sure only the focused
            // window displays the warning
            if (is_active && new_state != AppSettings.is_using_libadwaita) {
                popover.popdown ();

                var message_string = _ (
                    "This change will only be applied after you restart Spedread");

#if GTK_4_10
                new Gtk.AlertDialog ("%s", message_string) {
                    buttons = { _ ("_OK") },
                }.show (this);
#else
                var dialog = new Gtk.MessageDialog (
                    this,
                    Gtk.DialogFlags.MODAL,
                    Gtk.MessageType.WARNING,
                    Gtk.ButtonsType.OK,
                    "%s",
                    message_string);
                dialog.response.connect (() => {
                    dialog.close ();
                });
                dialog.show ();
#endif
            }

            // Set the state (see `Gtk.Switch.state_set`)
            return false;
        });

        var about_button = new Gtk.Button.with_label (_ ("About Spedread..."));
        about_button.clicked.connect (() => {
            popover.popdown ();

            // TR: "Name <email@domain.com>", "Name https://website.example" or "Name"
            var translator_credits = _ ("translator-credits");
            var catchphrase = _ ("Read like a speedrunner!");
            var authors = new string[] {
                "Naqua Darazaki <n.darazaki@gmail.com>",
            };

#if ADW_1_5
            if (AppSettings.is_using_libadwaita) {
                Adw.show_about_dialog_from_appdata (this,
                    application.resource_base_path + "/appdata.xml", VERSION,
                    "comments", catchphrase,
                    "translator-credits", translator_credits,
                    "developers", authors,
                    null
                );

                return;
            }
#elif ADW_1_2
            if (SpedreadSettings.is_using_libadwaita) {
                var win = new Adw.AboutWindow () {
                    application_name = "Spedread",
                    application_icon = "com.github.Darazaki.Spedread",
                    version = VERSION,
                    comments = catchphrase,
                    translator_credits = translator_credits,
                    license_type = Gtk.License.GPL_3_0,
                    developers = authors,
                    website = "https://github.com/Darazaki/Spedread",
                };
                win.set_transient_for (this);
                win.show ();

                return;
            }
#endif

            Gtk.show_about_dialog (this,
                "program-name", "Spedread",
                "website", "https://github.com/Darazaki/Spedread",
                "license-type", Gtk.License.GPL_3_0,
                "logo-icon-name", "com.github.Darazaki.Spedread",
                "comments", catchphrase,
                "translator-credits", translator_credits,
                "version", VERSION,
                "authors", authors
            );
        });

        contents.attach (new Gtk.Label (_ ("Milliseconds per Word")), 0, 0, 1, 1);
        contents.attach (_ms_per_word, 1, 0, 1, 1);
        contents.attach (new Gtk.Label (_ ("Words at a Time")), 0, 1, 1, 1);
        contents.attach (_words_at_a_time, 1, 1, 1, 1);
        contents.attach (new Gtk.Label (_ ("Reading Font")), 0, 2, 1, 1);
        contents.attach (_font_chooser, 1, 2, 1, 1);
        contents.attach (new Gtk.Label (_ ("Fixed Pivot")), 0, 3, 1, 1);
        contents.attach (pivot_enabled, 1, 3, 1, 1);
        contents.attach (new Gtk.Label (_ ("Use libadwaita")), 0, 4, 1, 1);
        contents.attach (use_libadwaita, 1, 4, 1, 1);
        contents.attach (about_button, 0, 5, 2, 1);

        popover.show.connect (popover_shown);

        return button;
    }

    /** Replaces the text to read with the clipboard's content */
    void quick_paste () {
        // Make sure pasting the text stops the current reading
        stop_reading ();

        var clipboard = Gdk.Display.get_default ().get_clipboard ();

        // Attempt reading text from the clipboard
        clipboard.read_text_async.begin (null, (_, result) => {
            // The clipboard's content may or may to be convertible into
            // text. If it isn't: return
            string? maybe_text;
            try {
                maybe_text = clipboard.read_text_async.end (result);
            } catch {
                return;
            }

            if (maybe_text != null) {
                // Update the text (all the annoying stuff should be automatic)
                _text.input.buffer.text = maybe_text;
            }
        });
    }

    Gtk.Button build_quick_paste_button () {
        var button = new Gtk.Button () {
            icon_name = "edit-paste-symbolic",
            tooltip_text = _ ("Paste (Ctrl+P)"),
        };

        button.clicked.connect (quick_paste);
        return button;
    }

    void switch_tab () {
        _stack.visible_child = _stack.visible_child == _read
            ? (Gtk.Widget) _text
            : (Gtk.Widget) _read;
    }

    void toggle_reading () {
        if (!_read.allow_playing)
            return;

        if (_read.is_playing)
            stop_reading ();
        else
            start_reading ();
    }

    void define_shortcuts () {
        const Gdk.ModifierType CTRL = Gdk.ModifierType.CONTROL_MASK;
        const Gdk.ModifierType CTRL_SHIFT = CTRL | Gdk.ModifierType.SHIFT_MASK;

        // Quick paste
        add_new_shortcut (CTRL, Gdk.Key.P, quick_paste);
        add_new_shortcut (CTRL_SHIFT, Gdk.Key.V, quick_paste);

        // Switch tabs
        add_new_shortcut (CTRL, Gdk.Key.Tab, switch_tab);
        add_new_shortcut (CTRL, Gdk.Key.KP_Tab, switch_tab);
        add_new_shortcut (CTRL_SHIFT, Gdk.Key.Tab, switch_tab);
        add_new_shortcut (CTRL_SHIFT, Gdk.Key.KP_Tab, switch_tab);

        // Search text
        add_new_shortcut (CTRL, Gdk.Key.F, () => {
            _text.search_bar.toggle_search_visible_focused ();
        }, is_tab_text);

        // New window
        add_new_shortcut (CTRL, Gdk.Key.N, () => {
            new MainWindow (application).present ();
        });

        // Previous word
        add_new_shortcut (0, Gdk.Key.Left, () => _read.previous_word (), is_tab_read);
        add_new_shortcut (0, Gdk.Key.KP_Left, () => _read.previous_word (), is_tab_read);

        // Next word
        add_new_shortcut (0, Gdk.Key.Right, () => _read.next_word (), is_tab_read);
        add_new_shortcut (0, Gdk.Key.KP_Right, () => _read.next_word (), is_tab_read);

        // Toggle reading
        add_new_shortcut (0, Gdk.Key.space, toggle_reading, is_tab_read);
        add_new_shortcut (0, Gdk.Key.Return, toggle_reading, is_tab_read);
        add_new_shortcut (0, Gdk.Key.KP_Space, toggle_reading, is_tab_read);
        add_new_shortcut (0, Gdk.Key.KP_Enter, toggle_reading, is_tab_read);
    }
}
