// A lazy file browser for the focused pane's folder, with search by file name (fuzzy) and by
// content (each file's first matching lines under it). The viewer's Cmd-F (file-view) scopes the
// search to its file, listing all of its matching lines, until Esc or the scope's ×. It remembers each
// folder's expanded subfolders and opens files in this tab's file-view pane. Right-click a file,
// a folder, or the space below them for its menu (files-menu): new, cut/copy/paste, copy its
// path, rename, and delete (this computer's Trash; elsewhere, after asking). Names are typed in place.
import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex, InputState, Input, Scrollbar, v_virtual_list, VirtualListScrollHandle } from "gpui-base";
import { spaces, panes, focused, exec, run, shared, setShared, watchFolder, theme, window, nextCommand, openOverlay, notify } from "herdr";

const VIEW = "file-view";
const parentOf = (path) => path.slice(0, Math.max(0, path.lastIndexOf("/")));
const nameOf = (path) => path.slice(path.lastIndexOf("/") + 1);

// File operations' shell scripts, run on the tree's machine with the paths as arguments.
// Paste ($1 into folder $2, by cp or mv as $3) takes the first free name of "a.txt", "a copy.txt",
// "a copy 2.txt", ...
const PASTE = 'src=$1; dir=$2; name=${src##*/}; base=$name; ext=; if [ ! -d "$src" ]; then case $name in ?*.*) base=${name%.*}; ext=.${name##*.};; esac; fi; dest=$dir/$name; n=1; while [ -e "$dest" ] || [ -L "$dest" ]; do if [ $n = 1 ]; then dest="$dir/$base copy$ext"; else dest="$dir/$base copy $n$ext"; fi; n=$((n+1)); done; if [ "$3" = mv ]; then mv -- "$src" "$dest"; else cp -R -- "$src" "$dest"; fi';
const TAKEN = 'if [ -e "$1" ] || [ -L "$1" ]; then echo "${1##*/} already exists" >&2; exit 1; fi; ';
const RENAME = 'set -- "$2" "$1"; ' + TAKEN + 'mv -- "$2" "$1"';
const NEW_FILE = TAKEN + ': > "$1"';
const NEW_FOLDER = TAKEN + 'mkdir -- "$1"';
// The clipboard is this computer's, whichever machine the path is on.
const copyText = (text) => exec("sh", ["-c", 'printf %s "$1" | pbcopy', "copy", text]);

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

