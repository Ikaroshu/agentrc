// Tabs for the files and diffs the Files and Graph panels opened in this tab: editable files
// (Markdown rendered until Source), and diffs stacked (removed lines above added ones), scrolling
// sideways for long lines. Cmd-S saves (keys.json
// binds it to `file-view.save`); Option-F (`file-view.find`, so not typing "ƒ" here) searches the
// shown file from the Files panel's search box, since the editor keeps Cmd-F for itself; a file changed on disk since it was opened needs a second Cmd-S to
// overwrite, and a tab with unsaved edits asks before closing. Files too large to load whole stay
// read-only. Local files and uncommitted diffs reload when the file changes on disk (not over
// unsaved edits); uncommitted diffs also recheck every 10 seconds, since a commit or reset changes
// them without touching the file. Preview/Source (Markdown) shows while the pointer is at the
// content's top right corner.
import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex, Editor, EditorState, TextView, Scrollbar, v_virtual_list } from "gpui-base";
import { props, shared, setShared, panes, run, exec, readTextFile, writeTextFile, watchFolder, theme, settings, nextCommand, notify, openOverlay } from "herdr";

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

// Numbers each line (a removed line by its old number) and sizes the rows to the longest line.
function diffRows(lines) {
  const rows = [];
  let old = 0, next = 0;
  for (const raw of lines.slice(0, DIFF_LINES)) {
    const line = raw.length > 4000 ? raw.slice(0, 4000) + "… (line truncated)" : raw;
    const match = /^@@ -(\d+)(?:,\d+)? \+(\d+)/.exec(line);
    if (match) { old = +match[1]; next = +match[2]; rows.push({ hunk: line }); continue; }
    const kind = line[0], text = line.slice(1) || " ";
    if (kind === "-") rows.push({ kind, number: old++, text });
    else if (kind === "+") rows.push({ kind, number: next++, text });
    else if (kind === " ") { old++; rows.push({ kind, number: next++, text }); }
  }
  if (lines.length > DIFF_LINES) rows.push({ hunk: `… diff truncated at ${DIFF_LINES} lines` });
  return { rows, width: Math.max(300, ...rows.map(row => (row.text ?? row.hunk).length * 7 + 60)) };
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

  // Shows the Files panel with its search scoped to the shown file.
  find() {
    const entry = this.docs.get(this.view().active)?.entry;
    if (!entry || entry.diff) return;
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
        if (doc.entry.diff) {
          const { lines, message } = await diffLines(doc.entry);
          if (this.docs.get(doc.id) !== doc) return;
          doc.error = message ?? null; doc.rows = lines ? diffRows(lines) : null; doc.loaded = true;
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
      syntax: { keyword: t.ansi5, string: t.ansi2, comment: t.dim, function: t.ansi4, type: t.ansi3, number: t.ansi1, constant: t.ansi6 } });
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
    for (const [id, doc] of this.docs) if (!open.has(id)) { doc.code?.release(); this.docs.delete(id); }
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

  diffRow(row, t) {
    if (row.hunk !== undefined) return div().w_full().px(12).h(20).flex_none().truncate().bg(t.raised).text_color(t.dim).child(row.hunk);
    return h_flex().w_full().h(20).flex_none().gap(10).when(row.kind === "+", (e) => e.bg(t.ansi2 + "18")).when(row.kind === "-", (e) => e.bg(t.ansi1 + "18"))
      .child(div().w(36).flex_none().text_right().text_color(t.dim).child(String(row.number)))
      .child(div().flex_1().min_w(0).truncate().child(row.text));
  }

  diffBody(doc, t) {
    const list = `diff-${doc.id}`, { rows, width } = doc.rows;
    const items = v_virtual_list(list, rows.length, 20, (i) => String(i),
      (range) => rows.slice(range.start, range.end).map((row) => this.diffRow(row, t))).size_full();
    return div().flex_1().min_h(0).relative().font_family(settings().font_family ?? "JetBrains Mono").text_size(11)
      .child(div().id(`${list}-x`).size_full().overflow_x_scrollbar().child(div().w_full().min_w(width).h_full().child(items)))
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
    const body = !doc ? div().p(12).text_color(t.dim).child("Open a file from the Files or Changes panel")
      : doc.error ? div().p(12).text_color(t.dim).child(doc.error)
      : !doc.loaded ? div().p(12).text_color(t.dim).child("Loading…")
      : entry.diff ? this.diffBody(doc, t)
      : markdown && !doc.source ? div().flex_1().min_h(0).px(20).py(12).child(TextView.markdown(`md-${doc.id}`, doc.text).size_full().scrollable(true).selectable(true))
      : Editor.new(doc.code).flex_1().min_h(0);
    return v_flex().id("file-view").size_full().min_h(0).bg(t.background).text_color(t.foreground).text_size(13)
      .child(h_flex().id("view-tabs").h(34).flex_none().px(6).gap(3).items_center().bg(t.chrome).border_b(1).border_color(t.border)
        .overflow_x_scrollbar().children(files.map(tab)))
      .child(v_flex().flex_1().min_h(0).relative()
        .child(body)
        .when(Boolean(modes), el => el.child(h_flex().id("view-corner").absolute().top_0().right_0().w(200).h(56).pt(8).pr(18).justify_end().items_start()
          .on_hover((over, cx) => { this.cornered = over; cx.notify(); })
          .when(Boolean(this.cornered), el => el.child(h_flex().gap(2).p(2).rounded(7).bg(t.popover).border(1).border_color(t.border).children(modes))))));
  }
}
