// The only pane of a space's hidden placeholder tab (see spaces-card), shown when you click the space
// or close its last tab. A row of buttons starts a terminal, Claude, Codex or Pi in a new tab, as
// Cmd-T, Cmd-Shift-C and Cmd-Shift-X do; under it, a card per tab in the space, the ones that need
// you first, each with the end of its screen; on hover, × closes it. With no tabs, only the buttons.
import { View, div, svg, image } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { theme, spaces, panes, agents, knownAgents, run, hc, shared, settings, home } from "herdr";

const STARTS = [["claude", "Claude"], ["codex", "Codex"], ["pi", "Pi"]];
const EMPTY = "space-empty";
const SNAPSHOT_LINES = 8;
const CONTENT_MAX_W = 1080;
const COLUMN_MAX_W = 640;
// Screens are reread this often, only while the page shows: a hidden copy isn't rendered.
const REFRESH_MS = 3000;
const ORDER = { blocked: 0, working: 1, done: 2, idle: 3 };

// A tab reads as the sidebar shows it (spaces-card): its name when someone named it, else its
// agent's own title; an automatic number reads as its program.
const clean = (s) => (s ?? "").replace(/^[^\p{L}\p{N}]+/u, "").trim();

function lead(tab, all) {
  const mine = all.filter((p) => p.tab === tab.id && p.terminal);
  return mine.find((p) => p.program?.agent) ?? mine.find((p) => p.focused) ?? mine[0];
}

function title(tab, l) {
  const prog = l?.program?.name;
  const live = clean(l?.title);
  const telling = live && live !== prog && !/^[~/]|^[A-Za-z]:\\/.test(live) && !live.includes("@") && live.toLowerCase() !== l?.program?.key;
  if ((!tab.named || tab.name === prog) && telling) return live;
  return /^\d+$/.test(tab.name) ? prog ?? "Terminal" : tab.name;
}

// The last lines with something on them. An agent's input box and footer sit under its last
// horizontal rule or prompt line near the bottom (Claude and Pi draw rules, Codex a › prompt).
// Prompt icons from Nerd Fonts (private-use code points) go, with the space after each: the card's
// font has none of them, and drawing has no fallback font.
const ICON = /[\u{E000}-\u{F8FF}\u{F0000}-\u{10FFFD}] ?/gu;

function snapshot(text, agent) {
  let lines = text.split("\n").map((l) => l.replace(ICON, "").trimEnd()).filter(Boolean);
  if (agent) {
    const tail = lines.length - SNAPSHOT_LINES;
    const cut = lines.findIndex((l, i) => i >= tail && /^\s*(─{10,}|[›❯](\s|$))/.test(l));
    if (cut >= 0) lines = lines.slice(0, cut);
  }
  return lines.slice(-SNAPSHOT_LINES);
}

const tilde = (path) => (path.startsWith(home()) ? "~" + path.slice(home().length) : path);

function duration(ms) {
  const m = Math.floor(ms / 60000);
  if (m < 1) return "<1m";
  if (m < 60) return `${m}m`;
  const h = Math.floor(m / 60);
  return h < 24 ? `${h}h` : `${Math.floor(h / 24)}d`;
}

function icon(p, size, color) {
  if (!p?.icon) return null;
  return p.tint ? svg(p.icon).size(size).flex_none().text_color(color) : image(p.icon).size(size).flex_none();
}

export default class SpaceEmpty extends View {
  init(_props, cx) {
    this.icons = {};
    this.screens = {}; // terminal -> its snapshot lines
    this.readAt = 0;
    cx.timer.every(REFRESH_MS, (cx) => cx.notify());
    cx.spawn(async (cx) => {
      const machine = spaces().find((s) => s.active)?.machine;
      for (const a of await knownAgents({ on: machine })) this.icons[a.key] = a;
      cx.notify();
    });
  }

  refresh(space, cards, cx) {
    this.readAt = Date.now();
    cx.spawn(async (cx) => {
      await Promise.all(cards.filter((c) => c.lead).map(async ({ lead: l }) => {
        const r = await hc(["read", space.machine ? `${space.machine}/${l.terminal}` : l.terminal]);
        if (r.code === 0) this.screens[l.terminal] = snapshot(r.stdout, l.program?.agent);
      }));
      cx.notify();
    });
  }

  startButton(t, id, pic, label, argv) {
    return h_flex().id(`empty-${id}`).w(132).h(48).gap(10).rounded(10).items_center().justify_center().cursor_pointer().flex_none()
      .text_size(14).border(1).border_color(t.border).text_color(t.foreground)
      .hover((s) => s.bg(t.hover))
      .on_click(() => run("tab.new", argv ? { argv } : {}))
      .child(pic).child(label);
  }

  startButtons(t) {
    return [
      this.startButton(t, "terminal", svg("icons/shell.svg").size(18).text_color(t.foreground), "Terminal", null),
      ...STARTS.map(([key, label]) => this.startButton(t, key, icon(this.icons[key], 18, t.foreground) ?? div().size(18), label, [key])),
    ];
  }

