// The window's top row beside the sidebar: where you are (space › tab, then the pane when the tab
// is split, branch, folder) and the side panel's buttons, which start at the panel's left edge
// while it shows. Tabs live in the sidebar, under their space. Keys bound to `top-bar.<program>` (keys.json) start that agent in a new tab, as the +
// menu does.
import { View, div, svg } from "gpui-kit";
import { h_flex } from "gpui-base";
import { spaces, panes, focused, knownAgents, nextCommand, run, theme, window, layout, shared, home } from "herdr";

// The side panel's views, each with a button here.
const PANELS = [
  { id: "files", label: "Files", icon: "mods/files/file.svg" },
  { id: "graph", label: "Graph", icon: "mods/git-graph/icons/graph.svg" },
  { id: "issues", label: "Issues", icon: "mods/issues/circle-dot.svg" },
];

// What a stored color name looks like on an avatar (the same in every mod
// that draws space avatars): one strong color per hue, light and dark alike.
const MARK = { ansi6: "#22a99a", ansi3: "#e3814f", ansi4: "#5b8def", ansi5: "#8b7cf6", ansi2: "#3fae6a", ansi1: "#d9649a" };

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

// A tab nobody named, or one still named after its program, shows its agent's
// own title, as the sidebar's rows do.
const clean = (s) => (s ?? "").replace(/^[^\p{L}\p{N}]+/u, "").trim();

function lead(tab, all) {
  const mine = all.filter(p => p.tab === tab.id && p.terminal);
  return mine.find(p => p.program?.agent) ?? mine.find(p => p.focused) ?? mine[0];
}

function title(tab, l) {
  const prog = l?.program?.name;
  const live = clean(l?.title);
  const telling = live && live !== prog && !/^[~/]|^[A-Za-z]:\\/.test(live) && !live.includes("@") && live.toLowerCase() !== l?.program?.key;
  if ((!tab.named || tab.name === prog) && telling) return live;
  return /^\d+$/.test(tab.name) ? prog ?? "Terminal" : tab.name;
}

export default class TopBar extends View {
  init(_props, cx) {
    this.panels = JSON.parse(localStorage.getItem("panels") ?? "{}");
    cx.spawn(async () => {
      for (;;) {
        const key = await nextCommand();
        const space = spaces().find(s => s.active);
        const agent = (await knownAgents({ on: space?.machine })).find(a => a.key === key);
        run("tab.new", { name: agent.name, space: space?.id, argv: agent.run });
      }
    });
  }

  // The side panel is remembered per space: switching shows that space's choice
  // (closed if it never had one), and opening or closing it records it.
  syncPanel(space, panel, body) {
    if (!space || !panel) return;
    const now = panel.hidden ? null : body?.active ?? null;
    if (space.id !== this.space) {
      const first = this.space === undefined;
      this.space = space.id; this.pending = null;
      if (!(first && !(space.id in this.panels))) {
        const stored = this.panels[space.id] ?? null, want = PANELS.some(p => p.id === stored) ? stored : null;
        if (want !== now) {
          this.pending = { want, until: Date.now() + 1000 };
          if (want) { run("layout.select", { stack: "panel-body", child: want }); run("layout.show", { id: "panel" }); }
          else run("layout.hide", { id: "panel" });
          return;
        }
      }
    }
    // Until the restore lands (or something else won), the old state isn't a choice.
    if (this.pending) {
      if (this.pending.want !== now && Date.now() < this.pending.until) return;
      this.pending = null;
    }
    if (this.panels[space.id] === now) return;
    this.panels[space.id] = now;
    localStorage.setItem("panels", JSON.stringify(this.panels));
  }

