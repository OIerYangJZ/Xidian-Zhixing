import { baseUrl } from '../config/env';

// Post content is user-supplied.  A markdown link may carry any scheme, so only
// let plain http(s) and in-app paths through; anything else renders as inert
// text rather than a live href.
const safeLinkUrl = (value) => {
  const text = String(value || '').trim();
  if (!text) return '';
  // Strip characters that browsers/rich-text ignore when resolving a scheme
  // ("java\nscript:alert(1)" is still javascript:).
  const collapsed = text.replace(/[\s\u0000-\u001f\u007f]/g, '').toLowerCase();
  if (/^https?:\/\//.test(collapsed)) return text;
  // Protocol-relative ("//evil.com") inherits the page scheme and points off-site.
  if (collapsed.startsWith('//')) return '';
  if (collapsed.startsWith('/')) return text;
  if (collapsed.indexOf(':') >= 0) return '';
  // Scheme-less relative link: harmless.
  return text;
};

const inlineNodes = (text) => {
  const source = String(text || '');
  const nodes = [];
  let rest = source;

  while (rest) {
    // 1. Inline code: `code`
    const codeMatch = /`([^`]+)`/.exec(rest);
    // 2. Bold: **bold**
    const boldMatch = /\*\*([^*]+)\*\*/.exec(rest);
    // 3. Italic: *italic* or _italic_
    const italicMatch = /(\*([^*]+)\*)|(_([^_]+)_)/.exec(rest);
    // 4. Image: ![alt](/api/storage/...) — the backend only accepts its own
    // uploads in Markdown, so nothing else is loaded.
    const imageMatch = /!\[([^\]]*)\]\(([^)\s]*)\)/.exec(rest);
    // 5. Link: [text](url)
    const linkMatch = /\[([^\]]*)\]\(([^)]*)\)/.exec(rest);
    // 5. Inline tag: #tag
    const tagMatch = /#[\w\u4e00-\u9fff-]{1,30}/.exec(rest);

    let earliest = null;
    let matchType = ''; // 'code', 'bold', 'italic', 'link'

    if (codeMatch && (earliest === null || codeMatch.index < earliest.index)) {
      earliest = codeMatch;
      matchType = 'code';
    }
    if (boldMatch && (earliest === null || boldMatch.index < earliest.index)) {
      earliest = boldMatch;
      matchType = 'bold';
    }
    if (italicMatch && (earliest === null || italicMatch.index < earliest.index)) {
      earliest = italicMatch;
      matchType = 'italic';
    }
    if (imageMatch && (earliest === null || imageMatch.index < earliest.index)) {
      earliest = imageMatch;
      matchType = 'image';
    }
    if (linkMatch && (earliest === null || linkMatch.index < earliest.index)) {
      earliest = linkMatch;
      matchType = 'link';
    }
    if (tagMatch && (earliest === null || tagMatch.index < earliest.index)) {
      earliest = tagMatch;
      matchType = 'tag';
    }

    if (!earliest) {
      nodes.push({ type: 'text', text: rest });
      break;
    }

    // Add text before the match
    if (earliest.index > 0) {
      nodes.push({ type: 'text', text: rest.slice(0, earliest.index) });
    }

    // Process the match
    if (matchType === 'code') {
      const codeText = earliest[1];
      nodes.push({
        name: 'span',
        attrs: { class: 'md-inline-code' },
        children: [{ type: 'text', text: codeText }]
      });
    } else if (matchType === 'bold') {
      const boldText = earliest[1];
      nodes.push({
        name: 'strong',
        children: inlineNodes(boldText)
      });
    } else if (matchType === 'italic') {
      const italicText = earliest[2] || earliest[4] || '';
      nodes.push({
        name: 'em',
        children: inlineNodes(italicText)
      });
    } else if (matchType === 'image') {
      const src = String(earliest[2] || '').trim();
      if (src.startsWith('/api/storage/')) {
        nodes.push({
          name: 'img',
          attrs: { style: 'display:block;max-width:100%;height:auto;margin:8px 0;border-radius:8px;', src: `${baseUrl.replace(/\/$/, '')}${src}`, alt: earliest[1] || '图片' },
        });
      } else {
        nodes.push({ type: 'text', text: earliest[1] || '图片' });
      }
    } else if (matchType === 'link') {
      const linkText = earliest[1];
      const linkUrl = safeLinkUrl(earliest[2]);
      if (linkUrl) {
        nodes.push({
          name: 'a',
          attrs: { class: 'md-link', href: linkUrl },
          children: inlineNodes(linkText)
        });
      } else {
        // Rejected scheme: show the label, but never as a live link.
        nodes.push({
          name: 'span',
          attrs: { class: 'md-link-blocked' },
          children: inlineNodes(linkText)
        });
      }
    } else if (matchType === 'tag') {
      nodes.push({
        name: 'span',
        attrs: { class: 'inline-tag' },
        children: [{ type: 'text', text: earliest[0] }]
      });
    }

    rest = rest.slice(earliest.index + earliest[0].length);
  }
  return nodes;
};

export const markdownToNodes = (markdown = '') => {
  const lines = String(markdown || '').split(/\r?\n/);
  const nodes = [];

  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    const trimmed = line.trim();

    // 1. Code Block
    if (trimmed.startsWith('```')) {
      let codeLines = [];
      i++;
      while (i < lines.length && !lines[i].trim().startsWith('```')) {
        codeLines.push(lines[i]);
        i++;
      }
      // If we found the ending ```, we skip past it
      if (i < lines.length) {
        // consumed
      }
      
      nodes.push({
        name: 'pre',
        attrs: { class: 'md-code' },
        children: [{
          name: 'code',
          attrs: { class: 'md-code-inner' },
          children: [{ type: 'text', text: codeLines.join('\n') }]
        }]
      });

      i++;
      continue;
    }

    // 2. Table Block
    if (trimmed.startsWith('|') && i + 1 < lines.length) {
      const nextLineTrimmed = lines[i + 1].trim();
      const isSeparator = /^\|?(\s*:?-+:?\s*\|?)+$/.test(nextLineTrimmed) && nextLineTrimmed.includes('-');
      
      if (isSeparator) {
        const headerRow = trimmed;
        const sepRow = nextLineTrimmed;

        const splitRow = (row) => {
          let cols = row.split('|').map(s => s.trim());
          if (row.startsWith('|')) cols.shift();
          if (row.endsWith('|') && cols.length > 0 && cols[cols.length - 1] === '') cols.pop();
          return cols;
        };

        const headers = splitRow(headerRow);
        const seps = splitRow(sepRow);

        const alignments = seps.map(s => {
          const start = s.startsWith(':');
          const end = s.endsWith(':');
          if (start && end) return 'center';
          if (end) return 'right';
          if (start) return 'left';
          return '';
        });

        i += 2; // Consume header and separator lines

        const tableChildren = [];

        // thead
        const ths = headers.map((h, index) => {
          const align = alignments[index] || 'left';
          const style = `text-align: ${align};`;
          return {
            name: 'th',
            attrs: { class: 'md-th', style },
            children: inlineNodes(h)
          };
        });
        tableChildren.push({
          name: 'thead',
          children: [{
            name: 'tr',
            children: ths
          }]
        });

        // tbody
        const tbodyRows = [];
        while (i < lines.length && lines[i].trim().startsWith('|')) {
          const bodyRow = lines[i].trim();
          const cols = splitRow(bodyRow);
          const tds = cols.map((col, index) => {
            const align = alignments[index] || 'left';
            const style = `text-align: ${align};`;
            return {
              name: 'td',
              attrs: { class: 'md-td', style },
              children: inlineNodes(col)
            };
          });
          tbodyRows.push({
            name: 'tr',
            children: tds
          });
          i++;
        }

        tableChildren.push({
          name: 'tbody',
          children: tbodyRows
        });

        nodes.push({
          name: 'table',
          attrs: { class: 'md-table' },
          children: tableChildren
        });

        continue;
      }
    }

    // 3. General Blocks
    const text = line.trimEnd();
    if (!text.trim()) {
      nodes.push({ name: 'br' });
      i++;
      continue;
    }

    const heading = /^(#{1,3})\s+(.+)$/.exec(text);
    if (heading) {
      nodes.push({
        name: heading[1].length === 1 ? 'h2' : 'h3',
        attrs: { class: 'md-heading' },
        children: inlineNodes(heading[2])
      });
      i++;
      continue;
    }

    const quote = /^>\s*(.+)$/.exec(text);
    if (quote) {
      nodes.push({
        name: 'blockquote',
        attrs: { class: 'md-quote' },
        children: inlineNodes(quote[1])
      });
      i++;
      continue;
    }

    const list = /^[-*]\s+(.+)$/.exec(text);
    if (list) {
      nodes.push({
        name: 'p',
        attrs: { class: 'md-list' },
        children: [{ type: 'text', text: '• ' }, ...inlineNodes(list[1])]
      });
      i++;
      continue;
    }

    nodes.push({ name: 'p', attrs: { class: 'md-p' }, children: inlineNodes(text) });
    i++;
  }

  return nodes;
};
