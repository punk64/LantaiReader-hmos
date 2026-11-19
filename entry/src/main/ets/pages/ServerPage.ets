import { promptAction } from '@kit.ArkUI';
import { connection } from '@kit.NetworkKit';
import { C, FT, R, S } from '../common/Theme';
import { appStore } from '../model/AppStore';
import { Prefs } from '../model/Prefs';
import { ServerProfile, ServerProfiles } from '../model/ServerProfile';
import { LanHit, LanScan } from '../net/LanScan';
import { AutoSwitch } from '../net/AutoSwitch';
import { GlyphIcon } from '../components/Icon';
import { ActionBtn, GroupHead, NoteCard, Pill, ScreenHead } from '../components/Shell';

import { t, tf } from '../common/I18n';
const KEY_ALIAS: string = 'pendingAlias';
const KEY_LAN_PORT: string = 'pendingLanPort';
const KEY_LAN_AUTO: string = 'pendingLanAuto';
const KEY_LAN_HOST: string = 'pendingLanHost';
const KEY_LAN_SCHEME: string = 'pendingLanScheme';

@Component
export struct ServerPage {
  @StorageLink('uiTick') uiTick: number = 0;
  @StorageLink('netTick') @Watch('onNetTick') netTick: number = 0;
  @StorageLink('profileTick') @Watch('onProfileTick') profileTick: number = 0;
  @Consume('nav') nav: NavPathStack;
  @State account: string = '';
  @State connText: string = '';
  @State connected: boolean = true;
  @State testing: boolean = false;
  @State profiles: ServerProfile[] = [];
  @State activeKey: string = '';
  @State busyKey: string = '';
  @State editingKey: string = '';
  @State editAlias: string = '';
  @State editOrigin: string = '';
  @State editPort: string = '25600';
  @State editAuto: boolean = true;
  @State editLan: string = '';
  @State editScheme: string = 'http';
  @State port: string = '25600';
  @State addScheme: string = 'http';
  @State scanning: boolean = false;
  @State scanned: boolean = false;
  @State hits: LanHit[] = [];
  @State addAuto: boolean = true;
  @State addLanHost: string = '';
  @State netLabel: string = t('读取中');
  @State autoNote: string = '';
  @State addAlias: string = '';
  @State addOrigin: string = '';

  aboutToAppear(): void {
    this.refreshIdentity();
    const savedPort: number = Prefs.int(KEY_LAN_PORT, 0);
    this.port = `${savedPort > 0 ? savedPort : LanScan.defaultPort()}`;
    this.addAuto = Prefs.read(KEY_LAN_AUTO) !== 'false';
    const savedHost: string = Prefs.read(KEY_LAN_HOST);
    this.addScheme = Prefs.read(KEY_LAN_SCHEME) === 'https' ? 'https' : 'http';
    this.addLanHost = savedHost.length > 0 ? `${savedHost}:${this.port}` : '';
    this.reloadProfiles();
    this.loadNet();
    this.test(true);
  }

  private refreshIdentity(): void {
    this.account = appStore.displayName();
    this.connText = appStore.connectionLabel();
    this.autoNote = AutoSwitch.note();
  }

  private onNetTick(): void {
    this.refreshIdentity();
    this.loadNet();
  }

  private onProfileTick(): void {
    this.account = appStore.displayName();
  }

  private reloadProfiles(): void {
    this.profiles = ServerProfiles.list();
    this.activeKey = ServerProfiles.activeKey();
  }

  private async loadNet(): Promise<void> {
    let wifi: boolean = false;
    let cellular: boolean = false;
    try {
      const net: connection.NetHandle = await connection.getDefaultNet();
      const caps: connection.NetCapabilities = await connection.getNetCapabilities(net);
      const types: connection.NetBearType[] = caps.bearerTypes;
      for (let index: number = 0; index < types.length; index++) {
        if (types[index] === connection.NetBearType.BEARER_WIFI) {
          wifi = true;
        } else if (types[index] === connection.NetBearType.BEARER_CELLULAR) {
          cellular = true;
        }
      }
    } catch (error) {
    }
    if (wifi) {
      const ip: string = await LanScan.localAddress();
      this.netLabel = ip.length > 0 ? `Wi-Fi · ${ip}` : 'Wi-Fi';
    } else if (cellular) {
      this.netLabel = t('公网');
    } else {
      this.netLabel = t('未联网');
    }
  }

