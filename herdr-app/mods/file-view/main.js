// Tabs for the files and diffs the Files and Graph panels opened in this tab: editable files
// (Markdown rendered until Source), and diffs stacked (removed lines above added ones), colored by
// the vendored Prism (prism.js) and scrolling sideways for long lines. Cmd-S saves (keys.json binds it to `file-view.save`); Cmd-F searches the
// shown file from the Files panel's search box; a file changed on disk since it was opened needs a
// second Cmd-S to overwrite, and a tab with unsaved edits asks before closing. Files too large to load whole stay
// read-only. Local files and uncommitted diffs reload when the file changes on disk (not over
// unsaved edits); uncommitted diffs also recheck every 10 seconds, since a commit or reset changes
// them without touching the file. Preview/Source (Markdown) shows while the pointer is at the
// content's top right corner. Issues the Issues panel opened show their body and comments, and
// take a comment, Close or Reopen (closing or reopening posts the box's text as a comment too).
import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex, Editor, EditorState, TextView, Scrollbar, v_virtual_list, TextareaState, Textarea } from "gpui-base";
import { props, shared, setShared, panes, run, exec, readTextFile, writeTextFile, watchFolder, theme, settings, nextCommand, notify, openOverlay, appHome } from "herdr";
import Prism from "./prism.js";

const LANG = { ts: "js", tsx: "js", mts: "js", cts: "js", jsx: "js", mjs: "js", toml: "yaml", jsonc: "json", svelte: "html", vue: "html" };
const MARKDOWN = new Set(["md", "markdown", "mdx"]);
const DIFF_LINES = 10000;
// A hunk longer than this is colored a row at a time as rows come into view: Prism in Herdr's engine
// takes about 80ms per 1000 lines of JavaScript, too long for one frame.
const HUNK_LINES = 1000;

// One Dark's code colors, for the editor and the diffs alike. Its orange (as vivid as the
// one-dark-vivid theme's colors) and comment gray aren't among a theme's colors.
const ORANGE = "#dd9f64";
const codeColors = (t) => ({ keyword: t.ansi5, function: t.ansi4, string: t.ansi2, "string.escape": t.ansi6, comment: "#7f848e", type: t.ansi3,
  number: ORANGE, boolean: ORANGE, constant: ORANGE, variable: t.foreground, operator: t.ansi6, punctuation: t.foreground });
// Diffs only: the editor has no slot for keys, tags and shell variables, which One Dark draws red.
const diffColors = (t) => ({ ...codeColors(t), property: t.ansi1 });
// Prism's grammar per extension; other files' diffs stay uncolored.
const PRISM = { js: "javascript", mjs: "javascript", cjs: "javascript", jsx: "jsx", ts: "typescript", mts: "typescript", cts: "typescript", tsx: "tsx",
  py: "python", sh: "bash", bash: "bash", zsh: "bash", rs: "rust", go: "go", json: "json", jsonc: "json", toml: "toml", yaml: "yaml", yml: "yaml",
  md: "markdown", markdown: "markdown", mdx: "markdown", html: "markup", xml: "markup", svg: "markup", vue: "markup", svelte: "markup", css: "css" };
// Prism's token names (a token's type, else one of its aliases) to the colors above.
const TOKEN = {
  comment: "comment", prolog: "comment", doctype: "comment", cdata: "comment",
  keyword: "keyword", atrule: "keyword", important: "keyword", rule: "keyword",
  string: "string", char: "string", "attr-value": "string", url: "string", inserted: "string",
  regex: "string.escape", escape: "string.escape", entity: "string.escape",
  function: "function", "class-name": "type", builtin: "type", namespace: "type", selector: "type",
  number: "number", boolean: "boolean", constant: "constant", symbol: "constant", "attr-name": "constant",
  operator: "operator", punctuation: "punctuation",
  property: "property", key: "property", tag: "property", variable: "property", title: "property", deleted: "property",
};

