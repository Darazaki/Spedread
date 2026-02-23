class Spedread.TextTab : Gtk.Box {
    /** Contains the text the user wants to read */
    public Gtk.TextView input;
    public SearchBar search_bar;

    const string BIGGER_TEXT_TAG_NAME = "bigger-text";
    const int TEXT_SIZE = 12;

    TagManager _tag_manager;

    /** Manages tags that are applied to portions the main text view */
    public class TagManager {
        public Gtk.TextTag next_word;
        public Gtk.TextTag needle;
        public Gtk.TextTag selected_needle;

        public TagManager (Gtk.TextBuffer buffer) {
            // Priority order is in reversed definition order
            next_word = new_tag (buffer, "next-word", "purple", "white");
            needle = new_tag (buffer, "needle", "yellow", "black");
            selected_needle = new_tag (buffer, "selected-needle", "orange", "black");
        }

        /** Add tag to highlight text to the buffer */
        static Gtk.TextTag new_tag (
            Gtk.TextBuffer buffer,
            string tag_name,
            string background,
            string foreground
        ) {
            var tag = buffer.create_tag (tag_name);
            tag.background = background;
            tag.background_set = true;
            tag.foreground = foreground;
            tag.foreground_set = true;
            return tag;
        }
    }

    public TextTab () {
        Object (
            orientation: Gtk.Orientation.VERTICAL,
            hexpand: true,
            vexpand: true,
            spacing: App.MARGIN
        );

        input = new Gtk.TextView () {
            wrap_mode = Gtk.WrapMode.WORD,
            bottom_margin = App.MARGIN,
            top_margin = App.MARGIN,
            right_margin = App.MARGIN,
            left_margin = App.MARGIN,
        };

        var buffer = input.buffer;
        _tag_manager = new TagManager (buffer);

        var scrolled = new Gtk.ScrolledWindow () {
            child = input,
            hexpand = true,
            vexpand = true,
        };

        search_bar = new SearchBar (input, _tag_manager) {
            visible = false,
        };

        var bigger_text = buffer.create_tag (BIGGER_TEXT_TAG_NAME, "size", TEXT_SIZE * Pango.SCALE);
        buffer.changed.connect (buffer => {
            // Reapply the tag to make sure that it covers the whole text
            var bounds = TextBounds.of (buffer);
            bounds.remove_tag (bigger_text);
            bounds.apply_tag (bigger_text);
        });

        append (scrolled);
        append (search_bar);
    }

    /** Highlight the text between `bounds`, removing any other highlight */
    public void highlight_current_word (TextBounds bounds) {
        var buffer = input.buffer;
        var absolute_bounds = TextBounds.of (buffer);
        var tag = _tag_manager.next_word;
        absolute_bounds.remove_tag (tag);
        bounds.apply_tag (tag);
    }

    /** Scroll the text so that the `position` is as close to the center as
        possible */
    public void scroll_to_position (Gtk.TextIter position) {
        input.scroll_to_iter (position, 0, true, 0, 0.5);
    }
}
