// Read-only tabs for the files and diffs the Files and Changes panels opened in this tab: rendered
// Markdown, and diffs side by side or unified. Local files and uncommitted diffs reload when the
// file changes on disk; uncommitted diffs also recheck every 10 seconds, since a commit or reset
// changes them without touching the file.
import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex, Editor, EditorState, TextView, Scrollbar, v_virtual_list } from "gpui-base";
import { props, shared, setShared, panes, run, exec, readTextFile, watchFolder, theme, settings } from "herdr";

const LANG = { ts: "js", tsx: "js", mts: "js", cts: "js", jsx: "js", mjs: "js", toml: "yaml", jsonc: "json", svelte: "html", vue: "html" };
const MARKDOWN = new Set(["md", "markdown", "mdx"]);
const DIFF_LINES = 10000;
const folderOf = (file) => file.slice(0, file.lastIndexOf("/"));
const nameOf = (file) => file.slice(file.lastIndexOf("/") + 1);
const extOf = (file) => nameOf(file).includes(".") ? nameOf(file).split(".").pop().toLowerCase() : "txt";
const entryId = (e) => e.diff ? `${e.diff.commit ?? "working"}:${e.file}` : e.file;
const working = (e) => !e.diff || e.diff.commit === null;

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

// Numbers each line and pairs each run of removals with the additions after it, so a split
// row shows the old line beside the new one.
function diffRows(lines) {
  const unified = [], split = [];
  let old = 0, next = 0, minus = [], plus = [];
  const flush = () => {
    for (let i = 0; i < Math.max(minus.length, plus.length); i++) split.push({ left: minus[i] ?? null, right: plus[i] ?? null });
    minus = []; plus = [];
  };
  for (const raw of lines.slice(0, DIFF_LINES)) {
    const line = raw.length > 4000 ? raw.slice(0, 4000) + "… (line truncated)" : raw;
    const match = /^@@ -(\d+)(?:,\d+)? \+(\d+)/.exec(line);
    if (match) {
      flush(); old = +match[1]; next = +match[2];
      unified.push({ hunk: line }); split.push({ hunk: line });
      continue;
    }
    const kind = line[0], text = line.slice(1) || " ";
    if (kind === "-") { const cell = { kind, number: old++, text }; minus.push(cell); unified.push(cell); }
    else if (kind === "+") { const cell = { kind, number: next++, text }; plus.push(cell); unified.push(cell); }
    else if (kind === " ") {
      flush();
      split.push({ left: { kind, number: old++, text }, right: { kind, number: next, text } });
      unified.push({ kind, number: next++, text });
    }
  }
  flush();
  if (lines.length > DIFF_LINES) { unified.push({ hunk: `… diff truncated at ${DIFF_LINES} lines` }); split.push({ hunk: `… diff truncated at ${DIFF_LINES} lines` }); }
  return { unified, split, width: Math.max(300, ...unified.map(row => (row.text ?? row.hunk).length * 7 + 60)) };
}

export default class FileView extends View {
  init(_props, cx) {
    this.docs = new Map(); this.watching = new Set();
    cx.timer.every(10000, cx => { for (const doc of this.docs.values()) if (doc.entry.diff && working(doc.entry)) this.load(doc, cx); });
  }

  view() {
    const view = (shared("file-view") ?? {})[props()?.tab];
    return view?.files ? view : { files: [], active: null };
  }

  setView(view) {
    setShared("file-view", { ...(shared("file-view") ?? {}), [props().tab]: view });
  }

  close(id) {
    const { files, active } = this.view(), at = files.findIndex(f => entryId(f) === id), rest = files.filter(f => entryId(f) !== id);
    if (!rest.length) {
      const all = { ...(shared("file-view") ?? {}) };
      delete all[props().tab];
      setShared("file-view", all);
      run("pane.close", { pane: panes().find(p => p.mod === "file-view" && p.tab === props().tab)?.pane });
      return;
    }
    this.setView({ files: rest, active: active === id ? entryId(rest[Math.min(at, rest.length - 1)]) : active });
  }

