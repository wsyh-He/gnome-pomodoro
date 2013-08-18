/*
 * Copyright (c) 2013 gnome-shell-pomodoro contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 *
 */

using GLib;

namespace Pomodoro
{
    const double TIMER_SCALE_LOWER = 60.0;
    const double TIMER_SCALE_UPPER = 60.0 * 120.0;

    const GLib.SettingsBindFlags BINDING_FLAGS =
                            GLib.SettingsBindFlags.DEFAULT |
                            GLib.SettingsBindFlags.GET |
                            GLib.SettingsBindFlags.SET;

    /* mapping from settings to keybinding */
    public bool get_keybinding_mapping (GLib.Value value,
                                        GLib.Variant variant,
                                        void* user_data)
    {
        var accelerators = variant.get_strv ();

        foreach (var accelerator in accelerators)
        {
            value.set_string (accelerator);
            return true;
        }

        value.set_string ("");
        return true;
    }

    /* mapping from keybinding to settings */
    public Variant set_keybinding_mapping (GLib.Value value,
                                           GLib.VariantType expected_type,
                                           void* user_data)
    {
        var accelerator = value.get_string ();
        //if (accelerator != "") {
        string[] strv = { accelerator };
        return new Variant.strv (strv);
        //}

        //return new Variant.strv (""); // TODO: why we can't pass null?
    }

    /* mapping from settings to file chooser */
    public bool get_file_mapping (GLib.Value value,
                                  GLib.Variant variant,
                                  void* user_data)
    {
        value.set_object (GLib.File.new_for_uri (variant.get_string ()));
        return true;
    }

    /* mapping from keybinding to file chooser */
    public Variant set_file_mapping (GLib.Value value,
                                     GLib.VariantType expected_type,
                                     void* user_data)
    {
        var file = value.get_object () as GLib.File;
        return new Variant.string (file != null
                                   ? file.get_uri () : "");
    }
}


public class Pomodoro.PreferencesDialog : Gtk.ApplicationWindow
{
    private GLib.Settings settings;
    private GLib.Settings timer_settings;
    private GLib.Settings keybindings_settings;
    private GLib.Settings notifications_settings;
    private GLib.Settings sounds_settings;
    private GLib.Settings presence_settings;
    private Gtk.Notebook  notebook;

    public Egg.ListBox contents { get; set; }

    public PreferencesDialog ()
    {
        this.title = _("Preferences");
        this.set_default_size (400, 500);
        this.set_modal (true);
        this.set_destroy_with_parent (true);
        this.set_position (Gtk.WindowPosition.CENTER);

        var application = GLib.Application.get_default() as Pomodoro.Application;
        this.settings = application.settings.get_child("preferences");
        this.timer_settings = this.settings.get_child ("timer");
        this.keybindings_settings = this.settings.get_child ("keybindings");
        this.notifications_settings = this.settings.get_child ("notifications");
        this.sounds_settings = this.settings.get_child ("sounds");
        this.presence_settings = this.settings.get_child ("presence");

        this.setup();
    }

    private void setup ()
    {
        var css_provider = new Gtk.CssProvider ();
        try {
            // TODO: can we put it into the resource file?
            css_provider.load_from_path (Config.PACKAGE_DATA_DIR + "/gtk-style.css");
        }
        catch (Error e) {
            GLib.warning ("Error while loading css file: %s", e.message);
        }
        var context = this.get_style_context ();
        context.add_provider_for_screen (Gdk.Screen.get_default(),
                                         css_provider,
                                         Gtk.STYLE_PROVIDER_PRIORITY_USER);
        context.add_class ("preferences-dialog");
        
        this.notebook = new Gtk.Notebook ();
        this.notebook.set_show_tabs (false);
        this.notebook.set_show_border (false);

        var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

        var scrolled_window = new Gtk.ScrolledWindow (null, null);
        scrolled_window.hscrollbar_policy = Gtk.PolicyType.NEVER;
        scrolled_window.vscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
        this.notebook.append_page (scrolled_window, null);

        var alignment = new Gtk.Alignment (0.5f, 0.0f, 0.3f, 1.0f);
        alignment.set_padding (10, 10, 20, 20);
        scrolled_window.add (alignment);

        this.contents = new Egg.ListBox();
        this.contents.set_selection_mode (Gtk.SelectionMode.NONE);
        this.contents.set_activate_on_single_click (false);
        this.contents.get_style_context ().add_class ("list");
        this.contents.set_separator_funcs (this.contents_separator_func);
        this.contents.width_request = 320;
        this.contents.can_focus = false;
        alignment.add (this.contents);

        vbox.pack_start (this.notebook, true, true);
        vbox.show_all ();

        this.setup_timer_page ();

        this.setup_notifications_page ();

        this.setup_presence_page ();

        this.add (vbox);
    }

