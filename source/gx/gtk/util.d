/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.gtk.util;

import std.conv;
import std.experimental.logger;
import std.file;
import std.format;
import std.path;

import gdk.RGBA;
import gdk.Screen;

import gio.File: GFile = File;
import gio.Resource;

import glib.ListG;
import glib.Util;

import gobject.ObjectG;

import gtk.ComboBox;
import gtk.CellRendererText;
import gtk.Container;
import gtk.CssProvider;
import gtk.Entry;
import gtk.ListStore;
import gtk.MessageDialog;
import gtk.StyleContext;
import gtk.TreeIter;
import gtk.TreeModelIF;
import gtk.TreePath;
import gtk.TreeStore;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.Widget;
import gtk.Window;

void showErrorDialog(Window parent, string message, string title = null) {
	MessageDialog dialog = new MessageDialog(parent, DialogFlags.MODAL + DialogFlags.USE_HEADER_BAR, MessageType.ERROR, ButtonsType.OK, message, null);
	scope (exit) {
		dialog.destroy();
	}
	if (title.length > 0)
        dialog.setTitle(title);
    dialog.run();        
}

bool showInputDialog(Window parent, out string value, string initialValue = null, string title = null, string message = null) {
	MessageDialog dialog = new MessageDialog(parent, DialogFlags.MODAL + DialogFlags.USE_HEADER_BAR, MessageType.QUESTION, ButtonsType.OK_CANCEL, message, null);
	dialog.setTitle(title);
	Entry entry = new Entry(initialValue);
	entry.addOnActivate(delegate(Entry) { dialog.response(ResponseType.OK); });
	dialog.getMessageArea().add(entry);
	entry.showAll();
	dialog.setDefaultResponse(ResponseType.OK);
	scope (exit) {
		dialog.destroy();
	}
	if (dialog.run() == ResponseType.OK) {
		value = entry.getText();
		return true;
	} else {
		return false;
	}
}

/**
 * Defined here since not defined in GtkD
 */
enum ProviderPriority : uint {
    FALLBACK = 1,
    THEME = 200,
    SETTINGS =  400,
    APPLICATION = 600,
    USER = 800
}

/**
 * Defined here since not defined in GtkD
 */
enum MouseButton : uint {
	PRIMARY = 1,
	MIDDLE = 2,
	SECONDARY = 3
}

/**
 * Compares two RGBA and returns if they are equal, supports null references
 */
bool equal(RGBA r1, RGBA r2) {
	if (r1 is null && r2 is null)
		return true;
	if ((r1 is null && r2 !is null) || (r1 !is null && r2 is null))
		return false;
	return r1.equal(r2);
}

/**
 * Converts an RGBA structure to a 8 bit HEX string, i.e #2E3436
 *
 * Params:
 * RGBA	 = The color to convert 
 * includeAlpha = Whether to include the alpha channel
 * includeHash = Whether to preface the color string with a # 
 */
string rgbaTo8bitHex(RGBA color, bool includeAlpha = false, bool includeHash = false) {
	string prepend = includeHash ? "#" : "";
	int red = to!(int)(color.red() * 255);
	int green = to!(int)(color.green() * 255);
	int blue = to!(int)(color.blue() * 255);
	if (includeAlpha) {
		int alpha = to!(int)(color.alpha() * 255);
		return prepend ~ format("%02X%02X%02X%02X", red, green, blue, alpha);
	} else {
		return prepend ~ format("%02X%02X%02X", red, green, blue);
	}
}

/**
 * Converts an RGBA structure to a 16 bit HEX string, i.e #2E2E34343636
 * Right now this just takes an 8 bit string and repeats each channel
 *
 * Params:
 * RGBA	 = The color to convert 
 * includeAlpha = Whether to include the alpha channel
 * includeHash = Whether to preface the color string with a # 
 */
string rgbaTo16bitHex(RGBA color, bool includeAlpha = false, bool includeHash = false) {
	string prepend = includeHash ? "#" : "";
	int red = to!(int)(color.red() * 255);
	int green = to!(int)(color.green() * 255);
	int blue = to!(int)(color.blue() * 255);
	if (includeAlpha) {
		int alpha = to!(int)(color.alpha() * 255);
		return prepend ~ format("%02X%02X%02X%02X%02X%02X%02X%02X", red, red, green, green, blue, blue, alpha, alpha);
	} else {
		return prepend ~ format("%02X%02X%02X%02X%02X%02X", red, red, green, green, blue, blue);
	}
}

