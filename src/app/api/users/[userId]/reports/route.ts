import { NextResponse } from 'next/server';
import { getServerUser } from '@/lib/getServerUser';
import prisma from '@/lib/prisma/prisma';

const statusText = (status?: string | null) => {
  if (status === 'RESOLVED') return 'resolved';
  if (status === 'DISMISSED') return 'rejected';
  if (status === 'APPEALED') return 'pending';
  return 'pending';
};

const actionText = (action?: string | null) => {
  if (action === 'REMOVE_CONTENT') return '内容已移除';
  if (action === 'LIMIT_VISIBILITY') return '内容可见范围已调整';
  if (action === 'WARN_USER') return '已发出提醒';
  if (action === 'SUSPEND_USER') return '已采取账号措施';
  return '';
};

export async function GET(request: Request, props: { params: Promise<{ userId: string }> }) {
  const { userId } = await props.params;
  const [user] = await getServerUser();
  if (!user?.id || user.id !== userId) return NextResponse.json({ error: 'unauthorized' }, { status: 401 });

  const { searchParams } = new URL(request.url);
  const reportId = searchParams.get('id');
  const reports = await prisma.report.findMany({
    where: { reporterId: userId, ...(reportId ? { id: reportId } : {}) },
    orderBy: { createdAt: 'desc' },
    take: reportId ? 1 : 100,
    select: {
      id: true,
      reason: true,
      details: true,
      createdAt: true,
      postId: true,
      commentId: true,
      post: { select: { content: true } },
      comment: { select: { content: true } },
      case: { select: { status: true, action: true, resolvedAt: true } },
    },
  });

  return NextResponse.json(
    reports.map((report) => ({
      id: report.id,
      reason: report.reason,
      description: report.details || '',
      createdAt: report.createdAt,
      handledAt: report.case?.resolvedAt || null,
      result: actionText(report.case?.action),
      status: statusText(report.case?.status),
      targetType: report.postId ? 'post' : 'comment',
      targetId: String(report.postId || report.commentId || ''),
      targetTitle: (report.post?.content || report.comment?.content || '').split('\n')[0].slice(0, 100),
    })),
  );
}
