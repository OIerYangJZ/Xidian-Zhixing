import type { LegalDocument } from '@/lib/legal';

/** A legal text: numbered sections of plain paragraphs, as in the Flutter app. */
export function LegalDocumentView({ document }: { document: LegalDocument }) {
  return (
    <article className="mx-auto w-full max-w-3xl px-4 py-8 sm:px-6">
      <header className="border-b border-border pb-5">
        <h1 className="text-2xl font-bold">{document.title}</h1>
        <p className="mt-2 text-sm text-muted-foreground">最后更新：{document.lastUpdated}</p>
      </header>
      {document.sections.map((section) => (
        <section key={section.title} className="border-b border-border py-5">
          <h2 className="text-base font-semibold">{section.title}</h2>
          <p className="mt-3 whitespace-pre-line text-[15px] leading-7 text-foreground/90">{section.content}</p>
        </section>
      ))}
      <footer className="whitespace-pre-line pt-6 text-center text-sm text-muted-foreground">{document.footer}</footer>
    </article>
  );
}
