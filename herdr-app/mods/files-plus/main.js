// A lazy file browser for the focused pane's folder, with fuzzy file search. It remembers each
// folder's expanded subfolders and opens files in this tab's file-view pane.
import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex, InputState, Input, Scrollbar, v_virtual_list, VirtualListScrollHandle } from "gpui-base";
import { spaces, panes, focused, exec, run, shared, setShared, watchFolder, theme, window, nextCommand } from "herdr";

const VIEW = "file-view";

function location() {
  const space = spaces().find(s => s.active), f = focused(), all = panes();
  // A mod pane (such as the file viewer) has no folder: follow its tab's first terminal.
  const pane = f?.pane ? all.find(p => p.pane === f.pane && p.terminal) ?? all.find(p => p.tab === f.tab && p.terminal) : null;
  const on = f?.pane === null ? (f.terminal?.includes("/") ? f.terminal.split("/")[0] : null) : space?.machine ?? null;
  return { cwd: pane?.cwd || f?.cwd || space?.folder, on };
}
const key = () => JSON.stringify(location());
const PER_FOLDER = 500, TOTAL = 5000, SEARCH_FILES = 30000, SEARCH_RESULTS = 100;

// Every file under root, relative to it, as the tree shows them (ignored files included), minus
// git internals and dependency and cache folders nobody browses.
const SKIP = [".git", "node_modules", ".venv", "venv", "__pycache__", ".cache", ".pytest_cache", ".ruff_cache", ".mypy_cache", "target"];
async function allFiles(root, on) {
  const prune = SKIP.map(name => `-name '${name}'`).join(" -o ");
  const script = `cd "$1" && find . \\( ${prune} \\) -prune -o -type f -print | head -n ${SEARCH_FILES}`;
  const r = await exec("sh", ["-c", script, "files", root], { on });
  return r.stdout.split("\n").filter(Boolean).map(path => path.slice(2));
}

// The score of the term's letters appearing in order from `from`, or null. Consecutive letters
// and letters starting a word score more.
function subsequence(text, term, from) {
  let score = 0, at = from - 1, run = 0;
  for (const ch of term) {
    const i = text.indexOf(ch, at + 1);
    if (i < 0) return null;
    run = i === at + 1 ? run + 1 : 0;
    score += 1 + run * 2 + (i === 0 || "/_-. ".includes(text[i - 1]) ? 3 : 0);
    at = i;
  }
  return score;
}

// Every space-separated term must match; a term matching within the file name scores more, and
// shorter paths win ties.
function fuzzy(path, query) {
  const lower = path.toLowerCase(), base = lower.lastIndexOf("/") + 1;
  let total = 0;
  for (const term of query.toLowerCase().split(/\s+/).filter(Boolean)) {
    const inName = subsequence(lower, term, base);
    const score = inName === null ? subsequence(lower, term, 0) : inName + 10;
    if (score === null) return null;
    total += score;
  }
  return total - path.length / 100;
}

async function directory(path, on) {
  if (!on && window()?.platform === "windows") {
    const r = await exec("powershell", ["-NoProfile", "-Command", "& { param($p) @(Get-ChildItem -LiteralPath $p -Force -ErrorAction Stop | Where-Object Name -ne '.git' | Select-Object -First 501 | ForEach-Object { @{ name=$_.Name; dir=($_.PSIsContainer -and -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)) } }) | ConvertTo-Json -Compress }", path]);
    if (r.code !== 0) throw new Error(r.stderr || "Cannot list this folder");
    const result = JSON.parse(r.stdout || "[]");
    return Array.isArray(result) ? result : [result];
  }
  const script = 'n=0; for p in "$1"/* "$1"/.[!.]* "$1"/..?*; do [ -e "$p" ] || [ -L "$p" ] || continue; name=${p##*/}; [ "$name" = .git ] && continue; if [ -d "$p" ] && [ ! -L "$p" ]; then kind=d; else kind=f; fi; printf "%s\\0%s\\0" "$kind" "$name"; n=$((n+1)); [ "$n" -gt 500 ] && break; done; test -d "$1"';
  const r = await exec("sh", ["-c", script, "files", path], { on });
  if (r.code !== 0) throw new Error(r.stderr || "Cannot list this folder");
  const fields = r.stdout.split("\0"), out = [];
  for (let i = 0; i + 1 < fields.length; i += 2) out.push({ name: fields[i + 1], dir: fields[i] === "d" });
  return out;
}

