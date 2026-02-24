struct Spedread.IterHistory {
    Gtk.TextIter[] _stack;
    int _true_size;

    const int BASE_CAPACITY = 32;

    public IterHistory () {
        _stack = new Gtk.TextIter[BASE_CAPACITY];
        _true_size = 0;
    }

    /** Add an iterator to the end of the history */
    public void push (Gtk.TextIter iter) {
        if (unlikely (_stack.length == _true_size)) {
            _stack.resize (int.max (_stack.length * 2, 4));
        }

        _stack[_true_size++] = iter;
    }

    /** Remove the last iterator added to the history and return it */
    public Gtk.TextIter pop ()
        requires (!is_empty ())
    {
        return _stack[--_true_size];
    }

    /** Get last text iterator added to the history */
    public Gtk.TextIter last ()
        requires (!is_empty ())
    {
        return _stack[_true_size - 1];
    }

    /** Delete the whole history, making it empty and family-friendly */
    public void erase () {
        _true_size = 0;
    }

    /** Is the history empty? */
    public bool is_empty () {
        return _true_size == 0;
    }
}
