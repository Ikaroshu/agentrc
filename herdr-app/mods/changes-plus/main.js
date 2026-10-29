// Uncommitted changes and a commit box, or with props {part: "history"} recent history; the layout
// stacks one copy of each so their boundary can be dragged. Picking a changed file, or a file in a
// commit, opens its diff in this tab's file-view pane.
import { View, div, PathBuilder } from "gpui-kit";
import { v_flex, h_flex, InputState, Input, Scrollbar, v_virtual_list } from "gpui-base";
import { spaces, panes, focused, exec, run, shared, setShared, watchFolder, theme, props } from "herdr";

const VIEW = "file-view", HISTORY = 200;
const LANE = 12, ROW = 28, MAX_LANES = 10;

function location() {
  const space = spaces().find((s) => s.active), f = focused(), all = panes();
  // A mod pane (such as the file viewer) has no folder: follow its tab's first terminal.
  const pane = f?.pane ? all.find(p => p.pane === f.pane && p.terminal) ?? all.find(p => p.tab === f.tab && p.terminal) : null;
  const on = f?.pane === null ? (f.terminal?.includes("/") ? f.terminal.split("/")[0] : null) : space?.machine ?? null;
  return { cwd: pane?.cwd || f?.cwd || space?.folder, on };
}
const key = () => JSON.stringify(location());
const entryId = (e) => e.diff ? `${e.diff.commit ?? "working"}:${e.file}` : e.file;

function ago(seconds) {
  const s = Date.now() / 1000 - seconds;
  for (const [unit, size] of [["y", 31536000], ["mo", 2592000], ["w", 604800], ["d", 86400], ["h", 3600], ["m", 60]]) if (s >= size) return `${Math.floor(s / size)}${unit}`;
  return "now";
}

// Gives each commit (in topological order) a lane, and records per row the lines to draw:
// lanes passing through, lines from children above into the commit, and lines down to its
// parents. `after` is the lanes running below the row, for rows listing the commit's files.
function layoutGraph(commits) {
  const lanes = [];
  for (const c of commits) {
    const top = lanes.flatMap((h, i) => h ? [i] : []), into = top.filter(i => lanes[i] === c.hash);
    let col = into.length ? into[0] : lanes.indexOf(null);
    if (col < 0) col = lanes.length;
    for (const i of into) lanes[i] = null;
    const down = c.parents.map((parent, k) => {
      let lane = lanes.indexOf(parent);
      if (lane < 0) {
        lane = k === 0 ? col : lanes.indexOf(null);
        if (lane < 0) lane = lanes.length;
        lanes[lane] = parent;
      }
      return lane;
    });
    while (lanes.length && lanes[lanes.length - 1] === null) lanes.pop();
    c.graph = { col, into, through: top.filter(i => !into.includes(i)), down, after: lanes.flatMap((h, i) => h ? [i] : []) };
  }
  return Math.min(MAX_LANES, Math.max(1, ...commits.map(c => Math.max(c.graph.col, ...c.graph.down, ...c.graph.through, ...c.graph.into) + 1)));
}

// One row's slice of the graph: a stroke per lane color and a dot for the commit.
function graphCell(g, width, colors) {
  const x = (i) => LANE / 2 + i * LANE, mid = ROW / 2, strokes = new Map();
  const stroke = (lane, draw) => {
    if (lane >= MAX_LANES) return;
    const color = colors[lane % colors.length];
    strokes.set(color, draw(strokes.get(color) ?? PathBuilder.stroke(1.5)));
  };
  const curve = (b, x1, y1, x2, y2) => x1 === x2 ? b.move_to(x1, y1).line_to(x2, y2) : b.move_to(x1, y1).cubic_bezier_to(x2, y2, x1, (y1 + y2) / 2, x2, (y1 + y2) / 2);
  for (const i of g.through) stroke(i, b => b.move_to(x(i), 0).line_to(x(i), ROW));
  if (g.node) {
    for (const i of g.into) stroke(i, b => curve(b, x(i), 0, x(g.col), mid));
    for (const lane of g.down) stroke(lane, b => curve(b, x(g.col), mid, x(lane), ROW));
  }
  const cell = div().relative().flex_none().w(width * LANE).h(ROW)
    .children([...strokes].map(([color, b]) => globalThis.window.paint_path(b.build(), color).absolute().inset_0()));
  if (!g.node || g.col >= MAX_LANES) return cell;
  const dot = PathBuilder.fill().add_polygon(Array.from({ length: 16 }, (_, k) => [x(g.col) + 3.5 * Math.cos(k * Math.PI / 8), mid + 3.5 * Math.sin(k * Math.PI / 8)]), true);
  return cell.child(globalThis.window.paint_path(dot.build(), colors[g.col % colors.length]).absolute().inset_0());
}

