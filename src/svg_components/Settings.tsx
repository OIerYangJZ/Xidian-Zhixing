import { SVGProps } from 'react';

export default function Settings(props: SVGProps<SVGSVGElement>) {
  return (
    <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" {...props}>
      <path d="M12 15.25a3.25 3.25 0 1 0 0-6.5 3.25 3.25 0 0 0 0 6.5Z" stroke="currentColor" strokeWidth="1.8" />
      <path
        d="m19.4 15 .05.04a1.8 1.8 0 1 1-2.55 2.55l-.04-.05a1.8 1.8 0 0 0-3.06 1.27v.14a1.8 1.8 0 1 1-3.6 0v-.08a1.8 1.8 0 0 0-3.06-1.27l-.04.05a1.8 1.8 0 1 1-2.55-2.55l.05-.04a1.8 1.8 0 0 0-1.27-3.06h-.14a1.8 1.8 0 1 1 0-3.6h.08a1.8 1.8 0 0 0 1.27-3.06l-.05-.04a1.8 1.8 0 1 1 2.55-2.55l.04.05a1.8 1.8 0 0 0 3.06-1.27v-.14a1.8 1.8 0 1 1 3.6 0v.08a1.8 1.8 0 0 0 3.06 1.27l.04-.05a1.8 1.8 0 1 1 2.55 2.55l-.05.04a1.8 1.8 0 0 0 1.27 3.06h.14a1.8 1.8 0 1 1 0 3.6h-.08A1.8 1.8 0 0 0 19.4 15Z"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinejoin="round"
      />
    </svg>
  );
}
