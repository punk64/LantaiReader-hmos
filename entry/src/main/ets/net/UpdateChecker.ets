import { http } from '@kit.NetworkKit';
import { J } from '../common/Json';
import { Prefs, PrefKeys } from '../model/Prefs';

export class UpdateResult {
  state: string = 'fail';
  version: string = '';
  notes: string = '';
  url: string = '';
  message: string = '';
}

export class UpdateChecker {
  static readonly fallback: string = 'punk64/LantaiReader-hmos';

  static source(): string {
    const saved: string = Prefs.read(PrefKeys.repo).trim();
    return saved.length > 0 ? saved : UpdateChecker.fallback;
  }

  static async saveRepo(text: string): Promise<void> {
    await Prefs.write(PrefKeys.repo, text.trim());
  }

  private static host(source: string): string {
    const mark: number = source.indexOf('://');
    if (mark < 0) {
      return '';
    }
    const rest: string = source.substring(mark + 3);
    const slash: number = rest.indexOf('/');
    return slash < 0 ? rest : rest.substring(0, slash);
  }

  private static segments(source: string): string[] {
    let body: string = source.trim();
    const mark: number = body.indexOf('://');
    if (mark >= 0) {
      const rest: string = body.substring(mark + 3);
      const slash: number = rest.indexOf('/');
      body = slash < 0 ? '' : rest.substring(slash + 1);
    }
    if (body.endsWith('.git')) {
      body = body.substring(0, body.length - 4);
    }
    const raw: string[] = body.split('/');
    const out: string[] = [];
    for (let index: number = 0; index < raw.length; index++) {
      const item: string = raw[index].trim();
      if (item.length > 0) {
        out.push(item);
      }
    }
    return out;
  }

  private static endpoint(): string {
    const source: string = UpdateChecker.source();
    const parts: string[] = UpdateChecker.segments(source);
    if (parts.length < 2) {
      return '';
    }
    const owner: string = parts[parts.length - 2];
    const name: string = parts[parts.length - 1];
    const host: string = UpdateChecker.host(source);
    if (host.indexOf('github') >= 0) {
      return `https://api.github.com/repos/${owner}/${name}/releases/latest`;
    }
    if (host.indexOf('gitee') >= 0) {
      return `https://gitee.com/api/v5/repos/${owner}/${name}/releases/latest`;
    }
    if (host.length > 0) {
      const mark: number = source.indexOf('://');
      const scheme: string = source.substring(0, mark);
      return `${scheme}://${host}/api/v1/repos/${owner}/${name}/releases/latest`;
    }
    return `https://api.github.com/repos/${owner}/${name}/releases/latest`;
  }

  private static numeric(version: string): number[] {
    let body: string = version.trim();
    while (body.length > 0 && (body.charAt(0) < '0' || body.charAt(0) > '9')) {
      body = body.substring(1);
    }
    const parts: string[] = body.split('.');
    const out: number[] = [];
    for (let index: number = 0; index < parts.length; index++) {
      const value: number = parseInt(parts[index], 10);
      out.push(isNaN(value) ? 0 : value);
    }
    return out;
  }

  static newer(local: string, remote: string): boolean {
    const a: number[] = UpdateChecker.numeric(local);
    const b: number[] = UpdateChecker.numeric(remote);
    const size: number = Math.max(a.length, b.length);
    for (let index: number = 0; index < size; index++) {
      const left: number = index < a.length ? a[index] : 0;
      const right: number = index < b.length ? b[index] : 0;
      if (right > left) {
        return true;
      }
      if (right < left) {
        return false;
      }
    }
    return false;
  }

  static async check(local: string): Promise<UpdateResult> {
    const result: UpdateResult = new UpdateResult();
    const url: string = UpdateChecker.endpoint();
    if (url.length === 0) {
      result.message = 'INVALID_SOURCE';
      return result;
    }
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Accept': 'application/json',
          'User-Agent': 'LantaiReader'
        },
        connectTimeout: 8000,
        readTimeout: 8000,
        expectDataType: http.HttpDataType.STRING
      });
      const text: string = typeof response.result === 'string' ? response.result as string : '';
      if (response.responseCode !== 200) {
        result.message = `HTTP ${response.responseCode}`;
        return result;
      }
      const body: Record<string, Object> = J.parse(text);
      const tag: string = J.str(body, 'tag_name');
      if (tag.length === 0) {
        result.message = 'NO_RELEASE';
        return result;
      }
      result.version = tag;
      result.notes = J.str(body, 'body');
      result.url = J.str(body, 'html_url');
      result.state = UpdateChecker.newer(local, tag) ? 'new' : 'latest';
      return result;
    } catch (error) {
      result.message = (error as Error).message;
      return result;
    } finally {
      request.destroy();
    }
  }
}
