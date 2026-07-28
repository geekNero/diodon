/*
 * Diodon - GTK+ clipboard manager.
 * Copyright (C) 2010-2011 Diodon Team <diodon-team@lists.launchpad.net>
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
    /**
     * A gtk menu item holding a checksum of a clipboard item. It only keeps
     * the checksum as it would waste memory to keep the whole item available.
     */
    class ClipboardMenuItem : Gtk.ImageMenuItem
    {
        private string _checksum;
        private string _full_text_lower;
        private static Gtk.CssProvider css; 
        const string css_data = """
          menuitem {
            margin: 2px 6px;
            padding: 4px 8px;
            border-radius: 6px;
            background-color: rgba(128, 128, 128, 0.08);
            border: 1px solid rgba(128, 128, 128, 0.15);
            border-left: 3px solid rgba(128, 128, 128, 0.35);
            transition: all 150ms cubic-bezier(0.25, 0.8, 0.25, 1);
        }

        menuitem:hover,
        menuitem:selected {
            background-color: rgba(53, 132, 228, 0.85);
            border-color: rgba(53, 132, 228, 0.95);
            border-left: 3px solid #78aeed;
            color: #ffffff;
            box-shadow: 0 2px 6px rgba(0, 0, 0, 0.22);
        }
        """;

        /**
         * Clipboard item constructor
         *
         * @param item clipboard item
         */
        public ClipboardMenuItem(IClipboardItem item)
        {
            _checksum = item.get_checksum();
            _full_text_lower = item.get_text().down();
            set_label(item.get_label());
            // styling clipboard item to make them more visible.
            ensure_css();
            this.get_style_context().add_provider(css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            // check if image needs to be shown
            Gtk.Image? image = item.get_image();
            if(image != null) {
                set_image(image);
                set_always_show_image(true);
            }
        }

        

        /**
         * Set ClipboardMenuItem label width in characters.
         *
         * @param width
         */
        public void set_item_label_width_chars(int width){
          Gtk.Label? label = ((Gtk.MenuItem)this).get_child() as Gtk.Label;
          if (label != null) {
            label.set_max_width_chars(width);
            label.set_ellipsize(Pango.EllipsizeMode.END);
            if (width< 60){
                label.set_line_wrap(true);
                label.set_line_wrap_mode(Pango.WrapMode.WORD_CHAR);
                label.set_lines(2); // Maximum number of lines to display
              }
           }
        }

        private static void ensure_css(){
          if (css != null){
            return;
          }
          css = new Gtk.CssProvider();
          try {
              css.load_from_data(css_data, -1);
          } catch (Error e) {
              warning("Failed to apply CSS: %s", e.message);
          }

        }

        /**
         * Check if this item matches the given search query (which should be lowercased)
         */
        public bool matches_search(string query_lower)
        {
            if (query_lower == null || query_lower.length == 0) {
                return true;
            }
            return _full_text_lower.contains(query_lower);
        }

        /**
         * Get encapsulated clipboard item checksum
         *
         * @return clipboard item checksum
         */
        public string get_item_checksum()
        {
            return _checksum;
        }

        /**
         * Highlight item by changing label to bold
         * TODO: get this up and running
         */
        /*public void highlight_item()
        {
            Gtk.Label label = get_menu_label();
            label.set_markup("<b>%s</b>".printf(get_label()));
        }*/

        /**
         * Gets the child of Gtk.Bin base class which represents
         * a Gtk.Label object.
         *
         * @return gtk label
         */
        /*private Gtk.Label get_menu_label()
        {
            Gtk.Label menu_label = (Gtk.Label) get_child();
            return menu_label;
        }*/
    }
}

