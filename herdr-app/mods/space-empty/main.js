// The only pane of a space's hidden placeholder tab (see spaces-card), shown once the space has no
// other tabs: buttons start a terminal, Claude or Codex in a new tab, as Cmd-T and the top bar's
// keys do.
import { View, div, svg, image } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { theme, spaces, knownAgents, run } from "herdr";

const AGENTS = ["claude", "codex"];

export default class SpaceEmpty extends View {
  init(_props, cx) {
    this.icons = {};
    cx.spawn(async (cx) => {
      const machine = spaces().find((s) => s.active)?.machine;
      for (const a of await knownAgents({ on: machine })) if (AGENTS.includes(a.key)) this.icons[a.key] = a;
      cx.notify();
    });
  }

  button(t, id, icon, label, command) {
    return h_flex().id(`empty-${id}`).h(48).px(20).gap(10).items_center().rounded(10).cursor_pointer()
      .border(1).border_color(t.border).text_color(t.foreground)
      .hover((s) => s.bg(t.hover))
      .on_click(() => run(command))
      .child(icon).child(label);
  }

  agentIcon(t, key) {
    const a = this.icons[key];
    if (!a?.icon) return div().size(20);
    return a.tint ? svg(a.icon).size(20).text_color(t.foreground) : image(a.icon).size(20);
  }

  render() {
    const t = theme();
    return v_flex().size_full().bg(t.background).items_center().justify_center().text_size(15)
      .child(h_flex().gap(12)
        .child(this.button(t, "terminal", svg("icons/shell.svg").size(20).text_color(t.foreground), "Terminal", "tab.new"))
        .child(this.button(t, "claude", this.agentIcon(t, "claude"), "Claude", "top-bar.claude"))
        .child(this.button(t, "codex", this.agentIcon(t, "codex"), "Codex", "top-bar.codex")));
  }
}