// Flattens Prism's token tree into [text, key] runs, a key naming one of the colors above; a nested
// token without a key of its own takes its parent's.
function runs(tokens, inherited, out) {
  for (const token of tokens) {
    if (typeof token === "string") { out.push([token, inherited]); continue; }
    const key = [token.type, ...[token.alias ?? []].flat()].map((name) => TOKEN[name]).find(Boolean) ?? inherited;
    if (typeof token.content === "string") out.push([token.content, key]);
    else runs([token.content].flat(), key, out);
  }
  return out;
}

// Splits lines of code, tokenized at once, into one list of [text, key] runs per line (key null:
// the text color). Keys, not colors, so a theme change shows without tokenizing again.
function colorLines(text, grammar) {
  const lines = [[]];
  for (const [chunk, key] of runs(Prism.tokenize(text, grammar), null, [])) {
    chunk.split("\n").forEach((part, i) => { if (i) lines.push([]); if (part) lines.at(-1).push([part, key]); });
  }
  return lines;
}

// Spaces that end a run would be drawn into the next run's ligature (` =>`): each run's trailing
// spaces lead the next run instead, where they keep their width. Tabs show as four spaces.
function spaced(line) {
  const out = [];
  let carry = "";
  for (const [text, key] of line) {
    const all = carry + text.replaceAll("\t", "    "), body = all.trimEnd();
    carry = all.slice(body.length);
    if (body) out.push([body, key]);
  }
  return out;
}
const folderOf = (file) => file.slice(0, file.lastIndexOf("/"));
const nameOf = (file) => file.slice(file.lastIndexOf("/") + 1);
const extOf = (file) => nameOf(file).includes(".") ? nameOf(file).split(".").pop().toLowerCase() : "txt";
const entryId = (e) => e.diff ? `${e.diff.commit ?? "working"}:${e.file}` : e.file;
const working = (e) => !e.issue && (!e.diff || e.diff.commit === null);
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const day = (iso) => { const d = new Date(iso); return `${MONTHS[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}`; };
const ISSUE_FIELDS = "number,title,state,stateReason,author,createdAt,body,comments,url";

// The diff's lines from its first hunk, or a message when there is no text diff.
async function diffLines({ file, on, diff: { root, path, commit } }) {
  const git = (args) => exec("git", args, { cwd: root, on });
  const flags = ["--no-ext-diff", "--no-textconv", "--no-color", "--no-renames"];
  let r;
  if (commit === null) {
    // A file HEAD doesn't have (untracked, newly added, or no commits yet) is all additions.
    if ((await git(["cat-file", "-e", `HEAD:${path}`])).code !== 0) {
      const text = await readTextFile(file, { on });
      if (text === null) return { message: "This file is no longer available" };
      if (text.includes("\0")) return { message: "Binary file · no text diff" };
      const lines = text.slice(0, 400000).replace(/\n$/, "").split("\n");
      return { lines: [`@@ -0,0 +1,${lines.length} @@`, ...lines.map(l => `+${l}`)] };
    }
    r = await git(["diff", "HEAD", ...flags, "--", path]);
  } else r = await git(["show", "--diff-merges=first-parent", "--format=", ...flags, commit, "--", path]);
  if (r.code !== 0) throw new Error(r.stderr);
  const all = r.stdout.replace(/\n$/, "").split("\n"), first = all.findIndex((l) => l.startsWith("@@"));
  if (first < 0) return { message: r.stdout.includes("Binary files") ? "Binary file changed" : "No text changes" };
  return { lines: all.slice(first) };
}

// Numbers each line (a removed line by its old number), notes each row's hunk (`at`, an index into
// `hunks`: its rows' range) and sizes the rows to the longest line.
function diffRows(lines) {
  const rows = [], hunks = [];
  let old = 0, next = 0;
  for (const raw of lines.slice(0, DIFF_LINES)) {
    const line = raw.length > 4000 ? raw.slice(0, 4000) + "… (line truncated)" : raw;
    const match = /^@@ -(\d+)(?:,\d+)? \+(\d+)/.exec(line);
    if (match) { old = +match[1]; next = +match[2]; rows.push({ hunk: line }); hunks.push({ from: rows.length, to: rows.length }); continue; }
    const kind = line[0], text = line.slice(1) || " ", at = hunks.length - 1;
    if (kind === "-") rows.push({ kind, at, number: old++, text });
    else if (kind === "+") rows.push({ kind, at, number: next++, text });
    else if (kind === " ") { old++; rows.push({ kind, at, number: next++, text }); }
    else continue;
    hunks[at].to = rows.length;
  }
  if (lines.length > DIFF_LINES) rows.push({ hunk: `… diff truncated at ${DIFF_LINES} lines` });
  return { rows, hunks, width: Math.max(300, ...rows.map(row => (row.text ?? row.hunk).length * 7 + 80)) };
}

