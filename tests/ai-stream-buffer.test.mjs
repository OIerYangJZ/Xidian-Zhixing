// Streamed answers arrive a token at a time. The writer is what keeps that from turning into one
// transcript re-render per token, so its batching rules are worth pinning down.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import test from 'node:test';
import ts from 'typescript';

const require = createRequire(import.meta.url);

function load(path) {
  const source = readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
  const compiled = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText;
  const module = { exports: {} };
  new Function('require', 'module', 'exports', compiled)(require, module, module.exports);
  return module.exports;
}

const { createCoalescedWriter } = load('src/lib/ai/streamBuffer.ts');
const phases = load('src/lib/ai/messagePhase.ts');

/** A scheduler the test drives by hand, so "one write per frame" is observable. */
function manualScheduler() {
  let nextHandle = 1;
  const pending = new Map();
  return {
    scheduler: {
      request: (callback) => {
        const handle = nextHandle++;
        pending.set(handle, callback);
        return handle;
      },
      cancel: (handle) => pending.delete(handle),
    },
    frame() {
      const callbacks = [...pending.values()];
      pending.clear();
      callbacks.forEach((callback) => callback());
      return callbacks.length;
    },
    get pendingCount() {
      return pending.size;
    },
  };
}

test('many deltas in one frame produce a single write', () => {
  const writes = [];
  const clock = manualScheduler();
  const writer = createCoalescedWriter((text) => writes.push(text), clock.scheduler);
  for (const token of ['西', '电', '奖', '学', '金']) writer.append(token);
  assert.deepEqual(writes, []);
  assert.equal(clock.frame(), 1);
  assert.deepEqual(writes, ['西电奖学金']);
});

test('a slow stream writes once per frame rather than once per token', () => {
  const writes = [];
  const clock = manualScheduler();
  const writer = createCoalescedWriter((text) => writes.push(text), clock.scheduler);
  writer.append('a');
  clock.frame();
  writer.append('b');
  clock.frame();
  writer.append('c');
  clock.frame();
  // Three frames, three cumulative snapshots: each render shows the whole answer so far.
  assert.deepEqual(writes, ['a', 'ab', 'abc']);
});

test('reset drops the previous answer instead of appending to it', () => {
  const writes = [];
  const clock = manualScheduler();
  const writer = createCoalescedWriter((text) => writes.push(text), clock.scheduler);
  writer.append('draft text');
  clock.frame();
  writer.append('final', { reset: true });
  clock.frame();
  assert.deepEqual(writes, ['draft text', 'final']);
});

test('flush commits immediately and leaves nothing scheduled', () => {
  const writes = [];
  const clock = manualScheduler();
  const writer = createCoalescedWriter((text) => writes.push(text), clock.scheduler);
  writer.append('answer');
  writer.flush();
  assert.deepEqual(writes, ['answer']);
  assert.equal(clock.pendingCount, 0);
  // A second flush with nothing pending must not repeat the write.
  writer.flush();
  assert.deepEqual(writes, ['answer']);
});

test('cancel drops a frame that belongs to a turn about to be discarded', () => {
  const writes = [];
  const clock = manualScheduler();
  const writer = createCoalescedWriter((text) => writes.push(text), clock.scheduler);
  writer.append('text that will never be committed');
  writer.cancel();
  assert.equal(clock.frame(), 0);
  assert.deepEqual(writes, []);
  // The writer stays usable afterwards, starting from an empty buffer.
  writer.append('next turn');
  clock.frame();
  assert.deepEqual(writes, ['next turn']);
});

test('a message settles through streaming, landed and final', () => {
  // While tokens arrive the answer is streaming, and its cards stay hidden.
  const streaming = phases.messagePhase(true, false);
  assert.equal(streaming, 'streaming');
  assert.equal(phases.phaseShowsCards(streaming), false);

  // The stream ended: the text is settling into the Markdown answer, still without cards.
  const landed = phases.messagePhase(false, true);
  assert.equal(landed, 'landed');
  assert.equal(phases.phaseShowsCards(landed), false);

  // The settling window is over: the answer is final and its cards may appear.
  const settled = phases.messagePhase(false, false);
  assert.equal(settled, 'final');
  assert.equal(phases.phaseShowsCards(settled), true);
});

test('a streaming message ignores a stale settling flag', () => {
  // A second answer in the same conversation must not inherit the previous message's window.
  assert.equal(phases.messagePhase(true, true), 'streaming');
});

test('a transcript loaded from the server is final immediately', () => {
  // Nothing sets the settling flag for old messages, so opening a conversation plays no animation.
  assert.equal(phases.messagePhase(false, false), 'final');
});

test('the settle window stays short enough to read as one motion', () => {
  assert.ok(phases.SETTLE_MS > 0);
  assert.ok(phases.CARD_DELAY_MS > 0);
  // Text then cards; a window longer than about half a second reads as lag, not as a sequence.
  assert.ok(phases.SETTLE_MS + phases.CARD_DELAY_MS <= 500);
});
