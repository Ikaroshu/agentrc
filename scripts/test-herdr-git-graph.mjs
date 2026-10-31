// Run with node scripts/test-herdr-git-graph.mjs. Native layout is checked with herdr-app check/shot.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";

let shown, renderingRow = false;
function element() {
  const node = new Proxy({}, { get: (_target, name) => (...args) => {
    assert.ok(!renderingRow || !String(name).startsWith("on_"), "lazy rows must not register event handlers");
    if (name === "when" && args[0]) args[1](node);
    return node;
  } });
  return node;
}
const source = readFileSync(new URL("../herdr-app/mods/git-graph/graph.js", import.meta.url), "utf8");
const Graph = vm.runInNewContext(source.replace(/^import[\s\S]*?;\n/gm, "").replace("export class Graph", "class Graph") + "\nGraph", {
  div: element, h_flex: element, v_flex: element,
  Scrollbar: { vertical: element },
  lazyList: (_id, count, key, render) => { shown = { keys: Array.from({ length: count }, (_, i) => key(i)), render }; return element(); },
});
const commits = [
  { hash: "*", uncommitted: true },
  { hash: "a", subject: "First", parents: [], author: "Author", email: "author@example.test", time: 1 },
  { hash: "b", subject: "Second", parents: [], author: "Author", email: "author@example.test", time: 1 },
];
const graph = new Graph();
Object.assign(graph, { commits, index: new Map(commits.map((c, i) => [c.hash, i])), lanes: 1, graphMax: 160,
  listId: "test", handle: { focus() {} }, limit: 300 });
graph.row = () => element();
graph.loadDetails = () => { graph.details = { files: [{ path: "file.js", status: "M", add: 2, del: 1 }], more: 0, message: "Subject\n\nLong description" }; };
let opened, pages = 0;
graph.openDiff = (commit, file) => { opened = [commit.hash, file.path]; };
graph.loadMore = () => { pages++; };
const cx = { notify() {}, spawn: (fn) => fn(cx) };
function draw() {
  graph.list({}, "mono");
  renderingRow = true;
  shown.keys.forEach((_key, i) => shown.render(i, cx));
  renderingRow = false;
  return shown.keys;
}
for (const hash of ["*", "a", "b"]) {
  graph.clicked(hash, cx);
  const keys = draw(), start = keys.indexOf(hash), next = commits.findIndex((c) => c.hash === hash) + 1;
  assert.equal(keys[start + 1], "details-close");
  assert.ok(keys.indexOf(`file:${hash}:file.js`) > start);
  if (next < commits.length) assert.ok(keys.indexOf(commits[next].hash) > keys.indexOf("details-end"));
  assert.deepEqual(keys.filter((key) => graph.index.has(key)), ["*", "a", "b"]);
  graph.clicked(`file:${hash}:file.js`, cx);
  assert.deepEqual(opened, [hash, "file.js"]);
  assert.equal(graph.selected, hash);
  graph.clicked(hash, cx);
  assert.deepEqual(draw(), ["*", "a", "b"]);
}
graph.clicked("a", cx);
graph.clicked("b", cx);
opened = null;
graph.clicked("file:a:file.js", cx);
assert.equal(opened, null, "a queued file click must not open a different commit's diff");
graph.details = null;
assert.ok(draw().includes("details-close"), "loading details remain directly under the selection");
graph.details = { error: "Cannot read commit" };
assert.ok(draw().includes("details-close"), "failed details retain their collapse control");
graph.clicked("details-close", cx);
assert.deepEqual(draw(), ["*", "a", "b"]);
graph.hasMore = true;
assert.equal(draw().at(-1), "more");
assert.equal(pages, 1);
draw();
assert.equal(pages, 1, "the same final row must not request a page twice");
console.log("Git graph inline details passed: placement, collapse, file routing, lazy handlers, and pagination.");
