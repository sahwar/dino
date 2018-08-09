using Gtk;
using Qlite;

namespace Dino.Plugins.Omemo {

[GtkTemplate (ui = "/im/dino/Dino/omemo/manage_key_dialog.ui")]
public class ManageKeyDialog : Gtk.Dialog {

    [GtkChild] private Stack manage_stack;

    [GtkChild] private Button cancel_button;
    [GtkChild] private Button ok_button;

    [GtkChild] private Box main_screen;
    [GtkChild] private Label main_desc;
    [GtkChild] private ListBox main_action_list;

    [GtkChild] private Box confirm_screen;
    [GtkChild] private Image confirm_image;
    [GtkChild] private Label confirm_title;
    [GtkChild] private Label confirm_desc;

    [GtkChild] private Box verify_screen;
    [GtkChild] private Label verify_label;
    [GtkChild] private Button verify_yes;
    [GtkChild] private Button verify_no;

    private Row device;
    private Database db;

    private bool return_to_main;
    private int current_response;

    public ManageKeyDialog(Row device, Database db) {
        Object(use_header_bar : 1); 

        this.device = device;
        this.db = db;

        setup_main_screen();
        setup_verify_screen();

        cancel_button.clicked.connect(handle_cancel);
        ok_button.clicked.connect(() => {
            response(current_response);
            close();
        });

        verify_yes.clicked.connect(() => {
            confirm_image.set_from_icon_name("security-high-symbolic", IconSize.DIALOG);
            confirm_title.label = "Verify key";
            confirm_desc.set_markup(@"Once confirmed, any future messages sent by <b>$(device[db.identity_meta.address_name])</b> using this key will be highlighted accordingly in the chat window.");
            manage_stack.set_visible_child_name("confirm");
            ok_button.sensitive = true;
            return_to_main = false;
            current_response = Database.IdentityMetaTable.TrustLevel.VERIFIED;
        });

        verify_no.clicked.connect(() => {
            return_to_main = false;
            confirm_image.set_from_icon_name("dialog-warning-symbolic", IconSize.DIALOG);
            confirm_title.label = "Fingerprints do not match";
            confirm_desc.set_markup(@"Please verify that you are comparing the correct fingerprint. If fingerprints do not match <b>$(device[db.identity_meta.address_name])</b>'s account may be compromised and you should consider rejecting this key.");
            manage_stack.set_visible_child_name("confirm");
        });
    }

    private void handle_cancel() {
        if (manage_stack.get_visible_child_name() == "main") close();

        if (manage_stack.get_visible_child_name() == "verify") {
            manage_stack.set_visible_child_name("main");
            cancel_button.label = "Cancel";
        }

        if (manage_stack.get_visible_child_name() == "confirm") {
            if (return_to_main) {
                manage_stack.set_visible_child_name("main");
                cancel_button.label = "Cancel";
            } else {
                manage_stack.set_visible_child_name("verify");
            }
        }

        ok_button.sensitive = false;
    }

    private Box make_action_box(string title, string desc){
        Box box = new Box(Orientation.VERTICAL, 0) { visible = true, margin_start = 20, margin_end = 20, margin_top = 14, margin_bottom = 14 }; 
        Label lbl_title = new Label(title) { visible = true, halign = Align.START };
        Label lbl_desc = new Label(desc) { visible = true, xalign = 0, wrap = true, max_width_chars = 40 };

        Pango.AttrList title_attrs = new Pango.AttrList();
        title_attrs.insert(Pango.attr_scale_new(1.1));
        lbl_title.attributes = title_attrs;
        Pango.AttrList desc_attrs = new Pango.AttrList();
        desc_attrs.insert(Pango.attr_scale_new(0.8));
        lbl_desc.attributes = desc_attrs;
        lbl_desc.get_style_context().add_class("dim-label");

        box.add(lbl_title);
        box.add(lbl_desc);

        return box;
    }   