// Colors a row's hunk the first time one of its rows is drawn. Each side is colored whole (context
// and removed lines as the old file, context and added lines as the new), so comments and strings
// spanning lines read right; context rows take the new side's colors.
function paint(diff, row) {
  if (row.runs || row.hunk !== undefined || !diff.grammar) return;
  const { from, to } = diff.hunks[row.at];
  if (to - from > HUNK_LINES) { row.runs = colorLines(row.text, diff.grammar)[0]; return; }
  const part = diff.rows.slice(from, to);
  for (const [side, other] of [["-", "+"], ["+", "-"]]) {
    const mine = part.filter((r) => r.kind !== other);
    const lines = colorLines(mine.map((r) => r.text).join("\n"), diff.grammar);
    mine.forEach((r, i) => { if (r.kind === side || (side === "+" && r.kind === " ")) r.runs = lines[i]; });
  }
}

export default class FileView extends View {
  init(_props, cx) {
    this.docs = new Map(); this.watching = new Set();
    cx.timer.every(10000, cx => { for (const doc of this.docs.values()) if (doc.entry.diff && working(doc.entry)) this.load(doc, cx); });
    // Every viewer gets the command; only the focused one acts.
    cx.spawn(async cx => {
      for (;;) {
        const command = await nextCommand();
        if (!panes().find(p => p.mod === "file-view" && p.tab === props().tab)?.focused && command !== "discard") continue;
        if (command === "save") this.save(this.docs.get(this.view().active), cx);
        else if (command === "find") this.find();
        else if (command === "discard" && this.closing) { this.close(this.closing, cx, true); this.closing = null; }
        cx.notify();
      }
    });
  }

  // The editor binds Cmd-F to its own search, ahead of keys.json; a binding in its own context, added
  // later, wins over it there (elsewhere in the viewer keys.json's `file-view.find` runs). Herdr drops
  // such bindings whenever it reloads keys.json, so the editor's focus adds it again after each change.
  bindFind(cx) {
    cx.spawn(async cx => {
      const changed = (await exec("stat", ["-f", "%Fm", `${appHome()}/keys.json`])).stdout;
      if (changed === this.keysChanged) return;
      this.keysChanged = changed;
      cx.bind_keys([{ keystroke: "cmd-f", action: "file_view_find", context: "FileView > Input" }]);
    });
  }

  // Shows the Files panel with its search scoped to the shown file.
  find() {
    const entry = this.docs.get(this.view().active)?.entry;
    if (!entry || entry.diff || entry.issue) return;
    setShared("files.scope", { file: entry.file, on: entry.on ?? null });
    run("layout.select", { stack: "panel-body", child: "files" });
    run("layout.show", { id: "panel" });
    run("files-plus.find_in_file");
  }

  // Writes the edits unless the file changed on disk since it was read: then the first save warns
  // and the next one overwrites. Another machine's file goes through `hc file write` from a temporary
  // copy here, since writeTextFile writes only on this computer.
  save(doc, cx) {
    if (!doc?.dirty) return;
    const { file, on } = doc.entry, text = doc.code.value();
    cx.spawn(async cx => {
      const disk = await readTextFile(file, { on });
      if (disk !== doc.saved && !doc.force) {
        doc.force = true;
        notify({ title: `${nameOf(file)} changed on disk`, body: "Save again to overwrite it with your version.", level: "warning" });
        return;
      }
      if (!on) await writeTextFile(file, text, disk);
      else {
        const copy = `/tmp/herdr-file-view-${Date.now()}`;
        await writeTextFile(copy, text, null);
        const r = await exec("sh", ["-c", 'hc file write --on "$1" "$2" < "$3"; s=$?; rm -f "$3"; exit $s', "save", on, file, copy]);
        if (r.code !== 0) { notify({ title: `Couldn't save ${nameOf(file)}`, body: r.stderr.trim(), level: "error" }); return; }
      }
      doc.saved = text; doc.dirty = false; doc.force = false;
      cx.notify();
    });
  }

