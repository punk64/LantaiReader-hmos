import { connection, http } from '@kit.NetworkKit';

export interface LanHit {
  origin: string;
  host: string;
  scheme: string;
  port: number;
}

const PROBE_PATH: string = '/api/v1/oauth2/providers';
const ME_PATH: string = '/api/v2/users/me';
const CONCURRENCY: number = 32;
const PLAIN_TIMEOUT: number = 900;
const TLS_TIMEOUT: number = 1800;
const DEFAULT_PORT: number = 25600;

export class LanScan {
  static defaultPort(): number {
    return DEFAULT_PORT;
  }

  static schemeOf(origin: string): string {
    return origin.startsWith('https://') ? 'https' : 'http';
  }

  static originOf(scheme: string, host: string, port: number): string {
    return `${scheme}://${host}:${port}`;
  }

  static hostOf(origin: string): string {
    return origin.replace('http://', '').replace('https://', '');
  }

  static isPrivate(origin: string): boolean {
    if (origin.length === 0) {
      return false;
    }
    const host: string = LanScan.hostOf(origin).split(':')[0];
    const parts: string[] = host.split('.');
    if (parts.length !== 4) {
      return false;
    }
    for (let index: number = 0; index < parts.length; index++) {
      const value: number = parseInt(parts[index], 10);
      if (isNaN(value) || value < 0 || value > 255) {
        return false;
      }
    }
    if (parts[0] === '10') {
      return true;
    }
    if (parts[0] === '192' && parts[1] === '168') {
      return true;
    }
    if (parts[0] === '172') {
      const second: number = parseInt(parts[1], 10);
      return second >= 16 && second <= 31;
    }
    return false;
  }

  static async probe(origin: string): Promise<boolean> {
    const tls: boolean = origin.startsWith('https://');
    const request: http.HttpRequest = http.createHttp();
    try {
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: tls ? TLS_TIMEOUT : PLAIN_TIMEOUT,
        readTimeout: tls ? TLS_TIMEOUT : PLAIN_TIMEOUT,
        usingCache: false,
        header: { 'Accept': 'application/json' }
      };
      const response: http.HttpResponse = await request.request(`${origin}${PROBE_PATH}`, options);
      const code: number = response.responseCode;
      return code === 200 || code === 401 || code === 403;
    } catch (error) {
      return false;
    } finally {
      request.destroy();
    }
  }

  static async ping(origin: string, cookie: string): Promise<boolean> {
    const request: http.HttpRequest = http.createHttp();
    try {
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 2500,
        readTimeout: 2500,
        usingCache: false,
        header: { 'Accept': 'application/json', 'Cookie': cookie }
      };
      const response: http.HttpResponse = await request.request(`${origin}${ME_PATH}`, options);
      return response.responseCode === 200;
    } catch (error) {
      return false;
    } finally {
      request.destroy();
    }
  }

  private static headOf(links: connection.LinkAddress[]): string {
    for (let index: number = 0; index < links.length; index++) {
      const address: connection.NetAddress = links[index].address;
      if (address.family !== 1) {
        continue;
      }
      const ip: string = address.address;
      if (ip.startsWith('127.') || ip.startsWith('169.254.')) {
        continue;
      }
      if (ip.split('.').length === 4) {
        return ip;
      }
    }
    return '';
  }

  private static async lanIp(): Promise<string> {
    try {
      const nets: connection.NetHandle[] = await connection.getAllNets();
      for (let index: number = 0; index < nets.length; index++) {
        const caps: connection.NetCapabilities = await connection.getNetCapabilities(nets[index]);
        const types: connection.NetBearType[] = caps.bearerTypes;
        let wired: boolean = false;
        for (let t: number = 0; t < types.length; t++) {
          if (types[t] === connection.NetBearType.BEARER_WIFI ||
            types[t] === connection.NetBearType.BEARER_ETHERNET) {
            wired = true;
          }
        }
        if (!wired) {
          continue;
        }
        const props: connection.ConnectionProperties =
          await connection.getConnectionProperties(nets[index]);
        const ip: string = LanScan.headOf(props.linkAddresses);
        if (ip.length > 0) {
          return ip;
        }
      }
    } catch (error) {
    }
    try {
      const net: connection.NetHandle = await connection.getDefaultNet();
      const props: connection.ConnectionProperties = await connection.getConnectionProperties(net);
      return LanScan.headOf(props.linkAddresses);
    } catch (error) {
      return '';
    }
  }

  static async localAddress(): Promise<string> {
    return LanScan.lanIp();
  }

  private static async sweep(hosts: string[], scheme: string, port: number): Promise<LanHit[]> {
    const hits: LanHit[] = [];
    let cursor: number = 0;
    while (cursor < hosts.length) {
      const batch: string[] = hosts.slice(cursor, cursor + CONCURRENCY);
      cursor += CONCURRENCY;
      const tasks: Promise<boolean>[] = [];
      for (let index: number = 0; index < batch.length; index++) {
        tasks.push(LanScan.probe(LanScan.originOf(scheme, batch[index], port)));
      }
      const results: boolean[] = await Promise.all(tasks);
      for (let index: number = 0; index < batch.length; index++) {
        if (results[index]) {
          hits.push({
            origin: LanScan.originOf(scheme, batch[index], port),
            host: batch[index],
            scheme: scheme,
            port: port
          });
        }
      }
      if (hits.length > 0) {
        return hits;
      }
    }
    return hits;
  }

  static async scan(ports: number[], schemes: string[]): Promise<LanHit[]> {
    const ip: string = await LanScan.lanIp();
    if (ip.length === 0) {
      return [];
    }
    const parts: string[] = ip.split('.');
    if (parts.length !== 4) {
      return [];
    }
    const head: string = `${parts[0]}.${parts[1]}.${parts[2]}`;
    const hosts: string[] = [];
    for (let index: number = 1; index <= 254; index++) {
      hosts.push(`${head}.${index}`);
    }
    for (let s: number = 0; s < schemes.length; s++) {
      for (let p: number = 0; p < ports.length; p++) {
        const hits: LanHit[] = await LanScan.sweep(hosts, schemes[s], ports[p]);
        if (hits.length > 0) {
          return hits;
        }
      }
    }
    return [];
  }
}
