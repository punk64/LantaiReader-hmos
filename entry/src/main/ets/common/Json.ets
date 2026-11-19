export class J {
  static parse(text: string): Record<string, Object> {
    if (text.length === 0) {
      return {} as Record<string, Object>;
    }
    return JSON.parse(text) as Record<string, Object>;
  }

  static arrayOf(text: string): Object[] {
    if (text.length === 0) {
      return [];
    }
    const value: Object = JSON.parse(text);
    return Array.isArray(value) ? value as Object[] : [];
  }

  static str(map: Record<string, Object>, key: string): string {
    const value: Object = map[key];
    return typeof value === 'string' ? value as string : '';
  }

  static num(map: Record<string, Object>, key: string): number {
    const value: Object = map[key];
    return typeof value === 'number' ? value as number : 0;
  }

  static bool(map: Record<string, Object>, key: string): boolean {
    const value: Object = map[key];
    return typeof value === 'boolean' ? value as boolean : false;
  }

  static obj(map: Record<string, Object>, key: string): Record<string, Object> {
    const value: Object = map[key];
    if (value === null || value === undefined) {
      return {} as Record<string, Object>;
    }
    return value as Record<string, Object>;
  }

  static list(map: Record<string, Object>, key: string): Object[] {
    const value: Object = map[key];
    if (value === null || value === undefined) {
      return [];
    }
    return value as Object[];
  }

  static strList(map: Record<string, Object>, key: string): string[] {
    const raw: Object[] = J.list(map, key);
    const out: string[] = [];
    for (let index = 0; index < raw.length; index++) {
      const item: Object = raw[index];
      if (typeof item === 'string') {
        out.push(item as string);
      }
    }
    return out;
  }
}
