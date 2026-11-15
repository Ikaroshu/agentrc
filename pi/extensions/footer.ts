// Footer in the style of the Claude Code status line (agentrc claude/statusline.sh):
// model + thinking · directory · Git branch · session cost · context used.
// Cost and context take the place of Claude's usage limits, since pi bills API credits.
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";
import { homedir } from "node:os";

function formatTokens(count: number): string {
  if (count < 1_000_000) return `${Math.round(count / 1000)}k`;
  return `${Number((count / 1_000_000).toFixed(1))}M`;
}

// Same entries the built-in footer counts: assistant replies, tool-made model calls, summaries.
function sessionCost(ctx: ExtensionContext): number {
  let cost = 0;
  for (const entry of ctx.sessionManager.getEntries() as any[]) {
    const usage = entry.type === "message" ? entry.message.usage : entry.usage;
    cost += usage?.cost?.total ?? 0;
  }
  return cost;
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;
    ctx.ui.setFooter((tui, theme, footerData) => ({
      dispose: footerData.onBranchChange(() => tui.requestRender()),
      invalidate() {},
      render(width: number): string[] {
        // "Claude Sonnet 5.5" -> "Sonnet 5.5", like the status line's display name.
        let model = (ctx.model?.name ?? ctx.model?.id ?? "no model").replace(/^Claude /, "");
        if (ctx.model?.reasoning) model += ` ${pi.getThinkingLevel()}`;
        const cwd = ctx.sessionManager.getCwd();
        const parts = [model, cwd === homedir() || cwd.startsWith(`${homedir()}/`) ? `~${cwd.slice(homedir().length)}` : cwd];
        const branch = footerData.getGitBranch();
        if (branch) parts.push(branch);
        parts.push(`$${sessionCost(ctx).toFixed(2)}`);

        const usage = ctx.getContextUsage();
        const contextWindow = usage?.contextWindow ?? ctx.model?.contextWindow ?? 0;
        const percent = usage?.percent ?? null;
        const context = `context ${percent === null ? "?" : Math.round(percent)}% of ${formatTokens(contextWindow)}`;
        const color = percent !== null && percent > 90 ? "error" : percent !== null && percent > 70 ? "warning" : "dim";

        const lines = [truncateToWidth(`${theme.fg("dim", `${parts.join(" · ")} · `)}${theme.fg(color, context)}`, width)];
        const statuses = [...footerData.getExtensionStatuses().entries()]
          .sort(([a], [b]) => a.localeCompare(b))
          .map(([, text]) => text.replace(/\s+/g, " "));
        if (statuses.length > 0) lines.push(truncateToWidth(statuses.join(" "), width, theme.fg("dim", "...")));
        return lines;
      },
    }));
  });
}