export default class Files extends View {
  init(_props, cx) {
    this.entries = new Map(); this.folders = new Set(); this.pending = new Set(); this.marks = {};
    this.memory = JSON.parse(localStorage.getItem("folders") ?? "{}");
    this.query = ""; this.found = []; this.at = 0; this.index = null;
    this.handle = cx.focus_handle(); this.scroll = VirtualListScrollHandle.new();
    this.input = InputState.new({ placeholder: "Search files" });
    this.input.on("change", (_e, cx) => this.search(this.input.value(), cx));
    this.input.on("submit", (_e, cx) => this.pick(this.found[this.at], cx));
    this.input.on("focus", (_e, cx) => { this.typing = true; cx.notify(); });
    this.input.on("blur", (_e, cx) => { this.typing = false; cx.notify(); });
    this.refresh(cx);
    cx.timer.every(10000, cx => this.refresh(cx));
    cx.spawn(async cx => { for (;;) { if (await nextCommand() === "search") this.input.focus(); cx.notify(); } });
  }

  remember() {
    if (this.folders.size) this.memory[this.context] = [...this.folders];
    else delete this.memory[this.context];
    localStorage.setItem("folders", JSON.stringify(this.memory));
  }

  watch(root, cx) {
    if (this.on || this.watched === root) return;
    this.watched = root;
    cx.spawn(async cx => {
      try { while (this.watched === root) { await watchFolder(root); if (this.watched === root) this.refresh(cx); } }
      catch { if (this.watched === root) this.watched = null; }
    });
  }

  async loadFolder(path, context) {
    const on = this.on, root = this.root;
    const entries = await directory(path ? `${root}/${path}` : root, on);
    if (key() !== context || (path && !this.folders.has(path))) return;
    const used = [...this.entries.entries()].filter(([p]) => p !== path).reduce((n, [, e]) => n + e.length, 0);
    this.entries.set(path, entries.slice(0, Math.max(0, Math.min(PER_FOLDER, TOTAL - used))).sort((a, b) => Number(b.dir) - Number(a.dir) || a.name.localeCompare(b.name)));
    if (entries.length > PER_FOLDER || used + entries.length > TOTAL) this.limited = true;
  }

  refresh(cx) {
    if (this.loading) return;
    const { cwd, on } = location(), context = key();
    if (context !== this.context) {
      this.context = context; this.root = cwd; this.on = on; this.entries = new Map(); this.folders = new Set(this.memory[context] ?? []);
      this.pending = new Set(); this.marks = {}; this.watched = null; this.error = null; this.limited = false;
      this.index = null; this.query = ""; this.found = []; this.input.set_value("");
    }
    if (!cwd) return;
    this.loading = true;
    this.limited = false;
    cx.spawn(async cx => {
      try {
        // Sorted, a folder comes after its parent, whose fresh listing says whether it still exists.
        let forgot = false;
        for (const path of ["", ...[...this.folders].sort()]) {
          const slash = path.lastIndexOf("/"), parent = slash < 0 ? "" : path.slice(0, slash);
          if (path && !this.entries.get(parent)?.some(e => e.dir && e.name === path.slice(slash + 1))) {
            this.folders.delete(path); this.entries.delete(path); forgot = true;
            continue;
          }
          await this.loadFolder(path, context);
        }
        if (forgot && key() === context) this.remember();
        const top = await exec("git", ["rev-parse", "--show-toplevel"], { cwd, on }).catch(() => null);
        const marks = {};
        if (top?.code === 0) {
          const status = await exec("git", ["--no-optional-locks", "status", "--porcelain=v1", "-z", "--no-renames", "--untracked-files=normal"], { cwd, on }).catch(() => null);
          if (status?.code === 0) for (const entry of status.stdout.split("\0").filter(Boolean).slice(0, TOTAL)) {
            const xy = entry.slice(0, 2);
            marks[`${top.stdout.trim()}/${entry.slice(3)}`] = xy === "??" || xy.includes("A") ? "A" : xy.includes("U") ? "U" : xy.includes("D") ? "D" : "M";
          }
        }
        if (key() !== context) return;
        this.marks = marks; this.error = null; this.watch(cwd, cx);
      } catch (e) { if (key() === context) this.error = String(e); }
      finally { this.loading = false; cx.notify(); }
    });
  }