export default class Changes extends View {
  init(_props, cx) {
    this.history = props()?.part === "history";
    this.files = []; this.commits = []; this.expanded = null; this.commitFiles = []; this.message = ""; this.handle = cx.focus_handle();
    this.input = InputState.new({ placeholder: "Commit message" });
    this.input.on("change", (_e, cx) => { this.message = this.input.value(); cx.notify(); });
    this.input.on("submit", (_e, cx) => this.commit(cx));
    this.input.on("focus", (_e, cx) => { this.typing = true; cx.notify(); });
    this.input.on("blur", (_e, cx) => { this.typing = false; cx.notify(); });
    this.refresh(cx);
    cx.timer.every(10000, (cx) => this.refresh(cx));
  }

  watch(root, cx) {
    if (this.on || this.watched === root) return;
    this.watched = root;
    cx.spawn(async (cx) => {
      try {
        while (this.watched === root) {
          await watchFolder(root);
          if (this.watched === root) this.refresh(cx);
        }
      } catch { this.watched = null; }
    });
  }

  refresh(cx) {
    if (this.loading || this.busy) return;
    const { cwd, on } = location(), context = key();
    if (context !== this.context) {
      this.context = context; this.root = null; this.files = []; this.commits = []; this.expanded = null; this.commitFiles = [];
      this.message = ""; this.input.set_value(""); this.error = null; this.note = null; this.watched = null; this.limited = false;
    }
    if (!cwd) return;
    this.loading = true;
    cx.spawn(async (cx) => {
      try {
        const top = await exec("git", ["rev-parse", "--show-toplevel"], { cwd, on });
        if (key() !== context) return;
        if (top.code !== 0) { this.root = null; this.files = []; this.commits = []; this.error = "Not a git repository"; return; }
        const root = top.stdout.trim(), git = (args) => exec("git", args, { cwd: root, on });
        const head = await git(["rev-parse", "--verify", "HEAD"]);
        const files = [], commits = [];
        let entries = [];
        if (!this.history) {
          const status = await git(["status", "--porcelain=v1", "-z", "--no-renames", "--untracked-files=all"]);
          if (status.code !== 0) throw new Error(status.stderr);
          const stats = {};
          const results = head.code === 0 ? [await git(["diff", "HEAD", "--numstat", "-z", "--no-renames"])] : [await git(["diff", "--cached", "--numstat", "-z", "--no-renames"]), await git(["diff", "--numstat", "-z", "--no-renames"])];
          for (const result of results) {
            if (result.code !== 0) throw new Error(result.stderr);
            for (const entry of result.stdout.split("\0")) {
              const [a, d, ...parts] = entry.split("\t");
              if (!parts.length) continue;
              const path = parts.join("\t"), old = stats[path] ?? { add: 0, del: 0 };
              stats[path] = { add: old.add + (Number(a) || 0), del: old.del + (Number(d) || 0), binary: a === "-" };
            }
          }
          entries = status.stdout.split("\0").filter(Boolean);
          for (const entry of entries.slice(0, 1000)) {
            const xy = entry.slice(0, 2), path = entry.slice(3), fresh = xy === "??";
            const conflict = xy.includes("U") || xy === "AA" || xy === "DD";
            const s = conflict ? "U" : xy.includes("D") ? "D" : fresh || xy.includes("A") ? "A" : "M";
            const stat = stats[path] ?? { add: 0, del: 0 };
            files.push({ path, status: s, fresh, ...stat });
          }
        } else if (head.code === 0) {
          const upstream = await git(["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"]);
          const log = await git(["log", "--topo-order", `--max-count=${HISTORY}`, "--no-color", "--format=%H%x1f%P%x1f%an%x1f%at%x1f%D%x1f%s%x1e", "HEAD", ...(upstream.code === 0 ? [upstream.stdout.trim()] : [])]);
          if (log.code !== 0) throw new Error(log.stderr);
          for (const record of log.stdout.split("\x1e")) {
            const [hash, parents, author, time, refs, subject] = record.trim().split("\x1f");
            if (!subject && !hash) continue;
            commits.push({ hash, parents: (parents ?? "").split(" ").filter(Boolean), author, time: Number(time), subject: subject ?? "",
              refs: (refs ?? "").split(", ").filter(r => r && r !== "origin/HEAD").map(r => r.replace(/^HEAD -> /, "")).slice(0, 2) });
          }
        }
        if (key() !== context) return;
        this.lanes = layoutGraph(commits);
        this.root = root; this.on = on; this.files = files; this.commits = commits; this.limited = entries.length > 1000; this.error = null;
        if (this.expanded && !commits.some(c => c.hash === this.expanded)) { this.expanded = null; this.commitFiles = []; }
        this.watch(root, cx);
      } catch (e) { if (key() === context) this.error = String(e); }
      finally { this.loading = false; cx.notify(); }
    });
  }

