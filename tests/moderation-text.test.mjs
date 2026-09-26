import assert from 'node:assert/strict';
import test from 'node:test';
import { assessPostText } from '../src/lib/moderation/text.ts';

test('ordinary campus posts pass automatic text review', () => {
  assert.deepEqual(assessPostText('今天图书馆的夕阳很漂亮。'), { decision: 'approve', reasons: [] });
});

test('prohibited terms are matched across punctuation and zero-width characters', () => {
  assert.equal(assessPostText('校​园-霸凌').decision, 'reject');
  assert.equal(assessPostText('a plan for violent assault').decision, 'reject');
});

test('default and server-configured sensitive words are rejected', () => {
  assert.equal(assessPostText('这里有广告内容').decision, 'reject');
  process.env.BACKEND_SENSITIVE_WORDS = '站内禁词';
  assert.equal(assessPostText('这里有站内禁词').decision, 'reject');
  delete process.env.BACKEND_SENSITIVE_WORDS;
});

test('marketing and spam signals enter manual review', () => {
  assert.equal(assessPostText('扫码联系我，兼职日赚').decision, 'review');
  assert.equal(assessPostText('哈'.repeat(10)).decision, 'review');
});
