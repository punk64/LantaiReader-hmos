import { promptAction } from '@kit.ArkUI';
import { fileUri } from '@kit.CoreFileKit';
import { C, R, S } from '../common/Theme';
import { F } from '../common/Format';
import { Chip } from '../components/BookViews';
import { CoverImage } from '../components/CoverImage';
import { ActionBtn, GroupHead, NoteCard, Pill, ScreenHead } from '../components/Shell';
import { appStore } from '../model/AppStore';
import { LocalBook, LocalLibrary } from '../net/LocalLibrary';
import { ArchiveBook, ComicArchive, comicArchive } from '../net/ComicArchive';
import { LocalMetas, LocalMeta, localKindOf, localMetas } from '../net/LocalMeta';
import { LocalStore } from '../net/LocalStore';
import { LocalFiles } from '../net/LocalFiles';
import { localBookSource } from '../net/LocalBookSource';

import { t } from '../common/I18n';
interface StepItem {
  index: string;
  title: string;
  sub: string;
}

const FORMATS: string[] = ['EPUB', 'TXT', 'CBZ / CBR / CB7', 'PDF', 'KEPUB'];

function steps(): StepItem[] {
  return [
    { index: '1', title: t('识别文件与编码'), sub: t('只读文件头，不改原文件') },
    { index: '2', title: t('建立章节 / 页索引'), sub: t('索引写入数据库，可随时重建') },
    { index: '3', title: t('生成封面与元数据'), sub: t('失败不阻断，稍后可补') }
  ];
}

@Component
export struct ImportPage {
  @StorageLink('uiTick') uiTick: number = 0;
  @Consume('nav') nav: NavPathStack;
  @State books: LocalBook[] = [];
  @State missing: string[] = [];
  @State busy: boolean = false;
  @State archiving: boolean = false;

  aboutToAppear(): void {
    this.books = appStore.localBooks;
    this.missing = appStore.localMissing;
  }

  private usedBytes(): number {
    let total: number = 0;
    for (let index: number = 0; index < this.books.length; index++) {
      total += this.books[index].size;
    }
    return total;
  }

  private isMissing(book: LocalBook): boolean {
    return this.missing.includes(LocalMetas.idOf(book.uri));
  }

  private extOf(name: string): string {
    const dot: number = name.lastIndexOf('.');
    return dot > 0 ? name.substring(dot + 1).toUpperCase() : 'FILE';
  }

