import 'server-only';
import { cookies } from 'next/headers';

export function getInterfaceLanguage() {
  return cookies().get('zhixing-language')?.value === 'en' ? 'en' : 'zh';
}
