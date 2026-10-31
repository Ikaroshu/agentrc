// A pane's split, zoom and close buttons, drawn over its top-right corner and shown only while the
// pointer is in that corner. Used as the pane header with reveal "hover": the rest of the header is
// left empty, so nothing covers the terminal elsewhere. Props from the app: { pane }.
import { View, div, svg } from "gpui-kit";
import { h_flex } from "gpui-base";
import { panes, props, run, theme } from "herdr";

export default class PaneCorner extends View {
  init() { this.hovered = false; }

  button(t, id, icon, tip, command, args) {
    return div().id(id).p(3).flex_none().rounded(5).text_color(t.dim).tooltip(tip)
      .hover((s) => s.bg(t.hover).text_color(t.foreground))
      .on_click((_e, cx) => { cx.stop_propagation(); run(command, args); })
      .child(svg(`mods/pane/${icon}.svg`).size(14));
  }

  render() {
    const t = theme(), pane = props()?.pane, p = panes().find((x) => x.pane === pane);
    if (!p) return div();
    return h_flex().size_full().justify_end().items_start()
      .child(h_flex().id(`corner-${pane}`).w(132).h_full().pt(6).pr(6).justify_end().items_start()
        .on_hover((hovered, cx) => { this.hovered = hovered; cx.notify(); })
        .when(this.hovered, (el) => el.child(h_flex().gap(2).p(2).rounded(7).bg(t.popover).border(1).border_color(t.border)
          .child(this.button(t, `pc-r-${pane}`, "split-right", "Split right", "pane.split", { direction: "right", pane }))
          .child(this.button(t, `pc-d-${pane}`, "split-down", "Split down", "pane.split", { direction: "down", pane }))
          .child(this.button(t, `pc-z-${pane}`, p.zoomed ? "unzoom" : "zoom", p.zoomed ? "Unzoom" : "Zoom", "pane.zoom", { pane }))
          .child(this.button(t, `pc-x-${pane}`, "close", "Close pane", "pane.close", { pane })))));
  }
}
