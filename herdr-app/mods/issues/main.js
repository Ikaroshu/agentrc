// The GitHub issues of the focused pane's repository, as a side panel beside Files and Graph: open
// or closed, filtered by number or title. A click opens the issue in this tab's file viewer
// (file-view), which reads it, comments on it, and closes or reopens it. The list comes from
// `gh issue list` on the space's machine, kept per repository and fetched again when the panel
// shows after a minute, on Refresh, and when the viewer changes an issue (shared `issues.changed`).
// Herdr renders every mod on each terminal change, so rendering reuses the filtered rows and draws
// only the visible ones.
import { div, svg, View, list as lazyList } from "gpui-kit";
import { v_flex, h_flex, InputState, Input, Scrollbar } from "gpui-base";
import { spaces, panes, focused, exec, run, layout, shared, setShared, theme } from "herdr";

const VIEW = "file-view";
const LIMIT = { OPEN: 500, CLOSED: 200 };
const STALE = 60000;

// The focused pane's folder; a focused mod pane (such as the file viewer) follows its tab's first terminal.
function location() {
  const space = spaces().find((s) => s.active), f = focused(), all = panes();
  const pane = f?.pane ? all.find((p) => p.pane === f.pane && p.terminal) ?? all.find((p) => p.tab === f.tab && p.terminal) : null;
  const on = f?.pane === null ? (f.terminal?.includes("/") ? f.terminal.split("/")[0] : null) : space?.machine ?? null;
  return { cwd: pane?.cwd || f?.cwd || space?.folder, on };
}

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

// Whether this panel is the side panel showing (read only when the list is due a fetch).
function showing() {
  const root = layout();
  return !find(root, "panel")?.hidden && find(root, "panel-body")?.active === "issues";
}

const issueId = (repo, number) => `issue:${repo}#${number}`;

export default class Issues extends View {
  init(_props, cx) {
    // Repository per "folder machine", from `gh repo view`; lists per repository and state.
    this.repos = JSON.parse(localStorage.getItem("repos") ?? "{}");
    this.lists = {}; this.state = "OPEN"; this.query = ""; this.rows = []; this.rowsKey = null;
    this.changed = shared("issues.changed")?.at;
    this.input = InputState.new({ placeholder: "Filter issues" });
    this.input.on("change", (_e, cx) => { this.query = this.input.value(); cx.notify(); });
    this.input.on("focus", (_e, cx) => { this.typing = true; cx.notify(); });
    this.input.on("blur", (_e, cx) => { this.typing = false; cx.notify(); });
  }

  // The repository of the focused folder, looked up once per folder.
  resolve(cx) {
    const { cwd, on } = location(), key = `${cwd} ${on ?? ""}`;
    if (key === this.where) return;
    this.where = key; this.error = null;
    if (!cwd) { this.repo = null; return; }
    if (key in this.repos) { this.repo = this.repos[key]; this.on = on; return; }
    this.repo = undefined;
    cx.spawn(async (cx) => {
      const r = await exec("gh", ["repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner"], { cwd, on });
      this.repos[key] = r.code === 0 ? r.stdout.trim() : null;
      localStorage.setItem("repos", JSON.stringify(this.repos));
      if (this.where === key) { this.repo = this.repos[key]; this.on = on; }
      cx.notify();
    });
  }

  fetch(cx) {
    const repo = this.repo, on = this.on, state = this.state, list = (this.lists[repo] ??= {});
    if (list.loading?.[state]) return;
    (list.loading ??= {})[state] = true;
    cx.spawn(async (cx) => {
      const r = await exec("gh", ["issue", "list", "-R", repo, "--state", state.toLowerCase(), "--limit", String(LIMIT[state]), "--json", "number,title,state"], { on });
      list.loading[state] = false;
      if (r.code === 0) { list[state] = JSON.parse(r.stdout); list.at = { ...list.at, [state]: Date.now() }; this.error = null; }
      else this.error = (r.stderr || r.stdout).trim() || `gh exited with ${r.code}`;
      cx.notify();
    });
  }

  // Filtered rows, worked out again only when what they depend on changes.
  shown() {
    const issues = this.lists[this.repo]?.[this.state], key = [this.repo, this.state, this.query];
    if (this.rowsKey?.[0] !== key[0] || this.rowsKey[1] !== key[1] || this.rowsKey[2] !== key[2] || this.rowsOf !== issues) {
      const q = this.query.trim().toLowerCase();
      this.rows = (issues ?? []).filter((i) => !q || `#${i.number} ${i.title}`.toLowerCase().includes(q));
      this.rowsKey = key; this.rowsOf = issues;
    }
    return this.rows;
  }

  // Adds the issue to this tab's viewer and shows it, splitting a viewer beside the terminal if the tab has none.
  open(number) {
    const f = focused(), tab = f?.tab, issue = this.lists[this.repo]?.[this.state]?.find((i) => i.number === number);
    if (!tab || !issue) return;
    const all = panes(), live = new Set(spaces().flatMap((s) => s.tabs.map((t) => t.id)));
    const views = Object.fromEntries(Object.entries(shared(VIEW) ?? {}).filter(([id]) => live.has(id)));
    const id = issueId(this.repo, number), files = views[tab]?.files ?? [];
    const entry = { file: id, on: this.on, issue: { repo: this.repo, number, title: issue.title } };
    views[tab] = { files: files.some((e) => e.file === id) ? files : [...files, entry], active: id };
    setShared(VIEW, views);
    if (!all.some((p) => p.tab === tab && p.mod === VIEW)) {
      const from = all.find((p) => p.pane === f.pane && p.terminal) ?? all.find((p) => p.tab === tab && p.terminal);
      run("pane.split", { direction: "right", pane: from?.pane, mod: VIEW, props: { tab } });
    }
  }

