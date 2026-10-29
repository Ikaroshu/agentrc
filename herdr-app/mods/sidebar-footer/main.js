// The sidebar's footer: the shipped workspace-chrome footer without "Add machine".
import { div, svg } from "gpui-kit";
import { View } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { theme, run, shared, updates } from "herdr";

export default class SidebarFooter extends View {
  render() {
    const t = theme(), collapsed = shared("sidebar.collapsed") === true;
    return v_flex().size_full().bg(t.chrome).px(8).pt(4).pb(8).text_size(13)
      .child(h_flex().id("settings").h(28).px(8).gap(9).items_center().rounded(8)
        .text_color(t.muted).hover(s => s.bg(t.hover).text_color(t.foreground)).cursor_pointer()
        .on_click(() => run("app.settings")).child(svg("mods/workspace-chrome/settings.svg").size(14))
        .when(!collapsed, el => el.child("Settings"))
        .when(Boolean(updates().app.ready), el => el.child(div().size(6).rounded_full().bg(t.accent))));
  }
}
