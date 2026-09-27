import parse, { Element, domToReact } from 'html-react-parser';
import DOMPurify from 'dompurify';
import Link from 'next/link';
import { tagHref } from '@/lib/profileHref';

export function HighlightedMentionsAndHashTags({ text, shouldAddLinks }: { text: string; shouldAddLinks?: boolean }) {
  /**
   * Define a regex pattern to match words that begin with `@` or `#`
   *
   * * The first group matches a line start, whitespace, or punctuation before the marker
   * * The second group matches either the `@` or `#`
   * * The third group matches Unicode letters, numbers, and underscores after the `@` or `#`
   */
  const pattern = /(^|[\s\p{P}\p{S}])(@|#)([\p{L}\p{N}_]+)/gu;
  const cleanText = DOMPurify.sanitize(text.replace(/</g, '&lt;').replace(/>/, '&gt;'));

  // Use replace() method to surround the matches' word with the <span> tag
  const html = cleanText.replace(pattern, (match, space: string, char: string, word: string) => {
    const coloredWord = `<span class="text-primary">${char}${word}</span>`;

    // Only hashtags link: users have no @handle to resolve on this backend.
    if (!shouldAddLinks || char !== '#') return `${space}${coloredWord}`;
    return `${space}<a href="${tagHref(word)}">${coloredWord}</a>`;
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