  segment(id, label, on, t, choose) {
    return div().id(id).h(24).px(9).flex().items_center().rounded(6).text_size(12).cursor_pointer()
      .bg(on ? t.selected : t.background).text_color(on ? t.foreground : t.muted)
      .hover((s) => s.bg(on ? t.selected : t.hover)).on_click((_e, cx) => { choose(); cx.notify(); }).child(label);
  }

  render(cx) {
    this.resolve(cx);
    const t = theme(), repo = this.repo, list = repo ? this.lists[repo] : null;
    const changed = shared("issues.changed");
    if (changed?.at && changed.at !== this.changed) { this.changed = changed.at; if (this.lists[changed.repo]) this.lists[changed.repo].at = {}; }
    if (repo && !list?.loading?.[this.state] && Date.now() - (list?.at?.[this.state] ?? 0) > STALE) {
      // Reading the layout costs more than the rest of a render: a hidden panel asks every two seconds at most.
      const now = Date.now(), first = !list?.[this.state];
      if (first || now > (this.asked ?? 0)) { this.asked = now + 2000; if (showing()) this.fetch(cx); }
    }
    const loading = Boolean(list?.loading?.[this.state]), rows = this.shown(), count = (state) => list?.[state] ? ` ${list[state].length}${list[state].length >= LIMIT[state] ? "+" : ""}` : "";
    const viewing = (shared(VIEW) ?? {})[focused()?.tab]?.active;
    const empty = repo === undefined ? "Looking for the repository…" : !repo ? "No GitHub repository here"
      : this.error ? this.error : !list?.[this.state] ? "Loading issues…" : this.query.trim() ? "No issues match"
      : `No ${this.state === "OPEN" ? "open" : "closed"} issues`;
    return v_flex().id("issues").size_full().min_h(0).rounded(10).overflow_hidden().bg(t.background).border_1().border_color(t.border).text_color(t.foreground).text_size(13)
      .child(h_flex().h(42).flex_none().px(14).gap(8).items_center().border_b(1).border_color(t.border)
        .child(svg("mods/issues/circle-dot.svg").size(14).flex_none().text_color(t.ansi2))
        .child(div().font_semibold().child("Issues"))
        .child(div().flex_1().min_w(0).truncate().text_right().text_size(12).text_color(t.dim).child(repo ?? ""))
        .when(Boolean(repo), (e) => e.child(div().id("issues-refresh").size(24).flex_none().flex().items_center().justify_center().rounded(6).cursor_pointer()
          .text_color(t.muted).hover((s) => s.bg(t.hover).text_color(t.foreground)).on_click((_e, cx) => { this.fetch(cx); cx.notify(); })
          .child(loading ? svg("mods/workspace-chrome/spinner.svg").size(13).text_color(t.working).spin(900) : svg("mods/git-graph/icons/refresh.svg").size(13)))))
      .child(v_flex().flex_none().px(8).pt(8).pb(6).gap(6).border_b(1).border_color(t.border)
        .child(h_flex().id("issues-filter").h(30).px(8).gap(6).items_center().rounded(7).border_1().border_color(this.typing ? t.accent : t.border).cursor_text()
          .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
          // The app returns focus to the terminal after a click in a side panel, so focus again once it has.
          .on_click((_e, cx) => { this.input.focus(); cx.timer.after(50, () => this.input.focus()); })
          .child(svg("mods/workspace-chrome/search.svg").size(13).flex_none().text_color(t.dim))
          .child(Input.new(this.input).flex_1().h_full().text_size(12).text_color(t.foreground)))
        .child(h_flex().child(h_flex().flex_none().p(2).gap(2).rounded(8).border_1().border_color(t.border)
          .child(this.segment("issues-open", `Open${count("OPEN")}`, this.state === "OPEN", t, () => { this.state = "OPEN"; }))
          .child(this.segment("issues-closed", `Closed${count("CLOSED")}`, this.state === "CLOSED", t, () => { this.state = "CLOSED"; })))))
      .child(div().flex_1().min_h(0).relative()
        .child(lazyList("issues-list", rows.length, (i) => String(rows[i].number), (i) => {
          const issue = rows[i];
          return h_flex().id(`issue-${issue.number}`).w_full().px(14).py(6).gap(8).items_start().cursor_pointer().hover((s) => s.bg(t.hover))
            .when(viewing === issueId(repo, issue.number), (e) => e.bg(t.selected))
            .child(div().w(40).flex_none().text_color(t.dim).child(`#${issue.number}`))
            .child(div().flex_1().min_w(0).child(issue.title));
        }).on_item_click((key) => this.open(Number(key))).size_full())
        .child(Scrollbar.vertical("issues-list").viewport_from_layout().absolute().inset_0())
        .when(!rows.length, (e) => e.child(div().absolute().top(16).w_full().px(16).text_center().text_size(12).text_color(this.error ? t.ansi1 : t.dim).child(empty))));
  }
}