  private async test(silent: boolean): Promise<void> {
    if (this.testing) {
      return;
    }
    this.testing = true;
    try {
      const who: string = await appStore.api.me();
      if (who.length === 0) {
        this.connected = false;
        if (!silent) {
          promptAction.showToast({ message: t('连接失败：会话已失效') });
        }
      } else {
        this.connected = true;
        this.account = appStore.displayName();
        if (!silent) {
          promptAction.showToast({ message: t(`连接正常 · ${appStore.displayName()}`) });
        }
      }
    } catch (error) {
      this.connected = false;
      if (!silent) {
        promptAction.showToast({ message: t(`连接失败：${(error as Error).message}`) });
      }
    }
    this.testing = false;
  }

  private async use(key: string): Promise<void> {
    if (this.busyKey.length > 0) {
      return;
    }
    if (key === this.activeKey) {
      promptAction.showToast({ message: t('已是当前服务器') });
      return;
    }
    this.busyKey = key;
    try {
      await appStore.switchTo(key);
      this.reloadProfiles();
      promptAction.showToast({ message: t('已切换服务器') });
      AppStorage.setOrCreate('serverTick', Date.now());
    } catch (error) {
      promptAction.showToast({ message: (error as Error).message });
    }
    this.busyKey = '';
  }

  private async menu(item: ServerProfile): Promise<void> {
    try {
      const result: promptAction.ActionMenuSuccessResponse = await promptAction.showActionMenu({
        title: this.nameOf(item),
        buttons: [
          { text: t('编辑'), color: C.acc },
          { text: t('删除档案'), color: C.bad }
        ]
      });
      if (result.index === 0) {
        this.editingKey = item.key;
        this.editAlias = this.nameOf(item);
        this.editOrigin = item.origin;
        this.editPort = `${item.lanPort > 0 ? item.lanPort : LanScan.defaultPort()}`;
        this.editAuto = item.lanAuto;
        this.editLan = item.lanHost;
        this.editScheme = item.lanScheme;
      } else if (result.index === 1) {
        this.drop(item);
      }
    } catch (error) {
    }
  }

  private lanBody(value: string): string {
    let body: string = value.trim();
    if (body.startsWith('https://')) {
      body = body.substring(8);
    } else if (body.startsWith('http://')) {
      body = body.substring(7);
    }
    const slash: number = body.indexOf('/');
    if (slash > 0) {
      body = body.substring(0, slash);
    }
    return body;
  }

  private lanSchemeOf(value: string, fallback: string): string {
    if (value.startsWith('https://')) {
      return 'https';
    }
    if (value.startsWith('http://')) {
      return 'http';
    }
    return fallback;
  }

  private lanHostOf(value: string): string {
    const body: string = this.lanBody(value);
    const colon: number = body.lastIndexOf(':');
    if (colon <= 0) {
      return body;
    }
    const tail: number = parseInt(body.substring(colon + 1), 10);
    return isNaN(tail) ? body : body.substring(0, colon);
  }

  private lanPortOf(value: string): number {
    const body: string = this.lanBody(value);
    const colon: number = body.lastIndexOf(':');
    if (colon <= 0) {
      return 0;
    }
    const value2: number = parseInt(body.substring(colon + 1), 10);
    if (isNaN(value2) || value2 < 1 || value2 > 65535) {
      return 0;
    }
    return value2;
  }

