import { getInterfaceLanguage } from '@/lib/getInterfaceLanguage';
import { MessagesInbox } from './MessagesInbox';

export async function generateMetadata() {
  return { title: (await getInterfaceLanguage()) === 'en' ? 'Messages | Xidian Zhixing' : '消息' };
}

export default function Page() {
  return <MessagesInbox />;
}
