// Switches the sidebar's stack between spaces and agents, files, and changes. The layout remembers
// the choice; icons only while the sidebar is collapsed.
import { div, svg, View } from "gpui-kit";
import { h_flex } from "gpui-base";
import { layout, run, shared, theme } from "herdr";

const STACK = "sidebar-body";
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
    const t = theme(), active = find(layout(), STACK)?.active, collapsed = shared("sidebar.collapsed") === true;
    return h_flex().size_full().px(8).gap(4).items_center().when(collapsed, el => el.flex_col().px(6).py(4))
      .children(TABS.map(tab => {
        const on = tab.id === active;
        return h_flex().id(`sidebar-tab-${tab.id}`).flex_1().h(28).px(8).gap(6).items_center().justify_center().rounded(7).text_size(12.5)
          .bg(on ? t.selected : t.canvas).text_color(on ? t.foreground : t.muted).hover(s => s.bg(t.hover).text_color(t.foreground))
          .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
          .on_click(() => run("layout.select", { stack: STACK, child: tab.id }))
          .child(svg(tab.icon).size(14).flex_none())
          .when(!collapsed, el => el.child(div().truncate().child(tab.label)));
      }));
  }
}
