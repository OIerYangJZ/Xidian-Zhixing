import { cn } from '@/lib/cn';
import { SVGProps, useRef } from 'react';
import { VariantProps, cva } from 'class-variance-authority';
import { AriaToggleButtonProps, mergeProps, useFocusRing, useToggleButton } from 'react-aria';
import { useToggleState } from 'react-stately';

const toggle = cva(
  'flex min-w-12 cursor-pointer select-none items-center gap-2 rounded-full px-2 py-2 text-sm active:ring-4',
  {
    variants: {
      color: {
        red: 'hover:bg-rose-500/10 focus:outline-none',
        blue: 'hover:bg-sky-500/10 focus:outline-none',
        accent: 'hover:bg-primary/10 focus:outline-none',
      },
    },
    defaultVariants: {
      color: 'accent',
    },
  },
);

const icon = cva('h-[18px] w-[18px]', {
  variants: {
    color: {
      red: 'fill-rose-500',
      blue: 'fill-sky-500',
      accent: 'fill-primary',
    },
  },
  defaultVariants: {
    color: 'accent',
  },
});

interface ToggleStepperProps extends VariantProps<typeof icon>, AriaToggleButtonProps {
  Icon: (props: SVGProps<SVGSVGElement>) => JSX.Element;
  quantity: number;
  noun?: string;
  compact?: boolean;
}

export function ToggleStepper({ Icon, quantity, noun, color, compact = false, ...rest }: ToggleStepperProps) {
  const ref = useRef<HTMLButtonElement>(null);
  const state = useToggleState(rest);
  const { buttonProps } = useToggleButton(rest, state, ref);
  const { isFocusVisible, focusProps } = useFocusRing();

  return (
    <button
      type="button"
      {...mergeProps(buttonProps, focusProps)}
      ref={ref}
      className={cn(
        'transition-transform active:scale-90',
        toggle({ color }),
        compact && 'py-1',
        isFocusVisible && 'ring-2 ring-primary ring-offset-2',
      )}>
      <Icon width={24} height={24} className={cn(state.isSelected ? icon({ color }) : 'stroke-muted-foreground')} />
      <p className="text-xs font-medium text-muted-foreground">
        {quantity} {noun !== undefined ? (quantity === 1 ? noun : `${noun}s`) : ''}
      </p>
    </button>
  );
}
