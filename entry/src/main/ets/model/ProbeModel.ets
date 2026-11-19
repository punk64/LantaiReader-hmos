export interface ProxyStat {
  assets: number;
  api: number;
  failed: number;
  cached: number;
  lastPath: string;
  lastMs: number;
}

export function emptyStat(): ProxyStat {
  return { assets: 0, api: 0, failed: 0, cached: 0, lastPath: '', lastMs: 0 };
}
