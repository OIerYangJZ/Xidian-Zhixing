import { getInterfaceLanguage } from '@/lib/getInterfaceLanguage';
import { CampusSchedulePage } from '../CampusSchedulePage';

export function generateMetadata() {
  return { title: getInterfaceLanguage() === 'en' ? 'Campus calendar | Xidian Zhixing' : '校园日历 | 西电知行' };
}

export default function CalendarPage() {
  return <CampusSchedulePage mode="calendar" />;
}
