import 'server-only';
import { unlink } from 'fs/promises';
import { storagePath } from '@/lib/media/storagePath';

export async function deleteObject(fileName: string) {
  await unlink(storagePath(fileName));
}