    private void contents_separator_func (ref Gtk.Widget? separator,
                                          Gtk.Widget      child,
                                          Gtk.Widget?     before)
    {
        var show_separator = true;

        if (before == null)
            show_separator = false;

        if (show_separator)
        {
            if (separator == null)
                separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        }
        else
        {
            separator = null;
        }
    }

    private Gtk.Widget create_section_label (string text,
                                             bool   is_first = false)
    {
        var label = new Gtk.Label (text);
        label.halign = Gtk.Align.START;
        label.valign = Gtk.Align.END;
        label.get_style_context().add_class ("list-section-label");
        if (is_first)
            label.get_style_context().add_class ("first");
        label.show ();

        return label;        
    }

    private Gtk.Widget create_section_separator ()
    {
        var separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        separator.get_style_context ().add_class ("list-section-separator");
        separator.show ();

        return separator;
    }

    private Gtk.Widget create_field (string text, Gtk.Widget widget, Gtk.Widget? bottom_widget=null)
    {
        var bin = new Gtk.Alignment (0.0f, 0.0f, 1.0f, 1.0f);
        bin.set_padding (5, 5, 0, 0);
        bin.get_style_context ().add_class ("list-item");

        var label = new Gtk.Label (text);
        label.xalign = 0.0f;
        label.yalign = 0.5f;
        label.get_style_context ().add_class ("list-label");

        var widget_bin = new Gtk.Alignment (1.0f, 0.5f, 0.0f, 0.0f);
        widget_bin.add (widget);

        var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 20);
        hbox.pack_start (label, true, true, 0);
        hbox.pack_start (widget_bin, false, false, 0);        

        if (bottom_widget != null)
        {
            var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            vbox.pack_start (hbox, false, true, 0);
            vbox.pack_start (bottom_widget, true, true, 0);

            bin.add (vbox);
        }
        else
        {        
            bin.add (hbox);
        }

