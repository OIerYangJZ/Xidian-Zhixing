import 'server-only';
import { mkdir, writeFile } from 'fs/promises';
import path from 'path';
import { storagePath } from '@/lib/media/storagePath';

export async function uploadObject(file: Buffer, fileName: string, _type: string) {
  const destination = storagePath(fileName);
  await mkdir(path.dirname(destination), { recursive: true });
  await writeFile(destination, file, { flag: 'wx' });
}