// Lines containing the query ($2) under folder $1, or in the files after $3 (case-insensitive
// unless it has capitals), at most $3 per file: ripgrep (which also skips git-ignored files) where
// installed, else grep. Prints "path\0line:text" lines.
const GREP = `cd "$1" || exit 1; q=$2; m=$3; shift 3; [ $# -gt 0 ] || set -- .; if command -v rg >/dev/null 2>&1; then rg --null --with-filename --line-number --no-heading --color never --fixed-strings --smart-case --hidden --max-count "$m" --max-columns 400 --max-columns-preview --max-filesize 1M ${SKIP.map(name => `-g '!${name}'`).join(" ")} -- "$q" "$@" 2>/dev/null; else case $q in *[A-Z]*) ci=;; *) ci=-i;; esac; grep -rInH --null -F $ci -m "$m" ${SKIP.map(name => `--exclude-dir='${name}'`).join(" ")} -- "$q" "$@" 2>/dev/null; fi | head -n 3000`;
async function contentMatches(root, on, query, file) {
  const r = await exec("sh", ["-c", GREP, "grep", root, query, file ? "3000" : "5", ...(file ? [file] : [])], { on });
  const files = new Map();
  for (const line of r.stdout.split("\n")) {
    const nul = line.indexOf("\0"), colon = line.indexOf(":", nul);
    if (nul < 0 || colon < 0) continue;
    const path = line.slice(0, nul).replace(/^\.\//, "");
    if (!files.has(path)) files.set(path, []);
    files.get(path).push({ line: +line.slice(nul + 1, colon), text: line.slice(colon + 1) });
  }
  return files;
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
    this.query = ""; this.found = []; this.at = 0; this.index = null; this.contents = null; this.searching = 0;
    this.handle = cx.focus_handle(); this.scroll = VirtualListScrollHandle.new();
    this.input = InputState.new({ placeholder: "Search files" });
    this.input.on("change", (_e, cx) => this.search(this.input.value(), cx));
    this.input.on("submit", (_e, cx) => this.pick(this.found[this.at]?.path, cx));
    this.input.on("focus", (_e, cx) => { this.typing = true; cx.notify(); });
    this.input.on("blur", (_e, cx) => { this.typing = false; cx.notify(); });
    this.refresh(cx);
    cx.timer.every(10000, cx => this.refresh(cx));
    cx.spawn(async cx => {
      for (;;) {
        const command = await nextCommand();
        if (command === "search") this.input.focus();
        else if (command === "find_in_file") this.findIn(shared("files.scope"), cx);
        else this.act(command, cx);
        cx.notify();
      }
    });
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
      this.index = null; this.query = ""; this.found = []; this.contents = null; this.scope = null; this.input.set_value(""); this.edit = null;
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
    const file = path.startsWith("/") ? path : `${this.root}/${path}`, files = views[tab]?.files ?? [];
    views[tab] = { files: files.some(o => o.file === file) ? files : [...files, { file, on: this.scope?.on ?? this.on }], active: file };
    setShared(VIEW, views);
    if (!all.some(p => p.tab === tab && p.mod === VIEW)) {
      const from = all.find(p => p.pane === f.pane && p.terminal) ?? all.find(p => p.tab === tab && p.terminal);
      run("pane.split", { direction: "right", pane: from?.pane, mod: VIEW, props: { tab } });
    }
  }

  // What can be done to a row (target: { path, dir }; path "" is the folder the tree shows).
  menu(target) {
    this.target = target;
    const local = !this.on, item = Boolean(target.path);
    const items = [
      ["New File…", "files-plus.new_file"], ["New Folder…", "files-plus.new_folder"], null,
      ...(item ? [["Cut", "files-plus.cut"], ["Copy", "files-plus.copy"]] : []),
      ...(this.clip?.on === this.on ? [["Paste", "files-plus.paste"]] : []), null,
      ["Copy Path", "files-plus.copy_path"], ...(item ? [["Copy Relative Path", "files-plus.copy_relative_path"]] : []),
      ...(item ? [null, ["Rename…", "files-plus.rename"], [local ? "Move to Trash" : "Delete…", "files-plus.delete"]] : []),
    ].filter((it, i, all) => it || (i > 0 && all[i - 1] && all.slice(i + 1).some(Boolean)));
    const rows = items.filter(Boolean).length;
    openOverlay({ mod: "files-menu", kind: "popup", width: 210, height: 10 + rows * 31 + (items.length - rows) * 9, props: { items } });
  }

  act(command, cx) {
    const target = this.target;
    if (!target) return;
    const abs = target.path ? `${this.root}/${target.path}` : this.root;
    const folder = target.dir ? target.path : parentOf(target.path), folderAbs = folder ? `${this.root}/${folder}` : this.root;
    if (command === "new_file" || command === "new_folder") this.startEdit(command === "new_file" ? "file" : "folder", folder, "", cx);
    else if (command === "rename") this.startEdit("rename", parentOf(target.path), target.path, cx);
    else if (command === "cut" || command === "copy") this.clip = { path: abs, on: this.on, cut: command === "cut" };
    else if (command === "paste") this.paste(folder, folderAbs, cx);
    else if (command === "copy_path") copyText(abs);
    else if (command === "copy_relative_path") copyText(target.path);
    else if (command === "delete" && !this.on) this.fileOp(cx, "trash", [abs]);
    else if (command === "delete") openOverlay({ mod: "confirm", kind: "dialog", width: 440, height: 190, props: {
      title: `Delete ${nameOf(abs)}?`, detail: `${abs} on ${this.on} will be deleted permanently; that machine has no Trash.`,
      command: { name: "files-plus.delete_now" } } });
    else if (command === "delete_now") this.fileOp(cx, "rm", ["-rf", "--", abs]);
  }

  // Runs a file operation on the tree's machine; a failure shows its message.
  fileOp(cx, command, args, then) {
    cx.spawn(async cx => {
      const r = await exec(command, args, { on: this.on });
      if (r.code !== 0) notify({ title: "File operation failed", body: r.stderr.trim() || `${command} exited with ${r.code}`, level: "error" });
      else then?.();
      this.refresh(cx);
    });
  }

  paste(folder, folderAbs, cx) {
    const { path, cut } = this.clip;
    if (folderAbs === path || folderAbs.startsWith(path + "/")) {
      notify({ title: "Can't paste a folder into itself", level: "error" });
      return;
    }
    if (cut && parentOf(path) === folderAbs) return;
    if (folder && !this.folders.has(folder)) this.toggle(folder, cx);
    if (cut) this.clip = null;
    this.fileOp(cx, "sh", ["-c", PASTE, "paste", path, folderAbs, cut ? "mv" : "cp"]);
  }

  // A name typed in place: a renamed row, or a new row at the top of its folder. Enter applies it,
  // Esc cancels. The menu's closing returns focus elsewhere, so the field takes it again after.
  startEdit(kind, folder, path, cx) {
    if (folder && !this.folders.has(folder)) this.toggle(folder, cx);
    const name = path ? nameOf(path) : "", dot = name.lastIndexOf(".");
    const input = InputState.new({ value: name });
    input.set_selected_range({ start: 0, end: kind === "rename" && dot > 0 ? dot : name.length });
    input.on("submit", (_e, cx) => this.finishEdit(cx));
    this.edit = { kind, folder, path, input };
    input.focus();
    for (const ms of [50, 300]) cx.timer.after(ms, () => { if (this.edit?.input === input) input.focus(); });
    cx.notify();
  }

  finishEdit(cx) {
    const { kind, folder, path, input } = this.edit, name = input.value().trim();
    this.edit = null;
    cx.notify();
    if (!name || (kind === "rename" && name === nameOf(path))) return;
    const rel = folder ? `${folder}/${name}` : name, abs = `${this.root}/${rel}`;
    if (kind === "rename") this.fileOp(cx, "sh", ["-c", RENAME, "rename", `${this.root}/${path}`, abs]);
    else if (kind === "file") this.fileOp(cx, "sh", ["-c", NEW_FILE, "new", abs], () => this.open(rel));
    else this.fileOp(cx, "sh", ["-c", NEW_FOLDER, "new", abs]);
  }

  nameField(t) {
    return div().id("files-edit").flex_1().min_w(0).on_mouse_down("left", (_e, cx) => cx.stop_propagation()).on_click((_e, cx) => cx.stop_propagation())
      .child(Input.new(this.edit.input).h(22).px(4).rounded(4).border_1().border_color(t.accent).bg(t.background).text_size(13).text_color(t.foreground));
  }

  // The file list reloads each time a search starts, so it reflects files created since.
  search(query, cx) {
    const starting = !this.query.trim() && query.trim();
    this.query = query; this.at = 0;
    if (starting) this.loadIndex(cx);
    this.contents = null;
    this.grep(cx);
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

  // Scopes the search to one file (the viewer's Cmd-F): its path relative to the tree when inside it.
  // The panel may have just been shown, so the field takes focus again once it's drawn.
  findIn(scope, cx) {
    if (!scope) return;
    const inside = scope.on === this.on && scope.file.startsWith(this.root + "/");
    this.scope = { ...scope, path: inside ? scope.file.slice(this.root.length + 1) : scope.file };
    this.search(this.query, cx);
    for (const ms of [0, 50, 300]) cx.timer.after(ms, () => this.input.focus());
  }

  // Content search waits until typing pauses, and only the latest query's answer is kept.
  grep(cx) {
    const query = this.query.trim(), turn = ++this.searching, context = this.context, scope = this.scope;
    const root = scope ? "/" : this.root, on = scope ? scope.on : this.on;
    if (query.length < (scope ? 1 : 2) || !root) return;
    cx.timer.after(250, cx => {
      if (turn !== this.searching) return;
      cx.spawn(async cx => {
        const found = await contentMatches(root, on, query, scope?.file);
        const files = scope ? new Map([[scope.path, found.get(scope.file) ?? []]]) : found;
        if (turn !== this.searching || this.context !== context) return;
        this.contents = files; this.rank(); cx.notify();
      });
    });
  }

  // Result rows: a file, then its matching lines. Names containing every term come first, then
  // files whose content matches, then looser name matches.
  rank() {
    const query = this.query.trim();
    if (!query) { this.found = []; return; }
    if (this.scope) {
      const lines = this.contents?.get(this.scope.path) ?? [];
      this.found = lines.length ? [{ path: this.scope.path }, ...lines.map(m => ({ path: this.scope.path, ...m }))] : [];
      return;
    }
    const terms = query.toLowerCase().split(/\s+/), named = [];
    for (const path of this.index ?? []) {
      const score = fuzzy(path, query);
      if (score !== null) named.push({ path, score, close: terms.every(term => path.toLowerCase().includes(term)) });
    }
    named.sort((a, b) => b.score - a.score);
    const contents = this.contents ?? new Map();
    const paths = [...new Set([...named.filter(r => r.close).map(r => r.path), ...contents.keys(), ...named.map(r => r.path)])].slice(0, SEARCH_RESULTS);
    this.found = paths.flatMap(path => [{ path }, ...(contents.get(path) ?? []).map(m => ({ path, ...m }))]);
  }

  // Opens the file and expands its folders in the tree.
  pick(path, cx) {
    if (!path) return;
    const parts = path.startsWith("/") ? [] : path.split("/");
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

  // A matching line, trimmed to start shortly before the match, with the match marked.
  snippet(text, t) {
    const query = this.query.trim(), line = text.replace(/^\s+/, "");
    const at = /[A-Z]/.test(query) ? line.indexOf(query) : line.toLowerCase().indexOf(query.toLowerCase());
    if (at < 0) return div().flex_1().min_w(0).truncate().text_color(t.muted).child(line);
    const from = at > 24 ? at - 16 : 0;
    return h_flex().flex_1().min_w(0).overflow_hidden().text_color(t.muted)
      .child(div().flex_none().child((from ? "…" : "") + line.slice(from, at)))
      .child(div().flex_none().rounded(3).bg(t.accent + "40").text_color(t.foreground).child(line.slice(at, at + query.length)))
      .child(div().flex_1().min_w(0).truncate().child(line.slice(at + query.length)));
  }

  results(t) {
    const found = this.found;
    const empty = this.scope ? (!this.query.trim() ? `Type to find in ${nameOf(this.scope.file)}` : this.contents === null ? "Searching…" : "No matches in this file")
      : !this.index ? "Listing files…" : this.contents === null && this.query.trim().length >= 2 ? "Searching contents…" : "No matching files";
    return div().flex_1().min_h(0).relative()
      .child(div().size_full().p(6).child(v_virtual_list("files-found", found.length, 26, (i) => `${found[i].path}:${found[i].line ?? ""}`, (range) => found.slice(range.start, range.end).map((row, k) => {
        const on = range.start + k === this.at, base = h_flex().h(26).flex_none().px(8).gap(7).items_center().rounded(7).cursor_pointer()
          .when(on, el => el.bg(t.selected)).hover(s => s.bg(t.hover));
        if (row.line !== undefined) return base.pl(29).text_size(12)
          .child(div().w(28).flex_none().text_right().text_size(11).text_color(t.dim).child(String(row.line)))
          .child(this.snippet(row.text, t));
        const slash = row.path.lastIndexOf("/");
        return base
          .child(svg("mods/files-plus/file.svg").size(14).flex_none().text_color(t.muted))
          .child(div().flex_none().max_w(200).truncate().child(row.path.slice(slash + 1)))
          .child(div().flex_1().min_w(0).truncate().text_size(11.5).text_color(t.dim).child(slash < 0 ? "" : row.path.slice(0, slash)));
      })).track_scroll(this.scroll).on_item_click((key, cx) => this.pick(key.slice(0, key.lastIndexOf(":")), cx)).size_full()))
      .child(Scrollbar.vertical("files-found").viewport_from_layout().absolute().inset_0())
      .when(!found.length, el => el.child(div().absolute().top(6).px(14).text_size(12).text_color(t.dim).child(empty)));
  }

  rows(prefix, depth, out, t, viewing) {
    if (out.length >= TOTAL || depth > 40) return out;
    const edit = this.edit;
    if (edit && edit.kind !== "rename" && edit.folder === prefix) out.push(h_flex().h(28).flex_none().pl(8 + depth * 18).pr(8).gap(7).items_center().rounded(7).bg(t.hover)
      .child(div().w(12).flex_none())
      .child(svg(`mods/files-plus/${edit.kind === "folder" ? "folder" : "file"}.svg`).size(14).flex_none().text_color(t.muted))
      .child(this.nameField(t)));
    for (const entry of this.entries.get(prefix) ?? []) {
      if (out.length >= TOTAL) break;
      const path = prefix ? `${prefix}/${entry.name}` : entry.name, open = this.folders.has(path), mark = this.marks[`${this.root}/${path}`];
      const renaming = edit?.kind === "rename" && edit.path === path;
      out.push(h_flex().id(`file-${path}`).h(28).flex_none().pl(8 + depth * 18).pr(8).gap(7).items_center().rounded(7).cursor_pointer().hover(s => s.bg(t.hover))
        .when(!entry.dir && viewing === `${this.root}/${path}`, el => el.bg(t.selected))
        .on_click((_e, cx) => entry.dir ? this.toggle(path, cx) : this.open(path))
        .on_mouse_down("right", (_e, cx) => { cx.stop_propagation(); this.menu({ path, dir: entry.dir }); })
        .child(entry.dir ? svg(`mods/files-plus/chevron-${open ? "down" : "right"}.svg`).size(12).flex_none().text_color(t.dim) : div().w(12).flex_none())
        .child(svg(`mods/files-plus/${entry.dir ? "folder" : "file"}.svg`).size(14).flex_none().text_color(t.muted))
        .child(renaming ? this.nameField(t) : div().flex_1().min_w(0).truncate().child(entry.name))
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
        if (this.edit && e.key === "escape") { this.edit = null; cx.notify(); cx.stop_propagation(); return; }
        if (!this.typing) return;
        if (e.key === "down") this.move(1, cx);
        else if (e.key === "up") this.move(-1, cx);
        else if (e.key === "escape") { this.scope = null; this.input.set_value(""); this.search("", cx); this.handle.focus(); }
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
        .when(Boolean(this.scope), el => el.child(h_flex().id("files-scope").flex_none().max_w(140).h(20).pl(6).pr(2).gap(2).items_center().rounded(5)
          .bg(t.selected).text_size(11).text_color(t.muted)
          .child(div().truncate().child(`in ${this.scope ? nameOf(this.scope.file) : ""}`))
          .child(div().id("files-scope-x").size(16).flex().items_center().justify_center().rounded(4).hover(s => s.bg(t.hover))
            .on_click((_e, cx) => { cx.stop_propagation(); this.scope = null; this.search(this.query, cx); })
            .child(svg("mods/pane/close.svg").size(10)))))
        .child(Input.new(this.input).flex_1().h_full().text_size(12).text_color(t.foreground))))
      .when(Boolean(this.query.trim()) || Boolean(this.scope), el => el.child(this.results(t)))
      .when(!this.query.trim() && !this.scope, el => el.child(v_flex().id("files-tree").flex_1().min_h(0).overflow_y_scrollbar().p(6)
        .on_mouse_down("right", () => { if (this.root) this.menu({ path: "", dir: true }); }).children(this.rows("", 0, [], t, viewing))
        .when(Boolean(this.error) || !this.entries.get("")?.length, el => el.child(div().p(8).text_size(12).text_color(t.dim).child(this.error || (this.loading ? "Loading files…" : this.root ? "No files" : "No folder"))))
        .when(this.limited, el => el.child(div().p(8).text_size(11).text_color(t.dim).child("File list limited to 500 entries per folder and 5,000 total")))));
  }
}
