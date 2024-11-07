include unrealprelude

#[
  Not all this types require the editor. But likely you will only use them in the editor. 
  If thats not the case, please, extract a file with them or guard WithEditor below for the editor ones.

  nuegame.h: #depending in what you use:
  #include "IImageWrapperModule.h"
  #include "ObjectTools.h"
  #include "ImageUtils.h"
  #include "Misc/ObjectThumbnail.h"

  game.json:
  "gameModules": ["ImageCore", "ImageWrapper", "CollectionManager"]
]#

type
    FObjectThumbnail* {.importcpp.} = object 
    FThumbnailMap* {.importcpp.} = object
   
    FImageView* {.importcpp.} = object
    

    EPixelFormat* {.importcpp.} = enum
      PF_Unknown,
      PF_A8,
      PF_R8G8B8A8,
      PF_B8G8R8A8

    IImageWrapperModule* {.importcpp.} = object
    IImageWrapper* {.importcpp.} = object
    EImageFormat* {.importcpp.} = enum
      PNG, JPG, BMP, EXR
    ERGBFormat* {.importcpp.} = enum
      Invalid = -1
      RGBA = 0
      BGRA = 1
      Gray = 2
      RGBAF = 3
      BGRE = 4
      GrayF = 5

proc getImageWidth*(thumbnail: ptr FObjectThumbnail): int32 {.importcpp: "#->GetImageWidth()".}
proc getImageHeight*(thumbnail: ptr FObjectThumbnail): int32 {.importcpp: "#->GetImageHeight()".}
proc getUncompressedImageData*(thumbnail: ptr FObjectThumbnail): var TArray[uint8] {.importcpp: "#->GetUncompressedImageData()".}
proc generateThumbnailForObjectToSaveToDisk*(obj: UObjectPtr): ptr FObjectThumbnail {.importcpp: "ThumbnailTools::GenerateThumbnailForObjectToSaveToDisk(@)".}
proc loadThumbnailsFromPackage*(packageFilename: FString, objectFullNames: TSet[FName], thumbnailMap: var FThumbnailMap) {.importcpp: "ThumbnailTools::LoadThumbnailsFromPackage(@)".}
proc find*(thumbnailMap: FThumbnailMap, objectFullName: FName): ptr FObjectThumbnail {.importcpp: "#.Find(@)".}
proc createImageWrapper*(imageWrapperModule: ptr IImageWrapperModule, format: EImageFormat): TSharedPtr[IImageWrapper] {.importcpp: "#->CreateImageWrapper(@)".}
proc importBufferAsTexture2D*(compressedByteArray: TArray64[uint8]): UTexture2DPtr {.importcpp: "FImageUtils::ImportBufferAsTexture2D(@)".}
proc getCompressed*(imageWrapper: TSharedPtr[IImageWrapper]): var TArray64[uint8] {.importcpp: "#->GetCompressed()".}
proc setRaw*(imageWrapper: TSharedPtr[IImageWrapper], data: ptr uint8, size: int32, width, height: int32, format: ERGBFormat, numComponents: int32) {.importcpp: "#->SetRaw(@)".}
#engine types
proc source*(texture: UTexturePtr): FTextureSource {.importcpp: "#.Source".} #Notice we import as func as its only available in editor = true

proc init*(source: FTextureSource, width, height, numSlices, numMips: int32, format: ETextureSourceFormat, data: ptr uint8 = nil) {.importcpp: "#.Init(@)".}
proc init*(source: FTextureSource, imageView: FImageView) {.importcpp: "#.Init(@)".}

proc updateResource*(texture: UTexturePtr) {.importcpp: "#->UpdateResource()".}

proc doesPackageExist*(packageName: FString, packageFilename: ptr FString): bool {.importcpp: "FPackageName::DoesPackageExist(@)".}


proc makeImageView*(data: pointer, width, height: int32): FImageView {.importcpp: "FImageView(@, ERawImageFormat::BGRA8)".}

proc getMipsAt*(texture: UTexture2DPtr, index: int32): var FTexture2DMipMap {.importcpp: "#->GetPlatformData()->Mips[#]".}

proc getPlatformData*(texture: UTexture2DPtr): ptr FTexturePlatformData {.importcpp: "#->GetPlatformData()".}
proc setPlatformData*(texture: UTexture2DPtr, platformData: ptr FTexturePlatformData) {.importcpp: "#->SetPlatformData(@)".}


when WithEditor:
  import editor/editor
  import ../../unreal/bindings/imported/unrealed/thumbnailrendering
else:
  import ../../unreal/bindings/exported/unrealed/thumbnailrendering

  proc getRenderingInfo*(manager: UThumbnailManagerPtr, obj: UObjectPtr): ptr FThumbnailRenderingInfo {.importcpp: "#->GetRenderingInfo(@)".}
  proc draw(rendered: UThumbnailRendererPtr, obj: UObjectPtr, x: int32, y: int32, width: uint32, height: uint32, renderTarget: ptr FRenderTarget, canvas: ptr FCanvas; bAdditionalViewFamily: bool) {.importcpp: "#->Draw(@)".}