Resource findResource(string resourcePath, bool register = true) {
	foreach (path; Util.getSystemDataDirs()) {
		auto fullpath = buildPath(path, resourcePath);
		trace("looking for resource " ~ fullpath);
		if (exists(fullpath)) {
			Resource resource = Resource.load(fullpath);
			if (register && resource) {
				trace("Resource found and registered " ~ fullpath);
				Resource.register(resource);
			}
            return resource;
		}
	}
    error(format("Resource %s could not be found", resourcePath));
	return null;
}

bool addCssProvider(string filename) {
    CssProvider provider = new CssProvider();
    if (provider.loadFromFile(GFile.parseName(filename))) {
        StyleContext.addProviderForScreen(Screen.getDefault(), provider, ProviderPriority.APPLICATION);
        return true;
    }
    return false;
}

/**
 * Given a pointer to GtkWidget, returns the existing
 * D object allocated for the struct. If none exists, one
 * is created
 */
Widget getWidget(GtkWidget* p) {
	return ObjectG.getDObject!(Widget)(p);
}

/**
 * Returns an aray of widgets held in the list.
 * This attempts to get the existing D Object rather
 * then creating a new reference.
 *
 * Params:
 * list = A ListG object with a list of widgets
 */
Widget[] getWidgets(ListG list) {
	Widget[] result = new Widget[list.length()];
	size_t count;

	while (list !is null && count < list.length) {
		result[count] = getWidget(cast(GtkWidget*) list.data);
		list = list.next();
		count++;
	}
	return result;
}

/**
 * Returns a list of all children of a container. This differs
 * from ListG.toArray!Widget() in that it attempts to get the
 * existing D object for a Widget rather then creating a new reference
 */
Widget[] getChildren(Container container) {
	ListG list = container.getChildren();
    return getWidgets(list);
}

/**
 * Appends multiple values to a row in a list store
 */
TreeIter appendValues(TreeStore ts, TreeIter parentIter, string[] values) {
	TreeIter iter = ts.createIter(parentIter);
	for (int i = 0; i < values.length; i++) {
		ts.setValue(iter, i, values[i]);
	}
    return iter;
}

/**
 * Appends multiple values to a row in a list store
 */
TreeIter appendValues(ListStore ls, string[] values) {
	TreeIter iter = ls.createIter();
	for (int i = 0; i < values.length; i++) {
		ls.setValue(iter, i, values[i]);
	}
    return iter;
}

/**
 * Creates a combobox that holds a set of name/value pairs
 * where the name is displayed.
 */
ComboBox createNameValueCombo(const string[] names, const string[] values) {
	assert(names.length == values.length);

	ListStore ls = new ListStore([GType.STRING, GType.STRING]);

	for (int i = 0; i < names.length; i++) {
		appendValues(ls, [names[i], values[i]]);
	}

	ComboBox cb = new ComboBox(ls, false);
	cb.setFocusOnClick(false);
	cb.setIdColumn(1);
	CellRendererText cell = new CellRendererText();
	cell.setAlignment(0, 0);
	cb.packStart(cell, false);
	cb.addAttribute(cell, "text", 0);

	return cb;
}

/**
 * Selects the specified row in a Treeview
 */
void selectRow(TreeView tv, int row, TreeViewColumn column = null) {
	TreeModelIF model = tv.getModel();
	TreeIter iter;
	model.iterNthChild(iter, null, row);
	if (iter !is null) {
		tv.setCursor(model.getPath(iter), column, false);
	} else {
		trace(format("No TreeIter found for row %d", row));
	}
}

/**
 * An implementation of a range that allows using foreach over a range
 */
struct TreeIterRange {

private:
	TreeModelIF model;
	TreeIter iter;
	bool _empty;

public:
	this(TreeModelIF model) {
		this.model = model;
		_empty = model.getIterFirst(iter);
	}

	@property bool empty() {
		return _empty;
	}

	@property auto front() {
		return iter;
	}

	void popFront() {
		_empty = !model.iterNext(iter);
	}

	/**
     * Based on the example here https://www.sociomantic.com/blog/2010/06/opapply-recipe/#.Vm8mW7grKEI
     */
	int opApply(int delegate(ref TreeIter iter) dg) {
		int result = 0;
		TreeIter iter;
		bool hasNext = model.getIterFirst(iter);
		while (hasNext) {
			result = dg(iter);
			if (result)
				break;
			hasNext = model.iterNext(iter);
		}
		return result;
	}
}