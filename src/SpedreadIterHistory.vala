struct SpedreadIterHistory {
    Gtk.TextIter[] _stack;

    /** Last text iterator added to the history */
    public Gtk.TextIter last {
        get {
            if (_stack.length == 0) {
                log (null, LogLevelFlags.FLAG_FATAL, "Tried to access last element of empty history");
            }

            return _stack[_stack.length - 1];
        }
    }

    public SpedreadIterHistory () {
        _stack = new Gtk.TextIter[] {};
    }

    /** Add an iterator to the end of the history */
    public void push (Gtk.TextIter iter) {
        var length = _stack.length;
        _stack.resize (length + 1);
        _stack[length] = iter;
    }

    /** Remove the last iterator added to the history and return it */
    public Gtk.TextIter pop () {
        if (_stack.length == 0) {
            log (null, LogLevelFlags.FLAG_FATAL, "Tried to remove entry from empty history");
        }

        var new_length = _stack.length - 1;
        var removed = _stack[new_length];
        _stack.resize (new_length);

        return removed;
    }

    /** Delete the whole history, making it empty and family-friendly */
    public void erase () {
        _stack.resize (0);
    }

    /** Is the history empty? */
    public bool is_empty () {
        return _stack.length == 0;
    }
}
