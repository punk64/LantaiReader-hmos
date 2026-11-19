import { t } from './I18n';
export class F {
  static pad(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  static moment(raw: string): number {
    if (raw.length === 0) {
      return 0;
    }
    const stamp: number = Date.parse(raw);
    return isNaN(stamp) ? 0 : stamp;
  }

  static ago(raw: string): string {
    const stamp: number = F.moment(raw);
    if (stamp === 0) {
      return '';
    }
    const delta: number = Date.now() - stamp;
    if (delta < 0) {
      return t('刚刚');
    }
    const minute: number = Math.floor(delta / 60000);
    if (minute < 1) {
      return t('刚刚');
    }
    if (minute < 60) {
      return t(`${minute} 分钟前`);
    }
    const hour: number = Math.floor(minute / 60);
    if (hour < 24) {
      return t(`${hour} 小时前`);
    }
    const day: number = Math.floor(hour / 24);
    if (day === 1) {
      return t('昨天');
    }
    if (day < 30) {
      return t(`${day} 天前`);
    }
    const date: Date = new Date(stamp);
    const month: string = F.pad(date.getMonth() + 1);
    const dayOfMonth: string = F.pad(date.getDate());
    if (date.getFullYear() === new Date().getFullYear()) {
      return `${month}-${dayOfMonth}`;
    }
    return `${date.getFullYear()}-${month}-${dayOfMonth}`;
  }

  static bytes(size: number): string {
    if (size <= 0) {
      return '—';
    }
    const units: string[] = ['B', 'KB', 'MB', 'GB', 'TB'];
    let value: number = size;
    let unit: number = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value = value / 1024;
      unit += 1;
    }
    const digits: number = value >= 100 || unit === 0 ? 0 : 1;
    return `${value.toFixed(digits)} ${units[unit]}`;
  }

  static cap(size: number): string {
    const units: string[] = ['B', 'K', 'M', 'G', 'T'];
    let value: number = size > 0 ? size : 0;
    let unit: number = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value = value / 1024;
      unit += 1;
    }
    if (unit === 0) {
      return `${Math.round(value)}B`;
    }
    const text: string = value >= 10 ? `${Math.round(value)}` : `${Math.round(value * 10) / 10}`;
    return `${text}${units[unit]}`;
  }

  static percent(page: number, total: number): number {
    if (total <= 0 || page <= 0) {
      return 0;
    }
    const ratio: number = page / total;
    if (ratio >= 1) {
      return 100;
    }
    return Math.max(1, Math.round(ratio * 100));
  }

  static duration(ms: number): string {
    if (ms <= 0) {
      return t('0 分钟');
    }
    const minute: number = Math.floor(ms / 60000);
    if (minute < 60) {
      return t(`${Math.max(1, minute)} 分钟`);
    }
    const hour: number = Math.floor(minute / 60);
    const rest: number = minute % 60;
    return rest === 0 ? t(`${hour} 小时`) : t(`${hour} 小时 ${rest} 分`);
  }

  static progressLabel(page: number, total: number, completed: boolean): string {
    if (completed) {
      return t('已读完');
    }
    if (page <= 0) {
      return t('未开始');
    }
    return t(`读到 ${F.percent(page, total)}%`);
  }

  static shortDuration(ms: number): string {
    if (ms <= 0) {
      return t('0 分');
    }
    const minute: number = Math.floor(ms / 60000);
    if (minute < 60) {
      return t(`${minute} 分`);
    }
    const hour: number = minute / 60;
    return hour >= 10 ? t(`${Math.round(hour)} 时`) : t(`${hour.toFixed(1)} 时`);
  }

  static day(iso: string): string {
    const stamp: number = F.moment(iso);
    if (stamp === 0) {
      return '';
    }
    const date: Date = new Date(stamp);
    return `${F.pad(date.getMonth() + 1)}-${F.pad(date.getDate())}`;
  }

  static stamp(iso: string): string {
    const stamp: number = F.moment(iso);
    if (stamp === 0) {
      return '';
    }
    const date: Date = new Date(stamp);
    return `${date.getFullYear()}-${F.pad(date.getMonth() + 1)}-${F.pad(date.getDate())} ${F.pad(date.getHours())}:${F.pad(date.getMinutes())}`;
  }
}
