import { apiError, apiSuccess } from '@/lib/apiResponse';
import { getServerUser } from '@/lib/getServerUser';

const datePattern = /^\d{4}-\d{2}-\d{2}$/;
const sources = ['all', 'course', 'exam', 'experiment'] as const;

function addDays(dateText: string, days: number) {
  const date = new Date(`${dateText}T00:00:00+08:00`);
  date.setUTCDate(date.getUTCDate() + days);
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(date);
}

export async function GET(request: Request) {
  const [user] = await getServerUser();
  if (!user?.id) return apiError('请先登录。', 401);

  const { searchParams } = new URL(request.url);
  const startDate = searchParams.get('startDate') || '';
  const days = Number(searchParams.get('days') || 7);
  const source = searchParams.get('source') || 'all';
  if (!datePattern.test(startDate) || Number.isNaN(Date.parse(`${startDate}T00:00:00+08:00`))) {
    return apiError('startDate 必须使用 YYYY-MM-DD 格式。', 400);
  }
  if (!Number.isInteger(days) || days < 1 || days > 31) return apiError('days 必须是 1 到 31 之间的整数。', 400);
  if (!sources.includes(source as (typeof sources)[number])) return apiError('source 参数不受支持。', 400);

  const daysList = Array.from({ length: days }, (_, index) => ({
    date: addDays(startDate, index),
    items: [] as unknown[],
  }));
  return apiSuccess({
    startDate,
    endDate: daysList[daysList.length - 1].date,
    days: daysList,
    sourceStatus: 'not_connected',
  });
}
