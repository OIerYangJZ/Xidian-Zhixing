import { Suspense } from 'react';
import { MessagesInbox } from './MessagesInbox';

export const metadata = { title: '消息 | 西电知行' };

export default function Page() {
  return (
    <Suspense>
      <MessagesInbox />
    </Suspense>
  );
}
