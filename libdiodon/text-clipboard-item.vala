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

    private const int LABEL_SIZE = 100;

    /**
     * Represents a text clipboard item holding simple text.
     */
    public class TextClipboardItem : GLib.Object, IClipboardItem
    {
        private string _text;
        private string? _origin;
        private string _label;
        private string _checksum;
        private ClipboardType _clipboard_type;
        private DateTime _date_copied;

        /**
         * Default data constructor needed for reflection.
         *
         * @param clipboard_type clipboard type item is coming from
         * @param data simple text
         * @param origin origin of clipboard item as application path
         */
        public TextClipboardItem(ClipboardType clipboard_type, string data, string? origin, DateTime date_copied, string? checksum = null)
        {
            _clipboard_type = clipboard_type;
            _text = data;
            _origin = origin;
            _date_copied = date_copied;
            _checksum = checksum;
            if(_checksum == null) {
                _checksum = Checksum.compute_for_string(ChecksumType.SHA1, _text);
            }

            
            /*
                Reduce whitespaces from string to squeeze in more of the text content in label.
             */
            StringBuilder label_cpy = new StringBuilder();
            bool in_space = false;
            int byte_index = 0;
            unichar c;


            while (_text.get_next_char(ref byte_index, out c)) {
                if (c.isspace()) {
                    if (!in_space) {
                        label_cpy.append_c(' ');
                        in_space = true;
                    }
                } else {
                    label_cpy.append_unichar(c);
                    in_space = false;
                }

                if (label_cpy.len >= LABEL_SIZE) {
                    break;
                }
            }

            _label = label_cpy.str;            
        }

        /**
	     * {@inheritDoc}
	     */
        public ClipboardType get_clipboard_type()
        {
            return _clipboard_type;
        }

        /**
	     * {@inheritDoc}
	     */
	    public DateTime get_date_copied()
        {
            return _date_copied;
        }

        /**
	     * {@inheritDoc}
	     */
	    public string get_text()
        {
            return _text;
        }

        /**
	     * {@inheritDoc}
	     */
	    public string? get_origin()
        {
            return _origin;
        }

        /**
	     * {@inheritDoc}
	     */
        public string get_label()
        {
            return _label;
        }

        /**
	     * {@inheritDoc}
	     */
        public string get_mime_type()
        {
            return "text/plain";
        }

        /**
	     * {@inheritDoc}
	     */
        public ClipboardCategory get_category()
        {
            return ClipboardCategory.TEXT;
        }

        /**
	     * {@inheritDoc}
	     */
        public Gtk.Image? get_image()
        {
            return null; // no image available for text content
        }

        /**
	     * {@inheritDoc}
	     */
        public Icon get_icon()
        {
            return ContentType.get_icon(get_mime_type());
        }

        /**
	     * {@inheritDoc}
	     */
        public ByteArray? get_payload()
        {
            return null;
        }

        /**
	     * {@inheritDoc}
	     */
        public string get_checksum()
        {
            return _checksum;
        }

        /**
	     * {@inheritDoc}
	     */
        public void to_clipboard(Gtk.Clipboard clipboard)
        {
            clipboard.set_text(_text, -1);
            clipboard.store();
        }

        /**
	     * {@inheritDoc}
	     */
	    public bool equals(IClipboardItem* item)
        {
            bool equals = false;

            if(item is TextClipboardItem) {
                equals = strcmp(_text, item->get_text()) == 0;
            }

            return equals;
        }

        /**
	     * {@inheritDoc}
	     */
	    public uint hash()
        {
            return str_hash(_text);
        }
    }
}
