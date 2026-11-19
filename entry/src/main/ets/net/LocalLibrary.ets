import { fileIo as fs, fileShare, fileUri, picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { LocalFiles } from './LocalFiles';


export interface LocalBook {
  name: string;
  uri: string;
  size: number;
}

const BOOK_EXT: string[] = ['epub', 'kepub', 'txt', 'pdf', 'zip', 'cbz', 'rar', 'cbr', '7z', 'cb7', 'mobi', 'azw3'];

export class LocalLibrary {
  static supportsFolders(): boolean {
    return canIUse('SystemCapability.FileManagement.UserFileService.FolderSelection')
      && canIUse('SystemCapability.FileManagement.UserFileService');
  }

  static supportsFiles(): boolean {
    return canIUse('SystemCapability.FileManagement.UserFileService');
  }

  static isBook(name: string): boolean {
    const dot: number = name.lastIndexOf('.');
    if (dot < 1) {
      return false;
    }
    const ext: string = name.substring(dot + 1).toLowerCase();
    return BOOK_EXT.includes(ext);
  }

  static async pickFolder(context: common.Context): Promise<string> {
    const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
    options.selectMode = picker.DocumentSelectMode.FOLDER;
    options.maxSelectNumber = 1;
    const view: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
    const uris: string[] = await view.select(options);
    return uris.length > 0 ? uris[0] : '';
  }

  static async pickFiles(context: common.Context): Promise<string[]> {
    const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
    options.maxSelectNumber = 100;
    const view: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
    return await view.select(options);
  }

  static toPath(uri: string): string {
    return uri.startsWith('file://') ? new fileUri.FileUri(uri).path : uri;
  }

  static async authorize(uri: string): Promise<void> {
    const policy: fileShare.PolicyInfo = {
      uri: uri,
      operationMode: fileShare.OperationMode.READ_MODE
    };
    await fileShare.persistPermission([policy]);
  }

  static async renew(uri: string): Promise<void> {
    const policy: fileShare.PolicyInfo = {
      uri: uri,
      operationMode: fileShare.OperationMode.READ_MODE
    };
    await fileShare.activatePermission([policy]);
  }

  static async revoke(uri: string): Promise<void> {
    const policy: fileShare.PolicyInfo = {
      uri: uri,
      operationMode: fileShare.OperationMode.READ_MODE
    };
    await fileShare.revokePermission([policy]);
  }

  private static async walk(root: string, relative: string,
    result: LocalBook[], depth: number): Promise<void> {
    if (depth > 32 || result.length > 20000) {
      return;
    }
    const path: string = relative.length === 0 ? root : `${root}/${relative}`;
    let names: string[] = [];
    try {
      names = await fs.listFile(path);
    } catch (error) {
      return;
    }
    for (let index: number = 0; index < names.length; index++) {
      const name: string = names[index];
      if (name === '.' || name === '..' || name.includes('/') || name.includes('\\')) {
        continue;
      }
      const childRelative: string = relative.length === 0 ? name : `${relative}/${name}`;
      const child: string = `${root}/${childRelative}`;
      let info: fs.Stat;
      try {
        info = await fs.lstat(child);
      } catch (error) {
        continue;
      }
      if (info.isSymbolicLink()) {
        continue;
      }
      if (info.isDirectory()) {
        await LocalLibrary.walk(root, childRelative, result, depth + 1);
      } else if (info.isFile() && LocalLibrary.isBook(name)) {
        result.push({ name: name, uri: fileUri.getUriFromPath(child), size: info.size });
      }
    }
  }

  static async scan(rootUri: string): Promise<LocalBook[]> {
    const out: LocalBook[] = [];
    await LocalLibrary.walk(LocalLibrary.toPath(rootUri), '', out, 0);
    return out;
  }

  static async adopt(context: common.Context, books: LocalBook[]): Promise<LocalBook[]> {
    const out: LocalBook[] = [];
    const prefix: string = `file://${context.filesDir}/imports/`;
    for (let index: number = 0; index < books.length; index++) {
      const book: LocalBook = books[index];
      let uri: string = book.uri;
      if (!book.uri.startsWith(prefix)) {
        try {
          uri = await LocalFiles.importFile(context.filesDir, book.uri, book.name);
        } catch (error) {
          uri = book.uri;
        }
      }
      out.push({ name: book.name, uri: uri, size: book.size });
    }
    return out;
  }
}
