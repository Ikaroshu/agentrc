// Run with node scripts/test-herdr-git-graph.mjs. Native layout is checked with herdr-app check/shot.
import assert from "node:assert/strict";
import { readFileSync, mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { spawnSync } from "node:child_process";
import * as git from "../herdr-app/mods/git-graph/git.js";
import { layoutLanes } from "../herdr-app/mods/git-graph/lanes.js";
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
  labels: new Map(commits.map((c) => [c.hash, []])),
  listId: "test", handle: { focus() {} }, limit: 300 });
graph.saw = () => {};
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

// Real Git checkouts: ignored nested worktrees and an external detached worktree.
const fixture = mkdtempSync('/private/tmp/agentrc-graph-test-');
const main = `${fixture}/main`, feature = `${main}/.worktrees/feature space`, detached = `${fixture}/detached`;
mkdirSync(main);
const runGit = (cwd, ...args) => {
  const result = spawnSync('git', args, { cwd, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.trim();
};
runGit(main, 'init', '-q', '-b', 'main');
runGit(main, 'config', 'user.name', 'Test');
runGit(main, 'config', 'user.email', 'test@example.test');
writeFileSync(`${main}/.gitignore`, '.worktrees/\n');
writeFileSync(`${main}/file.txt`, 'base\n');
runGit(main, 'add', '.'); runGit(main, 'commit', '-qm', 'Base');
runGit(main, 'worktree', 'add', '-qb', 'feature', feature);
runGit(main, 'worktree', 'add', '-q', '--detach', detached);
writeFileSync(`${feature}/file.txt`, 'feature commit\n');
runGit(feature, 'commit', '-qam', 'Feature commit');
writeFileSync(`${detached}/file.txt`, 'detached commit\n');
runGit(detached, 'commit', '-qam', 'Detached commit');
writeFileSync(`${feature}/file.txt`, 'feature staged\n'); runGit(feature, 'add', 'file.txt');
writeFileSync(`${feature}/file.txt`, 'feature staged\nand unstaged\n');
writeFileSync(`${feature}/new.txt`, 'untracked\n');
writeFileSync(`${detached}/file.txt`, 'detached edit\n');
const state = new Map(), calls = [], watched = [], tasks = [];
let overlay;
const native = {
  ...git, layoutLanes,
  exec: async (command, args, options) => {
    calls.push({ command, args, ...options });
    const result = spawnSync(command, args, { cwd: options.cwd, encoding: 'utf8' });
    return { code: result.status, stdout: result.stdout, stderr: result.stderr };
  },
  spaces: () => [{ active: true, tabs: [{ id: 'tab' }] }],
  panes: () => [{ pane: 'terminal', tab: 'tab', terminal: 't1', cwd: main }, { tab: 'tab', mod: 'file-view' }],
  focused: () => ({ pane: 'terminal', tab: 'tab', cwd: main }),
  shared: (key) => state.get(key), setShared: (key, value) => state.set(key, value),
  settings: () => ({}), openOverlay: (value) => { overlay = value; },
  watchFolder: (dir) => { watched.push(dir); return new Promise(() => {}); },
};
const runtime = vm.runInNewContext(source.replace(/^import[\s\S]*?;\n/gm, '').replace('export class Graph', 'class Graph') + '\n({ Graph, readFolder })', native);
const options = { all: true, remotes: true, limit: 300 };
const read = await runtime.readFolder(main, null, options);
const work = new runtime.Graph();
Object.assign(work, options, { folder: main, commitDetails: new Map(), watchToken: 0, graphMax: 160 });
work.reset(); Object.assign(work, read); work.build();
assert.equal(work.worktrees.find((w) => w.root === main).files.length, 0);
const dirty = work.commits.filter((c) => c.uncommitted);
assert.deepEqual(Array.from(dirty, (c) => c.worktree.root).sort(), [feature, detached].sort());
assert.equal(new Set(dirty.map((c) => c.hash)).size, 2);
for (const row of dirty) {
  assert.equal(row.parents[0], runGit(row.worktree.root, 'rev-parse', 'HEAD'));
  assert.ok(work.commits.some((c) => c.hash === row.parents[0]), 'detached and branch commits must be in the graph');
}
const featureRow = dirty.find((c) => c.worktree.root === feature);
assert.match(featureRow.subject, /\(2\)/);
assert.equal(work.labels.get(featureRow.hash)[0].parts[0].name, 'feature');
assert.equal(work.labels.get(dirty.find((c) => c.worktree.root === detached).hash)[0].parts[0].name, 'detached');
const testCx = { notify() {}, spawn: (fn) => { const task = fn(testCx); tasks.push(task); return task; } };
work.selected = featureRow.hash;
work.loadDetails(featureRow, testCx); await Promise.all(tasks.splice(0));
assert.deepEqual(Array.from(work.details.files, (f) => f.path), ['file.txt', 'new.txt']);
assert.equal(work.details.files[0].add, 2);
work.openDiff(featureRow, work.details.files[0]);
assert.equal(state.get('file-view').tab.files[0].diff.root, feature);
assert.equal(state.get('file-view').tab.files[0].file, `${feature}/file.txt`);
work.contextMenu(featureRow.hash, {}, testCx);
assert.equal(overlay.props.ctx.root, feature, 'stash/reset must target the selected worktree');
assert.equal(overlay.props.ctx.current, 'feature');
work.all = false; work.build();
assert.equal(work.commits.filter((c) => c.uncommitted).length, 0, 'Current excludes other worktrees');
work.all = true; work.context = work.key();
work.watch(work.context, testCx);
// Watch loops intentionally remain pending; only await the metadata discovery task.
await tasks.at(-1);
assert.ok(watched.includes(feature)); assert.ok(watched.includes(detached));
assert.ok(watched.includes(main));
work.refresh(testCx, false); await tasks.at(-1);
assert.equal(work.commits.filter((c) => c.uncommitted).length, 2);
work.selected = featureRow.hash;
writeFileSync(`${feature}/file.txt`, 'one\ntwo\nthree\n');
work.refresh(testCx, false); await tasks.at(-1); await tasks.at(-1);
assert.equal(work.details.files[0].add, 3, 'editing an already modified file refreshes its details');
runGit(feature, 'reset', '--hard', '-q', 'HEAD'); runGit(feature, 'clean', '-fdq');
work.refresh(testCx, false); await tasks.at(-1);
assert.equal(work.commits.filter((c) => c.uncommitted).length, 1);
assert.equal(work.selected, null, 'cleaning the selected worktree removes its row and details');
const linked = await runtime.readFolder(feature, 'test-machine', options);
assert.equal(linked.root, feature);
assert.ok(calls.filter((c) => c.on === 'test-machine').some((c) => c.cwd === detached), 'remote reads retain the machine for other worktrees');
rmSync(fixture, { recursive: true });
console.log('Git graph worktrees passed: staged, unstaged, untracked, detached history, diffs, action targets, refresh, and scope.');
