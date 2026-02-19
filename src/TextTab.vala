class Spedread.TextTab : Gtk.Box {
    /** Contains the text the user wants to read */
    public Gtk.TextView input;
    public SearchBar search_bar;

    const string BIGGER_TEXT_TAG_NAME = "bigger-text";
    const int TEXT_SIZE = 12;

    TagManager _tag_manager;

    public class TagManager {
        public Gtk.TextTag next_word;
        public Gtk.TextTag needle;
        public Gtk.TextTag selected_needle;

        public TagManager (Gtk.TextBuffer buffer) {
            selected_needle = add_bg_fg_tag (buffer, "selected-needle", "orange", "black");
            next_word = add_bg_fg_tag (buffer, "next-word", "purple", "white");
            needle = add_bg_fg_tag (buffer, "needle", "yellow", "black");

            selected_needle.set_priority (2);
            next_word.set_priority (0);
            needle.set_priority (1);
        }

        static Gtk.TextTag add_bg_fg_tag (
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
            spacing: 12
        );

        input = new Gtk.TextView () {
            wrap_mode = Gtk.WrapMode.WORD,
            bottom_margin = 12,
            top_margin = 12,
            right_margin = 12,
            left_margin = 12
        };
        var buffer = input.buffer;

        _tag_manager = new TagManager (buffer);

        var scrolled = new Gtk.ScrolledWindow () {
            child = input,
            hexpand = true,
            vexpand = true
        };

        search_bar = new SearchBar (input, _tag_manager) {
            visible = false,
        };

        append (scrolled);
        append (search_bar);

        var bigger_text = buffer.create_tag (BIGGER_TEXT_TAG_NAME, "size", TEXT_SIZE * Pango.SCALE);
        buffer.changed.connect (buffer => {
            // Reapply the tag to make sure that it covers the whole text
            var bounds = TextBounds.of (buffer);
            bounds.remove_tag (bigger_text);
            bounds.apply_tag (bigger_text);
        });
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
