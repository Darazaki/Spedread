
#include "spedread-config.h"
#include "spedread-window.h"

/* SPEDREAD_UNUSED
 *
 * Based on: https://stackoverflow.com/a/3418029 and
 * https://stackoverflow.com/a/9602511
 * This should really be part of Glib or standard C... Feel free to reuse */
#if defined(__GNUC__) /* GCC */
#  define SPEDREAD_UNUSED __attribute__((unused))
#elif defined(__LCLINT__) /* Clang */
#  define SPEDREAD_UNUSED /*@unused@*/
#elif defined(_MSC_VER) /* MSVC */
#  define SPEDREAD_UNUSED __pragma(warning(suppress:4100))
#else
#  define SPEDREAD_UNUSED
#endif

struct _SpedreadWindow
{
  GtkApplicationWindow  parent_instance;

  /* Template widgets */
  GtkToggleButton     *reading;
  GtkMenuButton       *main_popover_opener;
  GtkSpinButton       *milliseconds_per_word;
  GtkTextView         *input;
  GtkStack            *stack;
  GtkLabel            *word;

  /* Other properties */
  GtkTextIter input_iter;
  GSettings   *settings;
  guint       timeout_id;
};

G_DEFINE_TYPE (SpedreadWindow, spedread_window, GTK_TYPE_APPLICATION_WINDOW)

static void
spedread_window_stop_reading (SpedreadWindow *self);

static void
spedread_window_remove_timeout (SpedreadWindow *self)
{
  if (self->timeout_id) {
    g_source_remove (self->timeout_id);
    self->timeout_id = 0;
  }
}

static void
spedread_window_skip_trailing_characters (GtkTextIter *iter)
{
  for (;;) {
      gunichar current_char = gtk_text_iter_get_char (iter);

      if (current_char == (gunichar)'\n')
        break;
      else if (g_unichar_isspace (current_char) || g_unichar_ispunct (current_char)) {
        gtk_text_iter_forward_char (iter);
      } else
        break;
    }
}

static void
spedread_window_skip_whitespaces (GtkTextIter *iter)
{
  for (;;) {
    gunichar current_char = gtk_text_iter_get_char (iter);

    if (g_unichar_isspace (current_char))
      gtk_text_iter_forward_char (iter);
    else
      break;
  }
}

static void
spedread_window_next_word (GtkTextIter *iter)
{
  gtk_text_iter_forward_word_end (iter);
  spedread_window_skip_trailing_characters (iter);
}

static void
spedread_window_dispose (GObject *maybe_self)
{
  SpedreadWindow *self = SPEDREAD_WINDOW (maybe_self);

  spedread_window_remove_timeout (self);
  //g_free (self->settings);

  /* Fails G_TYPE_CHECK_INSTANCE assertion: self->stack is NULL?! */
  /* g_signal_handler_disconnect (self->stack, self->stack_changed_id); */

  G_OBJECT_CLASS (spedread_window_parent_class)->dispose (maybe_self);
}

static void
spedread_window_view_switched (SPEDREAD_UNUSED void *junk0,
                               SPEDREAD_UNUSED void *junk1,
                               SpedreadWindow       *self)
{
  g_assert (SPEDREAD_IS_WINDOW (self));

  GtkWidget *current_view = gtk_stack_get_visible_child (self->stack);
  GtkWidget *input_view = gtk_widget_get_parent (GTK_WIDGET (self->input));

  if (current_view == input_view) {
    /* "Text" view: focus on the text view */
    spedread_window_stop_reading (self);
    gtk_widget_grab_focus (current_view);
  } else {
    /* "Read" view: focus on the play/pause button */
    gtk_widget_grab_focus (GTK_WIDGET (self->reading));
  }
}

static void
spedread_window_text_changed (SPEDREAD_UNUSED void *junk,
                              SpedreadWindow       *self)
{
  g_assert (SPEDREAD_IS_WINDOW (self));

  GtkTextBuffer *buffer = gtk_text_view_get_buffer (self->input);
  GtkTextIter iter, next_iter;

  gtk_text_buffer_get_start_iter (buffer, &iter);
  spedread_window_skip_whitespaces (&iter);
  next_iter = iter;

  if (gtk_text_iter_is_end (&iter)) {
    gtk_label_set_text (self->word, "Go to \"Text\" and paste your read!");
  } else {
    spedread_window_next_word (&next_iter);
    gchar *word = gtk_text_buffer_get_text (buffer, &iter, &next_iter, TRUE);
    gtk_label_set_text (self->word, word);
    g_free (word);
  }

  self->input_iter = next_iter;
}

