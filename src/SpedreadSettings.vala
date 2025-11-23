public abstract class SpedreadSettings {
    public static Settings settings = null;
    public static bool is_using_libadwaita;
    public static uint words_at_a_time;

    /** Get the application's global settings */
    public static void init () {
        settings = new Settings ("com.github.Darazaki.Spedread");
        is_using_libadwaita = settings.get_boolean ("use-libadwaita");
        words_at_a_time = settings.get_uint("words-at-a-time");
    }
}
