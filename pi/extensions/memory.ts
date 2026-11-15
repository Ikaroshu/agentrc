// pi-memory reads this when it writes the quit summary; Haiku keeps that call cheap.
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (_pi: ExtensionAPI) {
  process.env.PI_MEMORY_EXIT_SUMMARY_MODEL ??= "anthropic/claude-haiku-5-5";
}