  private async applyEdit(): Promise<void> {
    const alias: string = this.editAlias.trim();
    if (alias.length === 0) {
      promptAction.showToast({ message: t('名称不能为空') });
      return;
    }
    const raw: string = this.editOrigin.trim();
    if (raw.length === 0) {
      promptAction.showToast({ message: t('请填写服务器地址') });
      return;
    }
    const origin: string = raw.startsWith('http://') || raw.startsWith('https://') ? raw : `http://${raw}`;
    const port: number = parseInt(this.editPort, 10);
    if (isNaN(port) || port < 1 || port > 65535) {
      promptAction.showToast({ message: t('端口不合法') });
      return;
    }
    const lanRaw: string = this.editLan.trim();
    const lanScheme: string = this.lanSchemeOf(lanRaw, this.editScheme);
    const lanHost: string = lanRaw.length > 0 ? this.lanHostOf(lanRaw) : '';
    if (lanHost.length > 0 && lanHost.indexOf(' ') >= 0) {
      promptAction.showToast({ message: t('局域网地址不合法') });
      return;
    }
    const typedPort: number = lanRaw.length > 0 ? this.lanPortOf(lanRaw) : 0;
    const lanPort: number = typedPort > 0 ? typedPort : port;
    const other: ServerProfile | null = ServerProfiles.findByOrigin(origin);
    if (other !== null && other.key !== this.editingKey) {
      promptAction.showToast({ message: t('该地址已被其它服务器档案使用') });
      return;
    }
    const isActive: boolean = ServerProfiles.isActive(this.editingKey);
    await appStore.editProfile(this.editingKey, alias, origin, lanPort, this.editAuto, lanHost, lanScheme);
    this.editingKey = '';
    this.reloadProfiles();
    if (isActive) {
      this.test(true);
      AppStorage.setOrCreate('serverTick', Date.now());
    }
    promptAction.showToast({ message: t('已保存') });
  }

  private async drop(item: ServerProfile): Promise<void> {
    const result: promptAction.ShowDialogSuccessResponse = await promptAction.showDialog({
      title: t('删除服务器档案'),
      message: t('仅移除本机保存的地址与会话，服务器上的数据与已下载副本不受影响。'),
      buttons: [
        { text: t('取消'), color: C.tx3 },
        { text: t('删除'), color: C.bad }
      ]
    });
    if (result.index !== 1) {
      return;
    }
    const done: boolean = await appStore.removeProfile(item.key);
    if (!done) {
      promptAction.showToast({ message: t('当前服务器不能删除') });
      return;
    }
    this.reloadProfiles();
  }

  private async discover(): Promise<void> {
    if (this.scanning) {
      return;
    }
    const value: number = parseInt(this.port, 10);
    if (isNaN(value) || value < 1 || value > 65535) {
      promptAction.showToast({ message: t('端口不合法') });
      return;
    }
    try {
      this.getUIContext().getFocusController().clearFocus();
    } catch (error) {
    }
    this.port = `${value}`;
    this.scanning = true;
    this.scanned = false;
    this.hits = [];
    const first: string = this.addScheme === 'https' ? 'https' : 'http';
    const second: string = first === 'https' ? 'http' : 'https';
    try {
      this.hits = await LanScan.scan([value], [first, second]);
      this.scanned = true;
      if (this.hits.length === 0) {
        promptAction.showToast({ message: t('同网段未发现兰台服务器') });
      }
    } catch (error) {
      promptAction.showToast({ message: t(`扫描失败：${(error as Error).message}`) });
    }
    this.scanning = false;
  }

  private async pick(hit: LanHit): Promise<void> {
    const existed: ServerProfile | null = ServerProfiles.findByOrigin(hit.origin);
    if (existed !== null && existed.cookie.length > 0) {
      await this.use(existed.key);
      return;
    }
    const result: promptAction.ShowDialogSuccessResponse = await promptAction.showDialog({
      title: t('连接这台服务器'),
      message: tf('将断开当前连接并回到登录页，地址预填为 {0}。已下载副本与阅读进度保留在本机。', [hit.origin]),
      buttons: [
        { text: t('取消'), color: C.tx3 },
        { text: t('去登录'), color: C.acc }
      ]
    });
    if (result.index !== 1) {
      return;
    }
    this.addLanHost = `${hit.host}:${hit.port}`;
    this.addScheme = hit.scheme;
    await this.saveLanPending();
    AppStorage.setOrCreate('loginOrigin', hit.origin);
    await appStore.logout();
    AppStorage.setOrCreate('logoutTick', Date.now());
  }