  view() {
    const view = (shared("file-view") ?? {})[props()?.tab];
    return view?.files ? view : { files: [], active: null };
  }

  setView(view) {
    setShared("file-view", { ...(shared("file-view") ?? {}), [props().tab]: view });
  }

  // Closes this viewer and forgets its files, as closing its last tab does: top-bar asks (shared
  // `file-view.leave`: the tab) when its tab, a space's placeholder, is shown again. A viewer with
  // unsaved edits stays.
  leave(cx) {
    if ([...this.docs.values()].some(d => d.dirty)) return;
    const all = { ...(shared("file-view") ?? {}) };
    delete all[props().tab];
    setShared("file-view", all);
    const pane = panes().find(p => p.mod === "file-view" && p.tab === props().tab)?.pane;
    cx.timer.after(0, () => run("pane.close", { pane }));
  }

  close(id, cx, discard = false) {
    if (this.docs.get(id)?.dirty && !discard) {
      this.closing = id;
      openOverlay({ mod: "confirm", kind: "dialog", width: 420, height: 180, props: {
        title: `Discard changes to ${nameOf(this.docs.get(id).entry.file)}?`, detail: "Your unsaved edits will be lost.",
        command: { name: "file-view.discard" } } });
      return;
    }
    const { files, active } = this.view(), at = files.findIndex(f => entryId(f) === id), rest = files.filter(f => entryId(f) !== id);
    if (!rest.length) {
      const all = { ...(shared("file-view") ?? {}) };
      delete all[props().tab];
      setShared("file-view", all);
      // Closed once the click is done: a pane closing itself inside its own click reports a failure.
      const pane = panes().find(p => p.mod === "file-view" && p.tab === props().tab)?.pane;
      cx.timer.after(0, () => run("pane.close", { pane }));
      return;
    }
    this.setView({ files: rest, active: active === id ? entryId(rest[Math.min(at, rest.length - 1)]) : active });
  }

  load(doc, cx) {
    cx.spawn(async cx => {
      try {
        if (doc.entry.issue) {
          const { repo, number } = doc.entry.issue;
          const r = await exec("gh", ["issue", "view", String(number), "-R", repo, "--json", ISSUE_FIELDS], { on: doc.entry.on });
          if (this.docs.get(doc.id) !== doc) return;
          doc.error = r.code === 0 ? null : r.stderr.trim() || `gh exited with ${r.code}`;
          if (r.code === 0) doc.issue = JSON.parse(r.stdout);
          if (!doc.box) { doc.box = TextareaState.new({ placeholder: "Leave a comment" }); doc.box.set_auto_grow(3, 12); }
          doc.loaded = true;
          return;
        }
        if (doc.entry.diff) {
          const { lines, message } = await diffLines(doc.entry);
          if (this.docs.get(doc.id) !== doc) return;
          doc.error = message ?? null; doc.loaded = true;
          // A recheck that finds the same diff keeps its rows, colored already.
          const text = lines?.join("\n") ?? null;
          if (text === doc.diffText) return;
          doc.diffText = text;
          doc.rows = lines ? { ...diffRows(lines), grammar: Prism.languages[PRISM[extOf(doc.entry.file)]] } : null;
          return;
        }
        const text = await readTextFile(doc.entry.file, { on: doc.entry.on });
        // Not over unsaved edits, and not when nothing changed (after a save): refilling moves the cursor.
        if (this.docs.get(doc.id) !== doc || doc.dirty || (doc.code && text === doc.saved)) return;
        doc.error = text === null ? "This file is no longer available" : text.includes("\0") ? "Binary file · no text preview" : null;
        if (!doc.error) this.fill(doc, text);
        doc.loaded = true;
      } catch { if (this.docs.get(doc.id) === doc) { doc.error = `Cannot show this ${doc.entry.diff ? "diff" : "file"} (binary, too large, or unreadable)`; doc.loaded = true; } }
      finally { cx.notify(); }
    });
  }

