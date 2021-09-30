use gtk::{
    glib,
    glib::clone,
    pango::{AttrList, Attribute, Weight},
    prelude::*,
    Application, ApplicationWindow, Button, Grid, HeaderBar, Label, License,
    MenuButton, Popover, ScrolledWindow, SpinButton, Stack, StackSwitcher,
    TextView, ToggleButton, WrapMode,
};

fn lbl(s: &str) -> Label { Label::new(Some(s)) }

macro_rules! margins {
    ($builder: expr, $val: expr) => {{
        let val = $val;

        $builder
            .margin_top(val)
            .margin_bottom(val)
            .margin_start(val)
            .margin_end(val)
    }};

    ($builder: expr) => {
        margins!($builder, 12)
    };
}

fn started(app: &Application) {
    let window = ApplicationWindow::builder()
        .application(app)
        .default_height(400)
        .default_width(600)
        .title("Spedread")
        .build();

    let menu_button = MenuButton::builder()
        .icon_name("open-menu-symbolic")
        .build();

    let menu_popover = Popover::builder()
        .child(&{
            let contents = Grid::builder()
                .column_spacing(12)
                .margin_end(6)
                .margin_start(6)
                .build();

            let about_button = Button::with_label("About Spedread...");
            about_button.connect_clicked(
                clone!(@weak window => move |_about_button| {
                    let authors = [
                        "Naqua Darazaki <n.darazaki@gmail.com>",
                    ];

                    gtk::show_about_dialog(Some(&window), &[
                        ("program-name",   &"Spedread"),
                        ("website",        &"https://github.com/Darazaki/Spedread"),
                        ("license-type",   &License::Gpl30),
                        ("logo-icon-name", &"n.darazaki.Spedread"),
                        ("comments",       &"Read like a speedrunner"),
                        ("version",        &"2.0.0"),
                        ("authors",        &authors.into_iter().map(ToString::to_string).collect::<Vec<_>>()),
                    ]);
                }),
            );

            let ms_per_word =
                SpinButton::builder().climb_rate(25.).digits(0).build();
            ms_per_word.set_increments(25., 50.);
            ms_per_word.set_range(100., 1000.);
            ms_per_word.set_value(175.);

            contents.attach(&lbl("Milliseconds per Word"), 0, 0, 1, 1);
            contents.attach(&ms_per_word, 1, 0, 1, 1);
            contents.attach(&about_button, 0, 1, 2, 1);

            contents
        })
        .build();

    let view_stack = Stack::builder().build();

    // "Text" tab
    view_stack.add_titled(
        &{
            let text_view = TextView::builder()
                .wrap_mode(WrapMode::Word)
                .top_margin(12)
                .left_margin(12)
                .right_margin(12)
                .bottom_margin(12)
                .build();

            margins!(ScrolledWindow::builder(), 18)
                .child(&text_view)
                .build()
        },
        Some("Text"),
        "Text",
    );

    // "Read" tab
    view_stack.add_titled(
        &{
            let attributes = AttrList::new();
            attributes.insert(Attribute::new_scale(2.));
            attributes.insert(Attribute::new_weight(Weight::Bold));

            let view = margins!(Grid::builder(), 18).column_spacing(12).build();

            let word = Label::builder()
                .label("Go to \"Text\" and paste your read!")
                .attributes(&attributes)
                .vexpand(true)
                .build();

            let play = ToggleButton::builder()
                .icon_name("media-playback-start-symbolic")
                .hexpand(true)
                .sensitive(false)
                .build();

            let previous = Button::builder()
                .icon_name("go-next-symbolic-rtl")
                .sensitive(false)
                .build();

            let next = Button::builder()
                .icon_name("go-next-symbolic")
                .sensitive(false)
                .build();

            view.attach(&word, 0, 0, 3, 1);
            view.attach(&previous, 0, 1, 1, 1);
            view.attach(&play, 1, 1, 1, 1);
            view.attach(&next, 2, 1, 1, 1);

            view
        },
        Some("Read"),
        "Read",
    );

    let switcher = StackSwitcher::builder().stack(&view_stack).build();

    menu_button.set_popover(Some(&menu_popover));

    let titlebar = HeaderBar::builder()
        .title_widget(&switcher)
        .show_title_buttons(true)
        .build();

    titlebar.pack_end(&menu_button);

    window.set_titlebar(Some(&titlebar));
    window.set_child(Some(&view_stack));

    window.present();
}

fn main() {
    let app = Application::builder()
        .application_id("n.darazaki.Spedread")
        .build();

    app.connect_activate(started);

    app.run();
}
