// Switches the sidebar's stack between spaces and agents, files, and changes, on the window's top
// row beside the macOS window buttons. The layout remembers the choice.
import { div, svg, View } from "gpui-kit";
import { h_flex } from "gpui-base";
import { layout, run, theme, window } from "herdr";

const STACK = "sidebar-body", ICON_TAB = 84;
const TABS = [
  { id: "sidebar-lists", label: "Spaces", icon: "mods/workspace-chrome/layers.svg" },
  { id: "files", label: "Files", icon: "mods/workspace-chrome/files.svg" },
  { id: "changes", label: "Changes", icon: "mods/workspace-chrome/git-compare.svg" },
];

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

export default class SidebarTabs extends View {
  render() {
    const t = theme(), active = find(layout(), STACK)?.active, mac = window()?.platform === "macos";
    // Three equal tabs fill the row; icons join the labels only when each tab has room for both.
    const icons = this.width !== undefined && (this.width - (mac ? 72 : 8) - 8 - 6) / 3 >= ICON_TAB;
    return h_flex().id("sidebar-tabs").size_full().px(8).gap(3).items_center().when(mac, el => el.pl(72))
      .on_size_change((size, cx) => { if (size.width !== this.width) { this.width = size.width; cx.notify(); } })
      .children(TABS.map(tab => {
        const on = tab.id === active;
        return h_flex().id(`sidebar-tab-${tab.id}`).flex_1().min_w(0).h(29).px(4).gap(5).items_center().justify_center().rounded(7).text_size(12.5)
          .border(1).border_color(on ? t.border : t.canvas).bg(on ? t.raised : t.canvas).text_color(on ? t.foreground : t.muted)
          .hover(s => s.bg(t.hover).text_color(t.foreground))
          .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
          .on_click(() => run("layout.select", { stack: STACK, child: tab.id }))
          .when(icons, el => el.child(svg(tab.icon).size(14).flex_none()))
          .child(div().truncate().child(tab.label));
      }));
  }
}
