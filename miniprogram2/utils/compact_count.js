export function compactCount(value) {
  if (value >= 1000000000) return (Math.floor(value / 100000000) / 10) + 'B';
  if (value >= 100000000) return Math.floor(value / 1000000) + 'M';
  if (value >= 1000000) return (Math.floor(value / 100000) / 10) + 'M';
  if (value >= 100000) return Math.floor(value / 1000) + 'K';
  if (value >= 1000) return (Math.floor(value / 100) / 10) + 'K';
  return String(value);
}
