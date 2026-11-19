import { C } from '../common/Theme';
import { appStore } from '../model/AppStore';
import { t } from '../common/I18n';
import { BottomTabs } from '../components/Shell';
import { HomePage } from './HomePage';
import { LibraryPage } from './LibraryPage';
import { MinePage } from './MinePage';
import { StatsPage } from './StatsPage';

@Component
struct OfflineStub {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop label: string = '';

  build() {
    Column({ space: 8 }) {
      Text(this.label)
        .fontSize(12)
        .fontColor(C.tx3)
      Text(t('到「我的」切换在线'))
        .fontSize(10.5)
        .fontColor(C.tx4)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(C.bg)
  }
}

@Component
export struct MainShell {
  @StorageLink('uiTick') @Watch('onUiTick') uiTick: number = 0;
  @StorageLink('mainTab') activeTab: number = 0;
  @State rev: number = 0;
  @State searchTick: number = 0;
  onLogout: () => void = () => {};
  private controller: TabsController = new TabsController();

  onUiTick(): void {
    this.rev = this.rev + 1;
  }

  private pick(index: number): void {
    this.activeTab = index;
    this.controller.changeIndex(index);
  }

  @Builder
  body() {
    Stack({ alignContent: Alignment.Bottom }) {
      Tabs({ barPosition: BarPosition.End, controller: this.controller, index: this.activeTab }) {
        TabContent() {
          if (appStore.offline) {
            OfflineStub({ label: t('离线模式下首页不可用') })
          } else {
            HomePage({
              onLogout: () => {
                this.onLogout();
              }
            })
          }
        }
        .tabBar('')

        TabContent() {
          LibraryPage({ embedded: true, focusTick: this.searchTick })
        }
        .tabBar('')

        TabContent() {
          if (appStore.offline) {
            OfflineStub({ label: t('离线模式下统计不可用') })
          } else {
            StatsPage()
          }
        }
        .tabBar('')

        TabContent() {
          MinePage({
            onOpenTab: (index: number) => {
              this.pick(index);
            }
          })
        }
        .tabBar('')
      }
      .barHeight(0)
      .scrollable(false)
      .animationDuration(0)
      .width('100%')
      .height('100%')
      .onChange((index: number) => {
        this.activeTab = index;
      })

      BottomTabs({
        current: this.activeTab,
        onPick: (index: number) => {
          this.pick(index);
        }
      })
      .margin({ left: 12, right: 12, bottom: 10 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
  }

  build() {
    Column() {
      if (this.rev % 2 === 0) {
        this.body()
      } else {
        this.body()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
  }
}
