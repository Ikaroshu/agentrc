// The Files panel's right-click menu. Props: { items: ([label, command] | null)[], overlay }; null
// draws a separator. Choosing an item runs its command (a `files-plus.<action>`); Enter chooses,
// Esc closes.
import { View, div } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { run, props, closeOverlay, theme } from "herdr";

const ROW = 31; // files-plus sizes the popup from this and the 9 px separators

export default class FilesMenu extends View {
  init(_props, cx) {
    this.at = 0;
    this.handle = cx.focus_handle();
    this.handle.focus();
  }

  choose(command) {
    closeOverlay(props().overlay);
    run(command);
  }

  render() {
    const t = theme(), items = props()?.items ?? [], commands = items.filter(Boolean);
    return v_flex().id("files-menu").track_focus(this.handle).w_full().min_h(0).p(5).bg(t.popover).text_size(12.8)
      .on_key_down((e, cx) => {
        if (e.key === "down") this.at = (this.at + 1) % commands.length;
        else if (e.key === "up") this.at = (this.at + commands.length - 1) % commands.length;
        else if (e.key === "enter") this.choose(commands[this.at][1]);
        else if (e.key === "escape") closeOverlay(props().overlay);
        else return;
        cx.notify();
      })
      .children(items.map((it) => it === null
        ? div().mx(7).my(4).h(1).flex_none().bg(t.border)
        : h_flex().id(`fm-${it[1]}`).h(ROW).flex_none().px(8).rounded(7).items_center().text_color(t.foreground)
          .when(commands.indexOf(it) === this.at, (el) => el.bg(t.selected))
          .hover((s) => s.bg(t.hover))
          .on_click(() => this.choose(it[1]))
          .child(it[0])));
  }
}
