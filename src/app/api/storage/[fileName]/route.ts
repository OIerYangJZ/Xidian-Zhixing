import { readFile } from 'fs/promises';
import { storagePath } from '@/lib/media/storagePath';
import prisma from '@/lib/prisma/prisma';
import { getServerUser } from '@/lib/getServerUser';
import { getKnowledgeAdmin } from '@/lib/ai/admin';

const contentTypes: Record<string, string> = {
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  png: 'image/png',
  webp: 'image/webp',
  gif: 'image/gif',
  mp4: 'video/mp4',
  mov: 'video/quicktime',
  avi: 'video/x-msvideo',
};

export async function GET(request: Request, props: { params: Promise<{ fileName: string }> }) {
  const { fileName } = await props.params;
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(fileName)) return new Response(null, { status: 400 });
  const media = await prisma.visualMedia.findFirst({
    where: { fileName },
    select: { userId: true, post: { select: { status: true, moderationCases: { where: { status: 'OPEN' }, select: { id: true } } } } },
  });
  if (!media) return new Response(null, { status: 404 });
  const isPublic = media.post.status === 'PUBLISHED' && media.post.moderationCases.length === 0;
  if (!isPublic) {
    const [user] = await getServerUser();
    if (!(await getKnowledgeAdmin()) && !(media.post.status === 'HIDDEN' && user?.id === media.userId)) {
      return new Response(null, { status: 404 });
    }
  }
  try {
    const bytes = await readFile(storagePath(fileName));
    const extension = fileName.split('.').at(-1)?.toLowerCase() || '';
    const range = request.headers.get('range')?.match(/^bytes=(\d*)-(\d*)$/);
    const suffixLength = range && !range[1] && range[2] ? Number(range[2]) : 0;
    const start = suffixLength ? Math.max(0, bytes.length - suffixLength) : range?.[1] ? Number(range[1]) : 0;
    const end = suffixLength ? bytes.length - 1 : range?.[2] ? Number(range[2]) : bytes.length - 1;
    if (range && (start > end || end >= bytes.length)) {
      return new Response(null, { status: 416, headers: { 'Content-Range': `bytes */${bytes.length}` } });
    }
    const body = range ? bytes.subarray(start, end + 1) : bytes;
    return new Response(new Uint8Array(body), {
      status: range ? 206 : 200,
      headers: {
        'Content-Type': contentTypes[extension] || 'application/octet-stream',
        'Content-Length': String(body.length),
        'Accept-Ranges': 'bytes',
        ...(range ? { 'Content-Range': `bytes ${start}-${end}/${bytes.length}` } : {}),
        'Cache-Control': isPublic ? 'public, max-age=60' : 'private, no-store',
        'X-Content-Type-Options': 'nosniff',
      },
    });
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') return new Response(null, { status: 404 });
    throw error;
  }
}