        bin.show_all ();
        return bin;
    }

    private Gtk.Widget create_scale_field (string text,
                                           Gtk.Adjustment adjustment)
    {
        var value_label = new Gtk.Label (null);
        var scale = new LogScale (adjustment);
        var widget = this.create_field (text, value_label, scale);
        
        adjustment.value_changed.connect (() => {
            value_label.set_text (format_time ((long) adjustment.value));
        });

        adjustment.value_changed ();

        return widget;
    }

    private void setup_timer_page ()
    {
        var pomodoro_adjustment = new Gtk.Adjustment (
            0.0,
            TIMER_SCALE_LOWER,
            TIMER_SCALE_UPPER,
            60.0,
            300.0,
            0.0);

        var short_break_adjustment = new Gtk.Adjustment(
            0.0,
            TIMER_SCALE_LOWER,
            TIMER_SCALE_UPPER,
            60.0,
            300.0,
            0.0);

        var long_break_adjustment = new Gtk.Adjustment(
            0.0,
            TIMER_SCALE_LOWER,
            TIMER_SCALE_UPPER,
            60.0,
            300.0,
            0.0);

        var keybinding = new Keybinding ();

        var binding_flags = GLib.SettingsBindFlags.DEFAULT |
                            GLib.SettingsBindFlags.GET |
                            GLib.SettingsBindFlags.SET;

        this.timer_settings.bind ("pomodoro-time",
                                  pomodoro_adjustment,
                                  "value",
                                  binding_flags);

        this.timer_settings.bind ("short-pause-time",
                                  short_break_adjustment,
                                  "value",
                                  binding_flags);

        this.timer_settings.bind ("long-pause-time",
                                  long_break_adjustment,
                                  "value",
                                  binding_flags);

        //this.timer_settings.bind ("session-limit",
        //                          session_limit_adjustment,
        //                          "value",
        //                          binding_flags);

        this.keybindings_settings.bind_with_mapping ("toggle-timer",
                                                     keybinding,
                                                     "accelerator",
                                                     binding_flags,
                                                     get_keybinding_mapping, 
                                                     set_keybinding_mapping,
                                                     null,
                                                     null);

        this.contents.add (this.create_section_label (_("Timer"), true));

        //this.timer_settings.delay ();
        //this.timer_settings.apply ();

        this.contents.add (this.create_scale_field (_("Pomodoro time"), pomodoro_adjustment));

        this.contents.add (this.create_scale_field (_("Short break time"), short_break_adjustment));

        this.contents.add (this.create_scale_field (_("Long break time"), long_break_adjustment));

        var toggle_key_button = new Pomodoro.KeybindingButton (keybinding);
        toggle_key_button.show ();

        this.contents.add (
            this.create_field (_("Toggle timer shortcut"), toggle_key_button));
    }

    private void setup_notifications_page ()
    {
// TODO
//        let status_options = {
//            '': _("Do not change"),
//            'available': _("Available"),
//            'away': _("Away"),
//            'busy': _("Busy")
//        };

//        let notification_sound_options = {
//            '': _("Silent"),
//            'default': _("Default"),
//        };

//        let background_sound_options = {
//            '': _("Silent"),
//            'cafe': _("Cafe"),
//        };

        var binding_flags = GLib.SettingsBindFlags.DEFAULT |
                            GLib.SettingsBindFlags.GET |
                            GLib.SettingsBindFlags.SET;

        this.contents.add (this.create_section_label (_("Notifications")));

        var notifications_toggle = new Gtk.Switch ();
        this.contents.add (
            this.create_field (_("Screen notifications"), notifications_toggle));

        var reminders_toggle = new Gtk.Switch ();
        this.contents.add (
            this.create_field (_("Reminders"), reminders_toggle));

        var pomodoro_start_sound = new Pomodoro.SoundChooserButton();
        this.contents.add (
            this.create_field (_("Start of pomodoro sound"), pomodoro_start_sound));

        var default_sound_file_uri = GLib.Path.build_filename (
                "file://",
                Config.PACKAGE_DATA_DIR,
                "sounds",
                "pomodoro-start.wav");

        pomodoro_start_sound.add_bookmark (
                _("(None)"),
                File.new_for_uri (""));

        pomodoro_start_sound.add_bookmark (
                _("Bell"),
                File.new_for_uri (default_sound_file_uri));

        var pomodoro_end_sound = new Pomodoro.SoundChooserButton ();
        this.contents.add (
            this.create_field (_("Start of break sound"), pomodoro_end_sound));

        pomodoro_end_sound.add_bookmark (
                _("(None)"),
                File.new_for_uri (""));

        pomodoro_end_sound.add_bookmark (
                _("Bell"),
                File.new_for_uri (default_sound_file_uri));

        var background_sound = new Pomodoro.SoundChooserButton ();
        this.contents.add (
            this.create_field (_("Background sound"), background_sound));

        this.notifications_settings.bind ("screen-notifications",
                                          notifications_toggle,
                                          "active",
                                          binding_flags);

        this.notifications_settings.bind ("reminders",
                                          reminders_toggle,
                                          "active",
                                          binding_flags);

        this.sounds_settings.bind_with_mapping ("pomodoro-start-sound",
                                                pomodoro_start_sound,
                                                "file",
                                                binding_flags,
                                                Sounds.get_file_mapping,
                                                Sounds.set_file_mapping,
                                                null,
                                                null);

        this.sounds_settings.bind_with_mapping ("pomodoro-end-sound",
                                                pomodoro_end_sound,
                                                "file",
                                                binding_flags,
                                                Sounds.get_file_mapping,
                                                Sounds.set_file_mapping,
                                                null,
                                                null);

        this.sounds_settings.bind_with_mapping ("background-sound",
                                                background_sound,
                                                "file",
                                                binding_flags,
                                                Sounds.get_file_mapping,
                                                Sounds.set_file_mapping,
                                                null,
                                                null);

        //var sounds_toggle = new Gtk.Switch ();
        //this.contents.add (
        //    this.create_field (_("Play sounds"), sounds_toggle));
        //
        //this.sounds_settings.bind ("enabled",
        //                           sounds_toggle,
        //                           "active",
        //                           binding_flags);
    }

    private void setup_presence_page ()
    {
        var binding_flags = GLib.SettingsBindFlags.DEFAULT |
                            GLib.SettingsBindFlags.GET |
                            GLib.SettingsBindFlags.SET;

        var pause_when_idle_toggle = new Gtk.Switch ();

        this.contents.add (this.create_section_label (_("Presence")));

        this.contents.add (
            this.create_field (_("Wait after break"), pause_when_idle_toggle));

        this.presence_settings.bind ("pause-when-idle",
                                     pause_when_idle_toggle,
                                     "active",
                                     binding_flags);

        //presence_section.add_toggle_item(_("Delay system notifications"), true);
        //presence_section.add_toggle_item(_("Change presence status"), true);
        //presence_section.add_combo_box_item(_("Status during pomodoro"), status_options, '');
        //presence_section.add_combo_box_item(_("Status during break"), status_options, '');
        //presence_section.add_toggle_item(_("Change status to busy during session"), true);
        //presence_section.add_toggle_item(_("Change status to away during break"), true);
    }
}