  private async saveLanPending(): Promise<void> {
    const fallback: number = parseInt(this.port, 10);
    const raw: string = this.addLanHost.trim();
    const host: string = raw.length > 0 ? this.lanHostOf(raw) : '';
    const typed: number = raw.length > 0 ? this.lanPortOf(raw) : 0;
    const scheme: string = this.lanSchemeOf(raw, this.addScheme);
    const port: number = typed > 0 ? typed : (isNaN(fallback) ? LanScan.defaultPort() : fallback);
    await Prefs.putInt(KEY_LAN_PORT, port);
    await Prefs.write(KEY_LAN_AUTO, this.addAuto ? 'true' : 'false');
    await Prefs.write(KEY_LAN_HOST, host);
    await Prefs.write(KEY_LAN_SCHEME, scheme);
  }

  private async addServer(): Promise<void> {
    const raw: string = this.addOrigin.trim();
    if (raw.length === 0) {
      promptAction.showToast({ message: t('请填写服务器地址') });
      return;
    }
    const origin: string = raw.startsWith('http://') || raw.startsWith('https://') ? raw : `http://${raw}`;
    const existed: ServerProfile | null = ServerProfiles.findByOrigin(origin);
    if (existed !== null && existed.cookie.length > 0) {
      await this.use(existed.key);
      return;
    }
    const result: promptAction.ShowDialogSuccessResponse = await promptAction.showDialog({
      title: t('添加服务器'),
      message: tf('将断开当前连接并回到登录页，地址预填为 {0}。已下载副本与阅读进度保留在本机。', [origin]),
      buttons: [
        { text: t('取消'), color: C.tx3 },
        { text: t('去登录'), color: C.acc }
      ]
    });
    if (result.index !== 1) {
      return;
    }
    await Prefs.write(KEY_ALIAS, this.addAlias.trim());
    await this.saveLanPending();
    AppStorage.setOrCreate('loginOrigin', origin);
    await appStore.logout();
    AppStorage.setOrCreate('logoutTick', Date.now());
  }

  private async unbind(): Promise<void> {
    const result: promptAction.ShowDialogSuccessResponse = await promptAction.showDialog({
      title: t('解绑并更换服务器'),
      message: t('将清除本机保存的会话凭据并回到登录页。离线副本与阅读进度保留在本机。'),
      buttons: [
        { text: t('取消'), color: C.tx3 },
        { text: t('解绑'), color: C.bad }
      ]
    });
    if (result.index !== 1) {
      return;
    }
    await appStore.logout();
    AppStorage.setOrCreate('logoutTick', Date.now());
  }

  private nameOf(item: ServerProfile): string {
    const name: string = item.alias;
    const sep: string = ' · ';
    const index: number = name.indexOf(sep);
    if (index > 0 && item.account.length > 0 && name.substring(index + sep.length) === item.account) {
      return name.substring(0, index);
    }
    return name;
  }

  private activeAlias(): string {
    const item: ServerProfile | null = ServerProfiles.current();
    if (item !== null && item.alias.length > 0) {
      return this.nameOf(item);
    }
    return appStore.serverLabel();
  }

  private activePlace(): string {
    return appStore.isLanActive() ? t('局域网') : t('公网');
  }

  private isLan(origin: string): boolean {
    return LanScan.isPrivate(origin);
  }

  private lanOf(item: ServerProfile, isActive: boolean): boolean {
    return isActive ? appStore.isLanActive() : this.isLan(item.origin);
  }