  toggle(path, cx) {
    if (this.folders.has(path)) {
      for (const folder of [...this.folders]) if (folder === path || folder.startsWith(path + "/")) {
        this.folders.delete(folder);
        this.entries.delete(folder);
      }
    } else {
      this.folders.add(path);
      if (!this.entries.has(path) && !this.pending.has(path)) {
        const context = this.context;
        this.pending.add(path);
        cx.spawn(async cx => {
          try { await this.loadFolder(path, context); }
          catch (e) { if (key() === context) this.error = String(e); }
          finally { this.pending.delete(path); cx.notify(); }
        });
      }
    }
    this.remember();
    cx.notify();
  }

  // Adds the file to this tab's viewer and shows it, splitting a viewer beside the terminal if
  // the tab has none. The viewer reads its files from the shared value, so later clicks reuse it.
  open(path) {
    const f = focused(), tab = f?.tab;
    if (!tab) return;
    const all = panes(), live = new Set(spaces().flatMap(s => s.tabs.map(t => t.id)));
    const views = Object.fromEntries(Object.entries(shared(VIEW) ?? {}).filter(([id]) => live.has(id)));
    const file = `${this.root}/${path}`, files = views[tab]?.files ?? [];
    views[tab] = { files: files.some(o => o.file === file) ? files : [...files, { file, on: this.on }], active: file };
    setShared(VIEW, views);
    if (!all.some(p => p.tab === tab && p.mod === VIEW)) {
      const from = all.find(p => p.pane === f.pane && p.terminal) ?? all.find(p => p.tab === tab && p.terminal);
      run("pane.split", { direction: "right", pane: from?.pane, mod: VIEW, props: { tab } });
    }
  }

  // The file list reloads each time a search starts, so it reflects files created since.
  search(query, cx) {
    const starting = !this.query.trim() && query.trim();
    this.query = query; this.at = 0;
    if (starting) this.loadIndex(cx);
    this.rank();
    this.scroll.scroll_to_item(0);
    cx.notify();
  }

  loadIndex(cx) {
    const context = this.context, root = this.root, on = this.on;
    if (!root) return;
    cx.spawn(async cx => {
      const files = await allFiles(root, on);
      if (this.context !== context) return;
      this.index = files; this.rank(); cx.notify();
    });
  }

  rank() {
    if (!this.query.trim() || !this.index) { this.found = []; return; }
    const scored = [];
    for (const path of this.index) {
      const score = fuzzy(path, this.query);
      if (score !== null) scored.push({ path, score });
    }
    this.found = scored.sort((a, b) => b.score - a.score).slice(0, SEARCH_RESULTS).map(r => r.path);
  }

  // Opens the file and expands its folders in the tree.
  pick(path, cx) {
    if (!path) return;
    const parts = path.split("/");
    for (let i = 1; i < parts.length; i++) {
      const folder = parts.slice(0, i).join("/");
      if (!this.folders.has(folder)) this.toggle(folder, cx);
    }
    this.open(path);
  }

  move(by, cx) {
    if (!this.found.length) return;
    this.at = (this.at + by + this.found.length) % this.found.length;
    this.scroll.scroll_to_item(this.at);
    cx.notify();
  }

  results(t) {
    const found = this.found;
    return div().flex_1().min_h(0).relative()
      .child(div().size_full().p(6).child(v_virtual_list("files-found", found.length, 28, (i) => found[i], (range) => found.slice(range.start, range.end).map((path, k) => {
        const slash = path.lastIndexOf("/");
        return h_flex().h(28).flex_none().px(8).gap(7).items_center().rounded(7).cursor_pointer()
          .when(range.start + k === this.at, el => el.bg(t.selected)).hover(s => s.bg(t.hover))
          .child(svg("mods/files-plus/file.svg").size(14).flex_none().text_color(t.muted))
          .child(div().flex_none().max_w(200).truncate().child(path.slice(slash + 1)))
          .child(div().flex_1().min_w(0).truncate().text_size(11.5).text_color(t.dim).child(slash < 0 ? "" : path.slice(0, slash)));
      })).track_scroll(this.scroll).on_item_click((path, cx) => this.pick(path, cx)).size_full()))
      .child(Scrollbar.vertical("files-found").viewport_from_layout().absolute().inset_0())
      .when(!found.length, el => el.child(div().absolute().top(6).px(14).text_size(12).text_color(t.dim).child(this.index ? "No matching files" : "Listing files…")));
  }

