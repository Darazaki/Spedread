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
            spacing: App.MARGIN
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

    /** Look for new search results and highlight them */
    void search_or_buffer_changed (string needle) {
        if (!visible) {
            // Don't try to search while the search bar isn't visible
            return;
        }

        var buffer = _text.buffer;
        var bounds = TextBounds.of (buffer);
        bounds.remove_tag (_tag_manager.needle);
        bounds.remove_tag (_tag_manager.selected_needle);

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
        _text.scroll_to_iter (region.start, 0.1, true, 0, 0.5);
    }

    /** Check needle for length and forbidden characters */
    static bool can_search_needle (string needle) {
        return needle.length >= 2 && needle.index_of_char ('\n') == -1;
    }

    /** Return all bounds of occurences of `needle` found within `buffer` */
    static TextBounds[] find_all_matches (
        Gtk.TextBuffer buffer,
        string needle
    ) {
        if (!can_search_needle (needle)) {
            return {};
        }

        var matches = new TextBoundsList ();

        Gtk.TextIter search_cursor, match_start, match_end;
        buffer.get_start_iter (out search_cursor);

        while (search_cursor.forward_search (
            needle,
            Gtk.TextSearchFlags.CASE_INSENSITIVE
                | Gtk.TextSearchFlags.TEXT_ONLY
                | Gtk.TextSearchFlags.VISIBLE_ONLY,
            out match_start,
            out match_end,
            null
        )) {
            matches.append (TextBounds (match_start, match_end));
            search_cursor = match_end;
        }

        return matches.into_array ();
    }
}
