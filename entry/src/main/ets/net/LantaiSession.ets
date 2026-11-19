import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';

import { t } from '../common/I18n';
export interface SessionResponse {
  status: number;
  contentType: string;
  bytes: ArrayBuffer;
}

interface RawResponse {
  status: number;
  contentType: string;
  setCookie: string;
  bytes: ArrayBuffer;
}

const SESSION_PATH: string = '/api/v2/users/me?remember-me=true';

export class LantaiSession {
  private origin: string = '';
  private cookie: string = '';
  private pool: http.HttpRequest[] = [];

  ready(): boolean {
    return this.origin.length > 0 && this.cookie.length > 0;
  }

  serverOrigin(): string {
    return this.origin;
  }

  cookieHeader(): string {
    return this.cookie;
  }

  reset(): void {
    this.origin = '';
    this.cookie = '';
  }

  normalizeServer(input: string): string {
    let value: string = input.trim();
    if (value.length === 0) {
      return '';
    }
    if (!/^https?:\/\//.test(value)) {
      value = `http://${value}`;
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  async login(server: string, account: string, password: string): Promise<string> {
    const origin: string = this.normalizeServer(server);
    if (origin.length === 0) {
      throw new Error(t('服务器地址不能为空'));
    }
    if (account.length === 0) {
      throw new Error(t('用户名不能为空'));
    }
    const encoded: Uint8Array = new util.TextEncoder().encodeInto(`${account}:${password}`);
    const authorization: string = `Basic ${new util.Base64Helper().encodeToStringSync(encoded)}`;
    const raw: RawResponse = await this.send(origin, http.RequestMethod.GET, SESSION_PATH, {
      'Authorization': authorization,
      'Accept': 'application/json'
    }, null);
    if (raw.status !== 200) {
      throw new Error(t(`登录失败 HTTP ${raw.status}`));
    }
    const cookie: string = this.cookieFromSetCookie(raw.setCookie);
    if (cookie.length === 0) {
      throw new Error(t('登录成功但未返回会话 Cookie'));
    }
    this.origin = origin;
    this.cookie = cookie;
    return this.decodeText(raw.bytes);
  }

  async fetch(path: string, accept: string = '*/*', maxLimit: number = 0,
    readTimeout: number = 20000): Promise<SessionResponse> {
    if (!this.ready()) {
      throw new Error(t('尚未登录'));
    }
    const raw: RawResponse = await this.send(this.origin, http.RequestMethod.GET, path, {
      'Cookie': this.cookie,
      'Accept': accept
    }, null, maxLimit, readTimeout);
    return { status: raw.status, contentType: raw.contentType, bytes: raw.bytes };
  }

  async request(method: http.RequestMethod, path: string, body: string | null): Promise<SessionResponse> {
    if (!this.ready()) {
      throw new Error(t('尚未登录'));
    }
    const headers: Record<string, string> = { 'Cookie': this.cookie, 'Accept': 'application/json' };
    const raw: RawResponse = await this.send(this.origin, method, path, headers, body);
    return { status: raw.status, contentType: raw.contentType, bytes: raw.bytes };
  }

  async verbs(method: string, path: string, body: string | null): Promise<SessionResponse> {
    const upper: string = method.toUpperCase();
    let verb: http.RequestMethod = http.RequestMethod.GET;
    if (upper === 'POST') {
      verb = http.RequestMethod.POST;
    } else if (upper === 'PUT') {
      verb = http.RequestMethod.PUT;
    } else if (upper === 'PATCH') {
      verb = 'PATCH' as http.RequestMethod;
    } else if (upper === 'DELETE') {
      verb = http.RequestMethod.DELETE;
    }
    return this.request(verb, path, body);
  }

  async postJson(path: string, body: string): Promise<SessionResponse> {
    return this.request(http.RequestMethod.POST, path, body);
  }

  restore(origin: string, cookie: string): void {
    this.origin = origin;
    this.cookie = cookie;
  }

  setOrigin(origin: string): void {
    this.origin = origin;
  }

  async sendJson(method: string, path: string, body: string | null): Promise<number> {
    if (!this.ready()) {
      throw new Error(t('尚未登录'));
    }
    const upper: string = method.toUpperCase();
    let verb: http.RequestMethod = http.RequestMethod.GET;
    if (upper === 'POST') {
      verb = http.RequestMethod.POST;
    } else if (upper === 'PUT') {
      verb = http.RequestMethod.PUT;
    } else if (upper === 'PATCH') {
      verb = 'PATCH' as http.RequestMethod;
    } else if (upper === 'DELETE') {
      verb = http.RequestMethod.DELETE;
    }
    const target: string = path.startsWith('/') ? path : `/${path}`;
    const payload: string | null = body === null || body.length === 0 || body === 'null' ? null : body;
    const raw: RawResponse = await this.send(this.origin, verb, target, {
      'Cookie': this.cookie,
      'Accept': 'application/json'
    }, payload);
    return raw.status;
  }

  decodeText(bytes: ArrayBuffer): string {
    if (bytes.byteLength === 0) {
      return '';
    }
    return util.TextDecoder.create('utf-8', { ignoreBOM: true }).decodeToString(new Uint8Array(bytes));
  }

  private acquire(): http.HttpRequest {
    const pooled: http.HttpRequest | undefined = this.pool.pop();
    return pooled === undefined ? http.createHttp() : pooled;
  }

  private release(request: http.HttpRequest): void {
    if (this.pool.length < 4) {
      this.pool.push(request);
      return;
    }
    request.destroy();
  }

  private async send(origin: string, method: http.RequestMethod, path: string,
    headers: Record<string, string>, body: string | null, maxLimit: number = 0,
    readTimeout: number = 20000): Promise<RawResponse> {
    try {
      return await this.sendOnce(origin, method, path, headers, body, 0, maxLimit, readTimeout);
    } catch (error) {
      const code: number = (error as BusinessError).code;
      if (code === 2300028) {
        return await this.sendOnce(origin, method, path, headers, body, 0, maxLimit, readTimeout);
      }
      if (code !== 2300006) {
        throw error as Error;
      }
    }
    try {
      return await this.sendOnce(origin, method, path, headers, body, 1, maxLimit, readTimeout);
    } catch (error) {
      if ((error as BusinessError).code !== 2300006) {
        throw error as Error;
      }
    }
    return await this.sendOnce(origin, method, path, headers, body, 2, maxLimit, readTimeout);
  }

  private async sendOnce(origin: string, method: http.RequestMethod, path: string,
    headers: Record<string, string>, body: string | null, level: number,
    maxLimit: number, readTimeout: number): Promise<RawResponse> {
    const request: http.HttpRequest = this.acquire();
    const options: http.HttpRequestOptions = {
      method: method,
      header: headers,
      expectDataType: http.HttpDataType.ARRAY_BUFFER,
      connectTimeout: 8000,
      readTimeout: readTimeout,
      usingCache: false
    };
    if (maxLimit > 0) {
      options.maxLimit = maxLimit;
    }
    if (level > 0) {
      options.dnsServers = ['223.5.5.5', '119.29.29.29', '1.1.1.1'];
    }
    if (level > 1) {
      options.addressFamily = http.AddressFamily.ONLY_V6;
    }
    if (body !== null) {
      options.extraData = body;
      headers['Content-Type'] = 'application/json';
    }
    let healthy: boolean = false;
    try {
      const response: http.HttpResponse = await request.request(`${origin}${path}`, options);
      const bytes: ArrayBuffer = this.asBuffer(response.result);
      healthy = true;
      return {
        status: response.responseCode,
        contentType: this.pickHeader(response.header, 'content-type'),
        setCookie: this.pickHeader(response.header, 'set-cookie'),
        bytes: bytes
      };
    } finally {
      if (healthy) {
        this.release(request);
      } else {
        request.destroy();
      }
    }
  }

  private asBuffer(result: string | Object | ArrayBuffer): ArrayBuffer {
    if (result instanceof ArrayBuffer) {
      return result as ArrayBuffer;
    }
    const raw: Object = result as Object;
    if (raw === null || raw === undefined) {
      return new ArrayBuffer(0);
    }
    if (typeof result === 'string') {
      const text: string = result as string;
      if (text.length === 0) {
        return new ArrayBuffer(0);
      }
      const encoded: Uint8Array = new util.TextEncoder().encodeInto(text);
      return encoded.buffer as ArrayBuffer;
    }
    const json: string = JSON.stringify(result);
    const encoded: Uint8Array = new util.TextEncoder().encodeInto(json);
    return encoded.buffer as ArrayBuffer;
  }

  private pickHeader(header: Object, name: string): string {
    try {
      const map: Record<string, Object> = JSON.parse(JSON.stringify(header)) as Record<string, Object>;
      const target: string = name.toLowerCase();
      const keys: string[] = Object.keys(map);
      for (let index = 0; index < keys.length; index++) {
        if (keys[index].toLowerCase() !== target) {
          continue;
        }
        const value: Object = map[keys[index]];
        if (typeof value === 'string') {
          return value as string;
        }
        if (Array.isArray(value)) {
          const list: Object[] = value as Object[];
          const parts: string[] = [];
          for (let cursor = 0; cursor < list.length; cursor++) {
            const item: Object = list[cursor];
            if (typeof item === 'string') {
              parts.push(item as string);
            }
          }
          return parts.join('\n');
        }
      }
    } catch (error) {
      return '';
    }
    return '';
  }

  private cookieFromSetCookie(raw: string): string {
    if (raw.length === 0) {
      return '';
    }
    const lines: string[] = raw.split('\n');
    const parts: string[] = [];
    for (let index = 0; index < lines.length; index++) {
      const line: string = lines[index].trim();
      if (line.length === 0) {
        continue;
      }
      const head: string = line.split(';')[0].trim();
      if (head.length === 0) {
        continue;
      }
      const eq: number = head.indexOf('=');
      if (eq <= 0 || eq === head.length - 1) {
        continue;
      }
      const key: string = head.substring(0, eq).toLowerCase();
      if (key === 'path' || key === 'expires' || key === 'domain' || key === 'max-age') {
        continue;
      }
      parts.push(head);
    }
    return parts.join('; ');
  }
}