  expand(hash, cx) {
    this.expanded = this.expanded === hash ? null : hash; this.commitFiles = [];
    const context = this.context, root = this.root, on = this.on;
    if (this.expanded) cx.spawn(async (cx) => {
      const r = await exec("git", ["show", "--diff-merges=first-parent", "--name-status", "--no-renames", "--format=", "-z", hash], { cwd: root, on });
      if (key() !== context || this.expanded !== hash) return;
      const fields = r.code === 0 ? r.stdout.split("\0") : [], files = [];
      for (let i = 0; i + 1 < fields.length; i += 2) if (fields[i]) files.push({ status: fields[i][0], path: fields[i + 1] });
      this.commitFiles = files;
      cx.notify();
    });
    cx.notify();
  }

  // Adds the diff to this tab's viewer and shows it, splitting a viewer beside the terminal if
  // the tab has none.
  openDiff(path, commit) {
    const f = focused(), tab = f?.tab;
    if (!tab || !this.root) return;
    const all = panes(), live = new Set(spaces().flatMap(s => s.tabs.map(t => t.id)));
    const views = Object.fromEntries(Object.entries(shared(VIEW) ?? {}).filter(([id]) => live.has(id)));
    const entry = { file: `${this.root}/${path}`, on: this.on, diff: { root: this.root, path, commit } }, id = entryId(entry);
    const files = views[tab]?.files ?? [];
    views[tab] = { files: files.some(o => entryId(o) === id) ? files : [...files, entry], active: id };
    setShared(VIEW, views);
    if (!all.some(p => p.tab === tab && p.mod === VIEW)) {
      const from = all.find(p => p.pane === f.pane && p.terminal) ?? all.find(p => p.tab === tab && p.terminal);
      run("pane.split", { direction: "right", pane: from?.pane, mod: VIEW, props: { tab } });
    }
  }

  commit(cx) {
    if (!this.message.trim() || !this.root || this.busy || this.loading || this.context !== key()) return;
    const root = this.root, on = this.on, context = this.context, message = this.message.trim();
    this.busy = true; this.note = null;
    cx.spawn(async (cx) => {
      try {
        for (const args of [["add", "-A"], ["commit", "-m", message]]) {
          const r = await exec("git", args, { cwd: root, on });
          if (r.code !== 0) throw new Error((r.stderr || r.stdout).trim());
        }
        if (key() === context) { this.message = ""; this.input.set_value(""); }
      } catch (e) { if (key() === context) this.note = `Commit failed: ${e}`; }
      finally { this.busy = false; this.refresh(cx); cx.notify(); }
    });
    cx.notify();
  }