  rows(prefix, depth, out, t, viewing) {
    if (out.length >= TOTAL || depth > 40) return out;
    for (const entry of this.entries.get(prefix) ?? []) {
      if (out.length >= TOTAL) break;
      const path = prefix ? `${prefix}/${entry.name}` : entry.name, open = this.folders.has(path), mark = this.marks[`${this.root}/${path}`];
      out.push(h_flex().id(`file-${path}`).h(28).flex_none().pl(8 + depth * 18).pr(8).gap(7).items_center().rounded(7).cursor_pointer().hover(s => s.bg(t.hover))
        .when(!entry.dir && viewing === `${this.root}/${path}`, el => el.bg(t.selected))
        .on_click((_e, cx) => entry.dir ? this.toggle(path, cx) : this.open(path))
        .child(entry.dir ? svg(`mods/files-plus/chevron-${open ? "down" : "right"}.svg`).size(12).flex_none().text_color(t.dim) : div().w(12).flex_none())
        .child(svg(`mods/files-plus/${entry.dir ? "folder" : "file"}.svg`).size(14).flex_none().text_color(t.muted))
        .child(div().flex_1().min_w(0).truncate().child(entry.name))
        .when(Boolean(mark), el => el.child(div().text_size(11).text_color(mark === "A" ? t.ansi2 : mark === "D" || mark === "U" ? t.ansi1 : t.blocked).child(mark))));
      if (entry.dir && open) this.rows(path, depth + 1, out, t, viewing);
    }
    return out;
  }

  render(cx) {
    if (key() !== this.context) this.refresh(cx);
    const t = theme(), viewing = (shared(VIEW) ?? {})[focused()?.tab]?.active;
    return v_flex().id("files").size_full().min_h(0).rounded(10).overflow_hidden().bg(t.background).border_1().border_color(t.border).text_color(t.foreground).text_size(13)
      .track_focus(this.handle)
      .on_key_down((e, cx) => {
        if (!this.typing) return;
        if (e.key === "down") this.move(1, cx);
        else if (e.key === "up") this.move(-1, cx);
        else if (e.key === "escape") { this.input.set_value(""); this.search("", cx); this.handle.focus(); }
        else return;
        cx.stop_propagation();
      })
      .child(h_flex().h(42).flex_none().px(14).gap(8).items_center().border_b(1).border_color(t.border)
        .child(div().font_semibold().child("Files"))
        .child(div().flex_1().min_w(0).truncate().text_right().text_size(12).text_color(t.dim).child(this.root?.split(/[\\/]/).pop() ?? "")))
      .child(h_flex().flex_none().px(8).pt(8).pb(2).child(h_flex().id("files-search").flex_1().h(30).px(8).gap(6).items_center().rounded(7)
        .border_1().border_color(this.typing ? t.accent : t.border).cursor_text().on_mouse_down("left", (_e, cx) => cx.stop_propagation())
        // The app returns focus to the terminal after a click in a side panel, so focus again once it has.
        .on_click((_e, cx) => { this.input.focus(); cx.timer.after(50, () => this.input.focus()); })
        .child(svg("mods/workspace-chrome/search.svg").size(13).flex_none().text_color(t.dim))
        .child(Input.new(this.input).flex_1().h_full().text_size(12).text_color(t.foreground))))
      .when(Boolean(this.query.trim()), el => el.child(this.results(t)))
      .when(!this.query.trim(), el => el.child(v_flex().id("files-tree").flex_1().min_h(0).overflow_y_scrollbar().p(6).children(this.rows("", 0, [], t, viewing))
        .when(Boolean(this.error) || !this.entries.get("")?.length, el => el.child(div().p(8).text_size(12).text_color(t.dim).child(this.error || (this.loading ? "Loading files…" : this.root ? "No files" : "No folder"))))
        .when(this.limited, el => el.child(div().p(8).text_size(11).text_color(t.dim).child("File list limited to 500 entries per folder and 5,000 total")))));
  }
}
