public class Spedread.TextBoundsList {
    TextBounds[]? _items;
    int _true_length;

    const int BASE_CAPACITY = 32;

    public TextBoundsList () {
        _items = new TextBounds[BASE_CAPACITY];
        _true_length = 0;
    }

    /** Push item to the end of the list */
    public void append (TextBounds item)
        requires (_items != null)
    {
        if (unlikely (_items.length == _true_length)) {
            _items.resize (int.max (_items.length * 2, 4));
        }

        _items[_true_length++] = item;
    }

    /** Convert list into a native array, invalidating itself and shriking
        memory usage */
    public TextBounds[] into_array ()
        requires (_items != null)
        ensures (_items == null)
    {
        var items = _items;

        // Create invalid state
        _items = null;

        items.resize (_true_length);
        return items;
    }
}
