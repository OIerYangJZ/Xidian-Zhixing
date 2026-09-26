import { apiSuccess } from '@/lib/apiResponse';

export const dynamic = 'force-dynamic';

export async function GET() {
  return apiSuccess({
    version: process.env.APP_VERSION || process.env.npm_package_version || '0.1.0',
    commit: process.env.APP_COMMIT || 'unknown',
    builtAt: process.env.APP_BUILT_AT || null,
  });
}