  load(doc, cx) {
    cx.spawn(async cx => {
      try {
        if (doc.entry.diff) {
          const { lines, message } = await diffLines(doc.entry);
          if (this.docs.get(doc.id) !== doc) return;
          doc.error = message ?? null; doc.rows = lines ? diffRows(lines) : null; doc.loaded = true;
          return;
        }
        const text = await readTextFile(doc.entry.file, { on: doc.entry.on });
        if (this.docs.get(doc.id) !== doc) return;
        doc.error = text === null ? "This file is no longer available" : text.includes("\0") ? "Binary file · no text preview" : null;
        if (!doc.error) this.fill(doc, text);
        doc.loaded = true;
      } catch { if (this.docs.get(doc.id) === doc) { doc.error = `Cannot show this ${doc.entry.diff ? "diff" : "file"} (binary, too large, or unreadable)`; doc.loaded = true; } }
      finally { cx.notify(); }
    });
  }

  fill(doc, text) {
    doc.text = text.length > 400000 ? text.slice(0, 400000) + "\n… (file truncated)" : text;
    if (doc.code) { doc.code.set_value(doc.text); return; }
    const t = theme(), ext = extOf(doc.entry.file);
    doc.code = EditorState.new({ language: LANG[ext] ?? ext, readonly: true, value: doc.text,
      font_family: settings().font_family, font_size: 12,
      syntax: { keyword: t.ansi5, string: t.ansi2, comment: t.dim, function: t.ansi4, type: t.ansi3, number: t.ansi1, constant: t.ansi6 } });
  }

