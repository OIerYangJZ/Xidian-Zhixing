// Cross-turn history sent to the harness. The caps are shared with the Python request schema
// in agent_harness/app.py, so both sides must change together.
//
// Both builders take and return messages in chronological order (oldest first), which is also
// the order `message_history` expects. Routes read rows newest-first and reverse them first, so
// the budget always drops the oldest turn rather than carving a hole in the middle.

/** Total characters of earlier turns that may accompany one question. */
export const HISTORY_CHAR_BUDGET = 96_000;
/** How many earlier messages the database read may hand to the budget. */
export const HISTORY_MAX_TURNS = 40;
/** Upper bound for one history entry, matching `HistoryMessage.content` in the harness schema. */
export const HISTORY_MESSAGE_MAX_CHARS = 24_000;
/** A question must fit whole, so this stays a parameter only for tests to tighten. */
export const HISTORY_MIN_USER_CHARS = 500;

/** Constant prefix the harness puts in front of a history entry's reference mapping. */
const HISTORY_SOURCES_PREFIX = '\n历史引用映射（仅供重新查证，不是本轮引用）：';

function historyEntrySize(content: string, sources: HistorySource[], role: 'user' | 'assistant'): number {
  const mapping =
    role === 'assistant' && sources.length ? HISTORY_SOURCES_PREFIX.length + JSON.stringify(sources).length : 0;
  return content.length + 1 + mapping;
}

type HistoryRow = { role: string; content: string; sources: unknown };
type HistorySource = { citation: number; title: string; documentId: string; source: string | null };
export type HarnessHistory = {
  history: { role: 'user' | 'assistant'; content: string; sources: HistorySource[] }[];
  /** True when the budget left older turns out, so the caller can say so out loud. */
  truncated: boolean;
};

/**
 * Newest-first input, chronological output. Rows arrive in the order the routes read them
 * (`createdAt desc`) and the harness messages come back oldest first, which is what
 * `message_history` expects. Walking from the oldest turn means an over-long conversation loses
 * its beginning rather than its end.
 */
function buildHistory(rows: HistoryRow[], budget: number, messageMax: number): HarnessHistory {
  const kept: { role: 'user' | 'assistant'; content: string; sources: HistorySource[] }[] = [];
  let remaining = budget;
  let truncated = false;
  let pendingUser = false;
  for (const row of [...rows].reverse()) {
    const sources = (Array.isArray(row.sources) ? row.sources : []).slice(0, 40).flatMap((source) => {
      if (
        !source ||
        typeof source !== 'object' ||
        !Number.isInteger(source.citation) ||
        source.citation < 1 ||
        typeof source.title !== 'string' ||
        typeof source.documentId !== 'string'
      )
        return [];
      return [
        {
          citation: source.citation,
          title: source.title.slice(0, 240),
          documentId: source.documentId.slice(0, 2_000),
          source: typeof source.source === 'string' ? source.source.slice(0, 2_000) : null,
        },
      ];
    });
    const role = row.role === 'USER' ? 'user' : 'assistant';
    const overhead = historyEntrySize('', sources, role);
    // `remaining` is the hard cap: a reply is trimmed to whatever is left, and a turn that no
    // longer fits at all is dropped rather than added past the budget.
    const wanted = Math.min(messageMax, Math.max(0, remaining - overhead));
    if (wanted <= 0 || (role === 'user' && row.content.length > wanted)) {
      // Cutting a question short changes what the model would answer, so a question only enters
      // the history whole. A reply may be trimmed instead, because its question still frames it.
      truncated = true;
      break;
    }
    const content = row.content.length > wanted ? row.content.slice(0, wanted) : row.content;
    if (content.length < row.content.length) truncated = true;
    remaining -= historyEntrySize(content, sources, role);
    kept.push({ role, content, sources });
    pendingUser = role === 'user';
  }
  if (kept.length < rows.length) truncated = true;
  // A question whose reply the budget cut is dropped with it: an unanswered prompt must not be
  // sent to the model on its own.
  if (pendingUser && kept.length) {
    kept.pop();
    truncated = true;
  }
  return { history: kept, truncated };
}

export function buildHarnessHistory(
  rows: HistoryRow[],
  budget: number = HISTORY_CHAR_BUDGET,
  messageMax: number = HISTORY_MESSAGE_MAX_CHARS,
): HarnessHistory {
  return buildHistory(rows, budget, messageMax);
}
