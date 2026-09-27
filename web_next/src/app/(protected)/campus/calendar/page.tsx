import { getInterfaceLanguage } from '@/lib/getInterfaceLanguage';
import { CampusSchedulePage } from '../CampusSchedulePage';

export async function generateMetadata() {
  return {
    title: (await getInterfaceLanguage()) === 'en' ? 'Campus calendar | Xidian Zhixing' : '校园日历 | 西电知行',
  };
}

export default function CalendarPage() {
  return <CampusSchedulePage mode="calendar" />;
}
