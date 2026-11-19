import { connection } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { C, R } from '../common/Theme';
import { appStore } from '../model/AppStore';
import { Prefs } from '../model/Prefs';
import { ServerProfile, ServerProfiles } from '../model/ServerProfile';

import { t, tf } from '../common/I18n';
@Component
export struct LoginPage {
  @StorageLink('uiTick') uiTick: number = 0;
  @StorageLink('loginOrigin') loginOrigin: string = '';
  @State server: string = '';
  @State account: string = '';
  @State password: string = '';
  @State busy: boolean = false;
  @State error: string = '';
  @State candidates: ServerProfile[] = [];
  onLogged: () => void = () => {};

  aboutToAppear(): void {
    ServerProfiles.load();
    this.candidates = ServerProfiles.list();
    const current: ServerProfile | null = ServerProfiles.current();
    if (this.loginOrigin.length > 0) {
      this.server = this.loginOrigin;
    } else if (current !== null && current.origin.length > 0) {
      this.server = current.origin;
    } else {
      this.server = Prefs.server();
    }
    this.account = Prefs.account();
  }

  private async submit(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.error = '';
    if (this.server.trim().length === 0) {
      this.error = t('请填写服务器地址');
      return;
    }
    if (this.account.trim().length === 0) {
      this.error = t('请填写用户名');
      return;
    }
    this.busy = true;
    try {
      await appStore.login(this.server, this.account.trim(), this.password);
      this.password = '';
      this.onLogged();
    } catch (error) {
      const message: string = (error as Error).message;
      const code: number = (error as BusinessError).code;
      let text: string = message.length > 0 ? message : t('连接失败');
      if (code > 0) {
        text = `${text}（${code}）`;
      }
      if (code === 2300006 || code === 2300007) {
        text = `${text} · ${await this.addresses(this.server)}`;
      }
      this.error = text;
    } finally {
      this.busy = false;
    }
  }

  private async addresses(server: string): Promise<string> {
    const body: string = server.trim().replace('https://', '').replace('http://', '');
    const host: string = body.split('/')[0].split(':')[0];
    if (host.length === 0) {
      return t('地址为空');
    }
    try {
      const list: connection.NetAddress[] = await connection.getAddressesByName(host);
      if (list.length === 0) {
        return t('域名未解析出地址');
      }
      let v6: number = 0;
      for (let index: number = 0; index < list.length; index++) {
        if (list[index].address.indexOf(':') >= 0) {
          v6 += 1;
        }
      }
      const text: string = tf('解析 {0} 个地址，其中 IPv6 {1} 个', [`${list.length}`, `${v6}`]);
      if (v6 === list.length) {
        return `${text} · ${t('该域名只有 IPv6 地址')}`;
      }
      return text;
    } catch (error) {
      return t('系统解析器无结果');
    }
  }

  @Builder
  field(label: string, hint: string, value: string, secret: boolean, onChange: (text: string) => void) {
    Column() {
      Text(label).fontSize(11).fontColor(C.tx4).width('100%').margin({ bottom: 6 })
      TextInput({ text: value, placeholder: hint })
        .type(secret ? InputType.Password : InputType.Normal)
        .height(44)
        .fontSize(14)
        .backgroundColor(C.bg2)
        .fontColor(C.tx)
        .placeholderColor(C.tx4)
        .borderRadius(R.s)
        .border({ width: 1, color: C.line })
        .padding({ left: 12, right: 12 })
        .onChange((text: string) => {
          onChange(text);
        })
    }
    .width('100%')
    .margin({ bottom: 14 })
  }

  @Builder
  candidateRow() {
    Column() {
      if (this.candidates.length > 0) {
        Scroll() {
          Row({ space: 6 }) {
            ForEach(this.candidates, (item: ServerProfile) => {
              Text(item.alias)
                .fontSize(10)
                .fontColor(item.origin === this.server ? C.acc : C.tx3)
                .maxLines(1)
                .padding({ left: 9, right: 9, top: 5, bottom: 5 })
                .backgroundColor(C.bg2)
                .borderRadius(7)
                .onClick(() => {
                  this.server = item.origin;
                })
            }, (item: ServerProfile) => `${item.key}-${item.origin}`)
          }
          .constraintSize({ minWidth: '100%' })
          .justifyContent(FlexAlign.Start)
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
      }
    }
    .width('100%')
    .margin({ bottom: 12 })
  }

  build() {
    Column() {
      Blank()

      Column() {
        Image($r('app.media.logo_lantai'))
          .width(52)
          .height(52)
          .borderRadius(R.m)
          .clip(true)
          .border({ width: 1, color: C.accLine })
          .margin({ bottom: 16 })

        Text(t('兰台阅读'))
          .fontSize(24)
          .fontColor(C.tx)
          .fontWeight(FontWeight.Medium)
          .letterSpacing(2)

        Text(t('连接你自己的兰台服务器'))
          .fontSize(12)
          .fontColor(C.tx3)
          .margin({ top: 8 })
      }
      .margin({ bottom: 34 })

      Column() {
        Column() {
          Text(t('服务器地址'))
            .fontSize(11)
            .fontColor(C.tx4)
            .width('100%')
            .margin({ bottom: 6 })
          TextInput({ text: $$this.server, placeholder: t('http://主机或IP:25600') })
            .type(InputType.Normal)
            .height(44)
            .fontSize(14)
            .backgroundColor(C.bg2)
            .fontColor(C.tx)
            .placeholderColor(C.tx4)
            .borderRadius(R.s)
            .border({ width: 1, color: C.line })
            .padding({ left: 12, right: 12 })
        }
        .width('100%')
        .margin({ bottom: 10 })

        this.candidateRow()

        this.field(t('用户名'), t('邮箱或登录名'), this.account, false,
          (text: string) => {
            this.account = text;
          })
        this.field(t('密码'), t('密码'), this.password, true,
          (text: string) => {
            this.password = text;
          })

        if (this.error.length > 0) {
          Text(this.error)
            .fontSize(11)
            .fontColor(C.bad)
            .width('100%')
            .margin({ bottom: 12 })
        }

        Button(this.busy ? t('连接中…') : t('登录'))
          .width('100%')
          .height(46)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(this.busy ? C.bg3 : C.acc)
          .fontColor(this.busy ? C.tx3 : C.bg)
          .borderRadius(R.m)
          .enabled(!this.busy)
          .onClick(() => {
            this.submit();
          })

        Text(t('离线使用'))
          .fontSize(12.5)
          .fontColor(C.tx2)
          .textAlign(TextAlign.Center)
          .width('100%')
          .height(42)
          .margin({ top: 10 })
          .backgroundColor(C.bg2)
          .borderRadius(R.s)
          .border({ width: 1, color: C.line })
          .onClick(() => {
            if (this.busy) {
              return;
            }
            appStore.enterOffline();
          })
      }
      .width('100%')
      .padding(18)
      .backgroundColor(C.bg1)
      .borderRadius(R.l)
      .border({ width: 1, color: C.line })

      Text(t('离线模式只显示已下载的云库书与本机导入的本地书'))
        .fontSize(10)
        .fontColor(C.tx4)
        .textAlign(TextAlign.Center)
        .margin({ top: 14 })

      Text(t('数据只留在你的服务器上，客户端不落副本'))
        .fontSize(10)
        .fontColor(C.tx4)
        .margin({ top: 8 })

      Blank()
    }
    .width('100%')
    .height('100%')
    .padding({ left: 24, right: 24, top: 40, bottom: 40 })
    .backgroundColor(C.bg)
  }
}
