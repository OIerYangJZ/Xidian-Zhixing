'use client';

import {
  ChangeEventHandler,
  Dispatch,
  FormEvent,
  SetStateAction,
  useCallback,
  useEffect,
  useRef,
  useState,
} from 'react';
import { resizeTextAreaHeight } from '@/lib/resizeTextAreaHeight';
import { useQuery } from '@tanstack/react-query';
import { replaceWordAtCursor } from '@/lib/replaceWordAtCursor';
import { cn } from '@/lib/cn';
import { AriaTextFieldProps, mergeProps, useKeyboard, useTextField } from 'react-aria';
import { useOverlayTriggerState } from 'react-stately';
import { useClickOutside } from '@/hooks/useClickOutside';
import { searchUsers } from '@/lib/backend/endpoints';
import { rememberMention } from '@/lib/mentions';
import { useLanguage } from '@/hooks/useLanguage';
import { Popover } from './ui/Popover';
import { TextAreaMentionItem } from './TextAreaMentionItem';
import { HighlightedMentionsAndHashTags } from './HighlightedMentionsAndHashTags';

/**
 * What may follow "@" while the mention list is open: any letter or digit
 * (Chinese nicknames included) and the - · _ that nicknames use.
 */
const MENTION_QUERY = /^[\p{L}\p{N}_\-·]+$/u;