  private titleOf(name: string): string {
    const dot: number = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  private subOf(book: LocalBook): string {
    const kind: string = ComicArchive.isReadable(book.name)
      ? t('漫画')
      : (localKindOf(book.name).length > 0 ? t('文档') : t('待接入阅读器'));
    const size: string = book.size > 0 ? ` · ${F.bytes(book.size)}` : '';
    return `${this.extOf(book.name)} ${kind}${size}`;
  }

  private merge(incoming: LocalBook[]): void {
    const merged: LocalBook[] = [];
    for (let index: number = 0; index < incoming.length; index++) {
      merged.push(incoming[index]);
    }
    for (let index: number = 0; index < appStore.localBooks.length; index++) {
      const current: LocalBook = appStore.localBooks[index];
      let exists: boolean = false;
      for (let inner: number = 0; inner < merged.length; inner++) {
        if (merged[inner].uri === current.uri) {
          exists = true;
          break;
        }
      }
      if (!exists) {
        merged.push(current);
      }
    }
    appStore.localBooks = merged;
    this.books = merged;
    if (appStore.localRoot.length === 0) {
      appStore.localRoot = 'picked';
      LocalStore.persistRoot('picked');
    }
    LocalStore.persistBooks(incoming, appStore.localRoot).then(() => {
      this.enrichAll(incoming);
    });
  }

  private async enrichAll(books: LocalBook[]): Promise<void> {
    for (let index: number = 0; index < books.length; index++) {
      try {
        const meta: LocalMeta = await localMetas.enrich(books[index]);
        for (let at: number = 0; at < appStore.localMetas.length; at++) {
          if (appStore.localMetas[at].id === meta.id) {
            meta.chapter = appStore.localMetas[at].chapter;
            meta.progress = appStore.localMetas[at].progress;
            break;
          }
        }
        appStore.localMetas = appStore.localMetas.filter((item: LocalMeta) => item.id !== meta.id).concat([meta]);
        await LocalStore.save(meta, appStore.localRoot);
      } catch (error) {
      }
    }
  }

  private async pickMany(): Promise<void> {
    if (this.busy) {
      return;
    }
    const context: Context | undefined = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    if (!LocalLibrary.supportsFiles()) {
      promptAction.showToast({ message: t('当前系统不支持文件选择') });
      return;
    }
    this.busy = true;
    let failed: number = 0;
    try {
      const uris: string[] = await LocalLibrary.pickFiles(context);
      if (uris.length === 0) {
        this.busy = false;
        return;
      }
      const picked: LocalBook[] = [];
      const filesDir: string = context.filesDir;
      for (let index: number = 0; index < uris.length; index++) {
        const name: string = new fileUri.FileUri(uris[index]).name;
        if (!LocalLibrary.isBook(name)) {
          continue;
        }
        let uri: string = '';
        try {
          uri = await LocalFiles.importFile(filesDir, uris[index], name);
        } catch (error) {
          failed++;
          continue;
        }
        picked.push({ name: name, uri: uri, size: await LocalFiles.statSize(uri) });
      }
      if (picked.length === 0) {
        promptAction.showToast({
          message: failed > 0 ? t('导入失败，文件未能复制到应用内') : t('所选文件中没有可识别的书籍格式')
        });
        this.busy = false;
        return;
      }
      this.merge(picked);
      promptAction.showToast({
        message: failed > 0 ? t(`已导入 ${picked.length} 本，失败 ${failed} 本`) : t(`已导入 ${picked.length} 本`)
      });
    } catch (error) {
      promptAction.showToast({ message: t(`导入失败：${(error as Error).message}`) });
    }
    this.busy = false;
  }

  private async pickDir(): Promise<void> {
    if (this.busy) {
      return;
    }
    const context: Context | undefined = this.getUIContext().getHostContext();
    if (context === undefined) {
      return;
    }
    if (!LocalLibrary.supportsFolders()) {
      promptAction.showToast({ message: t('当前系统不支持文件夹授权，请用多选文件导入') });
      return;
    }
    this.busy = true;
    try {
      const uri: string = await LocalLibrary.pickFolder(context);
      if (uri.length === 0) {
        this.busy = false;
        return;
      }
      await LocalLibrary.authorize(uri);
      const scanned: LocalBook[] = await LocalLibrary.scan(uri);
      const found: LocalBook[] = await LocalLibrary.adopt(context, scanned);
      if (found.length === 0) {
        promptAction.showToast({ message: t('这个文件夹里没有可识别的书籍') });
        this.busy = false;
        return;
      }
      appStore.localRoot = uri;
      this.merge(found);
      promptAction.showToast({ message: t(`扫描到 ${found.length} 本`) });
    } catch (error) {
      promptAction.showToast({ message: t(`扫描失败：${(error as Error).message}`) });
    }
    this.busy = false;
  }

  private async open(book: LocalBook): Promise<void> {
    if (this.archiving) {
      return;
    }
    if (this.isMissing(book)) {
      promptAction.showToast({ message: t('文件已缺失，请重新导入') });
      return;
    }
    if (ComicArchive.isReadable(book.name)) {
      this.archiving = true;
      try {
        const opened: ArchiveBook = await comicArchive.open(LocalLibrary.toPath(book.uri), book.name, book.size);
        const meta: LocalMeta | null = this.metaOf(book.uri);
        appStore.localArchive = opened;
        appStore.localArchiveId = LocalMetas.idOf(book.uri);
        appStore.localArchivePage = meta !== null && meta.chapter > 0 ? meta.chapter : 1;
        this.nav.pushPathByName('comic', null);
      } catch (error) {
        promptAction.showToast({ message: t(`打开失败：${(error as Error).message}`) });
      }
      this.archiving = false;
      return;
    }
    const meta: LocalMeta | null = this.metaOf(book.uri);
    if (meta === null) {
      promptAction.showToast({ message: t('这本书还没有完成解析') });
      return;
    }
    const blocked: string = await localBookSource.preflight(meta.id);
    if (blocked.length > 0) {
      promptAction.showToast({ message: t(blocked) });
      return;
    }
    appStore.readerBookId = meta.id;
    appStore.readerTitle = meta.title.length > 0 ? meta.title : meta.name;
    appStore.readerChapter = meta.chapter > 0 ? meta.chapter : 1;
    appStore.readerIncognito = false;
    this.nav.pushPathByName('reader', null);
  }

  private metaOf(uri: string): LocalMeta | null {
    for (let index: number = 0; index < appStore.localMetas.length; index++) {
      if (appStore.localMetas[index].uri === uri) {
        return appStore.localMetas[index];
      }
    }
    return null;
  }

  private async removeBook(book: LocalBook): Promise<void> {
    const confirm: promptAction.ShowDialogSuccessResponse = await promptAction.showDialog({
      title: t('移除本地书'),
      message: t(`确定移除《${this.titleOf(book.name)}》？应用内副本与封面会一并删除。`),
      buttons: [
        { text: t('取消'), color: C.tx3 },
        { text: t('移除'), color: C.bad }
      ]
    });
    if (confirm.index !== 1) {
      return;
    }
    const meta: LocalMeta | null = this.metaOf(book.uri);
    if (meta !== null) {
      await LocalStore.remove(meta);
    }
    const books: LocalBook[] = [];
    for (let index: number = 0; index < this.books.length; index++) {
      if (this.books[index].uri !== book.uri) {
        books.push(this.books[index]);
      }
    }
    this.books = books;
    appStore.localBooks = books;
    appStore.localMetas = appStore.localMetas.filter((item: LocalMeta) => item.uri !== book.uri);
    appStore.localMissing = appStore.localMissing.filter((id: string) => id !== LocalMetas.idOf(book.uri));
    this.missing = appStore.localMissing;
    if (books.length === 0) {
      appStore.localRoot = '';
      await LocalStore.persistRoot('');
    }
    promptAction.showToast({ message: t('已移除') });
  }

  private async purgeAll(): Promise<void> {
    if (this.books.length === 0) {
      return;
    }
    const confirm: promptAction.ShowDialogSuccessResponse = await promptAction.showDialog({
      title: t('清理全部本地书'),
      message: t(`将删除 ${this.books.length} 条记录、应用内副本与封面，共 ${F.bytes(this.usedBytes())}。授权目录中的原文件不会被删除。`),
      buttons: [
        { text: t('取消'), color: C.tx3 },
        { text: t('清理'), color: C.bad }
      ]
    });
    if (confirm.index !== 1) {
      return;
    }
    await LocalStore.purgeAll(appStore.localMetas, appStore.localRoot);
    appStore.localBooks = [];
    appStore.localMetas = [];
    appStore.localMissing = [];
    appStore.localRoot = '';
    appStore.localRootStale = false;
    this.books = [];
    this.missing = [];
    promptAction.showToast({ message: t('已清理全部本地书') });
  }

  @Builder
  pickCard() {
    Column({ space: 4 }) {
      Text(t('导'))
        .fontSize(20)
        .fontColor(C.acc2)
        .textAlign(TextAlign.Center)
        .width(52)
        .height(52)
        .backgroundColor(C.accBg)
        .borderRadius(16)
        .border({ width: 1, color: C.accLine })

      Text(this.busy ? t('选择文件中…') : t('从手机文件里选书'))
        .fontSize(15.5)
        .fontColor(C.tx)
        .letterSpacing(0.8)
        .margin({ top: 9 })

      Text(t('文件可多选，也可整个文件夹导入'))
        .fontSize(9.5)
        .fontColor(C.tx4)
        .margin({ top: 5 })
      Text(t('选中的文件会复制一份到应用内，原文件删除后仍可阅读'))
        .fontSize(9.5)
        .fontColor(C.tx4)

      Row({ space: 10 }) {
        ActionBtn({
          label: t('选择文件 · 多选'),
          primary: true,
          glyph: 'book',
          onTap: () => {
            this.pickMany();
          }
        })
        ActionBtn({
          label: t('选择文件夹'),
          glyph: 'folder',
          onTap: () => {
            this.pickDir();
          }
        })
      }
      .width('100%')
      .margin({ top: 14 })

      Text(t('选文件夹需要系统文件选择器授权，授权后可递归扫描子目录'))
        .fontSize(9)
        .fontColor(C.tx4)
        .textAlign(TextAlign.Center)
        .margin({ top: 9 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 24, bottom: 20 })
    .backgroundColor(C.bg1)
    .borderRadius(R.m)
    .border({ width: 1, color: C.accLine, style: BorderStyle.Dashed })
  }

  build() {
    Column() {
      ScreenHead({
        title: t('导入本地文件'),
        sub: this.books.length > 0
          ? t(`已导入 ${this.books.length} 本 · 占用 ${F.bytes(this.usedBytes())}`)
          : t('导入后复制到应用内，不上传'),
        back: t('我的'),
        onBack: () => {
          this.nav.pop();
        }
      })

      Scroll() {
        Column() {
          this.pickCard()

          GroupHead({ title: t('支持的格式') })
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(FORMATS, (label: string) => {
              Chip({ label: label, active: false, onTap: () => {} })
                .margin({ right: 6, bottom: 6 })
            }, (label: string) => label)
          }
          .width('100%')

          NoteCard({ text: t('MOBI / AZW3 / FB2 等格式需服务端安装可选转换组件；未安装时书籍仍可见、可下载、可记进度。') })
            .margin({ top: 12 })

          GroupHead({ title: t('导入流程'), meta: t('3 步') })
          Column() {
            ForEach(steps(), (item: StepItem) => {
              Row({ space: 11 }) {
                Text(item.index)
                  .fontSize(10.5)
                  .fontColor(C.acc2)
                  .textAlign(TextAlign.Center)
                  .width(26)
                  .height(26)
                  .backgroundColor(C.accBg)
                  .borderRadius(8)
                Column({ space: 2 }) {
                  Text(item.title)
                    .fontSize(12.5)
                    .fontColor(C.tx)
                    .width('100%')
                  Text(item.sub)
                    .fontSize(10)
                    .fontColor(C.tx4)
                    .maxLines(1)
                    .width('100%')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Pill({ label: t('完成'), tone: 'done' })
              }
              .width('100%')
              .padding({ top: 10, bottom: 10 })
              .alignItems(VerticalAlign.Center)
            }, (item: StepItem) => item.index)
          }
          .width('100%')
          .padding({ left: 13, right: 13 })
          .backgroundColor(C.bg1)
          .borderRadius(R.m)
          .border({ width: 1, color: C.line })

          GroupHead({
            title: t('已导入'),
            meta: this.books.length > 0
              ? `${this.books.length} 册 · ${F.bytes(this.usedBytes())}`
              : t('暂无'),
            action: this.books.length > 0 ? t('清理全部') : '',
            onAction: () => {
              this.purgeAll();
            }
          })
          Column() {
            if (this.books.length === 0) {
              Column({ space: 6 }) {
                Text(t('还没有导入任何文件'))
                  .fontSize(12)
                  .fontColor(C.tx2)
                Text(t('点上方「选择文件 · 多选」开始，导入的记录会保存在本机'))
                  .fontSize(10)
                  .fontColor(C.tx4)
                  .textAlign(TextAlign.Center)
              }
              .width('100%')
              .padding({ top: 26, bottom: 26 })
              .alignItems(HorizontalAlign.Center)
            } else {
              ForEach(this.books, (item: LocalBook, index: number) => {
                Row({ space: 12 }) {
                  CoverImage({
                    bookId: '',
                    title: this.titleOf(item.name).substring(0, 1),
                    coverWidth: 42,
                    coverHeight: 60,
                    radius: 4
                  })
                  Column({ space: 3 }) {
                    Text(this.titleOf(item.name))
                      .fontSize(12.5)
                      .fontColor(C.tx)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%')
                    Text(item.name)
                      .fontSize(10)
                      .fontColor(C.tx4)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%')
                    Text(this.subOf(item))
                      .fontSize(9.5)
                      .fontColor(C.tx4)
                      .width('100%')
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  if (this.isMissing(item)) {
                    Text(t('缺失'))
                      .fontSize(9)
                      .fontColor(C.bad)
                      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                      .backgroundColor(C.bg2)
                      .borderRadius(5)
                  }
                  Text(t('移除'))
                    .fontSize(10.5)
                    .fontColor(C.tx3)
                    .padding({ left: 9, right: 9, top: 5, bottom: 5 })
                    .backgroundColor(C.bg2)
                    .borderRadius(7)
                    .onClick(() => {
                      this.removeBook(item);
                    })
                }
                .width('100%')
                .padding({ top: 10, bottom: 10 })
                .onClick(() => {
                  this.open(item);
                })
              }, (item: LocalBook, index: number) => `${index}-${item.uri}-${item.size}-${this.isMissing(item) ? 1 : 0}`)
            }
          }
          .width('100%')
          .padding({ left: 13, right: 13 })
          .backgroundColor(C.bg1)
          .borderRadius(R.m)
          .border({ width: 1, color: C.line })

          Blank().height(28)
        }
        .width('100%')
        .padding({ left: S.page, right: S.page })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
  }
}
