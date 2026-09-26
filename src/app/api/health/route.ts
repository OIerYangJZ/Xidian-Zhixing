import prisma from '@/lib/prisma/prisma';
import { apiError, apiSuccess } from '@/lib/apiResponse';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    await prisma.$queryRaw`SELECT 1`;
    return apiSuccess({ status: 'healthy' });
  } catch {
    return apiError('database_unavailable', 503, { status: 'unhealthy' });
  }
}
