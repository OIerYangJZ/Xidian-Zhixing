import { redirect } from 'next/navigation';

export const metadata = {
  title: '西电知行 | 注册',
};

export default function Page() {
  redirect('/login');
}
