import 'server-only';
import { Blob, Buffer } from 'buffer';
import { assessPostText } from './text';

const MIME_BY_SIGNATURE: Array<[string, (bytes: Buffer) => boolean]> = [
  ['image/png', (bytes) => bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))],
  ['image/jpeg', (bytes) => bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff],
  [
    'image/gif',
    (bytes) =>
      bytes.subarray(0, 6).toString('ascii') === 'GIF87a' || bytes.subarray(0, 6).toString('ascii') === 'GIF89a',
  ],
  [
    'image/webp',
    (bytes) => bytes.subarray(0, 4).toString('ascii') === 'RIFF' && bytes.subarray(8, 12).toString('ascii') === 'WEBP',
  ],
  [
    'video/quicktime',
    (bytes) =>
      bytes.subarray(4, 8).toString('ascii') === 'ftyp' && bytes.subarray(8, 12).toString('ascii').startsWith('qt'),
  ],
  ['video/mp4', (bytes) => bytes.subarray(4, 8).toString('ascii') === 'ftyp'],
  [
    'video/x-msvideo',
    (bytes) => bytes.subarray(0, 4).toString('ascii') === 'RIFF' && bytes.subarray(8, 12).toString('ascii') === 'AVI ',
  ],
];

function detectMimeType(bytes: Buffer) {
  return MIME_BY_SIGNATURE.find(([, matches]) => matches(bytes))?.[0] || null;
}

function normalizedMimeType(value: string) {
  return value === 'image/jpg' ? 'image/jpeg' : value;
}

async function callImageService(url: string, bytes: Buffer, contentType: string) {
  const base64 = bytes.toString('base64');
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      imageBase64: base64,
      contentType,
      input: { type: 'base64', data: base64 },
    }),
    cache: 'no-store',
    signal: AbortSignal.timeout(Number(process.env.BACKEND_IMAGE_MODERATION_TIMEOUT_SECONDS || 3) * 1000),
  });
  if (!response.ok) throw new Error('image moderation service failed');
  return (await response.json()) as Record<string, unknown>;
}

async function inspectImage(file: Blob) {
  const bytes = Buffer.from(await file.arrayBuffer());
  const detectedType = detectMimeType(bytes);
  if (!detectedType || normalizedMimeType(file.type) !== detectedType) {
    return { decision: 'reject' as const, reasons: ['文件声明类型与实际内容不一致'] };
  }
  if (bytes.byteLength > Number(process.env.BACKEND_POST_MAX_FILE_BYTES || 20 * 1024 * 1024)) {
    return { decision: 'reject' as const, reasons: ['附件超过 20 MB 限制'] };
  }

  if (!detectedType.startsWith('image/')) {
    return { decision: 'review' as const, reasons: ['视频暂未接入自动内容审核'] };
  }

  const moderationUrl = process.env.BACKEND_IMAGE_MODERATION_URL?.trim();
  const ocrUrl = process.env.BACKEND_IMAGE_OCR_URL?.trim();
  if (!moderationUrl || !ocrUrl) {
    return { decision: 'review' as const, reasons: ['图片审核服务未完整配置，需人工审核'] };
  }

  let serviceResults: [Record<string, unknown>, Record<string, unknown>];
  try {
    serviceResults = (await Promise.all([
      callImageService(moderationUrl, bytes, detectedType),
      callImageService(ocrUrl, bytes, detectedType),
    ])) as [Record<string, unknown>, Record<string, unknown>];
  } catch {
    return { decision: 'review' as const, reasons: ['图片审核服务暂不可用，需人工审核'] };
  }
  const [moderation, ocr] = serviceResults;

  const prediction = (
    moderation.result && typeof moderation.result === 'object' ? moderation.result : moderation
  ) as Record<string, unknown>;
  const probability = Number(prediction.nsfw_probability ?? prediction.nsfwProbability);
  if (!Number.isFinite(probability)) {
    return { decision: 'review' as const, reasons: ['图片审核结果无效，需人工审核'] };
  }
  const blockThreshold = Number(process.env.BACKEND_IMAGE_NSFW_BLOCK_THRESHOLD || 0.85);
  const reviewThreshold = Number(process.env.BACKEND_IMAGE_NSFW_REVIEW_THRESHOLD || 0.6);
  if (probability >= blockThreshold) {
    return { decision: 'reject' as const, reasons: [`图片疑似不适宜内容（${probability.toFixed(2)}）`] };
  }
  if (probability >= reviewThreshold) {
    return { decision: 'review' as const, reasons: [`图片疑似不适宜内容，需人工审核（${probability.toFixed(2)}）`] };
  }

  const ocrText = [ocr.text, ocr.texts]
    .flatMap((value) => (Array.isArray(value) ? value : [value]))
    .filter((value): value is string => typeof value === 'string')
    .join(' ');
  const textResult = assessPostText(ocrText);
  if (textResult.decision !== 'approve') {
    return {
      decision: textResult.decision,
      reasons: textResult.reasons.map((reason) => `图片文字：${reason}`),
    };
  }
  return { decision: 'approve' as const, reasons: [] };
}

export async function reviewPostSubmission(content: string, files: Blob[]) {
  const textResult = assessPostText(content);
  if (textResult.decision === 'reject') return textResult;

  const reasons = [...textResult.reasons];
  let needsReview = textResult.decision === 'review';
  let rejected = false;
  for (const file of files) {
    // eslint-disable-next-line no-await-in-loop
    const result = await inspectImage(file);
    reasons.push(...result.reasons);
    if (result.decision === 'reject') rejected = true;
    if (result.decision === 'review') needsReview = true;
  }
  return { decision: rejected ? 'reject' : needsReview ? 'review' : 'approve', reasons };
}