  statusColor(status, t) {
    return status === "A" ? t.ansi2 : status === "D" || status === "U" ? t.ansi1 : t.blocked;
  }

  fileRow(id, path, status, indent, selected, t, onClick) {
    const parts = path.split("/"), name = parts.pop();
    return h_flex().id(id).h(28).flex_none().pl(8 + indent).pr(8).gap(8).items_center().rounded(7).cursor_pointer()
      .when(selected, (e) => e.bg(t.selected)).hover((s) => s.bg(t.hover)).when(Boolean(onClick), (e) => e.on_click(onClick))
      .child(div().w(14).flex_none().text_size(11).text_color(this.statusColor(status, t)).child(status))
      .child(h_flex().flex_1().min_w(0).child(div().text_color(t.dim).truncate().child(parts.length ? parts.join("/") + "/" : "")).child(div().max_w(260).min_w(0).truncate().child(name)));
  }

  // Rows as data: the virtual list builds elements for the visible ones during layout, where
  // handlers are not allowed, so clicks come through the list's on_item_click by row key.
  historyRows() {
    const rows = [];
    for (const c of this.commits) {
      rows.push({ key: `c\0${c.hash}`, c });
      if (this.expanded === c.hash) for (const f of this.commitFiles) rows.push({ key: `f\0${c.hash}\0${f.path}`, c, f });
    }
    return rows;
  }

  pickHistory(row, cx) {
    if (row.f) this.openDiff(row.f.path, row.c.hash);
    else this.expand(row.c.hash, cx);
  }

  historyRow({ c, f }, active, t) {
    const colors = [t.accent, t.ansi2, t.ansi3, t.ansi5, t.ansi6, t.ansi1, t.ansi4];
    if (f) {
      const id = `${c.hash}:${this.root}/${f.path}`;
      return this.fileRow(`commit-file-${id}`, f.path, f.status, this.lanes * LANE + 8, active === id, t, null).relative()
        .child(div().absolute().left(8).top(0).child(graphCell({ through: c.graph.after }, this.lanes, colors)));
    }
    const open = this.expanded === c.hash;
    return h_flex().id(`commit-${c.hash}`).h(ROW).flex_none().px(8).gap(8).items_center().rounded(7).cursor_pointer()
      .when(open, (e) => e.bg(t.raised)).hover((s) => s.bg(t.hover))
      .child(graphCell({ ...c.graph, node: true }, this.lanes, colors))
      .child(div().flex_1().min_w(0).truncate().child(c.subject))
      .children(c.refs.map(r => div().flex_none().max_w(90).truncate().px(5).rounded(4).border_1().border_color(t.border).text_size(10).text_color(t.accent).child(r)))
      .child(div().flex_none().text_size(11).text_color(t.dim).child(`${c.author.split(" ")[0]} · ${ago(c.time)}`));
  }

  renderHistory(t) {
    const active = (shared(VIEW) ?? {})[focused()?.tab]?.active, history = this.historyRows();
    return v_flex().id("history").size_full().min_h(0).rounded(10).overflow_hidden().bg(t.background).border_1().border_color(t.border).text_color(t.foreground).text_size(13)
      .child(h_flex().h(42).flex_none().px(14).gap(8).items_center().border_b(1).border_color(t.border)
        .child(div().font_semibold().child("History"))
        .child(div().flex_1())
        .when(this.commits.length >= HISTORY, (e) => e.child(div().text_size(11).text_color(t.dim).child(`latest ${HISTORY}`))))
      .child(div().flex_1().min_h(0).relative()
        .child(div().size_full().px(6).py(4).child(v_virtual_list("changes-history", history.length, 28, (i) => history[i].key, (range) => history.slice(range.start, range.end).map((row) => this.historyRow(row, active, t)))
          .on_item_click((key, cx) => { const row = history.find(r => r.key === key); if (row) this.pickHistory(row, cx); }).size_full()))
        .child(Scrollbar.vertical("changes-history").viewport_from_layout().absolute().inset_0())
        .when(!this.commits.length, (e) => e.child(div().absolute().top(6).px(12).text_color(t.dim).child(this.error || (this.loading ? "Loading history…" : this.root ? "No commits yet" : "No folder")))));
  }

