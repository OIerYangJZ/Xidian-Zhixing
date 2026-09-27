import { getInterfaceLanguage } from '@/lib/getInterfaceLanguage';
import { SettingsPanel } from './SettingsPanel';

export async function generateMetadata() {
  return { title: (await getInterfaceLanguage()) === 'en' ? 'Settings | Xidian Zhixing' : '设置 | 西电知行' };
}

export default function SettingsPage() {
  return <SettingsPanel />;
}
