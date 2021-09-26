
#pragma once

#include <gtk/gtk.h>

G_BEGIN_DECLS

#define SPEDREAD_TYPE_WINDOW (spedread_window_get_type())

G_DECLARE_FINAL_TYPE (SpedreadWindow, spedread_window, SPEDREAD, WINDOW, GtkApplicationWindow)

G_END_DECLS
