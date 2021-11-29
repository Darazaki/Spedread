class SpedreadTextTab : Gtk.ScrolledWindow {
    public Gtk.TextView input;

    Gtk.TextTag _current_word_tag;

    public SpedreadTextTab () {
        input = new Gtk.TextView () {
            wrap_mode = Gtk.WrapMode.WORD,
            bottom_margin = 12,
            top_margin = 12,
            right_margin = 12,
            left_margin = 12
        };

        Object (
            child = input
        );

        _current_word_tag = new Gtk.TextTag (null) {
            background = "purple",
            background_set = true,
            foreground = "white",
            foreground_set = true
        };
        input.buffer.tag_table.add (_current_word_tag);
    }

    public void highlight_current_word (Gtk.TextIter start, Gtk.TextIter end) {
        var buffer = input.buffer;
        Gtk.TextIter absolute_start, absolute_end;
        buffer.get_start_iter (out absolute_start);
        buffer.get_end_iter (out absolute_end);

        buffer.remove_all_tags (absolute_start, absolute_end);
        buffer.apply_tag (_current_word_tag, start, end);
    }
}
