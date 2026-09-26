import { getInterfaceLanguage } from '@/lib/getInterfaceLanguage';
import { CampusSchedulePage } from '../CampusSchedulePage';

export function generateMetadata() {
  return { title: getInterfaceLanguage() === 'en' ? 'Today | Xidian Zhixing' : '今日校园 | 西电知行' };
}

export default function TodayPage() {
  return <CampusSchedulePage mode="today" />;
}
