public abstract class SpedreadSettings {
    public static Settings settings = null;
    public static bool is_using_libadwaita;

    /** Get the application's global settings */
    public static void init () {
        settings = new Settings ("com.github.Darazaki.Spedread");
        is_using_libadwaita = settings.get_boolean ("use-libadwaita");
    }
}
