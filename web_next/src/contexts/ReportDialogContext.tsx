'use client';

import React, { createContext, useCallback, useMemo, useState } from 'react';
import { useOverlayTriggerState } from 'react-stately';
import { AnimatePresence } from 'framer-motion';
import { Modal } from '@/components/Modal';
import { GenericDialog } from '@/components/GenericDialog';
import Button from '@/components/ui/Button';
import { useLanguage } from '@/hooks/useLanguage';
import { useToast } from '@/hooks/useToast';
import { createReport, REPORT_REASONS, type ReportReason } from '@/lib/backend/endpoints';
import { ApiError } from '@/lib/backend/client';

export interface ReportTarget {
  targetType: 'post' | 'comment' | 'user';
  targetId: string;
}

export const ReportDialogContext = createContext<{ openReport: (target: ReportTarget) => void }>({
  openReport: () => {},
});

function ReportDialog({ target, close }: { target: ReportTarget; close: () => void }) {
  const { t } = useLanguage();
  const { showToast } = useToast();
  const [reason, setReason] = useState<ReportReason | ''>('');
  const [description, setDescription] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const submit = async () => {
    if (!reason) return;
    setSubmitting(true);
    try {
      await createReport({ ...target, reason, description: description.trim() || undefined });
      showToast({
        title: t('举报已提交', 'Report submitted'),
        message: t('管理员会尽快处理。', 'A moderator will review it.'),
        type: 'success',
      });
      close();
    } catch (error) {
      showToast({
        title: t('举报失败', 'Could not report'),
        message: error instanceof ApiError ? error.message : undefined,
        type: 'error',
      });
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <GenericDialog title={t('举报', 'Report')} handleClose={close}>
      <div className="px-4 pb-5">
        <p className="mb-3 text-sm text-muted-foreground">{t('请选择举报理由：', 'Why are you reporting this?')}</p>
        <div className="grid grid-cols-2 gap-2">
          {REPORT_REASONS.map((item) => (
            <button
              key={item}
              type="button"
              aria-pressed={reason === item}
              onClick={() => setReason(item)}
              className={
                reason === item
                  ? 'min-h-10 rounded-md border border-primary bg-primary/10 px-3 text-sm text-primary'
                  : 'min-h-10 rounded-md border border-border px-3 text-sm text-foreground hover:bg-secondary'
              }>
              {item}
            </button>
          ))}
        </div>
        <textarea
          value={description}
          onChange={(event) => setDescription(event.target.value.slice(0, 500))}
          placeholder={t('补充说明（选填）', 'Details (optional)')}
          aria-label={t('补充说明', 'Details')}
          rows={3}
          className="mt-3 w-full rounded-md border border-border bg-background p-3 text-sm text-foreground outline-none focus:border-primary"
        />
        <div className="mt-4 flex justify-end">
          <Button onPress={submit} isDisabled={!reason} loading={submitting} size="small">
            {t('提交', 'Submit')}
          </Button>
        </div>
      </div>
    </GenericDialog>
  );
}

export function ReportDialogContextProvider({ children }: { children: React.ReactNode }) {
  const state = useOverlayTriggerState({});
  const [target, setTarget] = useState<ReportTarget | null>(null);
  const openReport = useCallback(
    (next: ReportTarget) => {
      setTarget(next);
      state.open();
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [],
  );
  const value = useMemo(() => ({ openReport }), [openReport]);

  return (
    <ReportDialogContext.Provider value={value}>
      {children}
      <AnimatePresence>
        {state.isOpen && target && (
          <Modal state={state}>
            <ReportDialog target={target} close={state.close} />
          </Modal>
        )}
      </AnimatePresence>
    </ReportDialogContext.Provider>
  );
}