    private Box make_trust_screen(string icon_name, string title, string desc) {
        Box box = new Box(Orientation.VERTICAL, 12) { margin = 12, spacing = 12 };
        Image icon = new Image.from_icon_name(icon_name, IconSize.DIALOG) { visible = true };
        box.add(icon);
        Label lbl_title = new Label(title) { visible = true };
        Label lbl_desc = new Label(desc) { visible = true, use_markup = true, max_width_chars = 1, wrap = true, justify = Justification.CENTER };

        Pango.AttrList title_attrs = new Pango.AttrList();
        title_attrs.insert(Pango.attr_scale_new(1.1));
        lbl_title.attributes = title_attrs;
        Pango.AttrList desc_attrs = new Pango.AttrList();
        desc_attrs.insert(Pango.attr_scale_new(0.8));
        lbl_desc.attributes = desc_attrs;
        lbl_desc.get_style_context().add_class("dim-label");

        box.add(lbl_title);
        box.add(lbl_desc);

        return box;
    }

    private void setup_main_screen() {
        main_action_list.set_header_func((row, before_row) => {
            if (row.get_header() == null && before_row != null) {
                row.set_header(new Separator(Orientation.HORIZONTAL));
            }
        });

        ListBoxRow verify = new ListBoxRow() { visible = true };
        verify.add(make_action_box("Verify Key Fingerprint", "Compare this key's fingerprint with the fingerprint displayed on the contact's device."));
        ListBoxRow reject = new ListBoxRow() { visible = true };
        reject.add(make_action_box("Reject Key", "Stop accepting this key during communication with its associated contact."));
        ListBoxRow accept = new ListBoxRow() {visible = true };
        accept.add(make_action_box("Accept Key", "Start accepting this key during communication with its assoicated contact"));

        switch((Database.IdentityMetaTable.TrustLevel) device[db.identity_meta.trust_level]) {
            case Database.IdentityMetaTable.TrustLevel.TRUSTED:
                main_desc.set_markup(@"This key is currently <span color='#1A63D9'>accepted</span>. This means it can be used by <b>$(device[db.identity_meta.address_name])</b> to receive and send messages.");
                main_action_list.add(verify);
                main_action_list.add(reject);
                break;
            case Database.IdentityMetaTable.TrustLevel.VERIFIED:
                main_desc.set_markup(@"This key is currently <span color='#1A63D9'>verified</span>. This means it can be used by <b>$(device[db.identity_meta.address_name])</b> to receive and send messages. Additionaly it has been verified out-of-band to match the key on the contact's device.");
                main_action_list.add(reject);
                break;
            case Database.IdentityMetaTable.TrustLevel.UNTRUSTED:
                main_desc.set_markup(@"This key is currently <span color='#D91900'>rejected</span>. This means it cannot be used by <b>$(device[db.identity_meta.address_name])</b> to receive messages, and any messages sent by it will be ignored");
                main_action_list.add(accept);
                break;
        }

        main_action_list.row_activated.connect((row) => {
            if(row == verify) {
                manage_stack.set_visible_child_name("verify");
            } else if (row == reject) {
                confirm_image.set_from_icon_name("action-unavailable-symbolic", IconSize.DIALOG);
                confirm_title.label = "Reject key";
                confirm_desc.set_markup(@"Once confirmed, any future messages sent by <b>$(device[db.identity_meta.address_name])</b> using this key will be ignored and none of your messages will be readable using this key.");
                manage_stack.set_visible_child_name("confirm");
                ok_button.sensitive = true;
                return_to_main = true;
                current_response = Database.IdentityMetaTable.TrustLevel.UNTRUSTED;
            } else if (row == accept) {
                confirm_image.set_from_icon_name("emblem-ok-symbolic", IconSize.DIALOG);
                confirm_title.label = "Accept key";
                confirm_desc.set_markup(@"Once confirmed this key will be usable by <b>$(device[db.identity_meta.address_name])</b> to receive and send messages.");
                manage_stack.set_visible_child_name("confirm");
                ok_button.sensitive = true;
                return_to_main = true;
                current_response = Database.IdentityMetaTable.TrustLevel.TRUSTED;
            }
            cancel_button.label = "Back";
        });

        manage_stack.set_visible_child_name("main");
    }

    private void setup_verify_screen() {
        verify_label.set_markup(fingerprint_markup(fingerprint_from_base64(device[db.identity_meta.identity_key_public_base64])));
    }
}

}
