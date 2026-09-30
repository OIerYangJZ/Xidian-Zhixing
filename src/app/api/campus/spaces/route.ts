import { NextResponse } from 'next/server';
import prisma from '@/lib/prisma/prisma';

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const type = searchParams.get('type');
  const acceptedTypes = ['GLOBAL', 'COLLEGE', 'CLUB'] as const;
  if (type && type !== 'ALL' && !acceptedTypes.includes(type as (typeof acceptedTypes)[number])) {
    return NextResponse.json({ error: 'invalid_space_type' }, { status: 400 });
  }

  const spaces = await prisma.space.findMany({
    where: {
      status: 'ACTIVE',
      ...(type && type !== 'ALL' ? { type: type as (typeof acceptedTypes)[number] } : {}),
      ...(type === 'CLUB' ? { club: { is: { status: 'ACTIVE' } } } : {}),
    },
    orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
    select: { id: true, type: true, name: true, slug: true, description: true, avatar: true, collegeCode: true },
  });

  return NextResponse.json({
    spaces,
    colleges: spaces.filter((space) => space.type === 'COLLEGE'),
    sections: spaces,
  });
}
