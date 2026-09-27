import { useContext } from 'react';
import { ReportDialogContext } from '@/contexts/ReportDialogContext';

export function useReportDialog() {
  return useContext(ReportDialogContext);
}
