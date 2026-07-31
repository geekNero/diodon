/*
 * Diodon - GTK+ clipboard manager.
 * Copyright (C) 2011 Diodon Team <diodon-team@lists.launchpad.net>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published
 * by the Free Software Foundation, either version 2 of the License, or (at
 * your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 * License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Author:
 *  Oliver Sauder <os@esite.ch>
 */

namespace Diodon
{

    private enum SearchMode {
        DISABLED,
        LABEL,      // Incremental search triggered by '/'
        STORAGE     // Storage search triggered by '?'
    }

    /**
     * A gtk menu item holding a list of clipboard items
     */
    class ClipboardMenu : Gtk.Menu
    {
        private Controller controller;
        private unowned List<Gtk.Widget> static_menu_items;
        private string search_query = "";
        private Gtk.MenuItem search_menu_item;
        private Gtk.MenuItem spacer_menu_item;
        private SearchMode search_mode = SearchMode.DISABLED;
        private bool has_items = false;
        private bool pause_keystrokes = false;

        // Label related constants
        private const int MAX_LABEL_WIDTH = 150;
        private const int MIN_LABEL_WIDTH = 60;
        private const float LABEL_TO_WINDOW_RATIO = 0.04f;

        // Menu related CSS
        private static Gtk.CssProvider css; 

        /**
         * Create clipboard menu
         *
         * @param controller reference to controller
         * @param items clipboard items to be shown
         * @param menu_items additional menu items to be added after separator
         * @param privacy_mode check whether privacy mode is enabled
         */
        public ClipboardMenu(Controller controller, List<IClipboardItem> items, List<Gtk.MenuItem>? static_menu_items, bool privace_mode,string? error = null)
        {
            this.controller = controller;
            this.static_menu_items = static_menu_items;
            this.get_style_context().add_class("diodon-menu");
            
            load_css(controller.get_configuration().theme);

            Gtk.MenuItem clear_item = new Gtk.ImageMenuItem.from_stock(Gtk.Stock.CLEAR, null);
            clear_item.get_style_context().add_class("action-item");
            clear_item.activate.connect(on_clicked_clear);
            append(clear_item);

            Gtk.MenuItem preferences_item = new Gtk.ImageMenuItem.from_stock(Gtk.Stock.PREFERENCES, null);
            preferences_item.activate.connect(on_clicked_preferences);
            preferences_item.get_style_context().add_class("action-item");
            append(preferences_item);

            Gtk.MenuItem quit_item = new Gtk.ImageMenuItem.from_stock(Gtk.Stock.QUIT, null);
            quit_item.activate.connect(on_clicked_quit);
            quit_item.get_style_context().add_class("action-item");
            append(quit_item);

            Gtk.SeparatorMenuItem sep_item = new Gtk.SeparatorMenuItem();
            append(sep_item);

            search_menu_item = new Gtk.MenuItem();
            search_menu_item.get_style_context().add_class("search-item");
            search_menu_item.set_sensitive(false);
            search_menu_item.set_no_show_all(true);
            append(search_menu_item);

            if(error != null) {
                Gtk.MenuItem error_item = new Gtk.MenuItem.with_label(wrap_label(error));
                error_item.set_sensitive(false);
                append(error_item);
            } else if(items.length() <= 0) {
                Gtk.MenuItem empty_item = new Gtk.MenuItem.with_label(_("<Empty>"));
                empty_item.set_sensitive(false);
                append(empty_item);
            }

            if(privace_mode) {
                Gtk.MenuItem privacy_item = new Gtk.MenuItem.with_label(
                    _("Privacy mode is enabled. No new items will be added to history!")
                );
                privacy_item.set_sensitive(false);
                append(privacy_item);
            }


            foreach(IClipboardItem item in items) {
                append_clipboard_item(item);
            }

            if(static_menu_items != null) {
                foreach(Gtk.MenuItem menu_item in static_menu_items) {
                    append(menu_item);
                }
            }

            // Place-holder for Search Bar when it's disabled.
            spacer_menu_item = new Gtk.MenuItem();
            spacer_menu_item.set_label(" ");
            spacer_menu_item.get_style_context().add_class("spacer-item");
            spacer_menu_item.set_sensitive(false);
            spacer_menu_item.set_no_show_all(true);
            spacer_menu_item.show();
            append(spacer_menu_item);

            show_all();

            this.key_press_event.connect(on_key_pressed);

            this.hide.connect(() => {
                reset_search();
            });
        }

        /**
         * Append given clipboard item to menu.
         *
         * @param entry entry to be added
         */
        public void append_clipboard_item(IClipboardItem item)
        {
            ClipboardMenuItem menu_item = new ClipboardMenuItem(item);
            menu_item.activate.connect(on_clicked_item);
            menu_item.show();
            append(menu_item);
        }