  render(cx) {
    if (key() !== this.context) this.refresh(cx);
    if (this.history) return this.renderHistory(theme());
    const t = theme(), add = this.files.reduce((n, f) => n + f.add, 0), del = this.files.reduce((n, f) => n + f.del, 0);
    const enabled = Boolean(this.message.trim() && this.root && !this.busy && !this.loading);
    const active = (shared(VIEW) ?? {})[focused()?.tab]?.active;
    return v_flex().id("changes").size_full().min_h(0).rounded(10).overflow_hidden().bg(t.background).border_1().border_color(t.border).text_color(t.foreground).text_size(13).track_focus(this.handle)
      .on_key_down((e, cx) => {
        if (e.key === "escape" && this.typing) { this.typing = false; this.handle.focus(); cx.stop_propagation(); cx.notify(); }
      })
      .child(h_flex().h(42).flex_none().px(14).gap(8).items_center().border_b(1).border_color(t.border)
        .child(div().font_semibold().child("Changes"))
        .child(div().px(5).py(1).rounded(4).border_1().border_color(t.border).text_size(10).text_color(t.muted).child(`${this.files.length} files`))
        .child(div().flex_1()).child(div().text_size(11).text_color(t.ansi2).child(`+${add}`)).child(div().text_size(11).text_color(t.ansi1).child(`−${del}`)))
      .child(v_flex().id("changes-list").flex_1().min_h(0).overflow_y_scrollbar().p(6).children(this.files.map((f) =>
        this.fileRow(`change-${f.path}`, f.path, f.status, 0, active === `working:${this.root}/${f.path}`, t, () => this.openDiff(f.path, null))
          .when(f.add > 0, (e) => e.child(div().text_size(11).text_color(t.ansi2).child(`+${f.add}`))).when(f.del > 0, (e) => e.child(div().text_size(11).text_color(t.ansi1).child(`−${f.del}`)))))
        .when(!this.files.length, (e) => e.child(div().p(8).text_color(t.dim).child(this.error || (this.loading ? "Loading changes…" : this.root ? "No uncommitted changes" : "No folder")))))
      .when(this.limited, el => el.child(div().px(12).py(4).text_size(11).text_color(t.dim).child("Showing the first 1,000 changed files")))
      .when(Boolean(this.note), (e) => e.child(div().px(10).pb(8).text_size(11).text_color(t.ansi1).child(this.note)))
      .child(h_flex().flex_none().p(10).gap(8).border_t(1).border_color(t.border)
        .child(div().id("commit-message").flex_1().min_w(0).h(32).px(10).flex().items_center().rounded(8).border_1().border_color(this.typing ? t.accent : t.border).cursor_text().on_mouse_down("left", (_e, cx) => cx.stop_propagation())
        // The app returns focus to the terminal after a click in a side panel, so focus again once it has.
        .on_click((_e, cx) => { this.input.focus(); cx.timer.after(50, () => this.input.focus()); }).child(Input.new(this.input).h_full().text_size(12).text_color(t.foreground)))
        .child(div().id("commit").h(32).px(14).flex().items_center().rounded(8).bg(enabled ? t.solid : t.raised).text_color(enabled ? t.solid_foreground : t.dim).text_size(12).when(enabled, (e) => e.cursor_pointer()).on_click((_e, cx) => this.commit(cx)).child(this.busy ? "Committing…" : "Commit")));
  }
}
