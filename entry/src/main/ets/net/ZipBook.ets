import { fileIo as fs } from '@kit.CoreFileKit';
import { zlib } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { t } from '../common/I18n';

const ENTRY_LIMIT: number = 96 * 1024 * 1024;
const DIRECTORY_LIMIT: number = 32 * 1024 * 1024;
const COUNT_LIMIT: number = 50000;
const TAIL_LIMIT: number = 65557;

export interface ZipEntry {
  name: string;
  method: number;
  compressedSize: number;
  size: number;
  offset: number;
  crc: number;
}

const CRC_TABLE: Uint32Array = new Uint32Array(256);
for (let value: number = 0; value < 256; value++) {
  let crc: number = value;
  for (let bit: number = 0; bit < 8; bit++) {
    crc = (crc >>> 1) ^ ((crc & 1) !== 0 ? 0xedb88320 : 0);
  }
  CRC_TABLE[value] = crc >>> 0;
}

function crcOf(bytes: ArrayBuffer): number {
  const values: Uint8Array = new Uint8Array(bytes);
  let crc: number = 0xffffffff;
  for (let index: number = 0; index < values.length; index++) {
    crc = (crc >>> 8) ^ CRC_TABLE[(crc ^ values[index]) & 255];
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function safePath(name: string): boolean {
  if (name.length === 0 || name.startsWith('/') || name.includes('\\') || name.includes('\u0000')) {
    return false;
  }
  if (/^[a-z]:/i.test(name)) {
    return false;
  }
  const parts: string[] = name.split('/');
  for (let index: number = 0; index < parts.length; index++) {
    if (parts[index] === '..' || parts[index] === '.') {
      return false;
    }
  }
  return true;
}

function decodeName(bytes: Uint8Array): string {
  let encoded: string = '';
  for (let index: number = 0; index < bytes.length; index++) {
    encoded += '%' + bytes[index].toString(16).padStart(2, '0');
  }
  try {
    return decodeURIComponent(encoded);
  } catch (error) {
    return '';
  }
}

export class ZipBook {
  private path: string = '';
  private parsed: ZipEntry[] = [];
  private loaded: boolean = false;

  static async open(path: string): Promise<ZipBook> {
    const book: ZipBook = new ZipBook();
    book.path = path;
    await book.list();
    return book;
  }

  private async readRange(offset: number, size: number): Promise<ArrayBuffer> {
    if (offset < 0 || size < 0) {
      throw new Error(t('读取位置越界'));
    }
    const file: fs.File = await fs.open(this.path, fs.OpenMode.READ_ONLY);
    try {
      fs.lseek(file.fd, offset, fs.WhenceType.SEEK_SET);
      const output: Uint8Array = new Uint8Array(size);
      let read: number = 0;
      while (read < size) {
        const chunk: ArrayBuffer = new ArrayBuffer(size - read);
        const count: number = await fs.read(file.fd, chunk);
        if (count <= 0) {
          break;
        }
        output.set(new Uint8Array(chunk, 0, count), read);
        read += count;
      }
      return read === size ? output.buffer as ArrayBuffer : output.slice(0, read).buffer as ArrayBuffer;
    } finally {
      await fs.close(file);
    }
  }

  private async sizeOf(): Promise<number> {
    const file: fs.File = await fs.open(this.path, fs.OpenMode.READ_ONLY);
    try {
      return (await fs.stat(file.fd)).size;
    } finally {
      await fs.close(file);
    }
  }

  async list(): Promise<ZipEntry[]> {
    if (this.loaded) {
      return this.parsed;
    }
    const total: number = await this.sizeOf();
    if (total < 22) {
      throw new Error(t('不是有效的 EPUB 压缩包'));
    }
    const tailSize: number = Math.min(total, TAIL_LIMIT);
    const tail: ArrayBuffer = await this.readRange(total - tailSize, tailSize);
    const view: DataView = new DataView(tail);
    let directoryOffset: number = -1;
    let directorySize: number = 0;
    let count: number = 0;
    for (let offset: number = tail.byteLength - 22; offset >= 0; offset--) {
      if (view.getUint32(offset, true) !== 0x06054b50) {
        continue;
      }
      if (offset + 22 + view.getUint16(offset + 20, true) !== tail.byteLength) {
        continue;
      }
      count = view.getUint16(offset + 10, true);
      directorySize = view.getUint32(offset + 12, true);
      directoryOffset = view.getUint32(offset + 16, true);
      break;
    }
    if (directoryOffset < 0 || count === 0 || count > COUNT_LIMIT || directorySize > DIRECTORY_LIMIT) {
      throw new Error(t('EPUB 目录结构不受支持'));
    }
    const directory: ArrayBuffer = await this.readRange(directoryOffset, directorySize);
    const dirView: DataView = new DataView(directory);
    const entries: ZipEntry[] = [];
    let cursor: number = 0;
    for (let index: number = 0; index < count; index++) {
      if (cursor + 46 > directory.byteLength || dirView.getUint32(cursor, true) !== 0x02014b50) {
        throw new Error(t('EPUB 目录条目损坏'));
      }
      const flags: number = dirView.getUint16(cursor + 8, true);
      const method: number = dirView.getUint16(cursor + 10, true);
      const crc: number = dirView.getUint32(cursor + 16, true);
      const compressedSize: number = dirView.getUint32(cursor + 20, true);
      const size: number = dirView.getUint32(cursor + 24, true);
      const nameLength: number = dirView.getUint16(cursor + 28, true);
      const extraLength: number = dirView.getUint16(cursor + 30, true);
      const commentLength: number = dirView.getUint16(cursor + 32, true);
      const recordSize: number = 46 + nameLength + extraLength + commentLength;
      if (cursor + recordSize > directory.byteLength) {
        throw new Error(t('EPUB 目录条目损坏'));
      }
      const name: string = decodeName(new Uint8Array(directory, cursor + 46, nameLength));
      const start: number = dirView.getUint32(cursor + 42, true);
      cursor += recordSize;
      if (name.length === 0 || name.endsWith('/') || !safePath(name)) {
        continue;
      }
      if ((flags & 0x41) !== 0 || (method !== 0 && method !== 8) ||
        compressedSize > ENTRY_LIMIT || size > ENTRY_LIMIT) {
        continue;
      }
      entries.push({ name: name, method: method, compressedSize: compressedSize, size: size,
        offset: start, crc: crc });
    }
    this.parsed = entries;
    this.loaded = true;
    return entries;
  }

  async has(name: string): Promise<boolean> {
    const list: ZipEntry[] = await this.list();
    for (let index: number = 0; index < list.length; index++) {
      if (list[index].name === name) {
        return true;
      }
    }
    return false;
  }

  async read(name: string): Promise<ArrayBuffer> {
    const list: ZipEntry[] = await this.list();
    let target: ZipEntry | undefined = undefined;
    for (let index: number = 0; index < list.length; index++) {
      if (list[index].name === name) {
        target = list[index];
        break;
      }
    }
    if (target === undefined) {
      throw new Error(`EPUB 内没有 ${name}`);
    }
    const header: DataView = new DataView(await this.readRange(target.offset, 30));
    if (header.byteLength < 30 || header.getUint32(0, true) !== 0x04034b50) {
      throw new Error(t('EPUB 条目头损坏'));
    }
    const dataOffset: number = target.offset + 30 + header.getUint16(26, true) + header.getUint16(28, true);
    const input: ArrayBuffer = await this.readRange(dataOffset, target.compressedSize);
    const output: ArrayBuffer = target.method === 0 ? input : await this.inflate(input, target.size);
    if (output.byteLength !== target.size || crcOf(output) !== target.crc) {
      throw new Error(t('EPUB 条目校验失败'));
    }
    return output;
  }

  async text(name: string): Promise<string> {
    const bytes: ArrayBuffer = await this.read(name);
    return util.TextDecoder.create('utf-8', { ignoreBOM: true })
      .decodeToString(new Uint8Array(bytes), { stream: false });
  }

  private async inflate(input: ArrayBuffer, size: number): Promise<ArrayBuffer> {
    const zip: zlib.Zip = await zlib.createZip();
    const buffer: ArrayBuffer = new ArrayBuffer(size + 1);
    const stream: zlib.ZStream = {
      nextIn: input,
      availableIn: input.byteLength,
      nextOut: buffer,
      availableOut: buffer.byteLength
    };
    await zip.inflateInit2(stream, -15);
    try {
      const status: number = await zip.inflate(stream, zlib.CompressFlushMode.FINISH);
      if (status !== zlib.ReturnStatus.STREAM_END && status !== zlib.ReturnStatus.OK) {
        throw new Error(t('EPUB 条目解压失败'));
      }
      return buffer.slice(0, size);
    } finally {
      await zip.inflateEnd(stream);
    }
  }
}