  @Builder
  heroCard() {
    Column({ space: 0 }) {
      Stack() {
        GlyphIcon({
          glyphName: 'server',
          glyphSize: 22,
          glyphColor: this.connected ? C.ok : C.tx4
        })
      }
      .width(46)
      .height(46)
      .backgroundColor(this.connected ? '#1c2a1c' : C.bg3)
      .borderRadius(14)

      Text(this.connected ? t(`已连接 · ${this.activeAlias()}`) : t('未连接'))
        .fontSize(16)
        .fontColor(C.tx)
        .letterSpacing(0.5)
        .margin({ top: 11 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.connected ? `${this.account.length > 0 ? this.account : t('已登录')} · ${this.activePlace()}` : t('连接后可用服务器书库与进度同步'))
        .fontSize(9.5)
        .fontColor(C.tx4)
        .margin({ top: 4 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.connected ? this.connText : '')
        .fontSize(9)
        .fontColor(C.tx3)
        .margin({ top: 3 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 18, bottom: 18 })
    .backgroundColor(C.bg1)
    .borderRadius(R.m)
    .border({ width: 1, color: C.line })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  profileRow(item: ServerProfile, isActive: boolean) {
    Row({ space: 10 }) {
      Stack() {
        GlyphIcon({
          glyphName: this.lanOf(item, isActive) ? 'local' : 'server',
          glyphSize: 15,
          glyphColor: isActive ? C.ok : C.tx3
        })
      }
      .width(34)
      .height(34)
      .backgroundColor(isActive ? '#1c2a1c' : C.bg3)
      .borderRadius(10)

      Column({ space: 3 }) {
        Text(this.nameOf(item))
          .fontSize(12.5)
          .fontColor(C.tx)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(`${item.account.length > 0 ? item.account : t('未登录')} · ${this.lanOf(item, isActive) ? t('局域网') : t('公网')}`)
          .fontSize(9.5)
          .fontColor(C.tx4)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.busyKey === item.key) {
        LoadingProgress().width(16).height(16).color(C.acc)
      } else if (isActive) {
        Pill({ label: t('已连接'), tone: this.connected ? 'done' : 'warn' })
      } else {
        Text(t('切换'))
          .fontSize(10.5)
          .fontColor(C.acc)
          .padding({ left: 9, right: 9, top: 5, bottom: 5 })
          .borderRadius(7)
          .backgroundColor(C.bg3)
          .onClick(() => {
            this.use(item.key);
          })
      }

      Text('⋯')
        .fontSize(14)
        .fontColor(C.tx3)
        .textAlign(TextAlign.Center)
        .width(24)
        .height(24)
        .onClick(() => {
          this.menu(item);
        })
    }
    .width('100%')
    .padding({ left: 12, right: 8, top: 10, bottom: 10 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  editCard() {
    Column({ space: 9 }) {
      Row() {
        Text(t('编辑服务器'))
          .fontSize(12.5)
          .fontColor(C.tx)
          .layoutWeight(1)
        Text(t('取消'))
          .fontSize(11.5)
          .fontColor(C.tx3)
          .onClick(() => {
            this.editingKey = '';
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      TextInput({ text: this.editAlias, placeholder: t('名称') })
        .height(34)
        .fontSize(12)
        .backgroundColor(C.bg2)
        .fontColor(C.tx)
        .placeholderColor(C.tx4)
        .borderRadius(8)
        .padding({ left: 9, right: 9 })
        .onChange((text: string) => {
          this.editAlias = text;
        })
      TextInput({ text: this.editOrigin, placeholder: t('http(s)://主机或IP:端口') })
        .height(34)
        .fontSize(12)
        .fontFamily(FT.mono)
        .backgroundColor(C.bg2)
        .fontColor(C.tx)
        .placeholderColor(C.tx4)
        .borderRadius(8)
        .padding({ left: 9, right: 9 })
        .onChange((text: string) => {
          this.editOrigin = text;
        })

      Row({ space: 6 }) {
        Text(t('局域网地址'))
          .fontSize(9.5)
          .fontColor(C.tx4)
        Blank()
        Text('HTTP')
          .fontSize(9.5)
          .fontColor(this.editScheme === 'http' ? C.acc : C.tx4)
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .borderRadius(7)
          .backgroundColor(this.editScheme === 'http' ? C.bg3 : C.bg2)
          .onClick(() => {
            this.editScheme = 'http';
          })
        Text('HTTPS')
          .fontSize(9.5)
          .fontColor(this.editScheme === 'https' ? C.acc : C.tx4)
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .borderRadius(7)
          .backgroundColor(this.editScheme === 'https' ? C.bg3 : C.bg2)
          .onClick(() => {
            this.editScheme = 'https';
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      TextInput({ text: this.editLan, placeholder: t('可选，如 192.168.1.10:33100') })
        .height(34)
        .fontSize(12)
        .fontFamily(FT.mono)
        .backgroundColor(C.bg2)
        .fontColor(C.tx)
        .placeholderColor(C.tx4)
        .borderRadius(8)
        .padding({ left: 9, right: 9 })
        .onChange((text: string) => {
          this.editLan = text;
          const typed: number = this.lanPortOf(text);
          if (typed > 0) {
            this.editPort = `${typed}`;
          }
        })

      Row({ space: 8 }) {
        Column({ space: 2 }) {
          Text(t('局域网自动发现'))
            .fontSize(11.5)
            .fontColor(C.tx)
            .width('100%')
          Text(t('仅对这台服务器生效'))
            .fontSize(9.5)
            .fontColor(C.tx4)
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Toggle({ type: ToggleType.Switch, isOn: this.editAuto })
          .selectedColor(C.acc)
          .onChange((value: boolean) => {
            this.editAuto = value;
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 8 }) {
        Text(t('局域网端口'))
          .fontSize(10)
          .fontColor(C.tx4)
        TextInput({ text: this.editPort, placeholder: '25600' })
          .type(InputType.Number)
          .maxLength(5)
          .width(70)
          .height(30)
          .fontSize(11.5)
          .fontFamily(FT.mono)
          .fontColor(C.tx)
          .placeholderColor(C.tx4)
          .textAlign(TextAlign.Center)
          .padding(0)
          .backgroundColor(C.bg2)
          .borderRadius(8)
          .onChange((text: string) => {
            this.editPort = text;
          })
        Blank()
        Text(t('保存'))
          .fontSize(11)
          .fontColor(C.acc)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius(8)
          .backgroundColor(C.bg3)
          .onClick(() => {
            this.applyEdit();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(C.bg1)
    .borderRadius(R.m)
    .border({ width: 1, color: C.accLine })
    .margin({ bottom: 9 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  addCard() {
    Column({ space: 9 }) {
      Text(t('名称'))
        .fontSize(9.5)
        .fontColor(C.tx4)
        .width('100%')
      TextInput({ text: this.addAlias, placeholder: t('例如：书房 NAS') })
        .height(34)
        .fontSize(12)
        .backgroundColor(C.bg2)
        .fontColor(C.tx)
        .placeholderColor(C.tx4)
        .borderRadius(8)
        .padding({ left: 9, right: 9 })
        .onChange((text: string) => {
          this.addAlias = text;
        })
      Text(t('服务器地址'))
        .fontSize(9.5)
        .fontColor(C.tx4)
        .width('100%')
        .margin({ top: 2 })
      TextInput({ text: this.addOrigin, placeholder: t('http(s)://主机或IP:端口') })
        .height(34)
        .fontSize(12)
        .backgroundColor(C.bg2)
        .fontColor(C.tx)
        .placeholderColor(C.tx4)
        .borderRadius(8)
        .padding({ left: 9, right: 9 })
        .onChange((text: string) => {
          this.addOrigin = text;
        })
      Divider()
        .color(C.line)
        .margin({ top: 4, bottom: 2 })

      Row({ space: 8 }) {
        Column({ space: 2 }) {
          Text(t('局域网自动发现'))
            .fontSize(11.5)
            .fontColor(C.tx)
            .width('100%')
          Text(this.addLanHost.length > 0 ? t(`已记录 ${this.addLanHost}`) : t('仅对这台服务器生效'))
            .fontSize(9.5)
            .fontColor(C.tx4)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Toggle({ type: ToggleType.Switch, isOn: this.addAuto })
          .selectedColor(C.acc)
          .onChange((value: boolean) => {
            this.addAuto = value;
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 8 }) {
        Text(t('端口'))
          .fontSize(10)
          .fontColor(C.tx4)
        TextInput({ text: this.port, placeholder: '25600' })
          .type(InputType.Number)
          .maxLength(5)
          .width(70)
          .height(30)
          .fontSize(11.5)
          .fontFamily(FT.mono)
          .fontColor(C.tx)
          .placeholderColor(C.tx4)
          .textAlign(TextAlign.Center)
          .padding(0)
          .backgroundColor(C.bg2)
          .borderRadius(8)
          .onChange((text: string) => {
            this.port = text;
          })
        Blank()
        Text(this.scanning ? t('扫描中…') : t('扫描本机网段'))
          .fontSize(10.5)
          .fontColor(this.scanning ? C.tx4 : C.acc)
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .borderRadius(8)
          .backgroundColor(C.bg3)
          .onClick(() => {
            this.discover();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.scanning) {
        Row({ space: 8 }) {
          LoadingProgress().width(13).height(13).color(C.acc)
          Text(t('正在遍历本机网段，约需数秒'))
            .fontSize(9.5)
            .fontColor(C.tx4)
        }
        .width('100%')
      } else if (this.hits.length > 0) {
        Column() {
          ForEach(this.hits, (hit: LanHit, index: number) => {
            Column() {
              Row({ space: 8 }) {
                Text(`${hit.host}:${hit.port}`)
                  .fontSize(11.5)
                  .fontColor(C.tx)
                  .fontFamily(FT.mono)
                  .maxLines(1)
                  .layoutWeight(1)
                Text(hit.scheme)
                  .fontSize(8.5)
                  .fontColor(C.tx4)
                  .fontFamily(FT.mono)
                Text(t('用这台'))
                  .fontSize(10.5)
                  .fontColor(C.acc)
                  .padding({ left: 9, right: 9, top: 4, bottom: 4 })
                  .borderRadius(7)
                  .backgroundColor(C.bg3)
                  .onClick(() => {
                    this.pick(hit);
                  })
              }
              .width('100%')
              .height(34)
              .alignItems(VerticalAlign.Center)
              if (index < this.hits.length - 1) {
                Divider()
                  .color(C.line)
              }
            }
            .width('100%')
          }, (hit: LanHit) => `${hit.origin}-${this.hits.length}`)
        }
        .width('100%')
      } else if (this.scanned) {
        Text(t('未发现。确认服务端已启动、手机与服务器在同一网段。'))
          .fontSize(9.5)
          .fontColor(C.tx4)
          .lineHeight(15)
          .width('100%')
      }

      Row() {
        Blank()
        Text(t('添加并连接'))
          .fontSize(11)
          .fontColor(C.acc)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius(8)
          .backgroundColor(C.bg3)
          .onClick(() => {
            this.addServer();
          })
      }
      .width('100%')
      .margin({ top: 2 })
    }
    .width('100%')
    .padding(13)
    .backgroundColor(C.bg1)
    .borderRadius(R.m)
    .border({ width: 1, color: C.line })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      ScreenHead({
        title: t('连接服务器'),
        back: t('我的'),
        onBack: () => {
          this.nav.pop();
        }
      })

      Scroll() {
        Column() {
          this.heroCard()

          GroupHead({
            title: t('我的服务器'),
            meta: this.profiles.length > 0 ? t(`${this.profiles.length} 台`) : ''
          })

          if (this.editingKey.length > 0) {
            this.editCard()
          }

          Column() {
            if (this.profiles.length === 0) {
              Row() {
                Text(t('尚无保存的服务器'))
                  .fontSize(11)
                  .fontColor(C.tx4)
              }
              .width('100%')
              .height(60)
              .justifyContent(FlexAlign.Center)
            } else {
              ForEach(this.profiles, (item: ServerProfile) => {
                Column() {
                  this.profileRow(item, item.key === this.activeKey)
                  if (item.key !== this.profiles[this.profiles.length - 1].key) {
                    Divider()
                      .color(C.line)
                      .margin({ left: 12, right: 12 })
                  }
                }
                .width('100%')
              }, (item: ServerProfile) => `${item.key}-${item.alias}-${item.origin}-${item.key === this.activeKey}`)
            }
          }
          .width('100%')
          .padding({ top: 4, bottom: 4 })
          .backgroundColor(C.bg1)
          .borderRadius(R.m)
          .border({ width: 1, color: C.line })

          GroupHead({ title: t('添加服务器') })
          this.addCard()

          Row({ space: 10 }) {
            ActionBtn({
              label: this.testing ? t('测试中…') : t('测试连接'),
              primary: true,
              glyph: 'sync',
              onTap: () => {
                this.test(false);
              }
            })
            ActionBtn({
              label: t('解绑此设备'),
              danger: true,
              glyph: 'trash',
              onTap: () => {
                this.unbind();
              }
            })
          }
          .width('100%')
          .margin({ top: 12 })

          NoteCard({ text: t('扫描只在点按后进行，不常驻后台，也不会上传任何网络信息。') })
            .margin({ top: 14 })

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
