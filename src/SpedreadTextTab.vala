class SpedreadTextTab : Gtk.Grid {
    /** Contains the text the user wants to read */
    public Gtk.TextView input;

    const string BIGGER_TEXT_TAG_NAME = "bigger-text";
    const string HIGHLIGHT_TAG_NAME = "highlight";
    const int TEXT_SIZE = 12;
    
    Gtk.TextTag _current_word_tag;
    
    public SpedreadTextTab () {
        Object (
            hexpand: true,
            vexpand: true
        );
        
        input = new Gtk.TextView () {
            wrap_mode = Gtk.WrapMode.WORD,
            bottom_margin = 12,
            top_margin = 12,
            right_margin = 12,
            left_margin = 12
        };

        var scrolled = new Gtk.ScrolledWindow () {
            child = input,
            hexpand = true,
            vexpand = true
        };
        
        attach (scrolled, 0, 0, 1, 1);

        var bigger_text = new Gtk.TextTag (BIGGER_TEXT_TAG_NAME) {
            size = TEXT_SIZE * Pango.SCALE
        };

        _current_word_tag = new Gtk.TextTag (HIGHLIGHT_TAG_NAME) {
            background = "purple",
            background_set = true,
            foreground = "white",
            foreground_set = true
        };

        var buffer = input.buffer;
        buffer.tag_table.add (_current_word_tag);
        buffer.tag_table.add (bigger_text);

        buffer.changed.connect (buffer => {
            // Reapply the tag to make sure that it covers the whole text
            Gtk.TextIter start, end;
            buffer.get_start_iter (out start);
            buffer.get_end_iter (out end);
            buffer.remove_tag_by_name (BIGGER_TEXT_TAG_NAME, start, end);
            buffer.apply_tag (bigger_text, start, end);
        });
    }

    /** Highlight the text between `start` and `end`, removing any other
        highlight */
    public void highlight_current_word (Gtk.TextIter start, Gtk.TextIter end) {
        var buffer = input.buffer;
        Gtk.TextIter absolute_start, absolute_end;
        buffer.get_start_iter (out absolute_start);
        buffer.get_end_iter (out absolute_end);

        buffer.remove_tag_by_name (HIGHLIGHT_TAG_NAME,
            absolute_start, absolute_end
        );
        buffer.apply_tag (_current_word_tag, start, end);
    }

    /** Scroll the text so that the `position` is as close to the center as
        possible */
    public void scroll_to_position (Gtk.TextIter position) {
        input.scroll_to_iter (position, 0, true, 0, 0.5);
    }
}
