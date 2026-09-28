import parse, { Element, domToReact } from 'html-react-parser';
import DOMPurify from 'dompurify';
import Link from 'next/link';
import type { Mention } from '@/types/definitions';
import { profileHref, tagHref } from '@/lib/profileHref';

const escapeRegExp = (value: string) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const escapeHtml = (value: string) =>
  value.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

/**
 * Colours #hashtags and @mentions; with `shouldAddLinks`, hashtags open the
 * tag page and mentions the backend resolved (`mentions`) open that
 * person's profile.  Mentions are matched on the whole stored nickname, so
 * names containing - or · stay one link.
 */
export function HighlightedMentionsAndHashTags({
  text,
  shouldAddLinks,
  mentions = [],
}: {
  text: string;
  shouldAddLinks?: boolean;
  mentions?: Mention[];
}) {
  // Matched against the HTML-escaped text, so the nicknames are escaped too
  // ("a&b" is "a&amp;b" there).
  const byNickname = new Map(mentions.map((mention) => [escapeHtml(mention.nickname), mention.userId]));
  // Longest first, so "@小波波" is not taken as "@小波".
  const nicknames = [...byNickname.keys()].sort((a, b) => b.length - a.length).map(escapeRegExp);
  // The same rules as the backend: a resolved mention and a #tag count
  // anywhere, "你好@小波" and "中文#话题" included, as long as the name ends
  // there; any other @word needs a space or punctuation before it, so an
  // e-mail address is not coloured.
  const known = nicknames.length ? `@(${nicknames.join('|')})(?![\\p{L}\\p{N}_])|` : '';
  const pattern = new RegExp(`${known}(^|[\\s\\p{P}\\p{S}])@([\\p{L}\\p{N}_]+)|#([\\p{L}\\p{N}_-]+)`, 'gu');

  const cleanText = DOMPurify.sanitize(escapeHtml(text));
  const html = cleanText.replace(pattern, (...groups: Array<string | undefined>) => {
    // With no known nicknames the first capture group does not exist.
    const [knownMention, lead = '', otherMention, hashtag] = nicknames.length
      ? groups.slice(1, 5)
      : [undefined, ...groups.slice(1, 4)];
    const mention = knownMention ?? otherMention;
    const word = mention ?? hashtag ?? '';
    const coloured = `<span class="text-primary">${mention !== undefined ? '@' : '#'}${word}</span>`;
    if (!shouldAddLinks) return `${lead}${coloured}`;
    const href = mention !== undefined ? profileHref(byNickname.get(word)) : tagHref(word);
    return href ? `${lead}<a href="${escapeHtml(href)}">${coloured}</a>` : `${lead}${coloured}`;
  });

  if (!shouldAddLinks) return parse(html) as JSX.Element;
  return parse(html, {
    replace: (domNode) => {
      // Convert the <a> tags into NextJS <Link>'s
      if (domNode instanceof Element && domNode.attribs && domNode.attribs.href && domNode.children)
        return (
          <Link href={domNode.attribs.href} className="link">
            {domToReact(domNode.children)}
          </Link>
        );
      return domNode;
    },
  }) as JSX.Element;
}
