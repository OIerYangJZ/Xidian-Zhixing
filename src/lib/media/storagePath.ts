import 'server-only';
import path from 'path';

export function storagePath(fileName: string) {
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(fileName)) throw new Error('Invalid media file name.');
  const directory = process.env.MEDIA_STORAGE_DIR?.trim();
  if (!directory) throw new Error('MEDIA_STORAGE_DIR is required.');
  return path.join(path.resolve(directory), fileName);
}
