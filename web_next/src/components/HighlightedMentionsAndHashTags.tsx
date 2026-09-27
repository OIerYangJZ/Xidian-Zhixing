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
  const byNickname = new Map(mentions.map((mention) => [mention.nickname, mention.userId]));
  // Longest first, so "@小波波" is not taken as "@小波".
  const nicknames = [...byNickname.keys()].sort((a, b) => b.length - a.length).map(escapeRegExp);
  const mentionAlternatives = nicknames.length ? `${nicknames.join('|')}|` : '';
  const pattern = new RegExp(
    `(^|[\\s\\p{P}\\p{S}])(?:@(${mentionAlternatives}[\\p{L}\\p{N}_]+)|#([\\p{L}\\p{N}_]+))`,
    'gu',
  );

  const cleanText = DOMPurify.sanitize(escapeHtml(text));
  const html = cleanText.replace(pattern, (_match, lead: string, mention?: string, hashtag?: string) => {
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