        /**
        * show_menu computes the popup position, character width and height based on the cursor position. 
        */
        public void show_menu()
        {
            
            Gdk.Rectangle monitor_dimensions = Utility.get_current_window_geometry();

            // needed to set the popup positions
            Gdk.Rectangle popup_anchor_rect = {
                    monitor_dimensions.x + (monitor_dimensions.width / 2), // Horizontally centered
                    monitor_dimensions.y + 2, // 2px down from top edge
                    1,
                    1
                };

            // Forcing the popup to avoid flowing further than 3/4 of the monitor size.
            this.margin_bottom = (int)(monitor_dimensions.height / 4) - 30;

            // Determining the character width 
            int dynamic_char_width = width_in_charcters(monitor_dimensions.width);
        
            // The default cursor position is set to the first widget. So the first clipboard item has to be explicitly selected.
            Gtk.Widget first_clipboard_item = null;
            
            // Update the max_width_chars of every menu item before displaying
            foreach (Gtk.Widget item in get_children()) {
                 if (item is ClipboardMenuItem) {
                    ClipboardMenuItem clipboard_item = (ClipboardMenuItem)item;
                    clipboard_item.set_item_label_width_chars(dynamic_char_width);
                    if (first_clipboard_item == null)
                    {
                        first_clipboard_item = item;
                    }
                }
            }

            Timeout.add(
                    250,
                    () => {
                        popup_at_rect(
                            Gdk.Screen.get_default().get_root_window(),
                            popup_anchor_rect,
                            Gdk.Gravity.NORTH, // Top-Center of the anchor point
                            Gdk.Gravity.NORTH, // Align the top-center edge of our menu
                            null
                        );

                        if (first_clipboard_item != null){
                            this.select_item(first_clipboard_item);
                            has_items = true;
                        }else{
                            has_items = false;
                        }

                        return false;
                    }
                );
        }

        /**
         * Completely destroy menu by cleaning up menu items and menu itself.
         */
        public void destroy_menu()
        {
            foreach(Gtk.Widget item in get_children()) {
                remove(item);

                // make sure that static items do not get destroyed
                if(static_menu_items == null || static_menu_items.find(item) == null)
                {
                    item.destroy();
                    item.dispose();
                }
            }

            destroy();
            dispose();
        }

        public static void load_css(string theme){
            if (css == null){
              css = new Gtk.CssProvider();
            }
            
            string target_file = Path.build_filename(Config.PKG_DATA_DIR, "themes", theme + ".css");

            try {
            css.load_from_path(target_file);
            Gtk.StyleContext.add_provider_for_screen(
                      Gdk.Screen.get_default(),
                      css,
                      Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
                  );

            } catch (Error e) {
              warning("Failed to load theme CSS from %s: %s", target_file, e.message);
            }
        }


        /**
         * Wrap label at colons and dots.
         */
        private string wrap_label(string label)
        {
           string _label = label.replace(": ", ":\n");
           _label.replace(". ", ".\n");
           return _label;
        }

        /**
         * Calculating the width in characters based on the resolution width provided.
         */
        private int width_in_charcters(int width){
            return ((int)(width*LABEL_TO_WINDOW_RATIO)).clamp(MIN_LABEL_WIDTH, MAX_LABEL_WIDTH);   
        }

        /**
         * User event: clicked menu item clear
         */
        private void on_clicked_clear()
        {
            controller.clear.begin();
        }

        /**
         * User event: clicked menu item preferences
         */
        private void on_clicked_preferences()
        {
            controller.show_preferences();
        }

        /**
         * User event: clicked menu item quit
         */
        private void on_clicked_quit()
        {
            controller.quit();
        }

        /**
         * User event: clicked clipboard menu item
         *
         * @param menu_item menu item clicked
         */
        private void on_clicked_item(Gtk.MenuItem menu_item)
        {
            ClipboardMenuItem clipboard_menu_item = (ClipboardMenuItem)menu_item;
            controller.select_item_by_checksum.begin(clipboard_menu_item.get_item_checksum());
        }
        

        /**
         * Update search filter and UI
         */
        private void reset_search(){
            search_mode = SearchMode.DISABLED;
            search_query = "";
            search_menu_item.hide();
            spacer_menu_item.show();
            bool first = true;
            pause_keystrokes = false;
            foreach(Gtk.Widget item in get_children()) {
                if (item is ClipboardMenuItem) {
                    ClipboardMenuItem cb_item = (ClipboardMenuItem)item;
                    cb_item.show();           

                    // This can be called when an old menu is deleted before creating a new menu.
                    if (first && this.get_realized() && this.get_mapped() ){
                        this.select_item(cb_item);
                        first = false;
                    }
                }
            }
        }

        private void update_search_ui(){
            if (search_mode == SearchMode.DISABLED){
                return;
            }
            search_menu_item.set_label(_("Search: ")+ search_query);
            search_menu_item.show();
            spacer_menu_item.hide();
        }