  fill(doc, text) {
    const truncated = text.length > 400000;
    doc.text = truncated ? text.slice(0, 400000) + "\n… (file truncated)" : text;
    doc.saved = text;
    if (doc.code && truncated === doc.truncated) { doc.code.set_value(doc.text); return; }
    doc.code?.release();
    doc.truncated = truncated;
    const t = theme(), ext = extOf(doc.entry.file);
    doc.code = EditorState.new({ language: LANG[ext] ?? ext, readonly: truncated, value: doc.text,
      font_family: settings().font_family, font_size: 12,
      syntax: codeColors(t) });
    doc.code.on("focus", (_e, cx) => this.bindFind(cx));
    doc.code.on("change", (_e, cx) => {
      if (doc.truncated) return;
      doc.text = doc.code.value(); doc.dirty = doc.text !== doc.saved;
      cx.notify();
    });
  }

  // Opens docs for new entries, releases closed ones, and watches the folders of local files
  // whose content can change.
  sync(files, cx) {
    const open = new Set(files.map(entryId));
    for (const [id, doc] of this.docs) if (!open.has(id)) { doc.code?.release(); doc.box?.release(); this.docs.delete(id); }
    for (const entry of files) {
      const id = entryId(entry);
      if (this.docs.has(id)) continue;
      const doc = { id, entry, loaded: false, error: null, text: null, saved: null, code: null, rows: null, source: false, dirty: false, force: false, truncated: false };
      this.docs.set(id, doc);
      this.load(doc, cx);
    }
    const folders = new Set(files.filter(e => !e.on && working(e)).map(e => folderOf(e.file)));
    for (const folder of this.watching) if (!folders.has(folder)) this.watching.delete(folder);
    for (const folder of folders) if (!this.watching.has(folder)) {
      this.watching.add(folder);
      cx.spawn(async cx => {
        while (this.watching.has(folder)) {
          const changed = await watchFolder(folder);
          if (!this.watching.has(folder)) break;
          for (const doc of this.docs.values()) if (working(doc.entry) && changed.includes(doc.entry.file)) this.load(doc, cx);
        }
      });
    }
  }

  // A changed line: tinted, its number on a stronger tint, then its sign.
  diffRow(row, t, colors) {
    if (row.hunk !== undefined) return div().w_full().px(12).h(20).flex_none().truncate().bg(t.raised).text_color(t.dim).child(row.hunk);
    const tint = row.kind === "+" ? t.ansi2 : row.kind === "-" ? t.ansi1 : null;
    const code = row.runs ? h_flex().children(spaced(row.runs).map(([text, key]) => div().flex_none().when(Boolean(key), (e) => e.text_color(colors[key])).child(text)))
      : div().child(row.text);
    return h_flex().w_full().h(20).flex_none().when(Boolean(tint), (e) => e.bg(tint + "26"))
      .child(div().w(44).h_full().pr(8).flex_none().flex().items_center().justify_end().text_color(tint ?? t.dim).when(Boolean(tint), (e) => e.bg(tint + "33"))
        .child(String(row.number)))
      .child(div().w(18).flex_none().text_center().text_color(tint ?? t.dim).child(row.kind === " " ? "" : row.kind))
      .child(div().flex_1().min_w(0).overflow_hidden().child(code));
  }

  diffBody(doc, t) {
    const list = `diff-${doc.id}`, { rows, width } = doc.rows, colors = diffColors(t);
    const items = v_virtual_list(list, rows.length, 20, (i) => String(i),
      (range) => rows.slice(range.start, range.end).map((row) => { paint(doc.rows, row); return this.diffRow(row, t, colors); })).size_full();
    return div().flex_1().min_h(0).relative().font_family(settings().font_family ?? "JetBrains Mono").text_size(11)
      .child(div().id(`${list}-x`).size_full().overflow_x_scrollbar().child(div().w_full().min_w(width).h_full().child(items)))
      .child(Scrollbar.vertical(list).viewport_from_layout().absolute().inset_0());
  }

