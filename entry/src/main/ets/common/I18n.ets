import { Prefs, PrefKeys } from '../model/Prefs';
import { STR_EN } from './StrEn';
import { TPL_EN } from './StrTpl';

export class Lang {
  static code: string = 'zh';
  static readonly zh: string = 'zh';
  static readonly en: string = 'en';

  static isEn(): boolean {
    return Lang.code === Lang.en;
  }

  static label(): string {
    return Lang.isEn() ? 'English' : '简体中文';
  }

  static tag(): string {
    return Lang.isEn() ? 'en-US' : 'zh-CN';
  }

  static apply(code: string): void {
    Lang.code = code === Lang.en ? Lang.en : Lang.zh;
    Prefs.write(PrefKeys.lang, Lang.code);
    AppStorage.setOrCreate('uiTick', Date.now());
  }
}

function numbers(text: string): string[] {
  const re: RegExp = new RegExp('[0-9]+(?:\\.[0-9]+)?', 'g');
  const out: string[] = [];
  let hit: RegExpExecArray | null = re.exec(text);
  while (hit !== null && out.length < 8) {
    out.push(hit[0]);
    hit = re.exec(text);
  }
  return out;
}

function pattern(text: string): string {
  const re: RegExp = new RegExp('[0-9]+(?:\\.[0-9]+)?', 'g');
  let out: string = '';
  let last: number = 0;
  let count: number = 0;
  let hit: RegExpExecArray | null = re.exec(text);
  while (hit !== null && count < 8) {
    out += text.substring(last, hit.index) + '{' + count + '}';
    last = hit.index + hit[0].length;
    count += 1;
    hit = re.exec(text);
  }
  out += text.substring(last);
  return out;
}

function fill(tpl: string, args: string[]): string {
  let out: string = tpl;
  for (let index: number = 0; index < args.length; index++) {
    out = out.replace('{' + index + '}', args[index]);
  }
  return out;
}

export function t(key: string): string {
  if (Lang.code !== Lang.en) {
    return key;
  }
  const exact: string | undefined = STR_EN.get(key);
  if (exact !== undefined) {
    return exact;
  }
  const shape: string = pattern(key);
  if (shape === key) {
    return key;
  }
  const hit: string | undefined = TPL_EN.get(shape);
  if (hit === undefined) {
    return key;
  }
  return fill(hit, numbers(key));
}

export function tf(key: string, args: string[]): string {
  return fill(t(key), args);
}
