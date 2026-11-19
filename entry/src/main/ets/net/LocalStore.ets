import { fileIo as fs } from '@kit.CoreFileKit';
import { Prefs } from '../model/Prefs';
import { appStore } from '../model/AppStore';
import { offlineDb } from '../data/OfflineDb';
import { LocalBook, LocalLibrary } from './LocalLibrary';
import { LocalMeta, LocalMetas } from './LocalMeta';
import { LocalFiles } from './LocalFiles';
import { localBookSource } from './LocalBookSource';

const KEY_ROOT: string = 'localRoot';
const PICKED: string = 'picked';

export interface LocalRestore {
  root: string;
  books: LocalBook[];
  metas: LocalMeta[];
  missing: string[];
  stale: boolean;
}

export class LocalStore {
  static async restore(): Promise<LocalRestore> {
    const root: string = Prefs.read(KEY_ROOT);
    const saved: LocalMeta[] = await offlineDb.locals();
    localBookSource.setMetas(saved);
    if (saved.length === 0) {
      return { root: root, books: [], metas: [], missing: [], stale: false };
    }
    let stale: boolean = false;
    if (root.length > 0 && root !== PICKED) {
      try {
        await LocalLibrary.renew(root);
        stale = !fs.accessSync(LocalLibrary.toPath(root));
      } catch (error) {
        stale = true;
      }
    }
    const books: LocalBook[] = [];
    const missing: string[] = [];
    for (let index: number = 0; index < saved.length; index++) {
      const meta: LocalMeta = saved[index];
      books.push({ name: meta.name, uri: meta.uri, size: meta.sizeBytes });
      if (!LocalFiles.existsSync(LocalLibrary.toPath(meta.uri))) {
        missing.push(meta.id);
      }
    }
    return { root: root, books: books, metas: saved, missing: missing, stale: stale };
  }

  static async persistRoot(uri: string): Promise<void> {
    await Prefs.write(KEY_ROOT, uri);
  }

  static async persist(metas: LocalMeta[], root: string): Promise<void> {
    await offlineDb.saveLocals(metas, root);
    localBookSource.setMetas(metas);
  }

  static async persistBooks(books: LocalBook[], root: string): Promise<void> {
    const seeds: LocalMeta[] = [];
    const fresh: Set<string> = new Set<string>();
    for (let index: number = 0; index < books.length; index++) {
      const seed: LocalMeta = LocalMetas.seed(books[index]);
      for (let at: number = 0; at < appStore.localMetas.length; at++) {
        if (appStore.localMetas[at].id === seed.id) {
          seed.chapter = appStore.localMetas[at].chapter;
          seed.progress = appStore.localMetas[at].progress;
          break;
        }
      }
      seeds.push(seed);
      fresh.add(seed.id);
    }
    await offlineDb.saveLocals(seeds, root);
    const merged: LocalMeta[] = [];
    for (let index: number = 0; index < appStore.localMetas.length; index++) {
      const current: LocalMeta = appStore.localMetas[index];
      if (!fresh.has(current.id)) {
        merged.push(current);
      }
    }
    for (let index: number = 0; index < seeds.length; index++) {
      merged.push(seeds[index]);
    }
    appStore.localMetas = merged;
    localBookSource.setMetas(merged);
  }

  static async save(meta: LocalMeta, root: string): Promise<void> {
    await offlineDb.saveLocal(meta, root);
    localBookSource.setMetas(appStore.localMetas);
  }

  static async saveProgress(id: string, chapter: number, progress: number): Promise<void> {
    await offlineDb.patchLocalProgress(id, chapter, progress);
    for (let index: number = 0; index < appStore.localMetas.length; index++) {
      if (appStore.localMetas[index].id === id) {
        appStore.localMetas[index].chapter = chapter;
        appStore.localMetas[index].progress = progress;
        break;
      }
    }
  }

  static async remove(meta: LocalMeta): Promise<void> {
    await LocalStore.release(meta);
    await offlineDb.removeLocal(meta.id);
  }

  static async purgeAll(metas: LocalMeta[], root: string): Promise<number> {
    let freed: number = 0;
    for (let index: number = 0; index < metas.length; index++) {
      await LocalStore.release(metas[index]);
      freed += metas[index].sizeBytes;
    }
    await LocalStore.clear();
    localBookSource.releaseAll();
    if (root.length > 0 && root !== PICKED) {
      try {
        await LocalLibrary.revoke(root);
      } catch (error) {
      }
    }
    return freed;
  }

  private static async release(meta: LocalMeta): Promise<void> {
    const filesRoot: string = LocalMetas.filesRoot();
    localBookSource.forget(meta.id);
    await localBookSource.dropPages(meta.id);
    await LocalFiles.removeFile(LocalMetas.coverOf(meta.uri));
    await LocalFiles.removeTree(LocalMetas.dirOf(meta.uri));
    await LocalFiles.removeImport(meta.uri, filesRoot);
    LocalMetas.forget(meta.id);
    if (!meta.uri.startsWith('file://') || meta.uri.startsWith(`file://${filesRoot}/`)) {
      return;
    }
    try {
      await LocalLibrary.revoke(meta.uri);
    } catch (error) {
    }
  }

  static async clear(): Promise<void> {
    await offlineDb.clearLocals();
    await Prefs.write(KEY_ROOT, '');
  }
}
