import { z } from 'zod';
import { campusQuickLinks, getCampusServices } from '@/lib/campus/catalog';

export type UISource = { citation: number; title: string; source: string | null; documentId: string };
export type UIService = {
  id: string;
  name: string;
  description: string;
  href: string;
  status: 'available' | 'pending';
};

const text = (max: number) =>
  z
    .string()
    .trim()
    .min(1)
    .max(max)
    .refine((value) => !/[<>]/.test(value));
const citations = z.array(z.number().int().positive()).min(1).max(8);
export const uiCardSchema = z.discriminatedUnion('type', [
  z.object({ type: z.literal('source_list'), citations }).strict(),
  z
    .object({
      type: z.literal('guide'),
      title: text(240),
      steps: z
        .array(z.object({ title: text(240), detail: text(2000), citations }).strict())
        .min(1)
        .max(8),
    })
    .strict(),
  z.object({ type: z.literal('service_links'), serviceIds: z.array(text(100)).min(1).max(8) }).strict(),
]);
export const uiEnvelopeSchema = z
  .object({ version: z.literal(1), cards: z.array(uiCardSchema).min(1).max(3) })
  .strict();
export type UICard = z.infer<typeof uiCardSchema>;
export type UIEnvelope = z.infer<typeof uiEnvelopeSchema>;

export function getAIUIServices(): UIService[] {
  return [
    ...campusQuickLinks.map((item) => ({
      id: item.id,
      name: item.name,
      description: item.description,
      href: item.url,
      status: 'available' as const,
    })),
    ...getCampusServices(false)
      .filter((item) => item.enabled)
      .map((item) => ({
        id: item.id,
        name: item.name,
        description: item.emptyText,
        href: item.path,
        status: item.status,
      })),
  ];
}

export function harnessUIContext(version: unknown) {
  return version === 1
    ? { uiVersion: 1, uiServices: getAIUIServices().map(({ id, name, description }) => ({ id, name, description })) }
    : {};
}

export function safeSourceURL(value: string | null): string | undefined {
  if (!value) return undefined;
  try {
    const url = new URL(value);
    if (['http:', 'https:'].includes(url.protocol) && !url.username && !url.password) return url.href;
  } catch {
    // Local documents may have no public URL.
  }
  return undefined;
}

export function cardCitations(card: UICard): number[] {
  return card.type === 'source_list'
    ? card.citations
    : card.type === 'guide'
    ? card.steps.flatMap((step) => step.citations)
    : [];
}

// The model supplies IDs only. Titles and destinations come from trusted source/catalog records.
export function validateUI(value: unknown, sources: UISource[]): { ui: UIEnvelope | null; errors: string[] } {
  if (value == null) return { ui: null, errors: [] };
  const envelope = z
    .object({ version: z.literal(1), cards: z.array(z.unknown()).min(1).max(3) })
    .strict()
    .safeParse(value);
  if (!envelope.success) return { ui: null, errors: ['invalid_envelope'] };
  const sourceByCitation = new Map(sources.map((source) => [source.citation, source]));
  const services = new Set(getAIUIServices().map((service) => service.id));
  const cards: UICard[] = [];
  const errors: string[] = [];
  for (const [index, raw] of envelope.data.cards.entries()) {
    const parsed = uiCardSchema.safeParse(raw);
    if (!parsed.success) {
      errors.push(`card_${index}:invalid_schema`);
      continue;
    }
    const card = parsed.data;
    const invalidSource = cardCitations(card).some((citation) => {
      const source = sourceByCitation.get(citation);
      return !source || (source.source !== null && !safeSourceURL(source.source));
    });
    if (invalidSource || (card.type === 'service_links' && card.serviceIds.some((id) => !services.has(id)))) {
      errors.push(`card_${index}:${invalidSource ? 'invalid_source' : 'unknown_service'}`);
      continue;
    }
    cards.push(card);
  }
  return { ui: cards.length ? { version: 1, cards } : null, errors };
}
