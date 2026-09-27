import { Logo } from '@/svg_components';

export default function Navbar() {
  return (
    <div className="flex w-full flex-row border-b border-border bg-background px-4 py-3">
      <Logo className="h-12 w-12" />
    </div>
  );
}
