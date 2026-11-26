// Deterministic fast path for the guard's bash screen: decides, without the
// judge, commands made only of read-only programs and of agentrc's own
// install, validate, and push commands. Anything the scanner does not
// understand goes to the judge.
//
// Pi loads every file in the extensions directory as an extension entry point,
// so this module also exports a no-op factory. The parser itself is
// dependency-free and is tested directly by scripts/test-guard-fastpath.mjs.
import { homedir } from "node:os";
import { resolve } from "node:path";

const READ_ONLY_PROGRAMS = new Set([
  "cat", "cd", "date", "df", "du", "echo", "file", "grep", "head", "ls", "pwd",
  "rg", "stat", "tail", "tree", "true", "wc", "which",
]);
const READ_ONLY_GIT = new Set(["blame", "diff", "log", "rev-parse", "show", "status"]);
const READ_ONLY_HERDR_APP = new Set(["--help", "--skill", "commands", "ls", "status"]);
const READ_ONLY_HC = new Set(["--help", "--skill", "get", "ls"]);

// Scripts the user pre-approved in agentrc, relative to its root. They run
// without the judge only while agentrc has no uncommitted code changes.
export const AGENTRC_SCRIPTS = new Set([
  "install.sh",
  "codex/install.sh",
  "claude/install.sh",
  "pi/install.sh",
  "herdr-app/install.sh",
  "scripts/validate-config.sh",
]);
// Code that agentrc's scripts execute, as git pathspecs.
export const AGENTRC_CODE_PATHSPECS = ["*.sh", "*.py", "*.mjs", "*.ts"];

export type FastPath = "skip" | "skip-if-agentrc-clean" | "judge";

// The pre-approved agentrc commands count only when the command starts in the
// agentrc root and every cd targets that root, so a failed cd leaves the shell
// where the guard assumed it was.
export function classifyCommand(command: string, cwd: string, agentrcRoot: string): FastPath {
  if (command.trim() === "") return "judge";
  const segments = splitSegments(command);
  if (segments === null) return "judge";
  let inAgentrc = cwd === agentrcRoot;
  let runsScript = false;
  for (const tokens of segments) {
    if (tokens[0] === "cd" && !(tokens.length === 2 && expandHome(tokens[1]) === agentrcRoot)) inAgentrc = false;
    if (isReadOnlySegment(tokens)) continue;
    if (inAgentrc && isAgentrcPush(tokens)) continue;
    if (inAgentrc && isAgentrcScript(tokens, agentrcRoot)) {
      runsScript = true;
      continue;
    }
    return "judge";
  }
  return runsScript ? "skip-if-agentrc-clean" : "skip";
}

// All words of the command with quotes stripped and separators dropped, or
// null when the scanner rejects the command.
export function commandWords(command: string): string[] | null {
  const segments = splitSegments(command);
  return segments === null ? null : segments.flat();
}

function expandHome(word: string): string {
  return word === "~" || word.startsWith("~/") ? homedir() + word.slice(1) : word;
}

// Splits on top-level &&, ||, ;, |, and newlines, honoring single and double
// quotes. Returns null on any construct the fast path does not understand:
// expansions, command substitution, subshells, brace groups, background jobs,
// or redirects other than to /dev/null and fd duplication like 2>&1.
function splitSegments(command: string): string[][] | null {
  const segments: string[][] = [[]];
  let word = "";
  let i = 0;

  const endWord = (): void => {
    if (word !== "") segments[segments.length - 1].push(word);
    word = "";
  };
  const breakSegment = (skip: number): void => {
    endWord();
    segments.push([]);
    i += skip;
  };

  while (i < command.length) {
    const ch = command[i];
    if (ch === "'") {
      i++;
      while (i < command.length && command[i] !== "'") {
        word += command[i];
        i++;
      }
      if (i >= command.length) return null;
      i++;
      continue;
    }
    if (ch === '"') {
      i++;
      while (i < command.length && command[i] !== '"') {
        if (command[i] === "\\" && i + 1 < command.length) {
          i += 2;
          continue;
        }
        // Expansions and substitutions are judged, never fast-pathed.
        if (command[i] === "$" || command[i] === "`") return null;
        word += command[i];
        i++;
      }
      if (i >= command.length) return null;
      i++;
      continue;
    }
    if (ch === "\\") {
      if (command[i + 1] !== "\n") return null;
      i += 2;
      continue;
    }
    if (ch === "`" || ch === "$" || ch === "(" || ch === ")" || ch === "{" || ch === "}") return null;
    if (ch === "<") return null;
    if (ch === ";") {
      breakSegment(1);
      continue;
    }
    if (ch === "|") {
      breakSegment(command[i + 1] === "|" ? 2 : 1);
      continue;
    }
    if (ch === "&") {
      if (command[i + 1] !== "&") return null;
      breakSegment(2);
      continue;
    }
    if (ch === "\n") {
      breakSegment(1);
      continue;
    }
    if (ch === ">") {
      if (command[i + 1] === ">") return null;
      // The word buffer holds at most an fd digit (e.g. "2" in 2>/dev/null);
      // anything else means the redirect is attached to an opaque token.
      if (!/^\d*$/.test(word)) return null;
      word = "";
      if (command[i + 1] === "&") {
        if (!/^[12](?=$|[\s;|&])/.test(command.slice(i + 2))) return null;
        i += 3;
        continue;
      }
      i += 1;
      while (i < command.length && command[i] === " ") i++;
      const targetStart = i;
      // Stop at token separators; a quoted target keeps its quotes and fails
      // the exact match below.
      while (i < command.length && !/[\s;|&]/.test(command[i])) i++;
      if (command.slice(targetStart, i) !== "/dev/null") return null;
      continue;
    }
    if (ch === " " || ch === "\t") {
      endWord();
      i++;
      continue;
    }
    word += ch;
    i++;
  }
  endWord();
  return segments;
}

function isReadOnlySegment(tokens: string[]): boolean {
  if (tokens.length === 0) return true;
  const [program, ...args] = tokens;
  if (program === "git") {
    return args.length > 0 && READ_ONLY_GIT.has(args[0]) && !args.some((arg) => arg.startsWith("--output"));
  }
  if (program === "herdr-app") return args.length > 0 && READ_ONLY_HERDR_APP.has(args[0]);
  if (program === "hc") return args.length > 0 && READ_ONLY_HC.has(args[0]);
  // rg --pre runs an external command per file.
  if (program === "rg") return !args.some((arg) => arg.startsWith("--pre"));
  // tree -o writes its listing to a file.
  if (program === "tree") return !args.some((arg) => arg.startsWith("-o"));
  return READ_ONLY_PROGRAMS.has(program);
}

function isAgentrcPush(tokens: string[]): boolean {
  return tokens.length === 4 && tokens[0] === "git" && tokens[1] === "push" && tokens[2] === "origin" && tokens[3] === "main";
}

function isAgentrcScript(tokens: string[], agentrcRoot: string): boolean {
  if (tokens.length !== 1 || !tokens[0].includes("/")) return false;
  const path = resolve(agentrcRoot, expandHome(tokens[0]));
  return path.startsWith(`${agentrcRoot}/`) && AGENTRC_SCRIPTS.has(path.slice(agentrcRoot.length + 1));
}

// Not an extension: empty factory so pi's loader accepts this module.
export default function () {}
