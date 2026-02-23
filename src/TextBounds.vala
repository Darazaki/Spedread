public struct Spedread.TextBounds {
    public Gtk.TextIter start;
    public Gtk.TextIter end;

    public TextBounds (Gtk.TextIter start_, Gtk.TextIter end_)
        requires (start_.get_buffer () == end_.get_buffer ())
    {
        start = start_;
        end = end_;
    }

    /** Get bounds of selected text within `buffer` (invalid if none) */
    public TextBounds.selection_of (Gtk.TextBuffer buffer)
        requires (buffer.has_selection)
    {
        buffer.get_selection_bounds (out start, out end);
    }

    /** Get bounds from start of `buffer` to end of `buffer` */
    public TextBounds.of (Gtk.TextBuffer buffer) {
        buffer.get_bounds (out start, out end);
    }

    /** Get text contained between bounds */
    public string get_text () { return start.get_text (end); }

    /** Get buffer associated with both bounds */
    public Gtk.TextBuffer get_buffer () { return start.get_buffer (); }

    /** Apply `tag` between bounds */
    public void apply_tag (Gtk.TextTag tag) {
        get_buffer ().apply_tag (tag, start, end);
    }

    /** Remove all instances of `tag` between bounds */
    public void remove_tag (Gtk.TextTag tag) {
        get_buffer ().remove_tag (tag, start, end);
    }

    /** Check if bounds at the same position of the same buffer */
    public bool equal (TextBounds rhs) {
        return start.equal (rhs.start) && end.equal (rhs.end);
    }
}
