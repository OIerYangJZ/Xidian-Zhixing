// How a finished answer settles into place. The answer arrives as text, then becomes Markdown, then
// grows cards under it; those are three visual changes in a row, so they are sequenced instead of
// landing on the same frame.

/** While tokens are still arriving, the text is a little smaller than the final answer (see CSS). */
export const SETTLE_MS = 200;
/**
 * A beat between the text becoming the Markdown answer and the cards appearing under it. Without
 * it the two changes read as one jolt instead of a sequence.
 */
export const CARD_DELAY_MS = 120;

export type MessagePhase = 'streaming' | 'landed' | 'final';

/**
 * Phase of one message, from the two facts the renderer has: whether the stream is still running,
 * and whether this message is inside its settling window.
 *
 * A message that never streamed in this session (a transcript loaded from the server) reports
 * `final` immediately, so opening an old conversation plays no animation.
 */
export function messagePhase(streaming: boolean, settling: boolean): MessagePhase {
  if (streaming) return 'streaming';
  return settling ? 'landed' : 'final';
}

/** Whether a message's cards are allowed to be on screen yet. */
export function phaseShowsCards(phase: MessagePhase): boolean {
  return phase === 'final';
}