  // Comments on, closes or reopens the shown issue, then reloads it and tells the Issues panel.
  act(doc, kind, cx) {
    const { repo, number } = doc.entry.issue, text = doc.box.value().trim();
    if (kind === "comment" && !text) return;
    const args = kind === "comment" ? ["comment", String(number), "-R", repo, "--body", text]
      : [kind, String(number), "-R", repo, ...(text ? ["--comment", text] : [])];
    doc.busy = true;
    cx.spawn(async cx => {
      const r = await exec("gh", ["issue", ...args], { on: doc.entry.on });
      doc.busy = false;
      if (r.code !== 0) notify({ title: `Couldn't ${kind} #${number}`, body: r.stderr.trim(), level: "error" });
      else { doc.box.set_value(""); setShared("issues.changed", { repo, at: Date.now() }); this.load(doc, cx); }
      cx.notify();
    });
  }

  issueBody(doc, t) {
    const issue = doc.issue, open = issue.state === "OPEN";
    const button = (id, label, primary, action) => div().id(id).h(28).px(12).flex().flex_none().items_center().rounded(7).text_size(12.5).cursor_pointer()
      .when(primary, e => e.bg(t.accent).text_color(t.background)).when(!primary, e => e.border_1().border_color(t.border).hover(s => s.bg(t.hover)))
      .on_click((_e, cx) => action(cx)).child(label);
    const post = (key, login, at, text) => v_flex().flex_none().rounded(8).border_1().border_color(t.border).overflow_hidden()
      .child(h_flex().h(32).px(12).gap(6).items_center().bg(t.raised).border_b(1).border_color(t.border).text_size(12)
        .child(div().font_semibold().child(login ?? "ghost")).child(div().text_color(t.dim).child(day(at))))
      .child(div().px(14).py(10).child(text.trim() ? TextView.markdown(`${doc.id}-${key}`, text).selectable(true) : div().text_color(t.dim).child("No description provided.")));
    const comments = issue.comments.length;
    return v_flex().id(`issue-${doc.id}`).flex_1().min_h(0).overflow_y_scrollbar().px(20).py(16).gap(12)
      .child(div().flex_none().text_size(20).font_semibold().child(issue.title))
      .child(h_flex().flex_none().gap(8).items_center().text_size(12.5)
        .child(div().h(24).px(10).flex().items_center().rounded(12).font_semibold().bg(open ? t.ansi2 : t.ansi5).text_color(t.background)
          .child(open ? "Open" : issue.stateReason === "NOT_PLANNED" ? "Closed as not planned" : "Closed"))
        .child(div().flex_1().min_w(0).truncate().text_color(t.dim)
          .child(`#${issue.number} · ${issue.author?.login ?? "ghost"} opened ${day(issue.createdAt)} · ${comments} comment${comments === 1 ? "" : "s"}`))
        .child(button("issue-github", "Open on GitHub", false, cx => cx.open_url(issue.url))))
      .child(post("body", issue.author?.login, issue.createdAt, issue.body))
      .children(issue.comments.map((c, n) => post(`comment-${n}`, c.author?.login, c.createdAt, c.body)))
      .child(v_flex().flex_none().gap(8).pt(4)
        .child(Textarea.new(doc.box).text_size(13))
        .child(h_flex().gap(8).justify_end()
          .when(Boolean(doc.busy), e => e.child(div().text_color(t.dim).child("Saving…")))
          .when(!doc.busy, e => e
            .child(button("issue-state", open ? "Close issue" : "Reopen issue", false, cx => this.act(doc, open ? "close" : "reopen", cx)))
            .child(button("issue-comment", "Comment", true, cx => this.act(doc, "comment", cx))))));
  }

