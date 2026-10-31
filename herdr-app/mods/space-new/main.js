// Asks where a new space lives before making it: a folder typed on its machine ("~" is that
// machine's home; relative paths start there), or one chosen in the system picker on this
// computer. Props: { machine?, overlay }. Enter creates, Esc cancels.
import { View, div } from "gpui-kit";
import { v_flex, h_flex, InputState, Input } from "gpui-base";
import { run, props, closeOverlay, theme, exec, pickFolder } from "herdr";

// Prints the folder's absolute path, or fails when there is no such folder.
const RESOLVE = 'p=$1; case $p in "~"|"~/"*) p=$HOME${p#"~"};; esac; cd -- "$p" 2>/dev/null && pwd';

export default class SpaceNew extends View {
  init(_props, cx) {
    this.input = InputState.new({ value: "~/" });
    this.input.set_selected_range({ start: 2, end: 2 });
    this.input.on("change", (_e, cx) => { this.missing = null; cx.notify(); });
    this.input.on("submit", (_e, cx) => this.submit(cx));
    this.input.focus();
    cx.timer.after(600, () => this.input.focus());
    this.handle = cx.focus_handle();
  }

  create(folder) {
    const { machine, overlay } = props();
    closeOverlay(overlay);
    run("space.new", machine ? { folder, machine } : { folder });
  }

  submit(cx) {
    const typed = this.input.value().trim() || "~";
    cx.spawn(async (cx) => {
      const r = await exec("sh", ["-c", RESOLVE, "sh", typed], { on: props().machine ?? null });
      if (r.code === 0) this.create(r.stdout.trim());
      else { this.missing = typed; cx.notify(); }
    });
  }

  choose(cx) {
    cx.spawn(async () => {
      const folder = await pickFolder({ prompt: "Create Space" });
      if (folder) this.create(folder);
    });
  }

  key(e, cx) {
    if (e.key === "escape") { closeOverlay(props().overlay); cx.stop_propagation(); }
  }

  render() {
    const t = theme(), { machine, overlay } = props() ?? {};
    const button = (id, text, primary, action) => h_flex().id(id).h(32).px(14).items_center().rounded(8)
      .border_1().border_color(primary ? t.solid : t.input).bg(primary ? t.solid : t.raised)
      .text_color(primary ? t.solid_foreground : t.foreground).text_size(12.5).font_medium().cursor_pointer()
      .hover((s) => s.opacity(0.88)).on_click(action).child(text);
    const hint = this.missing ? `No folder ${this.missing} on ${machine ?? "this computer"}` : `A folder on ${machine ?? "this computer"}`;
    return v_flex().id("space-new").track_focus(this.handle).on_key_down((e, cx) => this.key(e, cx))
      .w_full().min_h(0).p(18).bg(t.popover).text_color(t.foreground)
      .child(h_flex().items_center().child(div().flex_1().text_size(15).font_semibold().child(machine ? `New space on ${machine}` : "New space"))
        .child(div().text_size(11).text_color(t.dim).child("Esc")))
      .child(div().pt(16).pb(7).text_size(11.5).text_color(t.dim).child("Folder"))
      .child(Input.new(this.input).h(36).px(10).rounded(9).border_1().border_color(this.missing ? t.ansi1 : t.accent).bg(t.background).text_size(12.8).text_color(t.foreground))
      .child(div().pt(6).text_size(11.5).text_color(this.missing ? t.ansi1 : t.dim).child(hint))
      .child(h_flex().pt(20).gap(8)
        .when(!machine, (el) => el.child(button("sn-choose", "Choose…", false, (_e, cx) => this.choose(cx))))
        .child(div().flex_1())
        .child(button("sn-cancel", "Cancel", false, () => closeOverlay(overlay)))
        .child(button("sn-create", "Create", true, (_e, cx) => this.submit(cx))));
  }
}