interface TextAreaWithMentionsAndHashTagsProps extends AriaTextFieldProps {
  content: string;
  setContent: Dispatch<SetStateAction<string>>;
  placeholder: string;
  shouldFocusOnMount?: boolean;
}
export function TextAreaWithMentionsAndHashTags({
  content,
  setContent,
  placeholder,
  shouldFocusOnMount = true,
  ...rest
}: TextAreaWithMentionsAndHashTagsProps) {
  const { t } = useLanguage();
  const [searchKeyword, setSearchKeyword] = useState('');
  const [focused, setFocused] = useState<string>('');

  const posOfActiveAt = useRef(0);
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);

  const { inputProps, labelProps, errorMessageProps } = useTextField(
    { ...rest, inputElementType: 'textarea', label: placeholder },
    textareaRef,
  );
  const { errorMessage } = rest;

  const popoverState = useOverlayTriggerState({});
  const { isOpen: mentionsShown, setOpen: setMentionsShown } = popoverState;

  // This query will refetch every time the `searchKeyword` state changess
  const { data, isPending, isError } = useQuery({
    queryKey: ['mentions', 'search', { keyword: searchKeyword }],
    queryFn: async () => (await searchUsers(searchKeyword)).filter((user) => !user.isOwnProfile),
    staleTime: 60000 * 10,
    enabled: !!searchKeyword,
  });

  // Focus the first item when `data` changes
  useEffect(() => {
    if (!data) return;
    setFocused(data[0]?.username || '');
  }, [data]);

  const closeMentions = useCallback(() => {
    setSearchKeyword('');
    setMentionsShown(false);
    setFocused('');
    posOfActiveAt.current = 0;
  }, [setMentionsShown]);

  // Since the <Popover>'s `isNonModal` is `true`, it will not be closed
  // when the user clicks outside, but we can handle it manually
  const [popoverRef] = useClickOutside(closeMentions);

  // Items are keyed by account id; the text gets the nickname, and the
  // pairing is remembered so the submit can send the account as a mention.
  const handleSelectUserToMention = (userId: string) => {
    const nickname = data?.find((user) => user.id === userId)?.name;
    if (!nickname) return;
    rememberMention(nickname, userId);
    setContent(
      replaceWordAtCursor(content, posOfActiveAt.current, `@${nickname} `),
      //                                                               ^ add one space character
    );

    // The cursor position must be right after the inserted string
    const newCursorPos = posOfActiveAt.current + nickname.length + 2;

    // Wait for the `setContent()` to finish before resizing the textarea
    setTimeout(() => {
      const textarea = textareaRef.current;
      if (textarea === null) return;
      textarea.focus();
      textarea.setSelectionRange(newCursorPos, newCursorPos);
      resizeTextAreaHeight(textarea);
    }, 100);

    closeMentions();
  };

  const handleToggleMentions = () => {
    const target = textareaRef.current;
    if (!target) return;

    const text = target.value;
    const cursorPos = target.selectionStart;

    const textBeforeCursor = text.slice(0, cursorPos);
    const wordsBeforeCursor = textBeforeCursor.split(/\s/);
    const currentWord = wordsBeforeCursor[wordsBeforeCursor.length - 1];

    /**
     * If the `currentWord` starts with '@' and the rest could be part of a
     * nickname (MENTION_QUERY), show the mention list, otherwise hide it
     */
    if (currentWord.startsWith('@')) {
      const keyword = currentWord.slice(1);
      if (MENTION_QUERY.test(keyword)) {
        setSearchKeyword(keyword);
        setMentionsShown(true);

        // Save the position of the active '@'
        posOfActiveAt.current = textBeforeCursor.length - currentWord.length;
      }
    } else if (mentionsShown) closeMentions();
  };

  // Since the `TextArea` is in `absolute` position, the container won't auto-resize
  // according to the height of the `TextArea`, we can set it manually instead
  useEffect(() => {
    if (containerRef.current) containerRef.current.style.height = `${textareaRef.current?.scrollHeight}px`;
  }, [content]);

  useEffect(() => {
    // Focus the `TextArea` on mount if requested
    if (!shouldFocusOnMount) return;

    textareaRef.current?.focus();
    // Set the cursor position to the end of the `TextArea`'s value
    const start = textareaRef.current?.value.length || 0;
    textareaRef.current?.setSelectionRange(start, start);
  }, [shouldFocusOnMount]);

  // Re-check the word at the cursor on every change, not only on keyup: text
  // committed by a Chinese IME (and pasted text) arrives without a keyup, so
  // the mention list would otherwise keep searching the half-typed name.
  const handleTextareaChange: ChangeEventHandler<HTMLTextAreaElement> = (event) => {
    const { target } = event;
    setContent(target.value);
    handleToggleMentions();
  };

  const { keyboardProps } = useKeyboard({
    onKeyDown: (e) => {
      // Propagate if mentions are not shown
      if (!mentionsShown || !data) return e.continuePropagation();

      // Allow navigating thru the mentions using the keyboard's arrow keys etc.
      const { length } = data;
      const firstIndex = 0;
      const focusedIndex = data.findIndex((user) => user.username === focused);
      const lastIndex = length - 1;

      // If the focused index is the first index, the `prevIndex` must be the `lastIndex`
      const prevIndex = focusedIndex === firstIndex ? lastIndex : focusedIndex - 1;
      // If the focused index is the last index, the `nextIndex` must be 0
      const nextIndex = focusedIndex === lastIndex ? 0 : focusedIndex + 1;

      if (['Escape', 'ArrowUp', 'ArrowDown', 'Home', 'End', 'Enter', 'Tab'].includes(e.key)) {
        e.preventDefault();
      }
      if (e.key === 'Escape') return closeMentions();
      if (e.key === 'ArrowUp') return setFocused(data[prevIndex].username!);
      if (e.key === 'ArrowDown') return setFocused(data[nextIndex].username!);
      if (e.key === 'Home') return setFocused(data[firstIndex].username!);
      if (e.key === 'End') return setFocused(data[lastIndex].username!);
      if (['Enter', 'Tab'].includes(e.key)) {
        handleSelectUserToMention(data[focusedIndex].username!);
      }
      return null;
    },
    onKeyUp: (e) => {
      if (e.key === 'Escape') return;
      handleToggleMentions();
    },
  });

  return (
    <>
      {mentionsShown && (
        <Popover
          triggerRef={textareaRef}
          popoverRef={popoverRef}
          state={popoverState}
          isNonModal
          placement="top"
          className="min-w-[200px]">
          <ul className="max-h-[242px] w-full overflow-auto border border-border bg-popover outline-none">
            {isPending ? (
              <li className="px-3 py-2 text-sm text-muted-foreground">{t('正在查找同学…', 'Finding people…')}</li>
            ) : isError ? (
              <li className="px-3 py-2 text-sm text-muted-foreground">
                {t('暂时无法加载同学。', 'Could not load people.')}
              </li>
            ) : data.length > 0 ? (
              data.map((user) => (
                <TextAreaMentionItem
                  key={user.id}
                  {...user}
                  {...{ handleSelectUserToMention }}
                  focused={user.username === focused}
                />
              ))
            ) : (
              <li className="px-3 py-2 text-sm text-muted-foreground">{t('没有找到同学。', 'No people found.')}</li>
            )}
          </ul>
        </Popover>
      )}
      <div className="relative bg-transparent" ref={containerRef}>
        <label {...labelProps} className="sr-only">
          {placeholder}
        </label>
        <textarea
          ref={textareaRef}
          {...mergeProps(inputProps, keyboardProps, {
            value: content,
            onChange: handleTextareaChange,
            onClick: handleToggleMentions,
            onInput: (e: FormEvent<HTMLTextAreaElement>) => {
              const textarea = e.target as HTMLTextAreaElement;
              resizeTextAreaHeight(textarea);
            },
            rows: 1,
            placeholder,
          })}
          className={cn(
            'absolute top-0 block w-full resize-none overflow-hidden break-words bg-transparent text-transparent caret-foreground outline-none',
            rest.errorMessage && 'rounded-sm ring-2 ring-red-900 ring-offset-4 placeholder:text-red-900',
          )}
        />
        <p className="whitespace-pre-wrap break-words bg-transparent">
          <HighlightedMentionsAndHashTags text={content} />
        </p>
      </div>
      {errorMessage !== undefined && (
        <p {...errorMessageProps} className="mt-4 font-semibold text-red-800">
          {errorMessage as string}
        </p>
      )}
    </>
  );
}
