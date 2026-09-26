import { apiError, apiSuccess } from '@/lib/apiResponse';
import { getServerUser } from '@/lib/getServerUser';

function shanghaiDate() {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(new Date());
  const part = (type: string) => parts.find((item) => item.type === type)?.value || '';
  return `${part('year')}-${part('month')}-${part('day')}`;
}

export async function GET() {
  const [user] = await getServerUser();
  if (!user?.id) return apiError('请先登录。', 401);
  return apiSuccess({ date: shanghaiDate(), items: [], sourceStatus: 'not_connected' });
}
