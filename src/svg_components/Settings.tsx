import { SVGProps } from 'react';

export default function Settings(props: SVGProps<SVGSVGElement>) {
  return (
    <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" {...props}>
      <g stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <path d="M12 1.8v2.1m0 16.2v2.1M1.8 12h2.1m16.2 0h2.1M4.78 4.78l1.49 1.49m11.46 11.46 1.49 1.49m0-14.44-1.49 1.49M6.27 17.73l-1.49 1.49" />
        <circle cx="12" cy="12" r="7.15" />
        <circle cx="12" cy="12" r="3.05" />
      </g>
    </svg>
  );
}
