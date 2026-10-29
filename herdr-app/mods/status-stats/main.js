// The shipped status bar with CPU, memory and GPU use of the active space's machine (macOS) in
// place of the commands hint. Memory counts what Activity Monitor calls Memory Used: app memory
// (anonymous minus purgeable pages), wired, and compressed; file cache is left out.
import { View, div, svg } from "gpui-kit";
import { h_flex } from "gpui-base";
import { spaces, agents, theme, exec } from "herdr";

const SAMPLE = `iostat -n0 -c 2 -w 1 | tail -1; vm_stat; sysctl -n hw.memsize; ioreg -r -d 1 -w 0 -c IOAccelerator | grep -o '"Device Utilization %"=[0-9]*' | head -1`;

function parse(stdout) {
  const lines = stdout.split("\n"), pages = (name) => Number(stdout.match(new RegExp(`${name}:\\s+(\\d+)`))?.[1] ?? 0);
  const idle = Number(lines[0].trim().split(/\s+/)[2]);
  const pageSize = Number(stdout.match(/page size of (\d+) bytes/)?.[1] ?? 0);
  const used = (pages("Anonymous pages") - pages("Pages purgeable") + pages("Pages wired down") + pages("Pages occupied by compressor")) * pageSize;
  const total = Number(lines.find(l => /^\d+$/.test(l.trim())));
  const gpu = stdout.match(/"Device Utilization %"=(\d+)/)?.[1];
  return { cpu: 100 - idle, used, total, gpu: gpu === undefined ? null : Number(gpu) };
}

export default class StatusStats extends View {
  init(_props, cx) {
    this.stats = null;
    this.sample(cx);
    cx.timer.every(3000, cx => this.sample(cx));
  }

  sample(cx) {
    if (this.sampling) return;
    const on = spaces().find(s => s.active)?.machine ?? null;
    this.sampling = true;
    cx.spawn(async cx => {
      const r = await exec("sh", ["-c", SAMPLE], { on });
      this.sampling = false;
      this.stats = r.code === 0 ? { on, ...parse(r.stdout) } : null;
      cx.notify();
    });
  }

  render() {
    const t = theme();
    const space = spaces().find(s => s.active);
    const list = agents();
    const needs = list.filter(a => a.status === "blocked").length;
    const label = (icon, text) => h_flex().gap(6).items_center().child(svg(`mods/workspace-chrome/${icon}.svg`).size(13)).child(text);
    const stat = (name, value, percent) => h_flex().gap(5).items_center()
      .child(div().text_color(t.dim).child(name))
      .child(div().text_color(percent >= 90 ? t.blocked : t.muted).child(value));
    const s = this.stats?.on === (space?.machine ?? null) ? this.stats : null;
    const gb = (bytes) => (bytes / 2 ** 30).toFixed(1);
    return h_flex().size_full().px(14).gap(16).items_center().text_size(11.8).text_color(t.muted)
      .child(label(space?.machine ? "server" : "monitor", space?.machine ?? "This computer"))
      .when(Boolean(space?.branch), el => el.child(label("branch", space.branch)))
      .child(h_flex().gap(6).items_center().child(div().size(6).rounded(3).bg(t.dim)).child(`${list.length} agents`)
        .when(needs > 0, el => el.child(div().text_color(t.blocked).child(`· ${needs} needs you`))))
      .child(div().flex_1())
      .when(Boolean(s), el => el
        .child(stat("CPU", `${Math.round(s.cpu)}%`, s.cpu))
        .child(stat("MEM", `${gb(s.used)} / ${Math.round(s.total / 2 ** 30)} GB`, 100 * s.used / s.total))
        .when(s.gpu !== null, el => el.child(stat("GPU", `${s.gpu}%`, s.gpu))));
  }
}
