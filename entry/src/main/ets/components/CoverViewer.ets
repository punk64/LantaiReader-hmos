import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { FT } from '../common/Theme';
import { GlyphIcon } from './Icon';
import { CoverCache } from './CoverCache';

import { t } from '../common/I18n';
@Component
export struct CoverViewer {
  @StorageLink('uiTick') uiTick: number = 0;
  @Prop bookId: string = '';
  @Prop title: string = '';
  @State pix: image.PixelMap | null = null;
  @State loading: boolean = true;
  @State error: string = '';
  @State saving: boolean = false;
  private packed: ArrayBuffer | null = null;
  onClose: () => void = () => {};

  aboutToAppear(): void {
    this.load();
  }

  aboutToDisappear(): void {
    this.packed = null;
    CoverCache.releaseFull(this.bookId);
  }

  private async load(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      this.pix = await CoverCache.loadFull(this.bookId);
      this.pack();
    } catch (error) {
      this.error = (error as Error).message;
    }
    this.loading = false;
  }

  private async pack(): Promise<void> {
    const pix: image.PixelMap | null = this.pix;
    if (pix === null) {
      return;
    }
    try {
      const packer: image.ImagePacker = image.createImagePacker();
      const option: image.PackingOption = { format: 'image/jpeg', quality: 96 };
      this.packed = await packer.packing(pix, option);
      packer.release();
    } catch (error) {
      this.packed = null;
    }
  }

  private writeTo(path: string, bytes: ArrayBuffer): void {
    const file: fileIo.File = fileIo.openSync(path,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(file.fd, bytes);
    } finally {
      fileIo.closeSync(file);
    }
  }

  private async save(): Promise<void> {
    const pix: image.PixelMap | null = this.pix;
    if (this.saving || pix === null) {
      return;
    }
    this.saving = true;
    let tmp: string = '';
    try {
      let bytes: ArrayBuffer | null = this.packed;
      if (bytes === null) {
        const packer: image.ImagePacker = image.createImagePacker();
        const option: image.PackingOption = { format: 'image/jpeg', quality: 96 };
        bytes = await packer.packing(pix, option);
        packer.release();
      }
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const name: string = `lantai-cover-${Date.now()}`;
      tmp = `${ctx.cacheDir}/${name}.jpg`;
      this.writeTo(tmp, bytes);
      const helper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(ctx);
      const config: photoAccessHelper.PhotoCreationConfig = {
        title: name,
        fileNameExtension: 'jpg',
        photoType: photoAccessHelper.PhotoType.IMAGE
      };
      let target: string = '';
      try {
        target = await helper.createAssetWithShortTermPermission(config);
      } catch (error) {
        const uris: string[] = await helper.showAssetsCreationDialog([`file://${tmp}`], [config]);
        target = uris.length > 0 ? uris[0] : '';
      }
      if (target.length === 0) {
        throw new Error(t('已取消'));
      }
      this.writeTo(target, bytes);
      promptAction.showToast({ message: t('已保存到相册') });
    } catch (error) {
      promptAction.showToast({ message: t(`保存失败：${(error as Error).message}`) });
    }
    if (tmp.length > 0) {
      try {
        fileIo.unlinkSync(tmp);
      } catch (error) {
      }
    }
    this.saving = false;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.pix !== null) {
        Image(this.pix)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
          .draggable(false)
      }

      if (this.loading) {
        Column({ space: 10 }) {
          LoadingProgress().width(34).height(34).color('#FFFFFF')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.error.length > 0) {
        Column({ space: 12 }) {
          GlyphIcon({ glyphName: 'cover', glyphSize: 30, glyphColor: '#FFFFFF66' })
          Text(this.error)
            .fontSize(12)
            .fontColor('#FFFFFF99')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }

      Row({ space: 10 }) {
        Row() {
          GlyphIcon({ glyphName: 'close', glyphSize: 17, glyphColor: '#FFFFFF' })
        }
        .width(36)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#FFFFFF24')
        .borderRadius(18)
        .onClick(() => {
          this.onClose();
        })

        Text(this.title)
          .fontSize(12)
          .fontColor('#FFFFFFCC')
          .fontFamily(FT.ui)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        SaveButton({ icon: SaveIconStyle.FULL_FILLED, text: SaveDescription.SAVE_IMAGE })
          .fontSize(11)
          .fontColor('#FFFFFF')
          .backgroundColor('#FFFFFF24')
          .height(36)
          .padding({ left: 12, right: 14 })
          .enabled(!this.saving)
          .onClick((event: ClickEvent, result: SaveButtonOnClickResult) => {
            if (result === SaveButtonOnClickResult.SUCCESS) {
              this.save();
            } else {
              promptAction.showToast({ message: t('未获得保存授权') });
            }
          })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
  }
}