  // Space › tab (› pane, when split), then the branch and folder of the focused pane (a mod pane,
  // such as the file viewer, has neither: its tab's first terminal's). A space showing its
  // placeholder tab (space-empty, see spaces-card) has no tabs to name.
  where(space, t) {
    const all = panes(), f = focused(), shown = space.tabs.find(c => c.active);
    const tab = all.some(p => p.tab === shown?.id && p.mod === "space-empty") ? null : shown;
    const pane = all.find(p => p.pane === f?.pane && p.terminal) ?? all.find(p => p.tab === tab?.id && p.terminal);
    const cur = tab?.panes > 1 ? all.find(p => p.pane === f?.pane) : null;
    const paneName = cur && (((cur.program?.agent || cur.program?.shell) && cur.program.name) || cur.title || cur.program?.name);
    const color = (shared("space.colors") ?? {})[space.id] ?? "ansi6";
    const fill = color.startsWith("#") ? color : (MARK[color] ?? t[color]);
    const folder = pane?.cwd && !space.machine && pane.cwd.startsWith(home()) ? `~${pane.cwd.slice(home().length)}` : pane?.cwd;
    return h_flex().flex_1().min_w(0).gap(8).items_center().text_size(12.8)
      .when(Boolean(space.machine), el => el.child(h_flex().flex_none().gap(5).items_center().text_color(t.muted)
        .child(svg("mods/workspace-chrome/server.svg").size(13)).child(space.machine))
        .child(div().flex_none().text_color(t.dim).child("›")))
      .child(h_flex().size(16).flex_none().rounded(4.5).bg(fill).items_center().justify_center().text_size(9.5).font_bold().text_color("#ffffff").child(space.name[0]?.toUpperCase() ?? "?"))
      .child(div().flex_shrink(0).max_w(160).truncate().text_color(t.foreground).font_medium().child(space.name))
      .when(Boolean(tab), el => el.child(div().flex_none().text_color(t.dim).child("›"))
        .child(div().flex_shrink(0).max_w(260).truncate().text_color(t.foreground).child(title(tab, lead(tab, all)))))
      .when(Boolean(paneName), el => el.child(div().flex_none().text_color(t.dim).child("›"))
        .child(div().flex_shrink(0).max_w(160).truncate().text_color(t.muted).child(paneName)))
      .when(Boolean(pane?.branch), el => el.child(h_flex().flex_none().ml(6).gap(5).items_center().text_size(11.5).text_color(t.muted)
        .child(svg("mods/workspace-chrome/branch.svg").size(12)).child(pane.branch)))
      .when(Boolean(folder), el => el.child(div().min_w(0).ml(6).truncate().text_size(11.5).text_color(t.dim).child(folder)));
  }

  render() {
    const t = theme();
    const space = spaces().find(p => p.active);
    const stop = (_e, cx) => cx.stop_propagation();
    const button = (id, label, action) => div().id(id).size(26).flex_none().flex().items_center().justify_center().rounded(6).text_color(t.dim).hover(s => s.bg(t.hover).text_color(t.foreground))
      .on_mouse_down("left", stop).on_click(action).child(label);
    const panel = find(layout(), "panel"), body = find(layout(), "panel-body");
    this.syncPanel(space, panel, body);
    const panelButton = ({ id, label, icon }) => {
      const on = panel && !panel.hidden && body?.active === id;
      return h_flex().id(`panel-${id}`).h(20).px(7).gap(5).flex_none().items_center().rounded(6)
        .text_size(12).bg(on ? t.selected : t.canvas).text_color(on ? t.foreground : t.muted)
        .hover(s => s.bg(t.hover)).on_mouse_down("left", stop)
        .on_click(() => {
          if (on) run("layout.hide", { id: "panel" });
          else { run("layout.select", { stack: "panel-body", child: id }); run("layout.show", { id: "panel" }); }
        }).child(svg(icon).size(14)).child(label);
    };
    // The panel's width as the layout draws it: a saved drag width is held to its min and max.
    const open = panel && !panel.hidden;
    const width = open ? Math.min(panel.max ?? Infinity, Math.max(panel.min ?? 0, panel.size?.px ?? 0)) : 0;
    return h_flex().size_full().min_w(0).pl(2).pr(open ? 0 : 2).gap(12).items_center()
      .child(space ? this.where(space, t) : div().flex_1())
      .child(h_flex().flex_none().gap(3).items_center().when(open, el => el.w(width).pl(2))
        .children(PANELS.map(panelButton))
        .when(window()?.buttons, el => el.child(div().flex_1()).child(button("minimize", "−", () => run("window.minimize")))
          .child(button("maximize", "□", () => run("window.maximize")))
          .child(button("close-window", svg("mods/pane/close.svg").size(13), () => run("window.close")))));
  }
}
