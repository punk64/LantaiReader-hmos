import { C, R, S } from '../common/Theme';

@Component
export struct SkeletonBlock {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop blockWidth: number = 0;
  @Prop blockHeight: number = 12;
  @Prop blockRadius: number = 5;
  @State lit: boolean = false;

  aboutToAppear(): void {
    setTimeout(() => {
      this.lit = true;
    }, 24);
  }

  build() {
    Row()
      .width(this.blockWidth > 0 ? this.blockWidth : '100%')
      .height(this.blockHeight)
      .borderRadius(this.blockRadius)
      .backgroundColor(C.bg3)
      .opacity(this.lit ? 0.34 : 0.88)
      .animation({ duration: 1000, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate })
  }
}

@Component
export struct LibrarySkeleton {
  @StorageLink('uiTick') uiTick: number = 0;

  @Builder
  chip(width: number) {
    SkeletonBlock({ blockWidth: width, blockHeight: 26, blockRadius: 13 })
  }

  @Builder
  cell() {
    Column() {
      SkeletonBlock({ blockWidth: 104, blockHeight: 148, blockRadius: 8 })
      SkeletonBlock({ blockHeight: 10, blockRadius: 4 })
        .margin({ top: 9 })
      SkeletonBlock({ blockWidth: 58, blockHeight: 8, blockRadius: 4 })
        .margin({ top: 6 })
    }
    .width(104)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        this.chip(52)
        this.chip(64)
        this.chip(46)
        this.chip(58)
      }
      .width('100%')
      .margin({ top: 4 })

      SkeletonBlock({ blockHeight: 13 })
        .margin({ top: 22, right: 220 })

      Grid() {
        ForEach([0, 1, 2, 3, 4, 5], (item: number) => {
          GridItem() {
            this.cell()
          }
        }, (item: number) => `sk-${item}`)
      }
      .columnsTemplate('1fr 1fr 1fr')
      .columnsGap(10)
      .rowsGap(16)
      .width('100%')
      .height(420)
      .margin({ top: 12 })
    }
    .width('100%')
    .padding({ left: S.page, right: S.page, top: 8 })
  }
}

@Component
export struct HomeSkeleton {
  @StorageLink('uiTick') uiTick: number = 0;

  @Builder
  shelf() {
    Row({ space: 10 }) {
      ForEach([0, 1, 2], (item: number) => {
        Column() {
          SkeletonBlock({ blockWidth: 82, blockHeight: 115, blockRadius: 7 })
          SkeletonBlock({ blockHeight: 9, blockRadius: 4 })
            .margin({ top: 7 })
          SkeletonBlock({ blockWidth: 48, blockHeight: 8, blockRadius: 4 })
            .margin({ top: 6 })
        }
        .width(82)
        .alignItems(HorizontalAlign.Start)
      }, (item: number) => `hs-${item}`)
    }
    .width('100%')
    .margin({ top: 12 })
  }

  build() {
    Column() {
      SkeletonBlock({ blockHeight: 192, blockRadius: R.l })

      SkeletonBlock({ blockWidth: 92, blockHeight: 14 })
        .margin({ top: 26 })
      this.shelf()

      SkeletonBlock({ blockWidth: 78, blockHeight: 14 })
        .margin({ top: 24 })
      this.shelf()
    }
    .width('100%')
    .padding({ left: S.page, right: S.page, top: 6 })
    .alignItems(HorizontalAlign.Start)
  }
}
