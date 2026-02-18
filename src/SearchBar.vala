class Spedread.SearchBar : Gtk.Box {
    unowned Gtk.TextView _text;
    unowned TextTab.TagManager _tag_manager;
    Gtk.Entry _search_entry;

    TextBounds[] _matches;

    Gtk.Label _counter_label;

    public SearchBar (Gtk.TextView text, TextTab.TagManager tag_manager) {
        Object (
            orientation: Gtk.Orientation.HORIZONTAL,
            hexpand: true,
            spacing: 12
        );

        _tag_manager = tag_manager;
        _matches = {};
        _text = text;

        _counter_label = new Gtk.Label (null);
        update_counter_label (0);

        _search_entry = new Gtk.Entry () {
            placeholder_text = _ ("Find in text"),
            hexpand = true,
        };

        text.buffer.changed.connect (() => {
            search_or_buffer_changed (_search_entry.text);
        });

        _search_entry.changed.connect (search_entry => {
            search_or_buffer_changed (search_entry.text);
        });

        var key_controller = new Gtk.EventControllerKey ();
        key_controller.propagation_phase = Gtk.PropagationPhase.CAPTURE;
        key_controller.key_pressed.connect ((keyval, keycode, state) => {
            if (keyval == Gdk.Key.Escape) {
                toggle_search_visible_focused ();
                return true;
            }

            var shift_pressed = (state & Gdk.ModifierType.SHIFT_MASK) != 0;
            if (keyval != Gdk.Key.Return && keyval != Gdk.Key.KP_Enter) {
                // We don't care about keys other than the Enter/Return ones
                return false;
            }

            if (shift_pressed) {
                find_previous ();
            } else {
                find_next ();
            }

            return true;
        });

        _search_entry.add_controller (key_controller);

        append (_search_entry);
        append (_counter_label);
    }

    public void toggle_search_visible_focused () {
        var buffer = _text.buffer;
        var was_visible = visible;
        var search_entry_is_focused =
            was_visible &&
            parent.get_focus_child () == this &&
            get_focus_child () == _search_entry;

        if (search_entry_is_focused) {
            var bounds = TextBounds.of (buffer);
            bounds.remove_tag (_tag_manager.selected_needle);
            bounds.remove_tag (_tag_manager.needle);

            _text.grab_focus ();
            visible = false;
            return;
        }

        if (!was_visible) {
            visible = true;
        }

        // If text is selected, search for it
        var search_modified = false;
        if (buffer.has_selection) {
            var selection = TextBounds.selection_of (buffer);
            var selected_text = selection.get_text ();

            if (can_search_needle (selected_text)) {
                _search_entry.text = selected_text;
                search_modified = true;

                // Mark selected text as selected needle
                selection.apply_tag (_tag_manager.selected_needle);
                for (var i = 0; i < _matches.length; i++) {
                    if (selection.equal (_matches[i])) {
                        update_counter_label (i + 1);
                        break;
                    }
                }
            }
        }

        if (!was_visible && !search_modified) {
            search_or_buffer_changed (_search_entry.text);
        }

        _search_entry.grab_focus ();
        _search_entry.select_region (0, (int) _search_entry.text_length);
    }

    /** `index` is 1-indexed */
    void update_counter_label (int index) {
        _counter_label.set_text ("%d/%d".printf (index, _matches.length));
    }

    void search_or_buffer_changed (string needle) {
        if (!visible) {
            // Don't try to search while the search bar isn't visible
            return;
        }

        var buffer = _text.buffer;
        var bounds = TextBounds.of (buffer);
        bounds.remove_tag (_tag_manager.needle);
        bounds.remove_tag (_tag_manager.selected_needle);

        if (!can_search_needle (needle)) {
            // Nothing to search for
            return;
        }

        _matches = find_all_matches (buffer, needle);
        foreach (var match in _matches) {
            match.apply_tag (_tag_manager.needle);
        }

        update_counter_label (0);
    }

    /** Go to next match */
    void find_next () {
        if (_matches.length == 0) {
            // Nothing to search for
            return;
        }

        // Select match at the cursor's right (if any)
        var cursor_position = _text.buffer.cursor_position;
        for (var i = 0; i < _matches.length; i++) {
            var start = _matches[i].start;
            if (start.get_offset () > cursor_position) {
                go_to_and_select_search_result (i);
                return;
            }
        }

        // If no match at the cursor's right: select first match
        go_to_and_select_search_result (0);
    }

    /** Go to previous match */
    void find_previous () {
        if (_matches.length == 0) {
            // Nothing to search for
            return;
        }

        // Select match at the cursor's left (if any)
        var cursor_position = _text.buffer.cursor_position;
        for (var i = _matches.length - 1; i >= 0; i--) {
            var end = _matches[i].end;
            if (end.get_offset () < cursor_position) {
                go_to_and_select_search_result (i);
                return;
            }
        }

        // If no match at the cursor's left: select last match
        go_to_and_select_search_result (_matches.length - 1);
    }

    void go_to_and_select_search_result (int index) {
        var buffer = _text.buffer;

        var match = _matches[index];
        var bounds = TextBounds.of (buffer);

        bounds.remove_tag (_tag_manager.selected_needle);
        match.apply_tag (_tag_manager.selected_needle);

        update_counter_label (index + 1);
        go_to_and_select_region (match);
    }

    void go_to_and_select_region (TextBounds region) {
        _text.buffer.select_range (region.start, region.end);
        _text.scroll_to_iter (region.start, 0.1, false, 0, 0);
    }

    static bool can_search_needle (string needle) {
        return needle.length >= 2 && needle.index_of_char ('\n') == -1;
    }

    static TextBounds[] find_all_matches (
        Gtk.TextBuffer buffer,
        string needle
    ) {
        var buffer_text = buffer.text;
        MatchInfo match_info;

        try {
            var regex = new Regex (
                Regex.escape_string (needle),
                GLib.RegexCompileFlags.CASELESS
            );

            regex.match (buffer_text, 0, out match_info);
        } catch (RegexError err) {
            error ("Regex ctor error: %s", err.message);
        }

        var matches = new TextBoundsList ();
        try {
            for (; match_info.matches (); match_info.next ()) {
                int start_pos, end_pos;
                match_info.fetch_pos (0, out start_pos, out end_pos);

                var start_char_offset = buffer_text.char_count (start_pos);
                var end_char_offset = buffer_text.char_count (end_pos);

                Gtk.TextIter start, end;
                buffer.get_iter_at_offset (out start, start_char_offset);
                buffer.get_iter_at_offset (out end, end_char_offset);

                matches.append (TextBounds (start, end));
            }
        } catch (RegexError err) {
            error ("Regex search error: %s", err.message);
        }

        return matches.into_array ();
    }
}
