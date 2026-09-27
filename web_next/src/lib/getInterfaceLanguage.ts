import 'server-only';
import { cookies } from 'next/headers';

export async function getInterfaceLanguage() {
  return (await cookies()).get('zhixing-language')?.value === 'en' ? 'en' : 'zh';
}
