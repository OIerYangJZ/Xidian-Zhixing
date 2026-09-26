import { VisualMediaType } from '@prisma/client';
import { v4 as uuid } from 'uuid';
import { uploadObject } from '@/lib/s3/uploadObject';
import { deleteObject } from '@/lib/s3/deleteObject';
import { Blob } from 'buffer';

const extensionByMimeType: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/gif': 'gif',
  'video/mp4': 'mp4',
  'video/quicktime': 'mov',
  'video/x-msvideo': 'avi',
};

/**
 * Use this function to efficiently save multiple files of a post.
 * If it encounters a `Blob`, it saves it to S3.
 * If it encounters a URL, it will return that URL instead of re-saving it.
 */
export async function savePostFiles(files: (Blob | string)[]) {
  const uploadedFileNames: string[] = [];
  type SavedFile = { type: VisualMediaType; fileName: string };
  const uploadPromises: Promise<SavedFile>[] = files.map(async (file) => {
    if (typeof file === 'string') {
      const fileName = decodeURIComponent(new URL(file).pathname.split('/').pop() || '');
      if (!fileName) throw new Error('Invalid media URL.');
      const type: VisualMediaType = /\.(jpg|jpeg|png|webp|gif)$/i.test(fileName) ? 'PHOTO' : 'VIDEO';
      return {
        type,
        fileName,
      };
    }

    // If the item is Blob, save it to S3 and return the `type` and the `fileName`
    const contentType = file.type === 'image/jpg' ? 'image/jpeg' : file.type;
    const fileExtension = extensionByMimeType[contentType];
    if (!fileExtension) throw new Error('Invalid file type.');
    const type: VisualMediaType = contentType.startsWith('image/') ? 'PHOTO' : 'VIDEO';
    const buffer = Buffer.from(await file.arrayBuffer());
    const fileName = `${Date.now()}-${uuid()}.${fileExtension}`;
    await uploadObject(buffer, fileName, contentType);
    uploadedFileNames.push(fileName);

    return { type, fileName };
  });

  const results = await Promise.allSettled(uploadPromises);
  const failure = results.find((result) => result.status === 'rejected');
  if (failure?.status === 'rejected') {
    await Promise.allSettled(uploadedFileNames.map((fileName) => deleteObject(fileName)));
    throw failure.reason;
  }
  return results.map((result) => {
    if (result.status === 'rejected') throw result.reason;
    return result.value;
  });
}
