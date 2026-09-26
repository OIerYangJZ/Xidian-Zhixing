export const metadata = {
  title: '西电知行 · Xidian University',
  description: '西电知行：连接西安电子科技大学的学习、研究与校园生活。',
};

export default async function Page() {
  return (
    <iframe
      title="西电知行首页"
      src="/zhixing-home/index.html"
      className="fixed inset-0 z-50 h-dvh w-full border-0 bg-white"
    />
  );
}
