import { getInterfaceLanguage } from '@/lib/getInterfaceLanguage';
import { MessagesInbox } from './MessagesInbox';

export function generateMetadata() {
  return { title: getInterfaceLanguage() === 'en' ? 'Messages | Xidian Zhixing' : '消息' };
}

export default function Page() {
  return <MessagesInbox />;
}
