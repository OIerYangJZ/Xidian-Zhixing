// Streamed answer text arrives one token at a time. Committing every delta re-renders the whole
// transcript once per token, so the text is buffered here and written at most once per frame.

export type StreamScheduler = {
  request: (callback: () => void) => number;
  cancel: (handle: number) => void;
};

export type CoalescedWriter = {
  /** Add a delta, or replace the buffer when the stream restarts its answer. */
  append: (text: string, options?: { reset?: boolean }) => void;
  /** Write whatever is buffered right now; safe to call when nothing is pending. */
  flush: () => void;
  /** Drop the buffer without writing, for a turn that is about to be discarded. */
  cancel: () => void;
};

function frameScheduler(): StreamScheduler {
  if (typeof window !== 'undefined' && typeof window.requestAnimationFrame === 'function') {
    return {
      request: (callback) => window.requestAnimationFrame(callback),
      cancel: (handle) => window.cancelAnimationFrame(handle),
    };
  }
  // A macrotask clock keeps the same "at most one write per tick" bound where no frame clock exists.
  return {
    request: (callback) => setTimeout(callback, 16) as unknown as number,
    cancel: (handle) => clearTimeout(handle),
  };
}

export function createCoalescedWriter(
  write: (text: string) => void,
  scheduler: StreamScheduler = frameScheduler(),
): CoalescedWriter {
  let buffered = '';
  let handle: number | null = null;
  const commit = () => {
    handle = null;
    write(buffered);
  };
  const dropPending = () => {
    if (handle === null) return;
    scheduler.cancel(handle);
    handle = null;
  };
  return {
    append(text, options) {
      buffered = options?.reset ? text : buffered + text;
      if (handle !== null) return;
      handle = scheduler.request(commit);
    },
    flush() {
      if (handle === null) return;
      dropPending();
      commit();
    },
    cancel() {
      dropPending();
      buffered = '';
    },
  };
}
