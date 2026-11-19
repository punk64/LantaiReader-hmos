import { fileIo as fs, fileUri } from '@kit.CoreFileKit';

export class LocalFiles {
  static pathOf(uri: string): string {
    if (!uri.startsWith('file://')) {
      return uri;
    }
    try {
      return new fileUri.FileUri(uri).path;
    } catch (error) {
      return uri;
    }
  }
  static ensureDir(dir: string): void {
    if (dir.length === 0) {
      return;
    }
    try {
      if (fs.accessSync(dir)) {
        return;
      }
    } catch (error) {
    }
    try {
      fs.mkdirSync(dir, true);
    } catch (error) {
    }
  }

  static async exists(path: string): Promise<boolean> {
    try {
      return (await fs.stat(path)).size > 0;
    } catch (error) {
      return false;
    }
  }

  static existsSync(path: string): boolean {
    if (path.length === 0) {
      return false;
    }
    try {
      return fs.accessSync(path);
    } catch (error) {
      return false;
    }
  }

  static async statSize(path: string): Promise<number> {
    try {
      return (await fs.stat(path)).size;
    } catch (error) {
      return 0;
    }
  }

  static async removeFile(path: string): Promise<void> {
    if (path.length === 0) {
      return;
    }
    try {
      if (fs.accessSync(path)) {
        await fs.unlink(path);
      }
    } catch (error) {
    }
  }

  static async removeTree(path: string): Promise<void> {
    if (path.length === 0) {
      return;
    }
    try {
      if (fs.accessSync(path)) {
        await fs.rmdir(path);
      }
    } catch (error) {
    }
  }

  static async removeImport(uri: string, filesRoot: string): Promise<void> {
    if (filesRoot.length === 0) {
      return;
    }
    const prefix: string = `file://${filesRoot}/imports/`;
    if (!uri.startsWith(prefix)) {
      return;
    }
    const rest: string = uri.substring(prefix.length);
    const slash: number = rest.indexOf('/');
    if (slash <= 0) {
      return;
    }
    await LocalFiles.removeTree(`${filesRoot}/imports/${rest.substring(0, slash)}`);
  }

  static async copyInto(uri: string, target: string): Promise<void> {
    if (await LocalFiles.exists(target)) {
      return;
    }
    const parent: string = target.substring(0, target.lastIndexOf('/'));
    LocalFiles.ensureDir(parent);
    const source: fs.File = fs.openSync(LocalFiles.pathOf(uri), fs.OpenMode.READ_ONLY);
    try {
      await fs.copyFile(source.fd, `${target}.part`);
      await fs.rename(`${target}.part`, target);
    } finally {
      fs.closeSync(source);
    }
  }

  static stableId(text: string): string {
    let hash: number = 5381;
    for (let index: number = 0; index < text.length; index++) {
      hash = ((hash << 5) + hash + text.charCodeAt(index)) & 0x7fffffff;
    }
    return hash.toString(36);
  }

  static async importFile(filesDir: string, uri: string, name: string): Promise<string> {
    const dir: string = `${filesDir}/imports/${LocalFiles.stableId(uri)}`;
    const target: string = `${dir}/${name}`;
    LocalFiles.ensureDir(dir);
    await LocalFiles.copyInto(uri, target);
    return `file://${target}`;
  }
}
