// Vendored from github.com/rabeeh-ta/herdr-git-graph at 1cfcff3 (MIT, see LICENSE). Changed here:
// a file clicked in a commit's details opens its diff in the tab's file-view pane instead of
// inline, the links to Herdr's Changes panel are gone (this layout has none), and a focused mod
// pane follows its tab's first terminal's repository, as the Files panel does.
import { View } from "gpui-kit";
import { props } from "herdr";
import { Graph } from "./graph.js";
import { Menu } from "./menu.js";
import { Dialog } from "./dialog.js";

// One mod, three roles: the graph (a panel or a pane), and over the window the
// right-click menu and the dialogs its actions ask first (props.role).
export default class GitGraph extends View {
  init(_props, cx) {
    const role = props()?.role;
    this.part = role === "menu" ? new Menu() : role === "dialog" ? new Dialog() : new Graph();
    this.part.init(cx);
  }

  render(cx) { return this.part.render(cx); }
}
