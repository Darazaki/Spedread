class SpedreadWindow : Gtk.ApplicationWindow {
    SpedreadReadTab _read;
    SpedreadTextTab _text;

    Gtk.ShortcutController _shortcut_controller;
    Gtk.SpinButton _ms_per_word;
    Gtk.SpinButton _words_at_a_time;
    Gtk.Stack _stack;

#if GTK_4_10
    Gtk.FontDialogButton _font_chooser;
#else
    Gtk.FontButton _font_chooser;
#endif

    SpedreadIterHistory _iter_history = SpedreadIterHistory ();
    Gtk.TextIter _input_iter;
    Gtk.TextIter _previous_iter;
    Gtk.TextIter _end_of_word;
    uint _timeout_id = 0;

    /** Type of the `is_*_between` methods, used by `next_word_using` for word
        detection */
    delegate bool IsThingBetween (Gtk.TextIter start, Gtk.TextIter end);

    /** The type of lambdas that are passed to the `add_new_shortcut` method */
    delegate void ShortcutFunc ();

    /** Used by `add_new_shortcut` to determine if the shortcut should run */
    delegate bool ShouldRunFunc ();
    static bool should_always_run () { return true; }
    bool is_tab_read () { return _stack.visible_child == _read; }

    public SpedreadWindow (Gtk.Application app) {
        Object (
            application: app,
            default_height: 400,
            default_width: 600,
            title: "Spedread"
        );

        _stack = build_main_stack ();
        _stack.notify["visible-child"].connect (view_switched);

        _text.input.buffer.get_start_iter (out _input_iter);
        _text.input.buffer.changed.connect (text_changed);
        _previous_iter = _input_iter;
        _end_of_word = _input_iter;

        var switcher = new Gtk.StackSwitcher () {
            stack = _stack
        };

        var titlebar = new Gtk.HeaderBar () {
            title_widget = switcher,
            show_title_buttons = true
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

    /** Skip whitespaces and punctuations then return the end of the
        "end of word" iterator */
    static Gtk.TextIter skip_trailing_characters (ref Gtk.TextIter iter) {
        var end_of_word = iter;

        for ( ;; ) {
            unichar current_char = iter.get_char ();

            if (current_char == (unichar) '\n') {
                break;
            } else if (current_char.ispunct ()) {
                iter.forward_char ();
                end_of_word = iter;
            } else if (current_char.isspace ()) {
                iter.forward_char ();
            } else {
                break;
            }
        }

        return end_of_word;
    }

    void skip_whitespaces (ref Gtk.TextIter iter) {
        for ( ;; ) {
            unichar current_char = iter.get_char ();

            if (current_char.isspace ())
                iter.forward_char ();
            else
                break;
        }
    }

    /** Advance the iterator to the next word (or group of words) and return the end of the
        "end of word" iterator for the previous word */
    Gtk.TextIter next_word (ref Gtk.TextIter iter) {
        Gtk.TextIter end_of_word, last_iter;

        last_iter = iter;
        var number_of_words = (int) _words_at_a_time.value;
        iter.forward_word_ends (number_of_words);
        end_of_word = skip_trailing_characters (ref iter);

        if (is_number_between (last_iter, iter)) {
            next_word_using (is_number_between, ref iter, last_iter, ref end_of_word);
        } else if (is_acronym_between (last_iter, iter)) {
            next_word_using (is_acronym_between, ref iter, last_iter, ref end_of_word);
        }

        return end_of_word;
    }

    /** Advance the iterator to the next word using a specific function to
        detect where the word stops */
    static void next_word_using (IsThingBetween is_thing_between,
        ref Gtk.TextIter iter,
        Gtk.TextIter last_iter,
        ref Gtk.TextIter end_of_word) {
        var initial_iter = last_iter;
        for ( ;; ) {
            last_iter = iter;
            iter.forward_word_end ();

            if (!is_thing_between (initial_iter, iter)) {
                iter = last_iter;
                end_of_word = skip_trailing_characters (ref iter);
                break;
            } else if (iter.equal (last_iter)) {
                end_of_word = skip_trailing_characters (ref iter);
                break;
            }
        }
    }

    /** Check if whatever is contained between `start` and `end` looks like an
        acronym */
    static bool is_acronym_between (Gtk.TextIter start, Gtk.TextIter end) {
        var expects_alpha_next = true;

        for (var c = start.get_char ();
             !start.equal (end);
             start.forward_char (), c = start.get_char ()) {
            if (expects_alpha_next && c.isalpha ()) {
                expects_alpha_next = false;
            } else if (!expects_alpha_next && c == '.') {
                expects_alpha_next = true;
            } else {
                return false;
            }
        }

        return true;
    }

    /** Check if whatever is contained between `start` and `end` looks like a
        number */
    static bool is_number_between (Gtk.TextIter start, Gtk.TextIter end) {
        var separator_found = false;
        var found_digit = false;

        for (var c = start.get_char ();
             !start.equal (end);
             start.forward_char (), c = start.get_char ()) {
            if (c.isdigit ()) {
                found_digit = true;
                separator_found = false;
            } else if (c.isspace () || c == '.' || c == ',') {
                // Separator found!

                if (separator_found) {
                    // 2 separators in a row => not a number
                    return false;
                } else {
                    separator_found = true;
                }
            } else {
                // Character not valid in a number
                return false;
            }
        }

        return found_digit;
    }

    /** Go to the previous word and show it */
    void previous_word_and_tick () {
        _input_iter = _iter_history.pop ();
        if (!_iter_history.is_empty ()) {
            _previous_iter = _iter_history.last;
        } else {
            _text.input.buffer.get_start_iter (out _previous_iter);
        }

        tick ();

        // Remove the extra iterator added by `tick`
        _iter_history.pop ();
    }

    bool has_previous_word (Gtk.TextIter iter) {
        return !_iter_history.is_empty ();
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
            _read.focus_play_button ();
            update_time_left ();
        }
    }

    /** Update the "Read" view's time left label */
    void update_time_left () {
        var iter = _input_iter;
        skip_whitespaces (ref iter);

        if (iter.is_end ()) {
            // Get the iter indicating the start of the first word
            Gtk.TextIter start_iter;
            _text.input.buffer.get_start_iter (out start_iter);
            skip_whitespaces (ref start_iter);

            // If the first word is also the end (=> text is empty)
            // then don't show the "End reached" message
            if (start_iter.equal (iter)) {
                _read.time_left = "";
            } else {
                _read.time_left = _ ("End reached");
            }

            return;
        }

        uint word_count;
        for (word_count = 0; !iter.is_end (); word_count++) {
            next_word (ref iter);
            skip_whitespaces (ref iter);
        }

        var ms_per_word = (uint) _ms_per_word.value;
        var time_left_in_ms = ms_per_word * word_count;
        var time_left_in_s = time_left_in_ms / 1000;

        // Always round up
        if (time_left_in_ms % 1000 != 0) {
            time_left_in_s++;
        }

        var seconds_left = time_left_in_s % 60;
        var minutes_left = time_left_in_s / 60;

        // TR: If plural is an issue, you can translate it as "Time left: %u min %u s"
        _read.time_left = _ ("%u min %u s left").printf (
            minutes_left,
            seconds_left
        );
    }

    /** Reset the reading position to the start and show the first word if any */
    void text_changed () {
        var buffer = _text.input.buffer;
        var iter = Gtk.TextIter ();

        buffer.get_start_iter (out iter);
        skip_whitespaces (ref iter);

        // Invalidate old `Gtk.TextIter`s
        var next_iter = _end_of_word = _previous_iter = iter;
        _iter_history.erase ();

        if (iter.is_end ()) {
            // No text, disable everything and prompt the user to add something
            // to read
            _read.word = _ ("Go to \"Text\" and paste your read!");
            _read.allow_playing = false;
            _read.has_next_word = false;
            _read.has_previous_word = false;
        } else {
            // There's text! Show the first word and highlight it

            _end_of_word = next_word (ref next_iter);

            var word = buffer.get_text (iter, next_iter, false);
            _read.word = word;

            var has_next = has_next_word (next_iter);
            _read.allow_playing = has_next;
            _read.has_next_word = has_next;
            _read.has_previous_word = false;

            _text.highlight_current_word (iter, _end_of_word);
        }

        _input_iter = next_iter;

        if (_stack.visible_child == _read) {
            update_time_left ();
        }
    }

    /** When the main menu is shown */
    void popover_shown () {
        stop_reading ();
    }

    /** Shows the next word if any and update the UI, returning if there's a
        next word */
    bool tick () {
        var buffer = _text.input.buffer;

        skip_whitespaces (ref _input_iter);

        var iter = _input_iter;
        var next_iter = iter;

        if (iter.is_end ()) {
            // Nothing left to read, update the UI and stop trying to read more
            _timeout_id = 0;
            _read.is_playing = false;
            _read.has_next_word = false;
            _read.has_previous_word = has_previous_word (iter);
            update_text_position ();
            update_time_left ();

            // Stop ticking
            return false;
        } else {
            // A new word has been read! Update the UI to reflect that
            _end_of_word = next_word (ref next_iter);
            var word = buffer.get_text (iter, next_iter, false);
            _read.word = word;

            // Add it to the history
            _iter_history.push (_previous_iter);
        }

        _previous_iter = _input_iter;
        _input_iter = next_iter;

        // Keep ticking
        return true;
    }

    /** Scroll to the current word and highlight it inside the "Text" tab */
    void update_text_position () {
        _text.scroll_to_position (_end_of_word);
        _text.highlight_current_word (_previous_iter, _end_of_word);
    }

    bool has_next_word (Gtk.TextIter iter) {
        skip_whitespaces (ref iter);
        return !iter.is_end ();
    }

    void start_reading () {
        if (_input_iter.is_end ())
            text_changed ();

        uint ms_per_word = (uint) _ms_per_word.value;

        _timeout_id = Timeout.add (ms_per_word, tick, Priority.HIGH);

        _read.is_playing = true;
    }

    void stop_reading () {
        remove_timeout ();

        _read.has_next_word = has_next_word (_input_iter);
        _read.has_previous_word = has_previous_word (_input_iter);
        _read.is_playing = false;
        update_text_position ();
        update_time_left ();
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
        _read = new SpedreadReadTab ();

        _read.start_reading.connect (start_reading);
        _read.stop_reading.connect (stop_reading);

        _read.previous_word.connect (() => {
            if (can_click_previous_word ()) {
                previous_word_and_tick ();
                _read.has_next_word = has_next_word (_input_iter);
                _read.has_previous_word = has_previous_word (_input_iter);
                update_text_position ();
                update_time_left ();
            }
        });

        _read.next_word.connect (() => {
            if (can_click_next_word ()) {
                tick ();
                _read.has_next_word = has_next_word (_input_iter);
                _read.has_previous_word = has_previous_word (_input_iter);
                update_text_position ();
                update_time_left ();
            }
        });
    }

    void build_text_tab () {
        _text = new SpedreadTextTab ();
    }

    Gtk.Button build_new_window_button () {
        var button = new Gtk.Button () {
            icon_name = "window-new-symbolic",
            tooltip_text = _ ("New Window (Ctrl+N)")
        };

        button.clicked.connect (() => {
            new SpedreadWindow (application).present ();
        });

        return button;
    }

    Gtk.MenuButton build_menu_button () {
        var settings = SpedreadSettings.settings;
        var is_using_libadwaita = SpedreadSettings.is_using_libadwaita;

        var contents = new Gtk.Grid () {
            column_spacing = 12,
            row_spacing = is_using_libadwaita ? 12 : 0,
            margin_start = 6,
            margin_end = 6,
            margin_top = is_using_libadwaita ? 6 : 0,
            margin_bottom = is_using_libadwaita ? 6 : 0,
        };

        var popover = new Gtk.Popover () {
            child = contents
        };

        var button = new Gtk.MenuButton () {
            icon_name = "open-menu-symbolic",
            popover = popover,
            tooltip_text = _ ("Main Menu")
        };

        _ms_per_word = new Gtk.SpinButton (null, 25, 0);
        _ms_per_word.set_increments (25, 50);
        _ms_per_word.set_range (25, 2000);
        _ms_per_word.value_changed.connect (() => {
            if (!_read.is_playing) {
                update_time_left ();
            }
        });
        settings.bind ("milliseconds-per-word",
                       _ms_per_word, "value",
                       SettingsBindFlags.DEFAULT
        );

        _words_at_a_time = new Gtk.SpinButton (null, 25, 0);
        _words_at_a_time.set_increments (1, 2);
        _words_at_a_time.set_range (1,10);

        settings.bind ("words-at-a-time",
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
        settings.bind ("reading-font",
                       _font_chooser, "font",
                       SettingsBindFlags.DEFAULT
        );
#endif
        var font_chooser_button = (Gtk.Button) _font_chooser.get_first_child ();
        font_chooser_button.clicked.connect (() => {
            popover.popdown ();
        });

        settings.bind ("reading-font",
                       _read, "font",
                       SettingsBindFlags.GET
        );

        var use_libadwaita = new Gtk.Switch () {
            halign = Gtk.Align.END,
        };
        settings.bind ("use-libadwaita",
                       use_libadwaita, "active",
                       SettingsBindFlags.DEFAULT
        );
        use_libadwaita.state_set.connect (new_state => {
            // Warn the user that the change will only be applied after an app
            // restart. `is_active` is there to make sure only the focused
            // window displays the warning
            if (is_active && new_state != SpedreadSettings.is_using_libadwaita) {
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
                "Naqua Darazaki <n.darazaki@gmail.com>"
            };

#if ADW_1_5
            if (SpedreadSettings.is_using_libadwaita) {
                Adw.show_about_dialog_from_appdata (this,
                    application.resource_base_path + "/appdata.xml", VERSION,
                    "comments", catchphrase,
                    "translator-credits", translator_credits,
                    "developers", authors,
                    null);

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
                    website = "https://github.com/Darazaki/Spedread"
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
        contents.attach (new Gtk.Label(_ ("Words at a Time")), 0, 1, 1, 1);
        contents.attach (_words_at_a_time, 1, 1, 1, 1);
        contents.attach (new Gtk.Label (_ ("Reading Font")), 0, 2, 1, 1);
        contents.attach (_font_chooser, 1, 2, 1, 1);
        contents.attach (new Gtk.Label (_ ("Use libadwaita")), 0, 3, 1, 1);
        contents.attach (use_libadwaita, 1, 3, 1, 1);
        contents.attach (about_button, 0, 4, 2, 1);

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
            string text;

            // The clipboard's content may or may to be convertible into
            // text. If it isn't: return
            try {
                var maybe_text = clipboard.read_text_async.end (result);
                if (maybe_text == null) {
                    return;
                }

                text = maybe_text;
            } catch {
                return;
            }

            // Update the text (all the annoying stuff should be automatic)
            _text.input.buffer.text = text;
        });
    }

    Gtk.Button build_quick_paste_button () {
        var button = new Gtk.Button () {
            icon_name = "edit-paste-symbolic",
            tooltip_text = _ ("Paste (Ctrl+P)")
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

        // New window
        add_new_shortcut (CTRL, Gdk.Key.N, () => {
            new SpedreadWindow (application).present ();
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