        /**
         * Filter items on label
         */
        private void filter_items_on_label()
        {

            string search_lower = search_query.down();
            bool first = true;

            foreach(Gtk.Widget item in get_children()) {
                if (item is ClipboardMenuItem) {
                    ClipboardMenuItem cb_item = (ClipboardMenuItem)item;
                    if (matches_search(cb_item, search_lower)) {
                        cb_item.show();
                        if (first && search_query.length > 0) {
                            this.select_item(item);
                            first = false;
                        }
                    } else {
                        cb_item.hide();
                    }
                }
            }

        }


        private void filter_items_on_text(){

            string search_lower = search_query.down();
            pause_keystrokes = true;

            this.controller.get_items_by_search_query.begin(search_lower, null, ClipboardTimerange.ALL, null, (obj, res) => {

                pause_keystrokes = false;
                if (!this.get_realized() || !this.get_mapped()){
                    return;
                }
            
                List<IClipboardItem> items = this.controller.get_items_by_search_query.end(res);

                
                 var matching_checksums = new HashTable<string, void*>(str_hash, str_equal);
                foreach (IClipboardItem item in items) {
                    matching_checksums.insert(item.get_checksum(),null);
                }

                bool first = true;

                foreach (Gtk.Widget widget in get_children()) {
                    if (widget is ClipboardMenuItem) {
                        ClipboardMenuItem cb_item = (ClipboardMenuItem) widget;
                        if (matching_checksums.contains(cb_item.get_item_checksum())) {
                            cb_item.show();
                            if (first) {
                                this.select_item(widget);
                                first = false;
                            }
                        } else {
                            cb_item.hide();
                        }
                    }
                }

            });

            
        }
        

        private bool matches_search(ClipboardMenuItem cb_item, string search_string)
        {
            string label = cb_item.get_label().down();   
            return label.contains(search_string);
        }

        /**
         * Allow moving of cursor with vi-style j and k keys
         */
        private bool on_key_pressed(Gdk.EventKey event)
        {
            uint down_keyval = Gdk.keyval_from_name("j");
            uint up_keyval = Gdk.keyval_from_name("k");
            uint label_search_keyval = Gdk.keyval_from_name("slash");
            uint storage_search_keyval = Gdk.keyval_from_name("question");
            uint backspace_keyval = Gdk.keyval_from_name("BackSpace");
            uint escape_keyval = Gdk.keyval_from_name("Escape");
            uint enter_keyval = Gdk.keyval_from_name("Return");
            uint kp_enter_keyval = Gdk.keyval_from_name("KP_Enter");

            uint pressed_keyval = Gdk.keyval_to_lower(event.keyval);

            if(pause_keystrokes == true){
                return false;
            }
            
            // Only use vi-style movement if search query is empty
            if(search_mode == SearchMode.DISABLED) {
                if(pressed_keyval == down_keyval) {
                    if(get_selected_item() == null) {
                        select_first(true);
                    } else {
                        move_selected(1);
                    }
                    return true;
                } else if(pressed_keyval == up_keyval) {
                    if(get_selected_item() == null) {
                        select_first(true);
                    }
                    move_selected(-1);
                    return true;
                } else if(pressed_keyval == label_search_keyval && has_items){
                    search_mode = SearchMode.LABEL;
                    update_search_ui();
                    return true;
                } else if(pressed_keyval == storage_search_keyval && has_items){
                    search_mode = SearchMode.STORAGE;
                    update_search_ui();
                    return true;
                }else{
                    return false;
                }
            }

            if (pressed_keyval == backspace_keyval) {
                long chars = search_query.char_count();
                if (chars > 0) {
                    long bytes = search_query.index_of_nth_char(chars - 1);
                    search_query = search_query.substring(0, bytes);
                    update_search_ui();
                    if (search_mode == SearchMode.LABEL){
                        filter_items_on_label();
                    }
                    return true;
                }
            } else if (pressed_keyval == escape_keyval) {
                    reset_search();
                    return true;

            } else if(search_mode == SearchMode.STORAGE && (pressed_keyval == kp_enter_keyval || pressed_keyval == enter_keyval)){
                 if (search_query.char_count() == 0){
                    reset_search();
                    return true;
                }   

                pause_keystrokes = true;
                filter_items_on_text();
                return true;
                
            }else {
                unichar c = Gdk.keyval_to_unicode(event.keyval);
                if (c != 0 && !c.iscntrl()) {
                    StringBuilder sb = new StringBuilder(search_query);
                    sb.append_unichar(c);
                    search_query = sb.str;
                    update_search_ui();
                    if (search_mode == SearchMode.LABEL){
                         filter_items_on_label();
                    }
                    return true;
                }
            }

            return false;
        }
    }
}