  // Opens docs for new entries, releases closed ones, and watches the folders of local files
  // whose content can change.
  sync(files, cx) {
    const open = new Set(files.map(entryId));
    for (const [id, doc] of this.docs) if (!open.has(id)) { doc.code?.release(); this.docs.delete(id); }
    for (const entry of files) {
      const id = entryId(entry);
      if (this.docs.has(id)) continue;
      const doc = { id, entry, loaded: false, error: null, text: null, code: null, rows: null, source: false, unified: false };
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

  splitRow(row, t) {
    if (row.hunk !== undefined) return div().w_full().h(20).px(12).flex_none().truncate().bg(t.raised).text_color(t.dim).child(row.hunk);
    const side = (cell) => h_flex().flex_1().min_w(0).h_full().gap(8)
      .when(!cell, e => e.bg(t.surface)).when(cell?.kind === "-", e => e.bg(t.ansi1 + "18")).when(cell?.kind === "+", e => e.bg(t.ansi2 + "18"))
      .child(div().w(36).flex_none().text_right().text_color(t.dim).child(cell ? String(cell.number) : ""))
      .child(div().flex_1().min_w(0).truncate().child(cell?.text ?? ""));
    return h_flex().w_full().h(20).flex_none().child(side(row.left)).child(div().w(1).h_full().flex_none().bg(t.border)).child(side(row.right));
  }

  unifiedRow(row, t) {
    if (row.hunk !== undefined) return div().w_full().px(12).h(20).flex_none().truncate().bg(t.raised).text_color(t.dim).child(row.hunk);
    return h_flex().w_full().h(20).flex_none().gap(10).when(row.kind === "+", (e) => e.bg(t.ansi2 + "18")).when(row.kind === "-", (e) => e.bg(t.ansi1 + "18"))
      .child(div().w(36).flex_none().text_right().text_color(t.dim).child(String(row.number)))
      .child(div().flex_1().min_w(0).truncate().child(row.text));
  }

  diffBody(doc, t) {
    const list = `diff-${doc.id}`, rows = doc.unified ? doc.rows.unified : doc.rows.split;
    const items = v_virtual_list(list, rows.length, 20, (i) => String(i),
      (range) => rows.slice(range.start, range.end).map((row) => doc.unified ? this.unifiedRow(row, t) : this.splitRow(row, t))).size_full();
    return div().flex_1().min_h(0).relative().font_family(settings().font_family ?? "JetBrains Mono").text_size(11)
      .child(doc.unified ? div().id(`${list}-x`).size_full().overflow_x_scrollbar().child(div().w_full().min_w(doc.rows.width).h_full().child(items)) : items)
      .child(Scrollbar.vertical(list).viewport_from_layout().absolute().inset_0());
  }

  render(cx) {
    const { files, active } = this.view();
    this.sync(files, cx);
    const t = theme(), doc = this.docs.get(active), entry = doc?.entry;
    const markdown = entry && !entry.diff && MARKDOWN.has(extOf(entry.file));
    const names = files.map(e => nameOf(e.file) + (e.diff ? ` · ${e.diff.commit ? e.diff.commit.slice(0, 7) : "changes"}` : ""));
    // Two open tabs with the same name show their parent folder too.
    const label = (e, i) => names.indexOf(names[i]) !== names.lastIndexOf(names[i]) ? `${nameOf(folderOf(e.file))}/${names[i]}` : names[i];
    const tab = (e, i) => {
      const id = entryId(e), on = id === active;
      return h_flex().id(`view-${id}`).h(26).pl(10).pr(4).gap(6).flex_none().items_center().rounded(6).text_size(12.5)
        .bg(on ? t.raised : t.chrome).text_color(on ? t.foreground : t.muted).hover(s => s.bg(t.hover))
        .on_click(() => this.setView({ files, active: id }))
        .when(Boolean(e.diff), el => el.child(div().text_size(11).text_color(t.ansi3).child("±")))
        .child(div().max_w(200).truncate().child(label(e, i)))
        .child(div().id(`view-close-${id}`).size(18).flex().items_center().justify_center().rounded(4).text_color(t.dim).hover(s => s.bg(t.selected))
          .on_click((_e, cx) => { cx.stop_propagation(); this.close(id); }).child(svg("mods/pane/close.svg").size(11)));
    };
    const toggle = (id, text, on, set) => div().id(id).px(8).h(22).flex().items_center().rounded(5).text_size(11.5)
      .bg(on ? t.selected : t.background).text_color(on ? t.foreground : t.muted)
      .hover(s => s.bg(t.hover)).on_click((_e, cx) => { set(); cx.notify(); }).child(text);
    const where = !entry ? "" : entry.diff ? `${entry.diff.path} · ${entry.diff.commit ? `commit ${entry.diff.commit.slice(0, 7)}` : "uncommitted, against HEAD"}` : folderOf(entry.file);
    const body = !doc ? div().p(12).text_color(t.dim).child("Open a file from the Files or Changes panel")
      : doc.error ? div().p(12).text_color(t.dim).child(doc.error)
      : !doc.loaded ? div().p(12).text_color(t.dim).child("Loading…")
      : entry.diff ? this.diffBody(doc, t)
      : markdown && !doc.source ? div().flex_1().min_h(0).px(20).py(12).child(TextView.markdown(`md-${doc.id}`, doc.text).size_full().scrollable(true).selectable(true))
      : Editor.new(doc.code).flex_1().min_h(0);
    return v_flex().id("file-view").size_full().min_h(0).bg(t.background).text_color(t.foreground).text_size(13)
      .child(h_flex().id("view-tabs").h(34).flex_none().px(6).gap(3).items_center().bg(t.chrome).border_b(1).border_color(t.border)
        .overflow_x_scrollbar().children(files.map(tab)))
      .when(Boolean(doc), el => el.child(h_flex().h(28).flex_none().px(12).gap(4).items_center().border_b(1).border_color(t.border)
        .child(div().flex_1().min_w(0).truncate().text_size(11.5).text_color(t.dim).child(where))
        .when(markdown, el => el.child(toggle("view-preview", "Preview", !doc.source, () => { doc.source = false; }))
          .child(toggle("view-source", "Source", doc.source, () => { doc.source = true; })))
        .when(Boolean(entry?.diff), el => el.child(toggle("view-split", "Split", !doc.unified, () => { doc.unified = false; }))
          .child(toggle("view-unified", "Unified", doc.unified, () => { doc.unified = true; })))))
      .child(body);
  }
}
