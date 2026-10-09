type HistoryRow = { role: string; content: string; sources: unknown };
type HistorySource = { citation: number; title: string; documentId: string; source: string | null };

export function buildHarnessHistory(rows: HistoryRow[]) {
  const history: { role: 'user' | 'assistant'; content: string; sources: HistorySource[] }[] = [];
  let remaining = 24_000;
  for (const row of rows) {
    const content = row.content.slice(0, 12_000);
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
    const size = content.length + JSON.stringify(sources).length + 60;
    if (size > remaining) break;
    remaining -= size;
    history.push({ role: row.role === 'USER' ? 'user' : 'assistant', content, sources });
  }
  history.reverse();
  // Only completed turns enter model history; failed or concurrent user messages have no reply yet.
  return history.filter((message, index) =>
    message.role === 'user' ? history[index + 1]?.role === 'assistant' : history[index - 1]?.role === 'user',
  );
}
