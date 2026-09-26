import { NextResponse } from 'next/server';

export function apiSuccess<T>(data: T, status = 200) {
  return NextResponse.json({ data }, { status });
}

export function apiError(message: string, status: number, data: Record<string, unknown> = {}) {
  return NextResponse.json({ message, data }, { status });
}
