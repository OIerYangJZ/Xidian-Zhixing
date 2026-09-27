import React, { useRef } from 'react';
import { AriaDialogProps, useDialog } from 'react-aria';
import SvgClose from '@/svg_components/Close';
import { ResponsiveContainer } from './ui/ResponsiveContainer';
import Button from './ui/Button';

interface GenericDialogProps extends AriaDialogProps {
  title: string;
  handleClose: () => void;
  children: React.ReactNode;
}

export function GenericDialog({ title, handleClose, children, ...props }: GenericDialogProps) {
  const dialogRef = useRef(null);
  const { dialogProps, titleProps } = useDialog(props, dialogRef);

  return (
    <div
      {...dialogProps}
      ref={dialogRef}
      className="flex h-full max-h-dvh w-full flex-col items-center justify-end overflow-y-auto sm:justify-center sm:p-3">
      <ResponsiveContainer>
        <div className="mb-0 max-h-[90dvh] w-full overflow-y-auto rounded-t-3xl border border-b-0 border-border bg-popover pb-[env(safe-area-inset-bottom)] sm:mb-6 sm:max-h-[min(80dvh,720px)] sm:rounded-lg sm:border sm:pb-0">
          <div className="sticky top-0 z-10 mb-4 rounded-t-3xl border-b border-border bg-background/95 py-4 backdrop-blur-xl sm:rounded-t-2xl">
            <h3 {...titleProps} className="text-center text-lg font-semibold">
              {title}
            </h3>
            <div className="absolute right-3 top-[50%] translate-y-[-50%]">
              <Button onPress={handleClose} Icon={SvgClose} mode="ghost" size="small" />
            </div>
          </div>
          {children}
        </div>
      </ResponsiveContainer>
    </div>
  );
}
