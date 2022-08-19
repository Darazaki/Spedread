struct SpedreadIterHistory {
    Gtk.TextIter[] _stack;

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

    public void push (Gtk.TextIter iter) {
        var length = _stack.length;
        _stack.resize (length + 1);
        _stack[length] = iter;
    }

    public Gtk.TextIter pop () {
        if (_stack.length == 0) {
            log (null, LogLevelFlags.FLAG_FATAL, "Tried to remove entry from empty history");
        }

        var new_length = _stack.length - 1;
        var removed = _stack[new_length];
        _stack.resize (new_length);

        return removed;
    }

    public void erase () {
        _stack.resize (0);
    }

    public bool is_empty () {
        return _stack.length == 0;
    }
}