  status(t, s) {
    if (s === "working") return svg("mods/workspace-chrome/spinner.svg").size(12).mx(1).flex_none().text_color(t.working).spin(900);
    if (s === "blocked") return div().flex_none().px(6).h(18).rounded(5).bg(t.blocked + "26").text_size(10.5).font_semibold().text_color(t.blocked).flex().items_center().child("Needs you");
    if (s === "idle") return div().size(7).mx(3).flex_none().rounded(4).border(1.5).border_color(t.idle ?? t.dim);
    return div().size(7).mx(3).flex_none().rounded(4).bg(t.done);
  }

  card(t, { tab, lead: l, label, agent }, changed, now) {
    const lines = (l && this.screens[l.terminal]) ?? [];
    const when = agent && changed[agent.address]?.at;
    const pic = icon(l?.program, 16, t.muted) ?? svg("icons/shell.svg").size(16).flex_none().text_color(t.muted);
    return v_flex().id(`card-${tab.id}`).flex_1().min_w(0).rounded(10).border(1).overflow_hidden().cursor_pointer()
      .border_color(agent?.status === "blocked" ? t.blocked + "73" : t.border)
      .hover((s) => s.border_color(t.input))
      .on_hover((over, cx) => {
        if (over) this.hovered = tab.id;
        else if (this.hovered === tab.id) this.hovered = null;
        cx.notify();
      })
      .on_click(() => run("tab.select", { id: tab.id }))
      .child(h_flex().h(44).px(12).gap(8).items_center()
        .child(pic)
        .child(div().flex_1().min_w(0).truncate().text_color(t.foreground).child(label))
        .when(Boolean(agent), (el) => el.child(this.status(t, agent.status)))
        .when(this.hovered === tab.id, (el) => el.child(div().id(`card-close-${tab.id}`).flex_none().p(2).rounded(4).text_color(t.dim)
          .hover((s) => s.bg(t.hover).text_color(t.foreground))
          .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
          .on_click((_e, cx) => { cx.stop_propagation(); run("tab.close", { id: tab.id }); })
          .child(svg("mods/pane/close.svg").size(12)))))
      .child(v_flex().h(SNAPSHOT_LINES * 18 + 22).py(11).px(12).overflow_hidden().bg(t.chrome)
        .border_t(1).border_b(1).border_color(t.border)
        .font_family(settings().font_family ?? "JetBrains Mono").text_size(10.5).text_color(t.muted)
        .children(lines.map((line) => div().h(18).flex_none().whitespace_nowrap().overflow_hidden().child(line))))
      .child(h_flex().h(36).px(12).gap(8).items_center()
        .child(div().flex_1().min_w(0).truncate().text_size(11.5).text_color(t.dim).child(l?.cwd ? tilde(l.cwd) : ""))
        .when(Boolean(when), (el) => el.child(div().flex_none().text_size(11.5).text_color(t.dim).child(duration(now - when)))));
  }

  render(cx) {
    const t = theme();
    const space = spaces().find((s) => s.active);
    const ps = panes(), list = agents();
    const held = new Set(ps.filter((p) => p.mod === EMPTY).map((p) => p.tab));
    const cards = (space?.tabs ?? []).filter((c) => !c.settled && !held.has(c.id)).map((tab, i) => {
      const l = lead(tab, ps);
      const agent = l && list.find((a) => a.pane === l.pane);
      return { tab, lead: l, label: title(tab, l), agent, i };
    }).sort((a, b) => (ORDER[a.agent?.status] ?? 4) - (ORDER[b.agent?.status] ?? 4) || a.i - b.i);
    if (cards.length && Date.now() - this.readAt >= REFRESH_MS) this.refresh(space, cards, cx);
    const changed = shared("agents.changed") ?? {};
    const now = Date.now();
    const rows = [];
    for (let i = 0; i < cards.length; i += 2) rows.push(cards.slice(i, i + 2));
    // Centered while it fits; auto margins, unlike justify_center, never push the top out of reach.
    // With fewer than two cards, one narrow column, so nothing sits off to one side.
    return v_flex().id("space-empty").size_full().bg(t.background).text_size(13).overflow_y_scrollbar()
      .child(v_flex().w_full().max_w(cards.length > 1 ? CONTENT_MAX_W : COLUMN_MAX_W).mx_auto().my_auto().px(24).py(22).gap(12)
        .child(h_flex().gap(12).justify_center().mb(16).children(this.startButtons(t)))
        .when(cards.length > 0, (el) => el.child(div().text_size(12).text_color(t.dim).child(`Running here · ${cards.length}`)))
        .when(cards.length === 1, (el) => el.child(this.card(t, cards[0], changed, now)))
        .when(cards.length > 1, (el) => el.children(rows.map((row) => h_flex().gap(12)
          .children(row.map((c) => this.card(t, c, changed, now)))
          .when(row.length === 1, (el) => el.child(div().flex_1()))))));
  }
}