static void
spedread_window_main_popover_shown (SPEDREAD_UNUSED void *junk,
                                    SpedreadWindow       *self)
{
  g_assert (SPEDREAD_IS_WINDOW (self));

  spedread_window_stop_reading (self);
}

static void
spedread_window_class_init (SpedreadWindowClass *klass)
{
  GtkWidgetClass *widget_class = GTK_WIDGET_CLASS (klass);

  G_OBJECT_CLASS (klass)->dispose = spedread_window_dispose;

  gtk_widget_class_set_template_from_resource (widget_class,
                                               "/n/darazaki/Spedread/spedread-window.ui");

  gtk_widget_class_bind_template_child (widget_class, SpedreadWindow, milliseconds_per_word);
  gtk_widget_class_bind_template_child (widget_class, SpedreadWindow, main_popover_opener);
  gtk_widget_class_bind_template_child (widget_class, SpedreadWindow, reading);
  gtk_widget_class_bind_template_child (widget_class, SpedreadWindow, input);
  gtk_widget_class_bind_template_child (widget_class, SpedreadWindow, stack);
  gtk_widget_class_bind_template_child (widget_class, SpedreadWindow, word);
}

static void
spedread_window_init (SpedreadWindow *self)
{
  gtk_widget_init_template (GTK_WIDGET (self));
  gtk_window_set_title (GTK_WINDOW (self), "Spedread");

  self->timeout_id = 0;
  g_signal_connect (self->stack,
                    "notify::visible-child",
                    G_CALLBACK (spedread_window_view_switched),
                    self);
  g_signal_connect (gtk_text_view_get_buffer (self->input),
                    "changed",
                    G_CALLBACK (spedread_window_text_changed),
                    self);
  g_signal_connect (self->main_popover_opener,
                    "clicked",
                    G_CALLBACK (spedread_window_main_popover_shown),
                    self);

  self->settings = g_settings_new ("n.darazaki.Spedread");

  gtk_spin_button_set_increments (self->milliseconds_per_word, 50, 100);
  gtk_spin_button_set_range (self->milliseconds_per_word, 50, 2000);
  g_settings_bind (self->settings, "milliseconds-per-word",
                   self->milliseconds_per_word, "value",
                   G_SETTINGS_BIND_DEFAULT);

  /* Initialize the input text iterator */
  GtkTextBuffer *buffer = gtk_text_view_get_buffer (self->input);
  gtk_text_buffer_get_start_iter (buffer, &self->input_iter);
}

static gboolean
spedread_window_tick (SpedreadWindow *self)
{
  g_assert (SPEDREAD_IS_WINDOW (self));

  GtkTextBuffer *buffer = gtk_text_view_get_buffer (self->input);
  GtkTextIter iter, next_iter;

  spedread_window_skip_whitespaces (&self->input_iter);

  iter = next_iter = self->input_iter;

  if (gtk_text_iter_is_end (&iter)) {
    self->timeout_id = 0;
    gtk_toggle_button_set_active (self->reading, FALSE);
    gtk_button_set_label (GTK_BUTTON (self->reading), "gtk-media-play");
    return FALSE;
  } else {
    spedread_window_next_word (&next_iter);
    gchar *word = gtk_text_buffer_get_text (buffer, &iter, &next_iter, TRUE);
    gtk_label_set_text (self->word, word);
    g_free (word);
  }

  self->input_iter = next_iter;

  /* Keep ticking */
  return TRUE;
}

static void
spedread_window_start_reading (SpedreadWindow *self)
{
  if (gtk_text_iter_is_end (&self->input_iter))
    spedread_window_text_changed (NULL, self);

  guint milliseconds_per_word =
    g_settings_get_uint (self->settings, "milliseconds-per-word");

  self->timeout_id =
    g_timeout_add (milliseconds_per_word,
                   G_SOURCE_FUNC (spedread_window_tick), self);

  gtk_button_set_label (GTK_BUTTON (self->reading), "gtk-media-pause");
}

static void
spedread_window_stop_reading (SpedreadWindow *self)
{
  spedread_window_remove_timeout (self);

  gtk_toggle_button_set_active (self->reading, FALSE);
  gtk_button_set_label (GTK_BUTTON (self->reading), "gtk-media-play");
}

extern void
spedread_window_play_toggled (GtkToggleButton *play_button,
                              SpedreadWindow  *window)
{
  g_assert (SPEDREAD_IS_WINDOW (window));

  gboolean start_playing = gtk_toggle_button_get_active (play_button);

  if (start_playing)
    spedread_window_start_reading (window);
  else
    spedread_window_stop_reading (window);
}
