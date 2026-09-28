import { searchUsers } from '../api/user';

// @-mentions, shared by the composer and the comment box.
//
// The backend only counts a mention whose "@<nickname>" is in the text and
// is not followed by another letter or digit (_social_handler.resolve_mentions),
// so the picker inserts "@nickname " and the ids sent are the ones whose name
// is still in the text when it is sent.

// Nicknames picked from the list during this visit, mapped to their account.
const picked = {};

// What may follow "@" while the name is being typed: letters, digits and the
// joiners nicknames use.  Mirrors the web client's MENTION_QUERY.
const QUERY_RE = /@([\p{L}\p{N}_\-·]{0,24})$/u;

export const rememberMention = (nickname, userId) => {
  if (nickname && userId) picked[nickname] = userId;
};

const escapeRegExp = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

// Whether "@nickname" appears in text as a whole name.
const namesIn = (text, nickname) => {
  const pattern = new RegExp(`@${escapeRegExp(nickname)}(?![\\p{L}\\p{N}_])`, 'u');
  return pattern.test(text);
};

// Accounts to send as mentionUserIds: remembered or already-stored mentions
// whose name is still in the text.
export const mentionIdsIn = (text, known = []) => {
  const ids = [];
  const add = (userId) => { if (userId && !ids.includes(userId)) ids.push(userId); };
  (known || []).forEach((item) => {
    if (item && item.nickname && namesIn(text, item.nickname)) add(item.userId);
  });
  Object.keys(picked).forEach((nickname) => {
    if (namesIn(text, nickname)) add(picked[nickname]);
  });
  return ids;
};

// The "@query" being typed just before the cursor, or null.
export const mentionQueryAt = (text, cursor) => {
  const before = String(text || '').slice(0, typeof cursor === 'number' ? cursor : String(text || '').length);
  const match = QUERY_RE.exec(before);
  if (!match) return null;
  return { start: before.length - match[0].length, end: before.length, query: match[1] };
};

// Replace the "@query" at `at` with "@nickname " and say where the cursor goes.
export const insertMention = (text, at, user) => {
  const value = String(text || '');
  const after = value.slice(at.end);
  const insert = `@${user.nickname} `;
  rememberMention(user.nickname, user.id);
  const next = `${value.slice(0, at.start)}${insert}${after.replace(/^ /, '')}`;
  return { text: next, cursor: at.start + insert.length };
};

// Candidates for a query: the backend's nickname search, oneself left out.
let searchSeq = 0;
export const searchMentionCandidates = async (query, selfId = '') => {
  const keyword = String(query || '').trim();
  if (!keyword) return [];
  searchSeq += 1;
  const seq = searchSeq;
  const users = await searchUsers(keyword);
  // A slower answer for an older query must not replace a newer one.
  if (seq !== searchSeq) return null;
  return users
    .filter((user) => user.id && user.id !== selfId && !user.isBlockedByMe)
    .slice(0, 8)
    .map((user) => ({ id: user.id, nickname: user.nickname, avatarUrl: user.avatarUrl, avatarInitial: user.avatarInitial }));
};
