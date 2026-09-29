import type { DisplayIdentity } from '@prisma/client';
import { GetVisualMedia } from '@/types/definitions';

export interface ToEditValues {
  postId: number;
  initialContent: string;
  initialVisualMedia: GetVisualMedia[];
  initialDisplayIdentity: DisplayIdentity;
}