  render(cx) {
    // Asked here, not by command: a viewer in a tab shown again may only start now.
    if (shared("file-view.leave") === props()?.tab) { setShared("file-view.leave", null); this.leave(cx); }
    const { files, active } = this.view();
    this.sync(files, cx);
    const t = theme(), doc = this.docs.get(active), entry = doc?.entry;
    const markdown = entry && !entry.diff && !entry.issue && MARKDOWN.has(extOf(entry.file));
    const names = files.map(e => e.issue ? `#${e.issue.number} ${e.issue.title}` : nameOf(e.file) + (e.diff ? ` · ${e.diff.commit ? e.diff.commit.slice(0, 7) : "changes"}` : ""));
    // Two open tabs with the same name show their parent folder too.
    const label = (e, i) => !e.issue && names.indexOf(names[i]) !== names.lastIndexOf(names[i]) ? `${nameOf(folderOf(e.file))}/${names[i]}` : names[i];
    const tab = (e, i) => {
      const id = entryId(e), on = id === active;
      return h_flex().id(`view-${id}`).h(26).pl(10).pr(4).gap(6).flex_none().items_center().rounded(6).text_size(12.5)
        .bg(on ? t.raised : t.chrome).text_color(on ? t.foreground : t.muted).hover(s => s.bg(t.hover))
        .on_click(() => this.setView({ files, active: id }))
        .when(Boolean(e.diff), el => el.child(div().text_size(11).text_color(t.ansi3).child("±")))
        .when(Boolean(e.issue), el => el.child(svg("mods/issues/circle-dot.svg").size(11).flex_none().text_color(t.ansi2)))
        .child(div().max_w(200).truncate().child(label(e, i)))
        .when(Boolean(this.docs.get(id)?.dirty), el => el.child(div().text_size(10).text_color(t.accent).child("●")))
        .child(div().id(`view-close-${id}`).size(18).flex().items_center().justify_center().rounded(4).text_color(t.dim).hover(s => s.bg(t.selected))
          .on_click((_e, cx) => { cx.stop_propagation(); this.close(id, cx); }).child(svg("mods/pane/close.svg").size(11)));
    };
    const toggle = (id, text, on, set) => div().id(id).px(8).h(22).flex().items_center().rounded(5).text_size(11.5)
      .bg(on ? t.selected : t.popover).text_color(on ? t.foreground : t.muted)
      .hover(s => s.bg(t.hover)).on_click((_e, cx) => { set(); cx.notify(); }).child(text);
    const modes = markdown && doc.loaded && !doc.error
      ? [toggle("view-preview", "Preview", !doc.source, () => { doc.source = false; }), toggle("view-source", "Source", doc.source, () => { doc.source = true; })]
      : null;
    const body = !doc ? div().p(12).text_color(t.dim).child("Open a file, diff or issue from the Files, Graph or Issues panel")
      : doc.error ? div().p(12).text_color(t.dim).child(doc.error)
      : !doc.loaded ? div().p(12).text_color(t.dim).child("Loading…")
      : entry.issue ? this.issueBody(doc, t)
      : entry.diff ? this.diffBody(doc, t)
      : markdown && !doc.source ? div().flex_1().min_h(0).px(20).py(12).child(TextView.markdown(`md-${doc.id}`, doc.text).size_full().scrollable(true).selectable(true))
      : Editor.new(doc.code).flex_1().min_h(0);
    return v_flex().id("file-view").key_context("FileView").on_action("file_view_find", () => this.find()).size_full().min_h(0).bg(t.background).text_color(t.foreground).text_size(13)
      .child(h_flex().id("view-tabs").h(34).flex_none().px(6).gap(3).items_center().bg(t.chrome).border_b(1).border_color(t.border)
        .overflow_x_scrollbar().children(files.map(tab)))
      .child(v_flex().flex_1().min_h(0).relative()
        .child(body)
        .when(Boolean(modes), el => el.child(h_flex().id("view-corner").absolute().top_0().right_0().w(200).h(56).pt(8).pr(18).justify_end().items_start()
          .on_hover((over, cx) => { this.cornered = over; cx.notify(); })
          .when(Boolean(this.cornered), el => el.child(h_flex().gap(2).p(2).rounded(7).bg(t.popover).border(1).border_color(t.border).children(modes))))));
  }
}
