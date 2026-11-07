class Spedread.WordIndex {
    const int BASE_CAPACITY = 256;

    int[] _starts = new int[BASE_CAPACITY];
    int[] _ends = new int[BASE_CAPACITY];
    int _size = 0;
    bool _valid = false;

    /** Text split into characters, used for the custom number/acronym rules */
    unichar[] _chars = new unichar[0];

    /** Pango's word boundary information for the whole text */
    Pango.LogAttr[] _attrs = new Pango.LogAttr[0];

    /** Character offset where each line starts, plus the end of the text */
    int[] _line_starts = new int[0];

    int _char_count = 0;

    /** Whether the index matches the current buffer contents */
    public bool is_valid {
        get { return _valid; }
    }

    /** Whether the index contains no words */
    public bool is_empty {
        get { return _size == 0; }
    }

    /** Number of words (or groups of words) in the index */
    public int length {
        get { return _size; }
    }

    /** Character offset where the word at `index` starts */
    public int start (int index) {
        return _starts[index];
    }

    /** Character offset where the word at `index` ends, including trailing
        punctuation but excluding trailing whitespace */
    public int end (int index) {
        return _ends[index];
    }

    /** Mark the index as outdated */
    public void invalidate () {
        _valid = false;
        _size = 0;
        _char_count = 0;
        _chars = new unichar[0];
        _attrs = new Pango.LogAttr[0];
        _line_starts = new int[0];
    }

    /** Rebuild the index from the whole buffer */
    public void rebuild (Gtk.TextBuffer buffer, int words_at_a_time) {
        _size = 0;
        _valid = false;

        Gtk.TextIter start, end;
        buffer.get_bounds (out start, out end);

        var text = buffer.get_text (start, end, true);
        _char_count = text.char_count ();

        _chars = new unichar[_char_count];
        var byte_index = 0;
        var char_index = 0;
        while (char_index < _char_count) {
            unichar current_char;

            if (!text.get_next_char (ref byte_index, out current_char)) {
                break;
            }

            _chars[char_index++] = current_char;
        }

        if (char_index < _char_count) {
            _char_count = char_index;
        }

        // Pango provides the same word boundaries GTK uses internally. Doing
        // this once for the whole text avoids an expensive `Gtk.TextIter`
        // lookup for every word
        Gtk.TextIter begin;
        buffer.get_start_iter (out begin);
        _attrs = new Pango.LogAttr[_char_count + 1];
        Pango.get_log_attrs (text, -1, -1, begin.get_language (), _attrs);

        // Cache where each line starts so word detection can cross lines
        // without asking GTK for an offset every time
        _line_starts = new int[1] { 0 };
        for (var i = 0; i < _char_count; i++) {
            if (_chars[i] == (unichar) '\n') {
                _line_starts += i + 1;
            }
        }
        _line_starts += _char_count;

        var cursor = 0;

        for ( ;; ) {
            while (cursor < _char_count && _chars[cursor].isspace ()) {
                cursor++;
            }

            if (cursor >= _char_count) {
                break;
            }

            var start_char = cursor;
            cursor = forward_word_ends (cursor, words_at_a_time);
            var end_of_word = skip_trailing (ref cursor);

            if (cursor == start_char && end_of_word == start_char) {
                // No word boundary was found: make sure we always make progress
                cursor++;
                end_of_word = cursor;
            }

            if (is_number_between (start_char, cursor)) {
                end_of_word = extend_word (start_char, ref cursor, true);
            } else if (is_acronym_between (start_char, cursor)) {
                end_of_word = extend_word (start_char, ref cursor, false);
            }

            append (start_char, end_of_word);
        }

        _valid = true;
    }

    /** Find the line containing `pos`, using the cached line starts */
    int line_of (int pos) {
        var low = 0;
        var high = _line_starts.length - 1;

        while (low + 1 < high) {
            var middle = (low + high) / 2;

            if (_line_starts[middle] <= pos) {
                low = middle;
            } else {
                high = middle;
            }
        }

        return low;
    }

    /** Move to the next word end, crossing lines like
        `Gtk.TextIter.forward_word_end` does */
    int forward_word_end (int pos) {
        var already_moved_initially = false;
        var current = pos;

        for ( ;; ) {
            var line = line_of (current);
            var line_start = _line_starts[line];
            var line_end = _line_starts[line + 1];
            var char_len = line_end - line_start;
            var offset = current - line_start;

            if (!already_moved_initially) {
                offset++;
            }

            while (offset <= char_len) {
                var global_offset = line_start + offset;

                if (global_offset <= _char_count
                    && _attrs[global_offset].is_word_end != 0) {
                    return global_offset;
                }

                offset++;
            }

            if (line + 1 >= _line_starts.length - 1) {
                return pos;
            }

            current = line_end;
            already_moved_initially = true;
        }
    }

    /** Move forward by up to `count` word ends */
    int forward_word_ends (int pos, int count) {
        for (var i = 0; i < count; i++) {
            var next = forward_word_end (pos);

            if (next == pos) {
                break;
            }

            pos = next;
        }

        return pos;
    }

    /** Skip punctuation and whitespace until the end of the line or the next
        word. Return the position after the last punctuation mark, which is the
        end of the word to highlight */
    int skip_trailing (ref int cursor) {
        var end_of_word = cursor;

        for ( ;; ) {
            if (cursor >= _char_count) {
                break;
            }

            var current_char = _chars[cursor];

            if (current_char == (unichar) '\n') {
                break;
            } else if (current_char.ispunct ()) {
                cursor++;
                end_of_word = cursor;
            } else if (current_char.isspace ()) {
                cursor++;
            } else {
                break;
            }
        }

        return end_of_word;
    }

    /** Extend a number or acronym by one word as long as it still looks like a
        number or acronym */
    int extend_word (int start_char, ref int cursor, bool is_number) {
        var last_accepted = cursor;

        for ( ;; ) {
            var candidate = forward_word_end (last_accepted);

            if (candidate == last_accepted) {
                return skip_trailing (ref cursor);
            }

            var matches = is_number
                ? is_number_between (start_char, candidate)
                : is_acronym_between (start_char, candidate);

            if (matches) {
                last_accepted = candidate;
                cursor = last_accepted;
            } else {
                return skip_trailing (ref cursor);
            }
        }
    }

    /** Check if whatever is contained in the index between the two offsets
        looks like a number */
    bool is_number_between (int start_char, int end_char) {
        var separator_found = false;
        var found_digit = false;

        for (var i = start_char; i < end_char; i++) {
            var current_char = _chars[i];

            if (current_char.isdigit ()) {
                found_digit = true;
                separator_found = false;
            } else if (current_char.isspace ()
                || current_char == '.' || current_char == ',') {
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

    /** Check if whatever is contained in the index between the two offsets
        looks like an acronym */
    bool is_acronym_between (int start_char, int end_char) {
        var expects_alpha_next = true;

        for (var i = start_char; i < end_char; i++) {
            var current_char = _chars[i];

            if (expects_alpha_next && current_char.isalpha ()) {
                expects_alpha_next = false;
            } else if (!expects_alpha_next && current_char == '.') {
                expects_alpha_next = true;
            } else {
                return false;
            }
        }

        return true;
    }

    /** Add a word to the index, growing the arrays if needed */
    void append (int start, int end) {
        if (_size == _starts.length) {
            var new_capacity = int.max (_starts.length * 2, 4);
            _starts.resize (new_capacity);
            _ends.resize (new_capacity);
        }

        _starts[_size] = start;
        _ends[_size] = end;
        _size++;
    }
}
