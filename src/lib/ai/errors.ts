// One place that turns a harness failure code into the sentence a user reads. Every AI route
// shares it so a budget limit can never be reported as a timeout again.

export type HarnessUsage = {
  requests?: number;
  toolCalls?: number;
  inputTokens?: number;
  outputTokens?: number;
};

export type HarnessFailureInput = {
  status?: number;
  reason?: string;
  usage?: HarnessUsage;
};

/** Human-readable summary of what the turn spent before it stopped. */
export function usageSummary(usage: HarnessUsage | undefined): string {
  if (!usage) return '';
  const parts: string[] = [];
  if (typeof usage.requests === 'number' && usage.requests > 0) parts.push(`模型请求 ${usage.requests} 次`);
  if (typeof usage.toolCalls === 'number' && usage.toolCalls > 0) parts.push(`工具调用 ${usage.toolCalls} 次`);
  if (typeof usage.inputTokens === 'number' && usage.inputTokens > 0) parts.push(`输入 ${usage.inputTokens} tokens`);
  if (typeof usage.outputTokens === 'number' && usage.outputTokens > 0) parts.push(`输出 ${usage.outputTokens} tokens`);
  return parts.join(' · ');
}

export function harnessErrorMessage(code: string | undefined, input: HarnessFailureInput = {}): string {
  switch (code) {
    case 'ai_busy':
      return '同时处理的提问已满，请稍后重试。';
    case 'ai_timeout':
      return '本轮回答等待超时，已中断。可以缩小问题范围，或换一轮更短的提问。';
    case 'ai_budget_exceeded':
      return '本轮已达到检索/推理预算上限（不是超时）。把问题拆小，或换一轮更具体的提问再试。';
    case 'ai_request_invalid':
      return input.reason
        ? `本轮请求体不符合 harness 的请求格式，已被拒绝：${input.reason}。这通常说明历史里有一段过长的内容。`
        : '本轮请求体不符合 harness 的请求格式，已被拒绝。这通常说明历史里有一段过长的内容。';
    case 'corpus_not_configured':
      return '本地校园资料库尚未配置。';
    case 'ai_not_configured':
      return 'DeepSeek API 尚未配置。';
    case 'harness_unavailable':
      return 'AI Agent 服务暂时无法连接。';
    default:
      return input.status
        ? `DeepSeek 返回 HTTP ${input.status}，本轮回答没有完成。`
        : 'DeepSeek 暂时无法完成请求，请稍后重试。';
  }
}
