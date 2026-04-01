class Spedread.PivotLabel : Gtk.Widget {
    string _text = "";
    Pango.FontDescription _font_desc;

    bool _previous_was_rtl = false;

    double _pivot_distance = 0.5;
    double _pivot_x = 80.0;
    bool _pivot_enabled = true;

    /** Layout rebuilt whenever any metric-affecting property changes */
    Pango.Layout? _layout = null;

    /** UTF-8 byte index of the pivot grapheme cluster's first byte */
    int _pivot_byte_start = 0;
    /** UTF-8 byte index one past the last byte of the pivot cluster */
    int _pivot_byte_end = 0;
    /** Leading-edge x of the pivot cluster, in Pango units auto-ajusted by
        `PANGO_SCALE` */
    int _pivot_pango_x = 0;

    static construct {
        set_css_name ("spedread-pivot-label");
    }

    /** Text shown by the label */
    public string text {
        get { return _text; }
        set { _text = value; invalidate (); }
    }

    /** The label's font */
    public Pango.FontDescription font_desc {
        get { return _font_desc; }
        set { _font_desc = value; invalidate (); }
    }

    /** Target distance from the beginning of the string (default: 0.5 em) */
    public double pivot_distance {
        get { return _pivot_distance; }
        set {
            _pivot_distance = value.clamp (0.0, double.MAX);
            invalidate ();
        }
    }

    /** X offset from the left edge at which the pivot will be anchored
        (default: 80.0 px) */
    public double pivot_x {
        get { return _pivot_x; }
        set { _pivot_x = value; queue_draw (); }
    }

    /** Whether the label should have a pivot behavior or not */
    public bool pivot_enabled {
        get { return _pivot_enabled; }
        set { _pivot_enabled = value; invalidate (); }
    }

    public PivotLabel () {
        Object ();
        _font_desc = Pango.FontDescription.from_string ("Sans 12");
    }

    /** Reassign `_layout` and force a complete redraw */
    void rebuild_layout () {
        _layout = new Pango.Layout (get_pango_context ());
        _layout.set_text (_text, -1);
        _layout.set_font_description (_font_desc);
        _layout.set_width (-1);
        _layout.set_single_paragraph_mode (true);

        if (_pivot_enabled) compute_pivot ();
        queue_draw ();
        queue_resize ();
    }

    /** Return device px per em unit for current font (if possible) */
    int font_em_pango () {
        if (_layout == null)
            return (int) (12.0 * Pango.SCALE);

        var metrics = _layout.get_context ().get_metrics (_font_desc, null);
        var em = metrics.get_ascent () + metrics.get_descent ();
        return (em > 0) ? em : (int) (12.0 * Pango.SCALE);
    }

    /** Compute pivot by selecting the cluster whose leading-edge is closest to
        the expected pivot distance or the last cluster on overshoot */
    void compute_pivot () {
        _pivot_byte_start = 0;
        _pivot_byte_end = 0;
        _pivot_pango_x = 0;

        if (_layout == null || _text.length == 0)
            return;

        // Target in Pango units
        var target_pango = (int) (_pivot_distance * (double) font_em_pango ());

        Pango.LogAttr[] attrs;
        _layout.get_log_attrs (out attrs);

        // Includes Pango sentinel
        var n_attrs = attrs.length;

        var best_byte_start = 0;
        var best_pango_x = 0;
        var best_dist = double.MAX;

        var byte_offset = 0;

        var is_rtl = is_text_rtl ();

        int total_width, dummy_h;
        _layout.get_size (out total_width, out dummy_h);

        for (var ci = 0; ci < n_attrs; ci++) {
            var attr = attrs[ci];
            // Make sure we're at a grapheme boundary and it isn't a whitespace
            if (attr.is_cursor_position != 0 && attr.is_white == 0) {
                Pango.Rectangle strong, weak;
                _layout.get_cursor_pos (byte_offset, out strong, out weak);

                double d;
                if (is_rtl) {
                    var dist_from_right = total_width - (strong.x + strong.width);
                    d = ((double) dist_from_right - (double) target_pango).abs ();
                } else {
                    d = ((double) strong.x - (double) target_pango).abs ();
                }

                if (d < best_dist) {
                    best_dist = d;
                    best_byte_start = byte_offset;
                    best_pango_x = strong.x;
                }

                if (is_rtl) {
                    // Once the cluster x has passed the target we can stop
                    // X is monotonically non-ascending so no later cluster is closer
                    if (total_width - (strong.x + strong.width) > target_pango)
                        break;
                } else {
                    // Once the cluster x has passed the target we can stop
                    // X is monotonically non-decreasing so no later cluster is closer
                    if (strong.x > target_pango)
                        break;
                }
            }

            // Increment `byte_offset` by one Unicode scalar value
            if (ci < n_attrs - 1 && byte_offset < _text.length) {
                var ch = _text.get_char (byte_offset);
                byte_offset += ch.to_utf8 (null);
            }
        }

        // On pivot overshoot: use last non-whitespace grapheme cluster
        if (best_byte_start >= _text.length) {
            best_byte_start = 0;
            best_pango_x = 0;
            var scan_byte = 0;
            for (var ci = 0; ci < n_attrs - 1; ci++) {
                var attr = attrs[ci];
                if (attr.is_cursor_position != 0 && attr.is_white == 0) {
                    Pango.Rectangle sp, wp;
                    _layout.get_cursor_pos (scan_byte, out sp, out wp);
                    best_byte_start = scan_byte;
                    best_pango_x = sp.x;
                }
                if (scan_byte < _text.length) {
                    var ch = _text.get_char (scan_byte);
                    scan_byte += ch.to_utf8 (null);
                }
            }
        }

        _pivot_byte_start = best_byte_start;
        _pivot_pango_x = best_pango_x;
        _pivot_byte_end = next_cluster_byte (best_byte_start, attrs, n_attrs);
    }

    /** Return the byte offset of the cluster that follows the one starting at
        `start_byte`, or `_text.length` if that was the last cluster */
    int next_cluster_byte (
        int start_byte,
        Pango.LogAttr[] attrs,
        int n_attrs
    ) {
        var byte_offset = 0;
        var passed_start = false;

        for (var ci = 0; ci < n_attrs; ci++) {
            if (passed_start && attrs[ci].is_cursor_position != 0)
                return byte_offset;
            if (byte_offset == start_byte)
                passed_start = true;
            if (ci < n_attrs - 1 && byte_offset < _text.length) {
                var ch = _text.get_char (byte_offset);
                byte_offset += ch.to_utf8 (null);
            }
        }
        return _text.length;
    }

    /** Set previous direction and return if text seems to be RTL */
    bool is_text_rtl () {
        // For some reason, using the layout-detected direction leads to
        // incorrect detection in some edge cases so we ask Pango to
        // recalculate it here
        var text_direction = Pango.find_base_dir (_text, -1);
        var previous_direction_was_rtl = _previous_was_rtl;
        var text_direction_seems_rtl =
            text_direction == Pango.Direction.WEAK_RTL ||
            text_direction == Pango.Direction.RTL;

        // Set previous value if we get a conclusive text direction
        if (text_direction != Pango.Direction.NEUTRAL)
            _previous_was_rtl = text_direction_seems_rtl;

        return text_direction == Pango.Direction.NEUTRAL
            ? previous_direction_was_rtl
            : text_direction_seems_rtl;
    }

    /** Map [0.0f, 1.0f] color components to [0, 65535] */
    static uint16 map_f2i (float x) {
        return (uint16) (x * (float) uint16.MAX);
    }

    public override void measure (
        Gtk.Orientation orientation,
        int for_size,
        out int minimum,
        out int natural,
        out int minimum_baseline,
        out int natural_baseline
    ) {
        ensure_layout ();
        minimum_baseline = -1;
        natural_baseline = -1;

        int pw, ph;
        _layout.get_size (out pw, out ph);
        var pix_w = (int) Math.ceil ((double) pw / Pango.SCALE);
        var pix_h = (int) Math.ceil ((double) ph / Pango.SCALE);

        if (orientation == Gtk.Orientation.HORIZONTAL) {
            if (_pivot_enabled) {
                var pivot_px = (int) Math.ceil ((double) _pivot_pango_x / Pango.SCALE);
                var right_rem = pix_w - pivot_px;
                minimum = natural = (int) _pivot_x + right_rem;
            } else {
                minimum = natural = pix_w;
            }
        } else {
            minimum = natural = pix_h;
        }
    }

    public override void snapshot (Gtk.Snapshot snapshot) {
        ensure_layout ();

        int pw_int, ph_int;
        _layout.get_size (out pw_int, out ph_int);

        var alloc_w = (double) get_width ();
        var alloc_h = (double) get_height ();
        var pw = (double) pw_int;
        var ph = (double) ph_int;

        var y_off = (float) ((alloc_h - ph / Pango.SCALE) / 2.0);

        if (!_pivot_enabled) {
            // Plain centred label: no attributes, horizontally centred
            _layout.set_attributes (null);
            float x_off = (float) ((alloc_w - pw / Pango.SCALE) / 2.0);
            var pt = Graphene.Point ();
            pt.x = x_off;
            pt.y = y_off;
            snapshot.save ();
            snapshot.translate (pt);
#if GTK_4_10
            var base_color = get_color ();
#else
            var base_color = get_style_context ().get_color ();
#endif
            snapshot.append_layout (_layout, base_color);
            snapshot.restore ();
            return;
        }

        assert (_pivot_enabled);

        // Try to guess expected text direction based on current and previous
        // values

        var is_rtl = is_text_rtl ();

        float x_off;
        if (is_rtl) {
            // Pivot leading edge lands at `_pivot_x` from the widget's right edge
            Pango.Rectangle trail_strong, trail_weak;
            _layout.get_cursor_pos (_pivot_byte_start, out trail_strong, out trail_weak);
            var trail_px = (double) trail_strong.x / Pango.SCALE;
            x_off = (float) (alloc_w - _pivot_x - trail_px);
        } else {
            // Pivot leading edge lands at `_pivot_x` from the widget's left edge
            x_off = (float) (_pivot_x - (double) _pivot_pango_x / Pango.SCALE);
        }

        // Read CSS foreground colour
#if GTK_4_10
        var fg = get_color ();
#else
        var fg = get_style_context ().get_color ();
#endif

        var attr_list = new Pango.AttrList ();

        // Before pivot
        if (_pivot_byte_start > 0) {
            var foreground = Pango.attr_foreground_new (
                map_f2i (fg.red),
                map_f2i (fg.green),
                map_f2i (fg.blue)
            );
            foreground.start_index = 0;
            foreground.end_index = _pivot_byte_start;
            attr_list.insert ((owned) foreground);
        }

        // Make pivot red
        {
            var foreground = Pango.attr_foreground_new (uint16.MAX, 0, 0);
            foreground.start_index = _pivot_byte_start;
            foreground.end_index = _pivot_byte_end;
            attr_list.insert ((owned) foreground);
        }

        // After pivot
        if (_pivot_byte_end < _text.length) {
            var foreground = Pango.attr_foreground_new (
                map_f2i (fg.red),
                map_f2i (fg.green),
                map_f2i (fg.blue)
            );
            foreground.start_index = _pivot_byte_end;
            foreground.end_index = _text.length;
            attr_list.insert ((owned) foreground);
        }

        _layout.set_attributes (attr_list);

        var pt = Graphene.Point ();
        pt.x = x_off;
        pt.y = y_off;

        snapshot.save ();
        snapshot.translate (pt);
        // White base color preserves the Pango attribute foreground values
        var white = Gdk.RGBA () { red = green = blue = alpha = 1.0f };
        snapshot.append_layout (_layout, white);
        snapshot.restore ();
    }

    void ensure_layout ()
        ensures (_layout != null)
    {
        if (_layout == null)
            rebuild_layout ();
    }

    void invalidate () {
        _layout = null;
        queue_resize ();
        queue_draw ();
    }
}
