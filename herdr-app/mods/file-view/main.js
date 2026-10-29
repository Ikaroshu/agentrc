// Read-only tabs for the files the Files panel opened in this tab, with rendered Markdown.
// Local files reload in place when they change on disk.
import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex, Editor, EditorState, TextView } from "gpui-base";
import { props, shared, setShared, panes, run, readTextFile, watchFolder, theme, settings } from "herdr";

const LANG = { ts: "js", tsx: "js", mts: "js", cts: "js", jsx: "js", mjs: "js", toml: "yaml", jsonc: "json", svelte: "html", vue: "html" };
const MARKDOWN = new Set(["md", "markdown", "mdx"]);
const folderOf = (file) => file.slice(0, file.lastIndexOf("/"));
const nameOf = (file) => file.slice(file.lastIndexOf("/") + 1);
const extOf = (file) => nameOf(file).includes(".") ? nameOf(file).split(".").pop().toLowerCase() : "txt";

export default class FileView extends View {
  init() {
    this.docs = new Map(); this.watching = new Set();
  }

  view() {
    const view = (shared("file-view") ?? {})[props()?.tab];
    return view?.files ? view : { files: [], active: null };
  }

  setView(view) {
    setShared("file-view", { ...(shared("file-view") ?? {}), [props().tab]: view });
  }

  close(file) {
    const { files, active } = this.view(), at = files.findIndex(f => f.file === file), rest = files.filter(f => f.file !== file);
    if (!rest.length) {
      const all = { ...(shared("file-view") ?? {}) };
      delete all[props().tab];
      setShared("file-view", all);
      run("pane.close", { pane: panes().find(p => p.mod === "file-view" && p.tab === props().tab)?.pane });
      return;
    }
    this.setView({ files: rest, active: active === file ? rest[Math.min(at, rest.length - 1)].file : active });
  }

  load(doc, cx) {
    cx.spawn(async cx => {
      try {
        const text = await readTextFile(doc.file, { on: doc.on });
        if (this.docs.get(doc.file) !== doc) return;
        doc.error = text === null ? "This file is no longer available" : text.includes("\0") ? "Binary file · no text preview" : null;
        if (!doc.error) this.fill(doc, text);
      } catch { if (this.docs.get(doc.file) === doc) doc.error = "Cannot preview this file (binary, too large, or unreadable)"; }
      finally { cx.notify(); }
    });
  }

  fill(doc, text) {
    doc.text = text.length > 400000 ? text.slice(0, 400000) + "\n… (file truncated)" : text;
    if (doc.code) { doc.code.set_value(doc.text); return; }
    const t = theme(), ext = extOf(doc.file);
    doc.code = EditorState.new({ language: LANG[ext] ?? ext, readonly: true, value: doc.text,
      font_family: settings().font_family, font_size: 12,
      syntax: { keyword: t.ansi5, string: t.ansi2, comment: t.dim, function: t.ansi4, type: t.ansi3, number: t.ansi1, constant: t.ansi6 } });
  }

  // Opens docs for new files, releases closed ones, and watches the folders of local ones.
  sync(files, cx) {
    const open = new Set(files.map(f => f.file));
    for (const [file, doc] of this.docs) if (!open.has(file)) { doc.code?.release(); this.docs.delete(file); }
    for (const f of files) if (!this.docs.has(f.file)) {
      const doc = { file: f.file, on: f.on, text: null, code: null, error: null, source: false };
      this.docs.set(f.file, doc);
      this.load(doc, cx);
    }
    const folders = new Set(files.filter(f => !f.on).map(f => folderOf(f.file)));
    for (const folder of this.watching) if (!folders.has(folder)) this.watching.delete(folder);
    for (const folder of folders) if (!this.watching.has(folder)) {
      this.watching.add(folder);
      cx.spawn(async cx => {
        while (this.watching.has(folder)) {
          const changed = await watchFolder(folder);
          if (!this.watching.has(folder)) break;
          for (const doc of this.docs.values()) if (changed.includes(doc.file)) this.load(doc, cx);
        }
      });
    }
  }

  render(cx) {
    const { files, active } = this.view();
    this.sync(files, cx);
    const t = theme(), doc = this.docs.get(active), markdown = doc && MARKDOWN.has(extOf(doc.file));
    const names = files.map(f => nameOf(f.file));
    // Two open files with the same name show their parent folder too.
    const label = (f, i) => names.indexOf(names[i]) !== names.lastIndexOf(names[i]) ? `${nameOf(folderOf(f.file))}/${names[i]}` : names[i];
    const tab = (f, i) => {
      const on = f.file === active;
      return h_flex().id(`view-${f.file}`).h(26).pl(10).pr(4).gap(6).flex_none().items_center().rounded(6).text_size(12.5)
        .bg(on ? t.raised : t.chrome).text_color(on ? t.foreground : t.muted).hover(s => s.bg(t.hover))
        .on_click(() => this.setView({ files, active: f.file }))
        .child(div().max_w(180).truncate().child(label(f, i)))
        .child(div().id(`view-close-${f.file}`).size(18).flex().items_center().justify_center().rounded(4).text_color(t.dim).hover(s => s.bg(t.selected))
          .on_click((_e, cx) => { cx.stop_propagation(); this.close(f.file); }).child(svg("mods/pane/close.svg").size(11)));
    };
    const mode = (id, text, source) => div().id(id).px(8).h(22).flex().items_center().rounded(5).text_size(11.5)
      .bg(doc?.source === source ? t.selected : t.background).text_color(doc?.source === source ? t.foreground : t.muted)
      .hover(s => s.bg(t.hover)).on_click((_e, cx) => { doc.source = source; cx.notify(); }).child(text);
    const body = !doc ? div().p(12).text_color(t.dim).child("Open a file from the Files panel")
      : doc.error ? div().p(12).text_color(t.dim).child(doc.error)
      : doc.text === null ? div().p(12).text_color(t.dim).child("Loading file…")
      : markdown && !doc.source ? div().flex_1().min_h(0).px(20).py(12).child(TextView.markdown(`md-${doc.file}`, doc.text).size_full().scrollable(true).selectable(true))
      : Editor.new(doc.code).flex_1().min_h(0);
    return v_flex().id("file-view").size_full().min_h(0).bg(t.background).text_color(t.foreground).text_size(13)
      .child(h_flex().id("view-tabs").h(34).flex_none().px(6).gap(3).items_center().bg(t.chrome).border_b(1).border_color(t.border)
        .overflow_x_scrollbar().children(files.map(tab)))
      .when(Boolean(doc), el => el.child(h_flex().h(28).flex_none().px(12).gap(4).items_center().border_b(1).border_color(t.border)
        .child(div().flex_1().min_w(0).truncate().text_size(11.5).text_color(t.dim).child(folderOf(doc.file)))
        .when(markdown, el => el.child(mode("view-preview", "Preview", false)).child(mode("view-source", "Source", true)))))
      .child(body);
  }
}
