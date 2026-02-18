public struct SpedreadDictionary {
    public SpedreadDictionary* left;
    public SpedreadDictionary* right;
    public uint8 value;

    public SpedreadDictionary (uint8 v) {
        left = null;
        right = null;
        value = v;
    }

    public static SpedreadDictionary * build_example_dictionary () {
        var dict = (SpedreadDictionary*) g_realloc (null, sizeof (SpedreadDictionary));
        *dict = SpedreadDictionary (0);

        // TODO: Finish building example dictionary

        return dict;
    }

    public static bool contains (SpedreadDictionary* node, string word) {
        return is_end_of_entry (find_prefix (node, word));
    }

    public static bool is_end_of_entry (SpedreadDictionary* node) {
        if (node == null) {
            return false;
        }

        if (node->left == null && node->right == null) {
            return true;
        }

        // TODO: Finish implementing `SpedreadDictionary.find_prefix_inner`
        return false;
    }

    public static SpedreadDictionary * find_prefix (SpedreadDictionary* node, string prefix) {
        return find_prefix_inner (node, prefix, 0);
    }

    static SpedreadDictionary * find_prefix_inner (SpedreadDictionary* node, string prefix, int index) {
        if (node == null) {
            return null;
        }

        var dict = *node;

        if (dict.value == 0) {
            var node_a = find_prefix_inner (dict.left, prefix, index);
            if (node_a != null) {
                return node_a;
            } else {
                return find_prefix_inner (dict.right, prefix, index);
            }
        }

        // TODO: Finish implementing `SpedreadDictionary.find_prefix_inner`
        return null;
    }
}
