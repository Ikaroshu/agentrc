// Deterministic fast path for the guard's bash screen. A command skips the
// judge only when every segment is a known read-only program with no redirects
// other than to /dev/null; anything the scanner does not understand is rejected
// so the judge can decide.
//
// Pi loads every file in the extensions directory as an extension entry point,
// so this module also exports a no-op factory. The parser itself is
// dependency-free and is tested directly by scripts/test-guard-fastpath.mjs.

const ASSIGNMENT = /^[A-Za-z_][A-Za-z0-9_]*=/;
const READ_ONLY_PROGRAMS = new Set([
  "cat", "cd", "date", "df", "du", "echo", "file", "grep", "head", "ls", "pwd",
  "rg", "stat", "tail", "tree", "true", "wc", "which",
]);
const READ_ONLY_GIT = new Set(["blame", "diff", "log", "rev-parse", "show", "status"]);
const READ_ONLY_HERDR_APP = new Set(["--help", "--skill", "commands", "ls", "status"]);
const READ_ONLY_HC = new Set(["--help", "--skill", "get", "ls"]);

export function isFastPath(command: string): boolean {
  if (command.trim() === "") return false;
  const segments = splitSegments(command);
  return segments !== null && segments.every(isReadOnlySegment);
}

// All words of the command with quotes stripped and separators dropped, or
// null when the scanner rejects the command.
export function commandWords(command: string): string[] | null {
  const segments = splitSegments(command);
  return segments === null ? null : segments.flat();
}

// Splits on top-level &&, ||, ;, |, and newlines, honoring single and double
// quotes. Returns null on any construct the fast path does not understand:
// expansions, command substitution, subshells, brace groups, background jobs,
// or redirects whose target is not /dev/null.
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
  let index = 0;
  while (index < tokens.length && ASSIGNMENT.test(tokens[index])) index++;
  if (index >= tokens.length) return true;
  const program = tokens[index].split("/").pop() ?? "";
  const args = tokens.slice(index + 1);
  if (program === "git") return args.length > 0 && READ_ONLY_GIT.has(args[0]);
  if (program === "herdr-app") return args.length > 0 && READ_ONLY_HERDR_APP.has(args[0]);
  if (program === "hc") return args.length > 0 && READ_ONLY_HC.has(args[0]);
  // sed edits in place with -i or --in-place.
  if (program === "sed") return args.every((arg) => !arg.startsWith("-i") && arg !== "--in-place");
  // rg --pre runs an external command per file.
  if (program === "rg") return !args.some((arg) => arg.startsWith("--pre"));
  return READ_ONLY_PROGRAMS.has(program);
}

// Not an extension: empty factory so pi's loader accepts this module.
export default function () {}
