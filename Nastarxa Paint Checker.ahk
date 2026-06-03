#Requires AutoHotkey v2.0
#SingleInstance Force
TraySetIcon "PaintChecker.ico"


; ===================================================================
; GDI+ Wrapper
; ===================================================================
class GDI {
    static pToken := 0

    static Startup() {
        if this.pToken
            return
        si := Buffer(24, 0)
        NumPut("UPtr", 1, si, 0)
        NumPut("UPtr", 0, si, 8)
        DllCall("gdiplus\GdiplusStartup", "Ptr*", &pToken:=0, "Ptr", si, "Ptr", 0)
        this.pToken := pToken
    }

    static Shutdown() {
        if this.pToken
            DllCall("gdiplus\GdiplusShutdown", "Ptr", this.pToken)
        this.pToken := 0
    }

    static LoadImage(file) {
        pImage := 0
        DllCall("gdiplus\GdipLoadImageFromFile", "WStr", file, "Ptr*", &pImage)
        if !pImage
            return 0
        dpi := this.GetResolution(pImage)
        dims := this.GetDimensions(pImage)
        pBitmap := this.CloneBitmapArea(pImage, 0, 0, dims.w, dims.h)
        if pBitmap
            this.SetResolution(pBitmap, dpi.x, dpi.y)
        this.DisposeImage(pImage)
        return pBitmap
    }

    static CloneImage(pBitmap) {
        dims := this.GetDimensions(pBitmap)
        return this.CloneBitmapArea(pBitmap, 0, 0, dims.w, dims.h)
    }

    static CloneBitmapArea(pBitmap, x, y, w, h) {
        pClone := this.CreateBitmap(w, h)
        if !pClone
            return 0
        if !this.DrawBitmap(pClone, pBitmap, 0, 0, w, h, x, y, w, h) {
            this.DisposeImage(pClone)
            return 0
        }
        return pClone
    }

    static DisposeImage(pBitmap) {
        if pBitmap
            try DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)
    }

    static GetDimensions(pBitmap) {
        if !pBitmap
            return {w: 0, h: 0}
        try {
            DllCall("gdiplus\GdipGetImageDimension", "Ptr", pBitmap, "Float*", &w:=0, "Float*", &h:=0)
            return {w: Integer(w), h: Integer(h)}
        } catch {
            return {w: 0, h: 0}
        }
    }

    static GetResolution(pBitmap) {
        DllCall("gdiplus\GdipGetImageHorizontalResolution", "Ptr", pBitmap, "Float*", &x:=96.0)
        DllCall("gdiplus\GdipGetImageVerticalResolution", "Ptr", pBitmap, "Float*", &y:=96.0)
        return {x: x, y: y}
    }

    static SetResolution(pBitmap, dpiX, dpiY) {
        if !pBitmap
            return
        if dpiX <= 0
            dpiX := 96
        if dpiY <= 0
            dpiY := 96
        DllCall("gdiplus\GdipBitmapSetResolution", "Ptr", pBitmap, "Float", dpiX, "Float", dpiY)
    }

    static GetPixel(pBitmap, x, y) {
        DllCall("gdiplus\GdipBitmapGetPixel", "Ptr", pBitmap, "Int", x, "Int", y, "UInt*", &argb:=0)
        return argb
    }

    static SetPixel(pBitmap, x, y, argb) {
        DllCall("gdiplus\GdipBitmapSetPixel", "Ptr", pBitmap, "Int", x, "Int", y, "UInt", argb)
    }

    static GetEncoderClsid(mimeType) {
        static clsids := Map(
            "image/bmp",  "{557CF400-1A04-11D3-9A73-0000F81EF32E}",
            "image/jpeg", "{557CF401-1A04-11D3-9A73-0000F81EF32E}",
            "image/gif",  "{557CF402-1A04-11D3-9A73-0000F81EF32E}",
            "image/tiff", "{557CF405-1A04-11D3-9A73-0000F81EF32E}",
            "image/png",  "{557CF406-1A04-11D3-9A73-0000F81EF32E}"
        )
        if !clsids.Has(mimeType)
            return 0
        clsid := Buffer(16, 0)
        if DllCall("ole32\CLSIDFromString", "WStr", clsids[mimeType], "Ptr", clsid)
            return 0
        return clsid
    }

    static SaveBitmap(pBitmap, file, mimeType) {
        clsid := this.GetEncoderClsid(mimeType)
        if !clsid
            return false
        return DllCall("gdiplus\GdipSaveImageToFile", "Ptr", pBitmap, "WStr", file, "Ptr", clsid, "Ptr", 0) = 0
    }

    static LockBits(pBitmap, &bd) {
        if !pBitmap
            return 0
        try {
            DllCall("gdiplus\GdipGetImageDimension", "Ptr", pBitmap, "Float*", &w:=0, "Float*", &h:=0)
            Rect := Buffer(16, 0)
            NumPut("UInt", 0, Rect, 0)
            NumPut("UInt", 0, Rect, 4)
            NumPut("UInt", w, Rect, 8)
            NumPut("UInt", h, Rect, 12)
            bdSize := A_PtrSize = 8 ? 32 : 24
            bd := Buffer(bdSize, 0)
            DllCall("gdiplus\GdipBitmapLockBits", "Ptr", pBitmap, "Ptr", Rect
                , "UInt", 5, "Int", 0x26200A, "Ptr", bd)
            return {Width: NumGet(bd, 0, "UInt")
                  , Height: NumGet(bd, 4, "UInt")
                  , Stride: NumGet(bd, 8, "Int")
                  , Scan0: NumGet(bd, 16, "UPtr")}
        } catch {
            return 0
        }
    }

    static UnlockBits(pBitmap, &bd) {
        DllCall("gdiplus\GdipBitmapUnlockBits", "Ptr", pBitmap, "Ptr", bd)
    }

    static CreateBitmap(w, h) {
        pBitmap := 0
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "UInt", Max(1, Round(w)), "UInt", Max(1, Round(h))
            , "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &pBitmap)
        return pBitmap
    }

    static DrawBitmap(pDest, pSrc, dstX, dstY, dstW, dstH, srcX, srcY, srcW, srcH) {
        if !pDest || !pSrc
            return false
        gfx := 0
        try {
            if DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", pDest, "Ptr*", &gfx)
                return false
            DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", gfx, "Int", 7)
            status := DllCall("gdiplus\GdipDrawImageRectRect", "Ptr", gfx, "Ptr", pSrc
                , "Float", dstX, "Float", dstY, "Float", dstW, "Float", dstH
                , "Float", srcX, "Float", srcY, "Float", srcW, "Float", srcH
                , "Int", 2, "Ptr", 0, "Ptr", 0)
            return status = 0
        } catch {
            return false
        } finally {
            if gfx
                try DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gfx)
        }
    }

    static GetFitRect(srcW, srcH, maxW, maxH) {
        if srcW <= 0 || srcH <= 0 || maxW <= 0 || maxH <= 0
            return {x: 0, y: 0, w: Max(1, maxW), h: Max(1, maxH)}
        scale := Min(maxW / srcW, maxH / srcH)
        drawW := Max(1, Round(srcW * scale))
        drawH := Max(1, Round(srcH * scale))
        return {
            x: Floor((maxW - drawW) / 2),
            y: Floor((maxH - drawH) / 2),
            w: drawW,
            h: drawH
        }
    }

    static GetHBITMAP(pBitmap) {
        hBitmap := 0
        DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", pBitmap, "Ptr*", &hBitmap, "UInt", 0xFF000000)
        return hBitmap
    }

    static DeleteHBITMAP(hBitmap) {
        if hBitmap
            try DllCall("DeleteObject", "Ptr", hBitmap)
    }

    static _tempCounter := 0
    static SaveToBmpFile(pBitmap) {
        this._tempCounter++
        tmpDir := A_Temp "\NastarxaPaintChecker"
        if !DirExist(tmpDir)
            DirCreate(tmpDir)
        tmpFile := tmpDir "\" A_TickCount "_" this._tempCounter ".bmp"
        if this.SaveBitmap(pBitmap, tmpFile, "image/bmp")
            return tmpFile
        return ""
    }

    static CreateThumbnail(pBitmap, maxW, maxH, bgColor := 0xFF23262C) {
        if !pBitmap
            return 0
        dims := this.GetDimensions(pBitmap)
        if !dims.w || !dims.h
            return 0
        fit := this.GetFitRect(dims.w, dims.h, maxW, maxH)
        thumb := this.CreateBitmap(maxW, maxH)
        if !thumb
            return 0
        gfx := 0
        try {
            if DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", thumb, "Ptr*", &gfx) {
                this.DisposeImage(thumb)
                return 0
            }
            brush := 0
            DllCall("gdiplus\GdipCreateSolidFill", "UInt", bgColor, "Ptr*", &brush)
            if brush {
                DllCall("gdiplus\GdipFillRectangle", "Ptr", gfx
                    , "Ptr", brush, "Float", 0, "Float", 0
                    , "Float", maxW, "Float", maxH)
                DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
            }
            DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", gfx, "Int", 7)
            DllCall("gdiplus\GdipDrawImageRectRect", "Ptr", gfx, "Ptr", pBitmap
                , "Float", fit.x, "Float", fit.y
                , "Float", fit.w, "Float", fit.h
                , "Float", 0, "Float", 0, "Float", dims.w, "Float", dims.h
                , "Int", 2, "Ptr", 0, "Ptr", 0)
            return thumb
        } catch {
            this.DisposeImage(thumb)
            return 0
        } finally {
            if gfx
                try DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gfx)
        }
    }

    static SaveWithFormat(pBitmap, file, ext) {
        switch ext {
            case "jpg", "jpeg":
                return this.SaveBitmap(pBitmap, file, "image/jpeg")
            case "png":
                return this.SaveBitmap(pBitmap, file, "image/png")
            case "bmp":
                return this.SaveBitmap(pBitmap, file, "image/bmp")
            case "tiff", "tif":
                return this.SaveBitmap(pBitmap, file, "image/tiff")
            case "tga":
                return this.SaveAsTga(pBitmap, file)
        }
        return this.SaveBitmap(pBitmap, file, "image/png")
    }

    static SaveAsTga(pBitmap, file) {
        dims := this.GetDimensions(pBitmap)
        w := dims.w, h := dims.h
        if !w || !h
            return false

        Rect := Buffer(16, 0)
        NumPut("UInt", 0, Rect, 0)
        NumPut("UInt", 0, Rect, 4)
        NumPut("UInt", w, Rect, 8)
        NumPut("UInt", h, Rect, 12)
        bd := Buffer(A_PtrSize = 8 ? 32 : 24, 0)
        if DllCall("gdiplus\GdipBitmapLockBits", "Ptr", pBitmap, "Ptr", Rect
            , "UInt", 1, "Int", 0x26200A, "Ptr", bd)
            return false
        scan0 := NumGet(bd, 16, "UPtr")
        stride := NumGet(bd, 8, "Int")

        hasAlpha := false
        loop h {
            y := A_Index - 1
            loop w {
                off := y * stride + (A_Index - 1) * 4 + 3
                if NumGet(scan0, off, "UChar") < 255 {
                    hasAlpha := true
                    break
                }
            }
            if hasAlpha
                break
        }

        bpp := hasAlpha ? 32 : 24
        rowBytes := w * (bpp // 8)
        pixelData := Buffer(rowBytes * h)

        loop h {
            y := A_Index - 1
            srcRow := y * stride
            dstOff := y * rowBytes
            loop w {
                x := A_Index - 1
                srcOff := srcRow + x * 4
                pxOff := dstOff + x * (bpp // 8)
                NumPut("UChar", NumGet(scan0, srcOff + 0, "UChar"), pixelData, pxOff + 0)
                NumPut("UChar", NumGet(scan0, srcOff + 1, "UChar"), pixelData, pxOff + 1)
                NumPut("UChar", NumGet(scan0, srcOff + 2, "UChar"), pixelData, pxOff + 2)
                if hasAlpha
                    NumPut("UChar", NumGet(scan0, srcOff + 3, "UChar"), pixelData, pxOff + 3)
            }
        }

        DllCall("gdiplus\GdipBitmapUnlockBits", "Ptr", pBitmap, "Ptr", bd)

        try {
            f := FileOpen(file, "w")
            if !f
                return false
            f.WriteUChar(0)
            f.WriteUChar(0)
            f.WriteUChar(2)
            f.WriteUShort(0)
            f.WriteUShort(0)
            f.WriteUChar(0)
            f.WriteUShort(0)
            f.WriteUShort(0)
            f.WriteUShort(w)
            f.WriteUShort(h)
            f.WriteUChar(bpp)
            f.WriteUChar(hasAlpha ? 0x28 : 0x20)
            f.RawWrite(pixelData)
            f.Close()
            return true
        } catch {
            return false
        }
    }
}

; ===================================================================
; Extensions supported
; ===================================================================
global SUPPORTED_EXTS := Map(
    "png", true, "jpg", true, "jpeg", true,
    "bmp", true, "tiff", true, "tif", true,
    "tga", true
)


LoadImageFallback(file) {
    ; Pure AHK TGA loader - reads the TGA file directly and creates a GDI+ bitmap
    try {
        f := FileOpen(file, "r")
        if !f
            return 0

        idLen := f.ReadUChar()
        colorMapType := f.ReadUChar()
        imageType := f.ReadUChar()
        colorMapStart := f.ReadUShort()
        colorMapLen := f.ReadUShort()
        colorMapBits := f.ReadUChar()
        xOrigin := f.ReadUShort()
        yOrigin := f.ReadUShort()
        width := f.ReadUShort()
        height := f.ReadUShort()
        pixelDepth := f.ReadUChar()
        descriptor := f.ReadUChar()

        ; Skip image ID
        if idLen > 0
            f.Read(idLen)

        ; Skip color map if present
        if colorMapType = 1 {
            mapBytes := colorMapLen * (colorMapBits // 8)
            if mapBytes > 0
                f.Read(mapBytes)
        }

        ; Determine bytes per pixel
        bpp := pixelDepth // 8
        if bpp < 3
            bpp := 3  ; Minimum 3 bytes for RGB

        ; Check supported types: 2=uncompressed RGB, 3=grayscale, 10=RLE RGB
        if imageType != 2 && imageType != 3 && imageType != 10 && imageType != 11 {
            f.Close()
            return 0
        }

        ; Read pixel data
        totalPixels := width * height
        pixelData := Buffer(totalPixels * 4)

        if imageType = 10 || imageType = 11 {
            ; RLE compressed
            idx := 0
            while idx < totalPixels {
                packet := f.ReadUChar()
                runLength := (packet & 0x7F) + 1
                if packet & 0x80 {
                    ; RLE packet - read one pixel and repeat
                    b := f.ReadUChar()
                    g := f.ReadUChar()
                    r := f.ReadUChar()
                    a := bpp > 3 ? f.ReadUChar() : 255
                    loop runLength {
                        if idx >= totalPixels
                            break
                        offset := idx * 4
                        NumPut("UChar", b, pixelData, offset)
                        NumPut("UChar", g, pixelData, offset + 1)
                        NumPut("UChar", r, pixelData, offset + 2)
                        NumPut("UChar", a, pixelData, offset + 3)
                        idx++
                    }
                } else {
                    ; Raw packet
                    loop runLength {
                        if idx >= totalPixels
                            break
                        offset := idx * 4
                        if bpp >= 3 {
                            NumPut("UChar", f.ReadUChar(), pixelData, offset)       ; B
                            NumPut("UChar", f.ReadUChar(), pixelData, offset + 1)   ; G
                            NumPut("UChar", f.ReadUChar(), pixelData, offset + 2)   ; R
                            if bpp > 3
                                NumPut("UChar", f.ReadUChar(), pixelData, offset + 3)  ; A
                            else
                                NumPut("UChar", 255, pixelData, offset + 3)
                        }
                        idx++
                    }
                }
            }
        } else {
            ; Uncompressed - read pixels one by one (avoids RawRead+Buffer issues)
            loop height {
                y := A_Index - 1
                loop width {
                    x := A_Index - 1
                    dstOffset := (y * width + x) * 4
                    if bpp >= 3 {
                        NumPut("UChar", f.ReadUChar(), pixelData, dstOffset)       ; B
                        NumPut("UChar", f.ReadUChar(), pixelData, dstOffset + 1)   ; G
                        NumPut("UChar", f.ReadUChar(), pixelData, dstOffset + 2)   ; R
                        NumPut("UChar", bpp > 3 ? f.ReadUChar() : 255, pixelData, dstOffset + 3) ; A
                    }
                }
            }
        }

        f.Close()

        ; Handle origin: TGA stores bottom-to-top by default
        ; Bit 5 of descriptor: 0 = bottom-left origin, 1 = top-left origin
        topToBottom := (descriptor >> 5) & 1
        if !topToBottom {
            ; Flip vertically (bottom-to-top to top-to-bottom)
            flipped := Buffer(totalPixels * 4)
            rowSize := width * 4
            loop height {
                y := A_Index - 1
                srcRow := (height - 1 - y) * rowSize
                dstRow := y * rowSize
                DllCall("RtlMoveMemory", "Ptr", flipped.Ptr + dstRow, "Ptr", pixelData.Ptr + srcRow, "UPtr", rowSize)
            }
            pixelData := flipped
        }

        ; Create GDI+ bitmap and copy pixel data via LockBits
        pBitmap := 0
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "UInt", width, "UInt", height
            , "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &pBitmap)
        if !pBitmap
            return 0

        Rect := Buffer(16, 0)
        NumPut("UInt", 0, Rect, 0)
        NumPut("UInt", 0, Rect, 4)
        NumPut("UInt", width, Rect, 8)
        NumPut("UInt", height, Rect, 12)
        bd := Buffer(A_PtrSize = 8 ? 32 : 24, 0)
        if DllCall("gdiplus\GdipBitmapLockBits", "Ptr", pBitmap, "Ptr", Rect
            , "UInt", 2, "Int", 0x26200A, "Ptr", bd) = 0 {
            scan0 := NumGet(bd, 16, "UPtr")
            stride := NumGet(bd, 8, "Int")
            if stride = width * 4 {
                DllCall("RtlMoveMemory", "Ptr", scan0, "Ptr", pixelData.Ptr, "UPtr", totalPixels * 4)
            } else {
                loop height {
                    y := A_Index - 1
                    srcOff := y * width * 4
                    dstOff := y * stride
                    DllCall("RtlMoveMemory", "Ptr", scan0 + dstOff, "Ptr", pixelData.Ptr + srcOff, "UPtr", width * 4)
                }
            }
            DllCall("gdiplus\GdipBitmapUnlockBits", "Ptr", pBitmap, "Ptr", bd)
        }
        return pBitmap
    } catch {
        return 0
    }
    return 0
}

GetDefaultHeatmapColors() {
    return {fill: 0xFFFF0000, edge1: 0xFFFFFF00, edge2: 0xFF80FF00, edge3: 0xFF00FF00
        , edge4: 0xFF00FF80, edge5: 0xFF0000FF, far: 0xFF0000FF}
}

ShowHeatmapColorsDialog(g, *) {
    hc := g.HasOwnProp("_heatmapColors") ? g._heatmapColors : GetDefaultHeatmapColors()
    hcCopy := {fill: hc.fill, edge1: hc.edge1, edge2: hc.edge2, edge3: hc.edge3
        , edge4: hc.edge4, edge5: hc.edge5, far: hc.far}

    myGui := Gui("+AlwaysOnTop +ToolWindow +Border", "Heatmap Colors")
    myGui.BackColor := "2B2D30"
    myGui.SetFont("s9 cCFCFCF", "Segoe UI")

    presets := Map(
        "Default", {fill: 0xFFFF0000, edge1: 0xFFFFFF00, edge2: 0xFF80FF00, edge3: 0xFF00FF00, edge4: 0xFF00FF80, edge5: 0xFF0000FF, far: 0xFF0000FF},
        "Hot", {fill: 0xFFFF0000, edge1: 0xFFFF8000, edge2: 0xFFFFD700, edge3: 0xFFFFFF00, edge4: 0xFFFF8080, edge5: 0xFFFF00FF, far: 0xFFFF00FF},
        "Cool", {fill: 0xFF0000FF, edge1: 0xFF0066FF, edge2: 0xFF00CCFF, edge3: 0xFF00FFCC, edge4: 0xFF00FF66, edge5: 0xFF00FF00, far: 0xFF00FF00},
        "Rainbow", {fill: 0xFFFF0000, edge1: 0xFFFF8000, edge2: 0xFFFFFF00, edge3: 0xFF00FF00, edge4: 0xFF0080FF, edge5: 0xFF0000FF, far: 0xFF8000FF},
        "Monochrome", {fill: 0xFFFFFFFF, edge1: 0xFFE0E0E0, edge2: 0xFFC0C0C0, edge3: 0xFFA0A0A0, edge4: 0xFF808080, edge5: 0xFF606060, far: 0xFF000000},
        "Fire", {fill: 0xFFFF0000, edge1: 0xFFFF4000, edge2: 0xFFFF8000, edge3: 0xFFFFC000, edge4: 0xFFFFFF00, edge5: 0xFFFFFF80, far: 0xFFFFFFFF},
        "Ocean", {fill: 0xFF000080, edge1: 0xFF0000FF, edge2: 0xFF0080FF, edge3: 0xFF00FFFF, edge4: 0xFF80FFFF, edge5: 0xFFC0FFFF, far: 0xFFFFFFFF},
        "Sunset", {fill: 0xFF800080, edge1: 0xFFFF00FF, edge2: 0xFFFF0080, edge3: 0xFFFF0000, edge4: 0xFFFF8000, edge5: 0xFFFFFF00, far: 0xFFFFFF00},
        "Forest", {fill: 0xFF004000, edge1: 0xFF008000, edge2: 0xFF00C000, edge3: 0xFF80FF00, edge4: 0xFFC0FF00, edge5: 0xFFFFFF00, far: 0xFFFFFF80},
        "Plasma", {fill: 0xFF440088, edge1: 0xFF7700AA, edge2: 0xFFAA0055, edge3: 0xFFDD3333, edge4: 0xFFFF8833, edge5: 0xFFFFCC44, far: 0xFFFFEE88}
    )
; ==========================================================
; GRADIENT PREVIEW BAR
; ==========================================================

myGui.AddText("x10 y6 w200 h18 vHC_grad_label", FormatColorArgb(hc.fill) " > " FormatColorArgb(hc.far))

barW := 195
steps := ["fill", "edge1", "edge2", "edge3", "edge4", "edge5", "far"]
segW := (barW - 6) // steps.Length
x := 10
for _, f in steps {
    hex := Format("{:06X}", (hc.%f% & 0xFFFFFF))
    myGui.AddProgress("x" x " y25 w" segW " h10 c" hex " Range0-1 vHC_grad_" f, 1)
    x += segW + 1
}

; ==========================================================
; LEFT COLUMN - COLORS
; ==========================================================

myGui.AddGroupBox("x5 y40 w225 h210", "Colors")

myGui.AddText("x15 y65", "Transparent:")
myGui.AddEdit("x95 y63 w80 BackgroundFFFFFF c000000 vHC_fill", FormatColorArgb(hc.fill))
myGui.AddProgress("x180 y64 w20 h18 cFF0000 Range0-1 vHC_fillSw", 1)

myGui.AddText("x15 y91", "Edge 1:")
myGui.AddEdit("x95 y89 w80 BackgroundFFFFFF c000000 vHC_edge1", FormatColorArgb(hc.edge1))
myGui.AddProgress("x180 y90 w20 h18 cFFFF00 Range0-1 vHC_edge1Sw", 1)

myGui.AddText("x15 y117", "Edge 2:")
myGui.AddEdit("x95 y115 w80 BackgroundFFFFFF c000000 vHC_edge2", FormatColorArgb(hc.edge2))
myGui.AddProgress("x180 y116 w20 h18 c80FF00 Range0-1 vHC_edge2Sw", 1)

myGui.AddText("x15 y143", "Edge 3:")
myGui.AddEdit("x95 y141 w80 BackgroundFFFFFF c000000 vHC_edge3", FormatColorArgb(hc.edge3))
myGui.AddProgress("x180 y142 w20 h18 c00FF00 Range0-1 vHC_edge3Sw", 1)

myGui.AddText("x15 y169", "Edge 4:")
myGui.AddEdit("x95 y167 w80 BackgroundFFFFFF c000000 vHC_edge4", FormatColorArgb(hc.edge4))
myGui.AddProgress("x180 y168 w20 h18 c00FF80 Range0-1 vHC_edge4Sw", 1)

myGui.AddText("x15 y195", "Edge 5:")
myGui.AddEdit("x95 y193 w80 BackgroundFFFFFF c000000 vHC_edge5", FormatColorArgb(hc.edge5))
myGui.AddProgress("x180 y194 w20 h18 c0000FF Range0-1 vHC_edge5Sw", 1)

myGui.AddText("x15 y221", "Far:")
myGui.AddEdit("x95 y219 w80 BackgroundFFFFFF c000000 vHC_far", FormatColorArgb(hc.far))
myGui.AddProgress("x180 y220 w20 h18 c0000FF Range0-1 vHC_farSw", 1)

; ==========================================================
; RIGHT COLUMN - PRESETS
; ==========================================================

myGui.AddGroupBox("x240 y5 w145 h280", "Presets")

presetY := 28

for name in presets {
    pVal := presets[name]

    myGui.AddButton(
        "x252 y" presetY
        " w120 h22 Background3A3C42 cFFFFFF",
        name
    ).OnEvent("Click", ApplyPreset.Bind(pVal, hcCopy, myGui))

    presetY += 25
}

; ==========================================================
; SWATCH SYNC
; ==========================================================

myGui._syncingHeatmapSwatch := false

for _, f in ["fill", "edge1", "edge2", "edge3", "edge4", "edge5", "far"]
    myGui["HC_" f].OnEvent("Change", SyncHeatmapSwatch.Bind(myGui, f))

; ==========================================================
; ACTION BUTTONS
; ==========================================================

myGui.AddButton(
    "x10 y260 w100 h28 Background3A3C42 cFFFFFF Default",
    "OK"
).OnEvent("Click", (*) => (
    hcCopy.fill  := ParseColorArgb(myGui["HC_fill"].Value),
    hcCopy.edge1 := ParseColorArgb(myGui["HC_edge1"].Value),
    hcCopy.edge2 := ParseColorArgb(myGui["HC_edge2"].Value),
    hcCopy.edge3 := ParseColorArgb(myGui["HC_edge3"].Value),
    hcCopy.edge4 := ParseColorArgb(myGui["HC_edge4"].Value),
    hcCopy.edge5 := ParseColorArgb(myGui["HC_edge5"].Value),
    hcCopy.far   := ParseColorArgb(myGui["HC_far"].Value),
    g._heatmapColors := hcCopy,
    g._defaultSettings := CaptureUiSettings(g),
    UpdateMainGradient(g),
    g._pendingRefresh := true,
    g["PreviewRefresh"].Text := "Apply!",
    g["PreviewRefresh"].Opt("BackgroundD97706 cffffff"),
    myGui.Destroy()
))

myGui.AddButton(
    "x120 y260 w100 h28 Background3A3C42 cFFFFFF",
    "Cancel"
).OnEvent("Click", (*) => myGui.Destroy())

myGui.OnEvent("Close", (*) => myGui.Destroy())

myGui.Show("w390 h300")
}

SyncHeatmapSwatch(myGui, field, *) {
    if myGui._syncingHeatmapSwatch
        return
    ctrl := myGui["HC_" field]
    swatch := myGui["HC_" field "Sw"]
    colorStr := Trim(ctrl.Value)
    if RegExMatch(colorStr, "i)^#?[0-9a-f]{6}$") {
        hex := RegExReplace(colorStr, "^#", "")
        swatch.Opt("c" hex)
        swatch.Value := 1
        hc := {}
        for _, f in ["fill", "edge1", "edge2", "edge3", "edge4", "edge5", "far"]
            hc.%f% := ParseColorArgb(myGui["HC_" f].Value)
        UpdateGradientPreview(myGui, hc)
    }
}

ApplyPreset(p, hcCopy, myGui, *) {
    hcCopy.fill := p.fill
    hcCopy.edge1 := p.edge1
    hcCopy.edge2 := p.edge2
    hcCopy.edge3 := p.edge3
    hcCopy.edge4 := p.edge4
    hcCopy.edge5 := p.edge5
    hcCopy.far := p.far
    myGui._syncingHeatmapSwatch := true
    for _, f in ["fill", "edge1", "edge2", "edge3", "edge4", "edge5", "far"] {
        hex := Format("{:06X}", (p.%f% & 0xFFFFFF))
        myGui["HC_" f].Value := "#" hex
        myGui["HC_" f "Sw"].Opt("c" hex)
        myGui["HC_" f "Sw"].Value := 1
    }
    UpdateGradientPreview(myGui, p)
    myGui._syncingHeatmapSwatch := false
}

UpdateGradientPreview(myGui, hcCopy) {
    barW := 195
    steps := ["fill", "edge1", "edge2", "edge3", "edge4", "edge5", "far"]
    segW := (barW - 6) // steps.Length
    x := 10
    for _, f in steps {
        hex := Format("{:06X}", (hcCopy.%f% & 0xFFFFFF))
        ctrl := myGui["HC_grad_" f]
        ctrl.Opt("c" hex)
        ctrl.Value := 1
        x += segW + 1
    }
    myGui["HC_grad_label"].Value := FormatColorArgb(hcCopy.fill) " > " FormatColorArgb(hcCopy.far)
}

UpdateMainGradient(g) {
    hc := g.HasOwnProp("_heatmapColors") ? g._heatmapColors : GetDefaultHeatmapColors()
    for _, f in ["fill", "edge1", "edge2", "edge3", "edge4", "edge5", "far"] {
        hex := Format("{:06X}", (hc.%f% & 0xFFFFFF))
        ctrl := g["MainGrad_" f]
        ctrl.Opt("c" hex)
        ctrl.Value := 1
    }
    g["MainGradLabel"].Value := FormatColorArgb(hc.fill) " > " FormatColorArgb(hc.far)
}

FormatColorArgb(argb) {
    r := Format("{:02X}", (argb >> 16) & 0xFF)
    g := Format("{:02X}", (argb >> 8) & 0xFF)
    b := Format("{:02X}", argb & 0xFF)
    return "#" r g b
}

ParseColorArgb(text) {
    text := Trim(text)
    if SubStr(text, 1, 1) = "#"
        text := SubStr(text, 2)
    if StrLen(text) = 6 {
        r := Integer("0x" SubStr(text, 1, 2))
        g := Integer("0x" SubStr(text, 3, 2))
        b := Integer("0x" SubStr(text, 5, 2))
    } else
        return 0xFFFF0000
    return 0xFF000000 | (r << 16) | (g << 8) | b
}

; ===================================================================
; Image Processing - Paint Checker
; ===================================================================
ProcessPaintCheck(pBitmap, alphaThreshold := 128, fillColor := "#FF00FF", progressCb := 0, heatmapColors := 0) {
    dims := GDI.GetDimensions(pBitmap)
    w := dims.w, h := dims.h

    pFilled := GDI.CreateBitmap(w, h)
    pHeatmap := GDI.CreateBitmap(w, h)

    if !pFilled || !pHeatmap
        return 0

    fillArgb := HexColorToArgb(fillColor)
    transparentPixels := 0
    minX := w, minY := h, maxX := 0, maxY := 0
    alphaBuckets := [0, 0, 0, 0, 0]

    ; Lock source bitmap for reading
    Rect := Buffer(16, 0)
    NumPut("UInt", 0, Rect, 0)
    NumPut("UInt", 0, Rect, 4)
    NumPut("UInt", w, Rect, 8)
    NumPut("UInt", h, Rect, 12)
    bdSize := A_PtrSize = 8 ? 32 : 24
    srcBd := Buffer(bdSize, 0)
    DllCall("gdiplus\GdipBitmapLockBits", "Ptr", pBitmap, "Ptr", Rect
        , "UInt", 1, "Int", 0x26200A, "Ptr", srcBd)
    srcScan0 := NumGet(srcBd, 16, "UPtr")
    srcStride := NumGet(srcBd, 8, "Int")

    ; Lock filled bitmap for writing
    fillBd := Buffer(bdSize, 0)
    DllCall("gdiplus\GdipBitmapLockBits", "Ptr", pFilled, "Ptr", Rect
        , "UInt", 2, "Int", 0x26200A, "Ptr", fillBd)
    fillScan0 := NumGet(fillBd, 16, "UPtr")
    fillStride := NumGet(fillBd, 8, "Int")

    ; Lock heatmap bitmap for writing
    heatBd := Buffer(bdSize, 0)
    DllCall("gdiplus\GdipBitmapLockBits", "Ptr", pHeatmap, "Ptr", Rect
        , "UInt", 2, "Int", 0x26200A, "Ptr", heatBd)
    heatScan0 := NumGet(heatBd, 16, "UPtr")
    heatStride := NumGet(heatBd, 8, "Int")

    ; Resolve heatmap colors before first pass (used by both loops)
    hc := IsObject(heatmapColors) && heatmapColors.HasOwnProp("fill") ? heatmapColors : GetDefaultHeatmapColors()
    transColor := hc.fill
    edgeArr := [0, hc.edge1, hc.edge2, hc.edge3, hc.edge4, hc.edge5]
    farColor := hc.far

    ; Allocate distance buffer for edge gradient
    maxEdgeDist := 5
    distBuf := Buffer(w * h, 0xFF)

    ; Process all pixels via direct memory access
    loop h {
        y := A_Index - 1
        loop w {
            x := A_Index - 1
            srcOff := y * srcStride + x * 4
            fillOff := y * fillStride + x * 4
            heatOff := y * heatStride + x * 4

            a := NumGet(srcScan0, srcOff + 3, "UChar")

            if a < alphaThreshold {
                transparentPixels++

                if x < minX
                    minX := x
                if y < minY
                    minY := y
                if x > maxX
                    maxX := x
                if y > maxY
                    maxY := y

                ; Filled: opaque magenta marker
                NumPut("UInt", fillArgb, fillScan0, fillOff)

                if a < 26
                    alphaBuckets[1]++
                else if a < 51
                    alphaBuckets[2]++
                else if a < 77
                    alphaBuckets[3]++
                else if a < 103
                    alphaBuckets[4]++
                else
                    alphaBuckets[5]++

                ; Heatmap: configurable color for transparent pixels
                NumPut("UInt", transColor, heatScan0, heatOff)

                ; Distance 0 (transparent pixel)
                NumPut("UChar", 0, distBuf, y * w + x)

            } else {
                ; Filled: fully transparent (no marker)
                NumPut("UInt", 0x00000000, fillScan0, fillOff)

                ; Heatmap: leave as 0 for now (overwritten by edge/fill pass)

            }
        }
        if progressCb && (Mod(y, 50) = 0 || y = h - 1)
            progressCb.Call(y + 1, h)
    }

    ; Distance transform (multi-pass dilation)
    loop maxEdgeDist {
        d := A_Index
        y := 0
        while y < h {
            yy := y
            x := 0
            while x < w {
                off := yy * w + x
                val := NumGet(distBuf, off, "UChar")
                if val != 255 {
                    x++
                    continue
                }
                if (yy > 0 && NumGet(distBuf, (yy - 1) * w + x, "UChar") = d - 1)
                    or (yy < h - 1 && NumGet(distBuf, (yy + 1) * w + x, "UChar") = d - 1)
                    or (x > 0 && NumGet(distBuf, yy * w + x - 1, "UChar") = d - 1)
                    or (x < w - 1 && NumGet(distBuf, yy * w + x + 1, "UChar") = d - 1)
                        NumPut("UChar", d, distBuf, off)
                x++
            }
            y++
        }
    }

    loop h {
        y := A_Index - 1
        loop w {
            x := A_Index - 1
            off := y * w + x
            heatOff := y * heatStride + x * 4
            val := NumGet(distBuf, off, "UChar")

            if val = 0
                continue

            NumPut("UInt", val <= maxEdgeDist ? edgeArr[val] : farColor, heatScan0, heatOff)
        }
    }

    ; Unlock all bitmaps
    DllCall("gdiplus\GdipBitmapUnlockBits", "Ptr", pBitmap, "Ptr", srcBd)
    DllCall("gdiplus\GdipBitmapUnlockBits", "Ptr", pFilled, "Ptr", fillBd)
    DllCall("gdiplus\GdipBitmapUnlockBits", "Ptr", pHeatmap, "Ptr", heatBd)

    clusters := transparentPixels > 0 ? FindTransparentClusters(pBitmap, w, h, alphaThreshold) : []

    totalPixels := w * h
    transparentPercent := Round(transparentPixels / totalPixels * 100, 2)

    result := {
        filled: pFilled,
        heatmap: pHeatmap,
        transparentCount: transparentPixels,
        totalPixels: totalPixels,
        transparentPercent: transparentPercent,
        width: w,
        height: h,
        minX: minX, minY: minY, maxX: maxX, maxY: maxY,
        hasTransparency: transparentPixels > 0,
        clusters: clusters,
        alphaBuckets: alphaBuckets
    }

    return result
}

FindTransparentClusters(pBitmap, w, h, alphaThreshold) {
    ; Lock source bitmap for reading
    Rect := Buffer(16, 0)
    NumPut("UInt", 0, Rect, 0)
    NumPut("UInt", 0, Rect, 4)
    NumPut("UInt", w, Rect, 8)
    NumPut("UInt", h, Rect, 12)
    bdSize := A_PtrSize = 8 ? 32 : 24
    bd := Buffer(bdSize, 0)
    DllCall("gdiplus\GdipBitmapLockBits", "Ptr", pBitmap, "Ptr", Rect
        , "UInt", 1, "Int", 0x26200A, "Ptr", bd)
    scan0 := NumGet(bd, 16, "UPtr")
    stride := NumGet(bd, 8, "Int")

    visited := Buffer(w * h, 0)
    clusters := []

    loop h {
        y := A_Index - 1
        loop w {
            x := A_Index - 1
            off := y * w + x
            if NumGet(visited, off, "UChar")
                continue
            a := NumGet(scan0, y * stride + x * 4 + 3, "UChar")
            if a >= alphaThreshold {
                NumPut("UChar", 1, visited, off)
                continue
            }

            cluster := {x1: x, y1: y, x2: x, y2: y, count: 0}
            stack := [{x: x, y: y}]
            NumPut("UChar", 1, visited, off)

            while stack.Length > 0 {
                p := stack.Pop()
                cx := p.x, cy := p.y
                cluster.count++
                if cx < cluster.x1
                    cluster.x1 := cx
                if cy < cluster.y1
                    cluster.y1 := cy
                if cx > cluster.x2
                    cluster.x2 := cx
                if cy > cluster.y2
                    cluster.y2 := cy

                ; Left
                if cx > 0 {
                    nOff := cy * w + (cx - 1)
                    if !NumGet(visited, nOff, "UChar") {
                        NumPut("UChar", 1, visited, nOff)
                        if NumGet(scan0, cy * stride + (cx - 1) * 4 + 3, "UChar") < alphaThreshold
                            stack.Push({x: cx - 1, y: cy})
                    }
                }
                ; Right
                if cx < w - 1 {
                    nOff := cy * w + (cx + 1)
                    if !NumGet(visited, nOff, "UChar") {
                        NumPut("UChar", 1, visited, nOff)
                        if NumGet(scan0, cy * stride + (cx + 1) * 4 + 3, "UChar") < alphaThreshold
                            stack.Push({x: cx + 1, y: cy})
                    }
                }
                ; Up
                if cy > 0 {
                    nOff := (cy - 1) * w + cx
                    if !NumGet(visited, nOff, "UChar") {
                        NumPut("UChar", 1, visited, nOff)
                        if NumGet(scan0, (cy - 1) * stride + cx * 4 + 3, "UChar") < alphaThreshold
                            stack.Push({x: cx, y: cy - 1})
                    }
                }
                ; Down
                if cy < h - 1 {
                    nOff := (cy + 1) * w + cx
                    if !NumGet(visited, nOff, "UChar") {
                        NumPut("UChar", 1, visited, nOff)
                        if NumGet(scan0, (cy + 1) * stride + cx * 4 + 3, "UChar") < alphaThreshold
                            stack.Push({x: cx, y: cy + 1})
                    }
                }
            }

            cluster.width := cluster.x2 - cluster.x1 + 1
            cluster.height := cluster.y2 - cluster.y1 + 1
            clusters.Push(cluster)
        }
    }

    DllCall("gdiplus\GdipBitmapUnlockBits", "Ptr", pBitmap, "Ptr", bd)

    ; Sort clusters by count descending (simple bubble sort)
    loop clusters.Length - 1 {
        swapped := false
        i := 1
        while i < clusters.Length {
            if clusters[i].count < clusters[i+1].count {
                tmp := clusters[i]
                clusters[i] := clusters[i+1]
                clusters[i+1] := tmp
                swapped := true
            }
            i++
        }
        if !swapped
            break
    }

    return clusters
}

GenerateReport(result, inputFile := "") {
    report := ""
    report .= "============================================`n"
    report .= "   Nastarxa Paint Checker - Analysis Report`n"
    report .= "============================================`n`n"

    if inputFile
        report .= "File: " inputFile "`n"

    report .= "Image Size: " result.totalPixels " pixels`n"
    report .= "Transparent Pixels: " result.transparentCount "`n"
    report .= "Transparent Area: " result.transparentPercent "%`n`n"

    if !result.hasTransparency {
        report .= "No transparent pixels detected in this image.`n"
        return report
    }

    report .= "--- Overall Bounding Box ---`n"
    report .= "Top-Left: (" result.minX ", " result.minY ")`n"
    report .= "Bottom-Right: (" result.maxX ", " result.maxY ")`n"
    report .= "Width: " (result.maxX - result.minX + 1) " px`n"
    report .= "Height: " (result.maxY - result.minY + 1) " px`n`n"

    report .= "--- Transparency Distribution ---`n"
    report .= "Fully transparent (alpha 0-25): " result.alphaBuckets[1] " px`n"
    report .= "Nearly transparent (alpha 26-50): " result.alphaBuckets[2] " px`n"
    report .= "Somewhat transparent (alpha 51-76): " result.alphaBuckets[3] " px`n"
    report .= "Lightly transparent (alpha 77-102): " result.alphaBuckets[4] " px`n"
    report .= "Barely transparent (alpha 103-127): " result.alphaBuckets[5] " px`n`n"

    report .= "--- Clusters (Connected Components) ---`n"
    report .= "Total clusters found: " result.clusters.Length "`n`n"

    for i, cluster in result.clusters {
        report .= "Cluster #" i ":`n"
        report .= "  Bounding Box: (" cluster.x1 "," cluster.y1 ") -> (" cluster.x2 "," cluster.y2 ")`n"
        report .= "  Size: " cluster.width " x " cluster.height " px`n"
        report .= "  Pixel Count: " cluster.count "`n"
        report .= "  Center: (" Round((cluster.x1 + cluster.x2) / 2) ", " Round((cluster.y1 + cluster.y2) / 2) ")`n`n"
    }

    return report
}

; ===================================================================
; GUI
; ===================================================================
BuildGui() {
    g := Gui("+Resize +MinSize1120x900 +E0x10", "Nastarxa Paint Checker")
    g.BackColor := "2B2D31"
    AddHeader(g)
    AddInputPanel(g)
    AddReportPanel(g)
    AddPreviewPanel(g)
    AddStatusAndActions(g)

    g._dropHandler := DropFilesHandler.Bind(g)
    OnMessage(0x0233, g._dropHandler)

    g._files := []
    g._results := []
    g._currentIndex := 0
    g._defaultSettings := 0

    g.Show("w1160 h917")
    SyncFillColorUi(g, g["FillColor"].Value)
    g._heatmapColors := GetDefaultHeatmapColors()
    g._defaultSettings := CaptureUiSettings(g)
    WireSettingEvents(g)
    UpdateMainGradient(g)
    return g
}

AddHeader(g) {
    g.SetFont("s11 w700", "Segoe UI")
    g.AddText("x15 y12 cFFFFFF", "Nastarxa Paint Checker")

    g.SetFont("s8 norm cAAAAAA", "Segoe UI")
    g.AddText("x15 y34", "Detects transparent areas and fills them with a chosen color")
}

AddInputPanel(g) {
    g.AddGroupBox("x10 y55 w760 h316", "Input and Settings")
    g.SetFont("s9 norm", "Segoe UI")

    g.AddText("x25 y82 cCFCFCF", "Input Path")
    g.AddEdit("x25 y100 w614 h24 BackgroundFFFFFF c000000 vInputPath ReadOnly")
    g.AddButton("x645 y100 w30 h24", "...").OnEvent("Click", BrowseInput.Bind(g))
    g.AddButton("x680 y100 w80 h24", "Browse").OnEvent("Click", BrowseInput.Bind(g))

    g.AddText("x25 y132 cCFCFCF", "Output Folder")
    g.AddEdit("x25 y150 w614 h24 BackgroundFFFFFF c000000 vOutputPath ReadOnly")
    g.AddButton("x645 y150 w30 h24", "...").OnEvent("Click", BrowseOutput.Bind(g))
    g.AddButton("x680 y150 w80 h24", "Browse").OnEvent("Click", BrowseOutput.Bind(g))

    g.AddCheckBox("x25 y180 Checked vMakeFolder cCFCFCF", "Create Output Folder")
    g.AddCheckBox("x180 y180 vRecursive cCFCFCF", "Include Subfolders")
    g.AddCheckBox("x320 y180 vZipExport cCFCFCF", "Export Outputs as ZIP")

    ; ==========================================================
    ; LEFT: SAVE OUTPUTS
    ; ==========================================================

    g.AddText("x25 y205 cCFCFCF", "Save Outputs:")
    g.AddCheckBox("x25 y225 vSaveFill cCFCFCF", "Filled")
    g.AddCheckBox("x+5 yp vSaveHeatmap cCFCFCF", "Heatmap")
    g.AddCheckBox("x+5 yp Checked vSaveOverlay cCFCFCF", "Overlay")
    g.AddCheckBox("x+5 yp vSaveReport cCFCFCF", "Report")

    ; ==========================================================
    ; CENTER: FILL COLOR
    ; ==========================================================

    g.AddText("x298 y205 cCFCFCF", "Fill Color:")
    g.AddEdit("x298 y225 w72 h24 BackgroundFFFFFF c000000 vFillColor","#FF00FF")
    g.AddProgress("x376 y225 w20 h20 cFF00FF Range0-1 vFillColorPreview",1)
    presetX := 403
    for i, preset in GetFillColorPresets() {
        swatch := g.AddText("x" presetX " y225 w20 h20 Border Background" SubStr(preset, 2)
            " c000000 vFillPreset" i, " ")
        swatch.OnEvent("Click", ApplyFillColorChoice.Bind(g, preset))
        presetX += 22
    }

    ; ==========================================================
    ; RIGHT: HEATMAP COLORS
    ; ==========================================================

    gBarW := 170
    gSteps := ["fill", "edge1", "edge2", "edge3", "edge4", "edge5", "far"]
    gSegW := (gBarW - 6) // gSteps.Length
    gx := 592
    hc0 := g.HasOwnProp("_heatmapColors") ? g._heatmapColors : GetDefaultHeatmapColors()
    for _, f in gSteps {
        hex := Format("{:06X}", (hc0.%f% & 0xFFFFFF))
        g.AddProgress("x" gx " y242 w" gSegW " h10 c" hex " Range0-1 vMainGrad_" f, 1)
        gx += gSegW + 1
    }
    g.AddText("x592 y254 w170 h14 cAAAAAA Center vMainGradLabel"
        , FormatColorArgb(hc0.fill) " > " FormatColorArgb(hc0.far))
    g.AddButton("x590 y214 w170 h24 cFFFFFF Background3A3C42 vHeatmapColorsBtn", "Heatmap Colors")
        .OnEvent("Click", ShowHeatmapColorsDialog.Bind(g))



    g.AddText("x25 y260 cCFCFCF", "Alpha Threshold")
    s := g.AddSlider("x20 y277 w300 h20 Range0-255 Tooltip vAlphaThreshold", 128)
    g.AddText("x328 y277 w30 cFFFFFF vAlphaVal", "128")
    s.OnEvent("Change", (*) => g["AlphaVal"].Text := g["AlphaThreshold"].Value)

    g.AddText("x363 y260 cCFCFCF", "Overlay Heatmap Opacity")
    g.AddSlider("x358 y277 w100 h20 Range0-100 Tooltip vHeatmapOpacity", 35)
    g.AddText("x462 y277 w42 h18 cFFFFFF Center vHeatmapOpacityVal", "35%")


    g.AddCheckBox("x522 y277 vWhiteInclude cCFCFCF", "Include white pixels")
    g.AddCheckBox("x665 y277 vFillOnTop cCFCFCF", "Fill On Top")

    g.AddText("x25 y305 cCFCFCF", "Name Template:")
    g.AddText("x117 y305 cAFAFAF", "{name} | {width} | {height} | {date} | {time}")
    g.AddEdit("x25 y325 w410 h22 BackgroundFFFFFF c000000 vNameTemplate", "{name}")
    g.AddButton("x450 y325 w100 h24 vFileListBtn cFFFFFF Background3A3C42", "📄 File List")
        .OnEvent("Click", ShowFileList.Bind(g))
    g.AddButton("x555 y325 w100 h24 vGuideBtn cFFFFFF Background3A3C42", "❓ Guide")
        .OnEvent("Click", ShowGuide.Bind(g))
    g.AddButton("x660 y325 w100 h24 vResetBtn cFFFFFF Background3A3C42", "🔄 Reset")
        .OnEvent("Click", ResetSettings.Bind(g))
}

AddReportPanel(g) {
    g.AddGroupBox("x785 y55 w330 h770", "Analysis Report")
    g.SetFont("s8", "Consolas")
    g.AddEdit(
        "x786 y75 w328 h750 "
        . "Backgroundffffff c000000 "
        . "ReadOnly vReportText"
    )
}

AddPreviewPanel(g) {
    g.AddGroupBox("x10 y375 w760 h452", "Preview")
    g.SetFont("s8", "Segoe UI")

    AddPreviewTile(g, 25, 400, "OrigPreview", "OrigLabel", "OrigViewBtn", "Original", "orig")
    AddPreviewTile(g, 400, 400, "FillPreview", "FillLabel", "FillViewBtn", "Filled", "fill")
    AddPreviewTile(g, 25, 600, "HeatPreview", "HeatLabel", "HeatViewBtn", "Heatmap", "heat")
    AddPreviewTile(g, 400, 600, "DupPreview", "DupLabel", "DupViewBtn", "Overlay", "overlay")

    AddPreviewToggles(g)
    AddPreviewNavigation(g)
}

AddPreviewTile(g, x, y, picName, labelName, btnName, labelText, which) {
    g.AddPic("x" x " y" y " w360 h170 Background23262C v" picName)
    g.AddText("x" x " y" (y + 175) " w270 Center cAAAAAA v" labelName, labelText)
    btn := g.AddButton("x" (x + 285) " y" (y + 175) " w75 h18 cFFFFFF Background3A3C42 v" btnName, "View Full")
    btn.OnEvent("Click", (*) => ShowZoomWindow(g, which))
    g[picName].OnEvent("DoubleClick", (*) => ShowZoomWindow(g, which))
}

AddPreviewToggles(g) {
    g.AddText("x25 y797 w70 h22 cFFFFFF Background3A3C42 Center +0x100 +0x200 vPreviewRefresh", "Refresh")
        .OnEvent("Click", ReprocessCurrent.Bind(g))
    g.AddText("x410 y800 cCFCFCF", "Combined Overlay:")
    g.AddCheckBox("x510 y800 Checked vShowOrig cAAAAAA", "Original")
    g.AddCheckBox("x580 y800 Checked vShowFill cAAAAAA", "Fill")
    g.AddCheckBox("x625 y800 Checked vShowHeatmap cAAAAAA", "Heatmap")
}

AddPreviewNavigation(g) {
    g.AddText("x10 y833 w345 h30 Background23262C cCFCFCF vNavInfo", "No image selected")
    g.AddButton("x360 y831 w35 h30 cFFFFFF Background3A3C42 vNavPrev", "<").OnEvent("Click", NavigatePrev.Bind(g))
    g.AddButton("x400 y831 w35 h30 cFFFFFF Background3A3C42 vNavNext", ">").OnEvent("Click", NavigateNext.Bind(g))
    g.AddText("x440 y833 w330 h30 Background23262C cAAAAAA vNavTimer", "")
    g["NavPrev"].Enabled := false
    g["NavNext"].Enabled := false
}

AddStatusAndActions(g) {
    g.SetFont("s8", "Segoe UI")

    g.AddText(
        "x10 y867 w760 h22 Background23262C "
        . "cAAAAAA vStatusText",
        "Drop image files or a folder here to begin."
    )

    g.AddProgress(
        "x10 y892 w760 h18 "
        . "cE8A93A Background23262C "
        . "Range0-100 vProgressBar",
        0
    )
    g.SetFont("s9", "Segoe UI")

    g.AddButton("x785 y833 w90 h30", "▶️ Start")
        .OnEvent("Click", StartProcessing.Bind(g))

    g.AddButton("x880 y833 w75 h30", "💾 Save All")
        .OnEvent("Click", SaveAll.Bind(g))

    g.AddButton("x960 y833 w75 h30", "🧹 Clear")
        .OnEvent("Click", ClearAll.Bind(g))

    g.AddButton("x1040 y833 w75 h30", "📂 Folder")
        .OnEvent("Click", OpenOutputFolder.Bind(g))
}

RefreshCurrentPreview(g) {
    if g._currentIndex < 1 || g._currentIndex > g._files.Length
        return

    file := g._files[g._currentIndex]
    for r in g._results {
        if ResultMatchesFile(r, file) {
            ShowPreview(g, r)
            return
        }
    }
    LoadAndShowFile(g, g._currentIndex)
}

CaptureUiSettings(g) {
    hc := g.HasOwnProp("_heatmapColors") ? g._heatmapColors : GetDefaultHeatmapColors()
    return {
        alphaThreshold: g["AlphaThreshold"].Value,
        heatmapOpacity: g["HeatmapOpacity"].Value,
        fillColor: NormalizeHexColor(g["FillColor"].Value),
        fillOnTop: g["FillOnTop"].Value,
        saveFill: g["SaveFill"].Value,
        saveHeatmap: g["SaveHeatmap"].Value,
        saveOverlay: g["SaveOverlay"].Value,
        saveReport: g["SaveReport"].Value,
        zipExport: g["ZipExport"].Value,
        makeFolder: g["MakeFolder"].Value,
        recursive: g["Recursive"].Value,
        nameTemplate: g["NameTemplate"].Value,
        whiteInclude: g["WhiteInclude"].Value,
        showHeatmap: g["ShowHeatmap"].Value,
        showOrig: g["ShowOrig"].Value,
        showFill: g["ShowFill"].Value,
        heatmapColors: {fill: hc.fill, edge1: hc.edge1, edge2: hc.edge2, edge3: hc.edge3
            , edge4: hc.edge4, edge5: hc.edge5, far: hc.far}
    }
}

ApplyUiSettings(g, settings) {
    if !IsObject(settings)
        return
    g._applyingSettings := true
    try {
        if settings.HasOwnProp("alphaThreshold") {
            g["AlphaThreshold"].Value := settings.alphaThreshold
            g["AlphaVal"].Text := settings.alphaThreshold
        }
        if settings.HasOwnProp("heatmapOpacity") {
            g["HeatmapOpacity"].Value := settings.heatmapOpacity
            g["HeatmapOpacityVal"].Text := settings.heatmapOpacity "%"
        }
        if settings.HasOwnProp("fillColor")
            SyncFillColorUi(g, settings.fillColor)
        if settings.HasOwnProp("fillOnTop")
            g["FillOnTop"].Value := settings.fillOnTop
        if settings.HasOwnProp("saveFill")
            g["SaveFill"].Value := settings.saveFill
        if settings.HasOwnProp("saveHeatmap")
            g["SaveHeatmap"].Value := settings.saveHeatmap
        if settings.HasOwnProp("saveOverlay")
            g["SaveOverlay"].Value := settings.saveOverlay
        if settings.HasOwnProp("saveReport")
            g["SaveReport"].Value := settings.saveReport
        if settings.HasOwnProp("zipExport")
            g["ZipExport"].Value := settings.zipExport
        if settings.HasOwnProp("makeFolder")
            g["MakeFolder"].Value := settings.makeFolder
        if settings.HasOwnProp("recursive")
            g["Recursive"].Value := settings.recursive
        if settings.HasOwnProp("nameTemplate")
            g["NameTemplate"].Value := settings.nameTemplate
        if settings.HasOwnProp("whiteInclude")
            g["WhiteInclude"].Value := settings.whiteInclude
        if settings.HasOwnProp("showHeatmap")
            g["ShowHeatmap"].Value := settings.showHeatmap
        if settings.HasOwnProp("showOrig")
            g["ShowOrig"].Value := settings.showOrig
        if settings.HasOwnProp("showFill")
            g["ShowFill"].Value := settings.showFill
        if settings.HasOwnProp("heatmapColors") && IsObject(settings.heatmapColors)
            g._heatmapColors := settings.heatmapColors
    } finally {
        g._applyingSettings := false
    }
}

GetActiveResult(g) {
    if g._currentIndex < 1 || g._currentIndex > g._files.Length
        return 0
    file := g._files[g._currentIndex]
    for r in g._results {
        if ResultMatchesFile(r, file)
            return r
    }
    return 0
}

WireSettingEvents(g) {
    for _, name in ["SaveFill", "SaveHeatmap", "SaveOverlay", "SaveReport"
        , "ZipExport", "MakeFolder", "Recursive", "WhiteInclude"
        , "ShowHeatmap", "ShowOrig", "ShowFill", "FillOnTop"] {
        g[name].OnEvent("Click", (*) => OnSettingChanged(g))
    }

    g["FillColor"].OnEvent("Change", (*) => (
        FillColorEditChanged(g) ? OnSettingChanged(g) : 0
    ))

    g["AlphaThreshold"].OnEvent("Change", (*) => (
        g["AlphaVal"].Text := g["AlphaThreshold"].Value,
        OnSettingChanged(g)
    ))
    g["HeatmapOpacity"].OnEvent("Change", (*) => (
        g["HeatmapOpacityVal"].Text := g["HeatmapOpacity"].Value "%",
        OnSettingChanged(g)
    ))
    g["NameTemplate"].OnEvent("Change", (*) => OnSettingChanged(g))
}

OnSettingChanged(g, *) {
    if g.HasOwnProp("_applyingSettings") && g._applyingSettings
        return
    g._defaultSettings := CaptureUiSettings(g)
    RefreshCurrentPreview(g)
    g._pendingRefresh := true
    if g.HasOwnProp("PreviewRefresh") {
        g["PreviewRefresh"].Text := "Apply!"
        g["PreviewRefresh"].Opt("BackgroundFF8800 c000000")
    }
}

CreateCheckerboardBitmap(w, h, cellSize := 16) {
    pBitmap := GDI.CreateBitmap(w, h)
    if !pBitmap
        return 0

    gfx := 0
    if DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", pBitmap, "Ptr*", &gfx) {
        GDI.DisposeImage(pBitmap)
        return 0
    }

    c1 := 0xFF2B2D31
    c2 := 0xFF363A40
    y := 0
    row := 0
    while y < h {
        x := 0
        tileH := Min(cellSize, h - y)
        col := row
        while x < w {
            tileW := Min(cellSize, w - x)
            brush := 0
            color := Mod(col, 2) = 0 ? c1 : c2
            DllCall("gdiplus\GdipCreateSolidFill", "UInt", color, "Ptr*", &brush)
            if brush {
                DllCall("gdiplus\GdipFillRectangle", "Ptr", gfx, "Ptr", brush
                    , "Float", x, "Float", y, "Float", tileW, "Float", tileH)
                DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
            }
            x += cellSize
            col++
        }
        y += cellSize
        row++
    }

    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gfx)
    return pBitmap
}

ApplyBitmapOpacity(pBitmap, opacity := 0.3) {
    if !pBitmap
        return 0

    opacity := Max(0.0, Min(opacity, 1.0))
    pCopy := GDI.CloneImage(pBitmap)
    if !pCopy
        return 0

    dims := GDI.GetDimensions(pCopy)
    if !dims.w || !dims.h {
        GDI.DisposeImage(pCopy)
        return 0
    }

    Rect := Buffer(16, 0)
    NumPut("UInt", 0, Rect, 0)
    NumPut("UInt", 0, Rect, 4)
    NumPut("UInt", dims.w, Rect, 8)
    NumPut("UInt", dims.h, Rect, 12)
    bd := Buffer(A_PtrSize = 8 ? 32 : 24, 0)
    if DllCall("gdiplus\GdipBitmapLockBits", "Ptr", pCopy, "Ptr", Rect
        , "UInt", 3, "Int", 0x26200A, "Ptr", bd) = 0 {
        scan0 := NumGet(bd, 16, "UPtr")
        stride := NumGet(bd, 8, "Int")
        loop dims.h {
            y := A_Index - 1
            row := y * stride
            loop dims.w {
                x := A_Index - 1
                off := row + x * 4 + 3
                a := NumGet(scan0, off, "UChar")
                if a > 0 {
                    scaled := Round(a * opacity)
                    if scaled < 1
                        scaled := 1
                    NumPut("UChar", scaled, scan0, off)
                }
            }
        }
        DllCall("gdiplus\GdipBitmapUnlockBits", "Ptr", pCopy, "Ptr", bd)
    }

    return pCopy
}

GetDisplayBitmap(g, result, which, filePath := "", settings := 0) {
    switch which {
        case "orig":
            srcPath := filePath
            if !srcPath && IsObject(result) && result.HasOwnProp("fullPath")
                srcPath := result.fullPath
            pBitmap := GDI.LoadImage(srcPath)
            if !pBitmap && srcPath {
                ext := ""
                SplitPath(srcPath, , , &ext)
                if ext = "tga"
                    pBitmap := LoadImageFallback(srcPath)
            }
            return {bmp: pBitmap, owned: true}

        case "fill":
            return {bmp: result.filled, owned: false}

        case "heat":
            return {bmp: result.heatmap, owned: false}

        case "overlay":
            return {bmp: ComposeOverlayBitmap(settings ? settings : CaptureUiSettings(g), result, filePath), owned: true}
    }
    return {bmp: 0, owned: false}
}

ComposeOverlayBitmap(settings, result, filePath := "", sourceBitmap := 0) {
    dims := GDI.GetDimensions(result.filled)
    pBitmap := GDI.CreateBitmap(dims.w, dims.h)
    if !pBitmap
        return 0

    fillOnTop := !settings.HasOwnProp("fillOnTop") || settings.fillOnTop

    if fillOnTop {
        if settings.showOrig {
            if sourceBitmap {
                pOrig := sourceBitmap
                ownOrig := false
            } else {
                pOrig := LoadSourceBitmap(result, filePath, sourceBitmap)
                ownOrig := true
            }
            if pOrig {
                GDI.DrawBitmap(pBitmap, pOrig, 0, 0, dims.w, dims.h, 0, 0, dims.w, dims.h)
                if ownOrig
                    GDI.DisposeImage(pOrig)
            }
        }

        if settings.showHeatmap {
            opacity := settings.HasOwnProp("heatmapOpacity") ? settings.heatmapOpacity / 100.0 : 0.3
            pHeat := ApplyBitmapOpacity(result.heatmap, opacity)
            if pHeat {
                GDI.DrawBitmap(pBitmap, pHeat, 0, 0, dims.w, dims.h, 0, 0, dims.w, dims.h)
                GDI.DisposeImage(pHeat)
            }
        }

        if settings.showFill
            GDI.DrawBitmap(pBitmap, result.filled, 0, 0, dims.w, dims.h, 0, 0, dims.w, dims.h)
    } else {
        if settings.showFill
            GDI.DrawBitmap(pBitmap, result.filled, 0, 0, dims.w, dims.h, 0, 0, dims.w, dims.h)

        if settings.showOrig {
            if sourceBitmap {
                pOrig := sourceBitmap
                ownOrig := false
            } else {
                pOrig := LoadSourceBitmap(result, filePath, sourceBitmap)
                ownOrig := true
            }
            if pOrig {
                GDI.DrawBitmap(pBitmap, pOrig, 0, 0, dims.w, dims.h, 0, 0, dims.w, dims.h)
                if ownOrig
                    GDI.DisposeImage(pOrig)
            }
        }

        if settings.showHeatmap {
            opacity := settings.HasOwnProp("heatmapOpacity") ? settings.heatmapOpacity / 100.0 : 0.3
            pHeat := ApplyBitmapOpacity(result.heatmap, opacity)
            if pHeat {
                GDI.DrawBitmap(pBitmap, pHeat, 0, 0, dims.w, dims.h, 0, 0, dims.w, dims.h)
                GDI.DisposeImage(pHeat)
            }
        }
    }

    return pBitmap
}

LoadSourceBitmap(result, filePath := "", sourceBitmap := 0) {
    if sourceBitmap
        return sourceBitmap
    srcPath := filePath
    if !srcPath && IsObject(result) && result.HasOwnProp("fullPath")
        srcPath := result.fullPath
    if !srcPath
        return 0
    pOrig := GDI.LoadImage(srcPath)
    if !pOrig {
        ext := ""
        SplitPath(srcPath, , , &ext)
        if ext = "tga"
            pOrig := LoadImageFallback(srcPath)
    }
    return pOrig
}

NormalizeHexColor(value, fallback := "#FF00FF") {
    text := Trim(value)
    if !text
        return fallback
    if SubStr(text, 1, 1) = "#"
        text := SubStr(text, 2)
    if !RegExMatch(text, "i)^[0-9a-f]{6}$")
        return fallback
    return "#" StrUpper(text)
}

HexColorToArgb(value, fallback := 0xFFFF00FF) {
    color := NormalizeHexColor(value)
    rgb := ("0x" SubStr(color, 2)) + 0
    return 0xFF000000 | rgb
}

GetFillColorPresets() {
    return ["#ff0000", "#0000ff", "#00FF00", "#FF00FF",  "#00FFFF", "#FF8000", "#FFFFFF", "#000000"]
}

SyncFillColorUi(g, color) {
    norm := NormalizeHexColor(color)
    if g.HasOwnProp("vFillColor") && g["FillColor"].Value != norm
        g["FillColor"].Value := norm
    UpdateFillColorPreview(g, norm)
}

UpdateFillColorPreview(g, color)
{
    color := NormalizeHexColor(color)

    try {
        ctrl := g["FillColorPreview"]
        ctrl.Opt("c" SubStr(color, 2))
        ctrl.Value := 1
    }
}

FillColorEditChanged(g, *) {
    if (g.HasOwnProp("_applyingSettings") && g._applyingSettings)
        return false
    if g.HasOwnProp("_syncingFillColor") && g._syncingFillColor
        return false
    raw := Trim(g["FillColor"].Value)
    if RegExMatch(raw, "i)^#?[0-9a-f]{6}$") {
        norm := NormalizeHexColor(raw)
        g._syncingFillColor := true
        try {
            g["FillColor"].Value := norm
            UpdateFillColorPreview(g, norm)
        } finally {
            g._syncingFillColor := false
        }
        return true
    }
    return false
}


ApplyFillColorChoice(g, color, *)
{
    color := NormalizeHexColor(color)

    g._syncingFillColor := true

    try {
        g["FillColor"].Value := color
        UpdateFillColorPreview(g, color)
    }

    finally {
        g._syncingFillColor := false
    }

    OnSettingChanged(g)
}

GetZoomCompareTargets(which) {
    switch which {
        case "orig":
            return ["fill", "heat", "overlay"]
        case "fill":
            return ["orig", "heat", "overlay"]
        case "heat":
            return ["orig", "fill", "overlay"]
        case "overlay":
            return ["orig", "fill", "heat"]
    }
    return []
}

GetZoomViewLabel(which) {
    switch which {
        case "orig":
            return "Original"
        case "fill":
            return "Filled"
        case "heat":
            return "Heatmap"
        case "overlay":
            return "Overlay"
    }
    return which
}

ResultMatchesFile(result, filePath) {
    SplitPath(filePath, &fileName)
    return (result.HasOwnProp("fullPath") && result.fullPath = filePath)
        || (result.HasOwnProp("fileName") && result.fileName = fileName)
}

; ===================================================================
; Event Handlers
; ===================================================================
BrowseInput(g, *) {
    g.Opt("+OwnDialogs")
    folder := FileSelect("D", "", "Select a folder containing images")
    if folder {
        g["InputPath"].Value := folder
        UpdateDefaultOutputPath(g)
        ScanFolder(g, folder)
    }
}

UpdateDefaultOutputPath(g) {
    inputPath := g["InputPath"].Value
    if !inputPath
        return
    SplitPath(inputPath, , &parentDir)
    if parentDir
        g["OutputPath"].Value := parentDir
}

BrowseOutput(g, *) {
    g.Opt("+OwnDialogs")
    folder := FileSelect("D", "", "Select output folder")
    if folder {
        g["OutputPath"].Value := folder
    }
}

DropFilesHandler(g, wParam, lParam, msg, hwnd) {
    global SUPPORTED_EXTS
    if hwnd != g.Hwnd
        return
    count := DllCall("shell32\DragQueryFileW", "Ptr", wParam, "UInt", 0xFFFFFFFF, "Ptr", 0, "UInt", 0)
    if !count
        return
    files := []
    loop count {
        idx := A_Index - 1
        length := DllCall("shell32\DragQueryFileW", "Ptr", wParam, "UInt", idx, "Ptr", 0, "UInt", 0) + 1
        buf := Buffer(length * 2)
        DllCall("shell32\DragQueryFileW", "Ptr", wParam, "UInt", idx, "Ptr", buf, "UInt", length)
        files.Push(StrGet(buf))
    }
    DllCall("shell32\DragFinish", "Ptr", wParam)

    if files.Length = 0
        return

    first := files[1]
    if DirExist(first) {
        g["InputPath"].Value := first
        UpdateDefaultOutputPath(g)
        ScanFolder(g, first)
    } else if FileExist(first) {
        ext := ""
        dotPos := InStr(first, ".", 0, -1)
        if dotPos
            ext := SubStr(first, dotPos + 1)
        if SUPPORTED_EXTS.Has(ext) {
            g["InputPath"].Value := first
            UpdateDefaultOutputPath(g)
            if files.Length = 1 {
                g._files := [first]
            } else {
                allFiles := []
                for fn in files {
                    e := ""
                    dp := InStr(fn, ".", 0, -1)
                    if dp
                        e := SubStr(fn, dp + 1)
                    if SUPPORTED_EXTS.Has(e)
                        allFiles.Push(fn)
                }
                g._files := allFiles
            }
            UpdateFileList(g)
        }
    }
}

ScanFolder(g, folder) {
    files := []
    recursive := g["Recursive"].Value
    extList := ["png", "jpg", "jpeg", "bmp", "tiff", "tif", "tga"]
    for ext in extList {
        pattern := folder "\*." ext
        if recursive {
            Loop Files pattern, "FR"
                files.Push(A_LoopFileFullPath)
        } else {
            Loop Files pattern, "F"
                files.Push(A_LoopFileFullPath)
        }
    }
    g._files := files
    UpdateFileList(g)
}

UpdateFileList(g) {
    count := g._files.Length
    if count = 0 {
        g["StatusText"].Value := "No images found."
        return
    }
    g["StatusText"].Value := "Found " count " image(s). Click 'Start' to process."
    g._currentIndex := 1
    LoadAndShowFile(g, 1)
}

NavigatePrev(g, *) {
    if g._currentIndex > 1
        LoadAndShowFile(g, g._currentIndex - 1)
}

ShowFileList(g, *) {
    if !g._files.Length {
        g.Opt("+OwnDialogs")
        MsgBox("No files are loaded yet.`n`nDrop a folder or image files onto the window first.", "File List", 64)
        return
    }

    dlg := Gui("+AlwaysOnTop +ToolWindow", "Loaded File List")
    dlg.BackColor := "2B2D31"
    dlg.SetFont("s9", "Segoe UI")
    dlg.Add("Text", "x12 y10 cFFFFFF", "Loaded files: " g._files.Length)
    dlg.Add("Text", "x12 y30 w560 cAAAAAA", "The list below reflects the current input set and processing status.")

    listText := ""
    for idx, file in g._files {
        status := "Pending"
        for r in g._results {
            if ResultMatchesFile(r, file) {
                status := "Processed"
                break
            }
        }
        listText .= idx ". " file " [" status "]`r`n"
    }

    dlg.Add("Edit", "x12 y55 w640 h320 ReadOnly WantTab -Wrap Background23262C cCFCFCF", listText)
    closeBtn := dlg.Add("Button", "x290 y388 w80 h28", "Close")
    closeBtn.OnEvent("Click", (*) => dlg.Destroy())
    dlg.Show("w665 h430")
    closeBtn.Focus()
}

OpenOutputFolder(g, *) {
    folder := ""

    if g._results.Length > 0 && g._results[1].HasOwnProp("outputBase")
        folder := g._results[1].outputBase

    if !folder
        folder := g["OutputPath"].Value

    if !folder
        folder := A_ScriptDir

    if !DirExist(folder) {
        g.Opt("+OwnDialogs")
        MsgBox("The folder does not exist yet:`n`n" folder, "Open Folder", 48)
        return
    }

    Run('explorer.exe "' folder '"')
}

NavigateNext(g, *) {
    if g._currentIndex < g._files.Length
        LoadAndShowFile(g, g._currentIndex + 1)
}

LoadAndShowFile(g, idx) {
    if idx < 1 || idx > g._files.Length
        return
    g._currentIndex := idx
    file := g._files[idx]

    total := g._files.Length
    g["NavInfo"].Value := "[" idx "/" total "] " file
    g["NavPrev"].Enabled := idx > 1
    g["NavNext"].Enabled := idx < total

    ; Load original image
    ext := ""
    SplitPath(file, , , &ext)
    pOrig := GDI.LoadImage(file)
    if !pOrig && ext = "tga"
        pOrig := LoadImageFallback(file)
    if !pOrig {
        g["StatusText"].Value := "Failed to load: " file
        return
    }

    if g._defaultSettings
        ApplyUiSettings(g, g._defaultSettings)

    ; Create thumbnail and show original preview (no stretch)
    pThumb := GDI.CreateThumbnail(pOrig, 360, 170)
    origBmp := ""
    if pThumb {
        origBmp := GDI.SaveToBmpFile(pThumb)
        GDI.DisposeImage(pThumb)
    } else {
        origBmp := GDI.SaveToBmpFile(pOrig)
    }
    if origBmp && FileExist(origBmp)
        g["OrigPreview"].Value := origBmp
    GDI.DisposeImage(pOrig)

    ; Check if processed result exists
    found := false
    for r in g._results {
        if ResultMatchesFile(r, file) {
            ShowPreview(g, r)
            found := true
            break
        }
    }

    if !found {
        g["FillPreview"].Value := ""
        g["HeatPreview"].Value := ""
        g["DupPreview"].Value := ""
        g["FillLabel"].Value := "Filled (" NormalizeHexColor(g["FillColor"].Value) ")"
        g["NavTimer"].Value := ""
        g["StatusText"].Value := "Preview: " file " (not yet processed)"
    }
}

StartProcessing(g, *) {
    if g._files.Length = 0 {
        g.Opt("+OwnDialogs")
        MsgBox("No files to process. Drop files or select an input folder first.", "No Files", 48)
        return
    }

    g["StatusText"].Value := "Processing..."
    g["ProgressBar"].Value := 0

    outputBase := g["OutputPath"].Value
    makeFolder := g["MakeFolder"].Value

    if !outputBase {
        inputPath := g["InputPath"].Value
        if inputPath {
            SplitPath(inputPath, , &outputBase)
        }
        if !outputBase
            outputBase := A_ScriptDir
    }
    if makeFolder {
        inputPath := g["InputPath"].Value
        if DirExist(inputPath)
            SplitPath(inputPath, &folderName)
        else {
            SplitPath(inputPath, &name)
            folderName := name
        }
        outputBase := RTrim(outputBase, "\") "\" folderName "_paint_check_output"
    }
    if !DirExist(outputBase)
        DirCreate(outputBase)

    ; Cleanup previous results
    for r in g._results {
        if r.HasOwnProp("filled") && r.filled
            GDI.DisposeImage(r.filled)
        if r.HasOwnProp("heatmap") && r.heatmap
            GDI.DisposeImage(r.heatmap)
    }
    g._results := []

    total := g._files.Length
    processed := 0
    failed := []
    log := ""
    overallStart := A_TickCount

    for file in g._files {
        processed++
        imageStart := A_TickCount
        g["ProgressBar"].Value := Round((processed - 1) / total * 100)
        g["StatusText"].Value := "Processing (" processed "/" total "): " file

        pathParts := StrSplit(file, "\")
        fileName := pathParts[pathParts.Length]
        dotPos := InStr(fileName, ".", 0, -1)
        nameOnly := dotPos ? SubStr(fileName, 1, dotPos - 1) : fileName
        inputExt := dotPos ? SubStr(fileName, dotPos + 1) : "png"

        pBitmap := GDI.LoadImage(file)
        if !pBitmap {
            ext := ""
            dotPos := InStr(file, ".", 0, -1)
            if dotPos
                ext := SubStr(file, dotPos + 1)
            if ext = "tga" {
                log .= "  TGA detected, using built-in TGA parser...`n"
                pBitmap := LoadImageFallback(file)
            }
        }

        if !pBitmap {
            log .= "FAILED load: " fileName "`n"
            failed.Push(fileName)
            continue
        }
        dims := GDI.GetDimensions(pBitmap)
        log .= "OK load: " fileName " (" dims.w "x" dims.h ")`n"

        alphaThreshold := g["AlphaThreshold"].Value
        progressFn := (done, total_) => (
            elapsed := A_TickCount - overallStart,
            completed := ((processed - 1) + done / total_) / total,
            etaMs := completed > 0 ? Round(elapsed / completed * (1 - completed)) : 0,
            g["ProgressBar"].Value := Round(completed * 100),
            g["StatusText"].Value := "Processing " fileName " (" done "/" total_ ") ~ ETA: " FormatDuration(etaMs)
        )

        ; Save thumbnail preview (not full-size) to avoid stretching in picture control
        pThumb := GDI.CreateThumbnail(pBitmap, 360, 170)
        origPreviewFile := pThumb ? GDI.SaveToBmpFile(pThumb) : GDI.SaveToBmpFile(pBitmap)
        GDI.DisposeImage(pThumb)
        log .= "  preview: " (origPreviewFile ? "OK" : "FAILED") "`n"

        hc := g.HasOwnProp("_heatmapColors") ? g._heatmapColors : GetDefaultHeatmapColors()
        result := ProcessPaintCheck(pBitmap, alphaThreshold, NormalizeHexColor(g["FillColor"].Value), progressFn, hc)

        if !result {
            GDI.DisposeImage(pBitmap)
            log .= "  ProcessPaintCheck FAILED`n"
            failed.Push(fileName)
            continue
        }

        imageDuration := A_TickCount - imageStart
        imageDurStr := FormatDuration(imageDuration)
        log .= "  result: " result.transparentCount " transparent pixels (" imageDurStr ")`n"

        result.report := GenerateReport(result, fileName)
        result.fileName := fileName
        result.fullPath := file
        result.nameOnly := nameOnly
        result.inputExt := inputExt
        result.outputBase := outputBase
        result.origPreviewFile := origPreviewFile
        result.durationMs := imageDuration
        result.settings := CaptureUiSettings(g)

        SaveOutputs(g, result, outputBase, nameOnly, pBitmap)

        g._results.Push(result)
        GDI.DisposeImage(pBitmap)
    }

    totalDuration := A_TickCount - overallStart
    totalDurStr := FormatDuration(totalDuration)
    g._totalDuration := totalDuration
    g["ProgressBar"].Value := 100
    g["StatusText"].Value := "Done. Processed " processed " file(s) in " totalDurStr "."

    ; Append summary to log
    log .= "`n----------------------------------------`n"
        . "Total: " processed " file(s) in " totalDurStr
    if failed.Length > 0
        log .= " (" failed.Length " failed)"
    log .= "`nOutput: " outputBase "`n"

    ; Write log to report
    g["ReportText"].Value := log

    ; Create ZIP if checkbox is checked
    zipCreated := ""
    if g["ZipExport"].Value {
        zipCreated := CreateZipExport(outputBase)
        if zipCreated
            log .= "ZIP: " zipCreated "`n"
        else
            log .= "ZIP creation failed`n"
    }

    if failed.Length > 0 {
        failList := ""
        for f in failed
            failList .= "`n  - " f
        msg := "Processed " processed " file(s) in " totalDurStr ". " failed.Length " failed:" failList
        ShowResultDialog(msg, "Complete - " failed.Length " Failed")
    } else {
        msg := "All " processed " file(s) processed in " totalDurStr ".`n`nOutput saved to:`n" outputBase
        ShowResultDialog(msg, "Complete")
    }

    if g._results.Length > 0 {
        g._currentIndex := 1
        LoadAndShowFile(g, 1)
    }
    ClearPendingRefresh(g)
}

ClearPendingRefresh(g) {
    g._pendingRefresh := false
    if g.HasOwnProp("PreviewRefresh") {
        g["PreviewRefresh"].Text := "Refresh"
        g["PreviewRefresh"].Opt("Background3A3C42 cFFFFFF")
    }
}

ReprocessCurrent(g, *) {
    idx := g._currentIndex
    if idx < 1 || idx > g._files.Length
        return

    file := g._files[idx]
    SplitPath(file, &fileName, , &ext, &nameOnly)
    inputExt := ext = "" ? "png" : ext

    g["StatusText"].Value := "Refreshing: " fileName
    g["ProgressBar"].Value := 0
    for i, r in g._results {
        if ResultMatchesFile(r, file) {
            if r.HasOwnProp("filled") && r.filled
                GDI.DisposeImage(r.filled)
            if r.HasOwnProp("heatmap") && r.heatmap
                GDI.DisposeImage(r.heatmap)
            g._results.RemoveAt(i)
            break
        }
    }

    pBitmap := GDI.LoadImage(file)
    if !pBitmap {
        if ext = "tga"
            pBitmap := LoadImageFallback(file)
    }
    if !pBitmap {
        g.Opt("+OwnDialogs")
        MsgBox("Failed to load image.", "Refresh Error", 48)
        return
    }

    alphaThreshold := g["AlphaThreshold"].Value
    hc := g.HasOwnProp("_heatmapColors") ? g._heatmapColors : GetDefaultHeatmapColors()

    progressFn := (done, total_) => (
        g["ProgressBar"].Value := Round(done / total_ * 100),
        g["StatusText"].Value := "Refreshing " fileName " (" done "/" total_ ")"
    )
    refreshImageStart := A_TickCount
    result := ProcessPaintCheck(pBitmap, alphaThreshold, NormalizeHexColor(g["FillColor"].Value), progressFn, hc)
    imageDuration := A_TickCount - refreshImageStart
    if !result {
        GDI.DisposeImage(pBitmap)
        MsgBox("Processing failed.", "Refresh Error", 48)
        return
    }

    result.fileName := fileName
    result.fullPath := file
    result.nameOnly := nameOnly
    result.inputExt := inputExt
    result.report := GenerateReport(result, fileName)
    result.settings := CaptureUiSettings(g)
    result.durationMs := imageDuration

    pThumb := GDI.CreateThumbnail(pBitmap, 360, 170)
    result.origPreviewFile := pThumb ? GDI.SaveToBmpFile(pThumb) : GDI.SaveToBmpFile(pBitmap)
    GDI.DisposeImage(pThumb)

    g._results.Push(result)
    GDI.DisposeImage(pBitmap)
    LoadAndShowFile(g, idx)
    ClearPendingRefresh(g)
    g["ProgressBar"].Value := 100
    g["StatusText"].Value := "Refresh complete. " fileName " (" FormatDuration(imageDuration) ")"
}

SaveOutputs(g, result, outputBase, nameOnly, srcBitmap := 0) {
    basePath := outputBase "\" nameOnly
    ext := result.HasOwnProp("inputExt") && result.inputExt ? result.inputExt : "png"
    settings := CaptureUiSettings(g)
    if settings.saveFill {
        filledPath := basePath "_filled." ext
        GDI.SaveWithFormat(result.filled, filledPath, ext)
    }

    if settings.saveHeatmap {
        heatPath := basePath "_heatmap." ext
        GDI.SaveWithFormat(result.heatmap, heatPath, ext)
    }

    if settings.saveOverlay {
        overlayPath := basePath "_overlay." ext
        pOverlay := ComposeOverlayBitmap(settings, result, "", srcBitmap)
        if pOverlay {
            GDI.SaveWithFormat(pOverlay, overlayPath, ext)
            GDI.DisposeImage(pOverlay)
        }
    }

    if settings.saveReport {
        reportPath := basePath "_report.txt"
        try FileDelete(reportPath)
        FileAppend(result.report, reportPath)
    }
}

CreateZipExport(outputBase) {
    src := outputBase "\*"
    zipPath := outputBase ".zip"
    try FileDelete(zipPath)
    psCmd := 'Compress-Archive -Path "' src '" -DestinationPath "' zipPath '" -Force'
    try {
        ComObject("WScript.Shell").Exec("powershell.exe -NoProfile -Command " psCmd).StdOut.ReadAll()
    }
    if FileExist(zipPath)
        return zipPath
    return ""
}

SaveAll(g, *) {
    if g._results.Length = 0 {
        g.Opt("+OwnDialogs")
        MsgBox("No results to process. Process some images first.", "No Results", 48)
        return
    }

    dlg := Gui("+AlwaysOnTop +ToolWindow", "Save All Outputs")
    dlg.BackColor := "2B2D31"
    dlg.SetFont("s9", "Segoe UI")
    dlg.AddText("x14 y12 cFFFFFF", "Choose what to save for all processed images:")
    dlg.AddCheckBox("x18 y40 Checked vSaveAllFill cCFCFCF", "Filled")
    dlg.AddCheckBox("x18 y68 Checked vSaveAllHeatmap cCFCFCF", "Heatmap")
    dlg.AddCheckBox("x18 y96 Checked vSaveAllOverlay cCFCFCF", "Overlay")
    dlg.AddCheckBox("x18 y124 Checked vSaveAllReport cCFCFCF", "Report")
    dlg.AddCheckBox("x18 y154 Checked vSaveAllOpenOutput cCFCFCF", "Open output folder after save")
    dlg.AddText("x14 y184 w280 cAAAAAA", "All boxes are checked by default. Uncheck any output you do not want to save.")

    btnSave := dlg.AddButton("x58 y216 w80 h26", "Save")
    btnCancel := dlg.AddButton("x148 y216 w80 h26", "Cancel")
    btnSave.OnEvent("Click", (*) => SaveAllConfirm(g, dlg))
    btnCancel.OnEvent("Click", (*) => dlg.Destroy())
    dlg.OnEvent("Close", (*) => dlg.Destroy())
    dlg.Show("w300 h260")
}

SaveAllConfirm(g, dlg) {
    if SaveAllSelected(g, dlg) {
        if dlg["SaveAllOpenOutput"].Value
            OpenOutputFolder(g)
        dlg.Destroy()
    }
}

SaveAllSelected(g, dlg) {
    if g._results.Length = 0
        return false

    saveFill := dlg["SaveAllFill"].Value
    saveHeatmap := dlg["SaveAllHeatmap"].Value
    saveOverlay := dlg["SaveAllOverlay"].Value
    saveReport := dlg["SaveAllReport"].Value

    if !saveFill && !saveHeatmap && !saveOverlay && !saveReport {
        g.Opt("+OwnDialogs")
        MsgBox("Select at least one output type to save.", "Save All", 48)
        return false
    }

    count := 0
    for r in g._results {
        if !r.HasOwnProp("outputBase") || !r.HasOwnProp("nameOnly")
            continue
        SaveOutputsSelected(g, r, r.outputBase, r.nameOnly, saveFill, saveHeatmap, saveOverlay, saveReport)
        count++
    }

    g.Opt("+OwnDialogs")
    MsgBox("Saved selected outputs for " count " processed file(s).", "Saved", 64)
    return true
}

SaveOutputsSelected(g, result, outputBase, nameOnly, saveFill, saveHeatmap, saveOverlay, saveReport) {
    basePath := outputBase "\" nameOnly
    settings := CaptureUiSettings(g)
    if saveFill {
        filledPath := basePath "_filled.png"
        GDI.SaveBitmap(result.filled, filledPath, "image/png")
    }

    if saveHeatmap {
        heatPath := basePath "_heatmap.png"
        GDI.SaveBitmap(result.heatmap, heatPath, "image/png")
    }

    if saveOverlay {
        overlayPath := basePath "_overlay.png"
        overlayDisp := GetDisplayBitmap(g, result, "overlay", "", settings)
        if overlayDisp.bmp {
            GDI.SaveBitmap(overlayDisp.bmp, overlayPath, "image/png")
            if overlayDisp.owned
                GDI.DisposeImage(overlayDisp.bmp)
        }
    }

    if saveReport {
        reportPath := basePath "_report.txt"
        try FileDelete(reportPath)
        FileAppend(result.report, reportPath)
    }
}

ClearAll(g, *) {
    ; Cleanup GDI bitmaps
    for r in g._results {
        if r.HasOwnProp("filled") && r.filled
            GDI.DisposeImage(r.filled)
        if r.HasOwnProp("heatmap") && r.heatmap
            GDI.DisposeImage(r.heatmap)
    }
    g._files := []
    g._results := []
    g._currentIndex := 0
    g["InputPath"].Value := ""
    g["OutputPath"].Value := ""
    g["OrigPreview"].Value := ""
    g["FillPreview"].Value := ""
    g["HeatPreview"].Value := ""
    g["DupPreview"].Value := ""
    g["FillLabel"].Value := "Filled (" NormalizeHexColor(g["FillColor"].Value) ")"
    g["NavInfo"].Value := "No image selected"
    g["NavTimer"].Value := ""
    g["NavPrev"].Enabled := false
    g["NavNext"].Enabled := false
    g["ReportText"].Value := ""
    g["StatusText"].Value := "Ready. Drop image files or a folder here."
    g["ProgressBar"].Value := 0
}

ResetSettings(g, *) {
    g._applyingSettings := true
    try {
        ClearAll(g)
        g["AlphaThreshold"].Value := 128
        g["AlphaVal"].Text := "128"
        g["HeatmapOpacity"].Value := 35
        g["HeatmapOpacityVal"].Text := "35%"
        SyncFillColorUi(g, "#FF00FF")
        g["FillOnTop"].Value := 0
        g["SaveFill"].Value := 0
        g["SaveHeatmap"].Value := 0
        g["SaveOverlay"].Value := 1
        g["SaveReport"].Value := 0
        g["ZipExport"].Value := 0
        g["MakeFolder"].Value := 1
        g["Recursive"].Value := 0
        g["ShowHeatmap"].Value := 1
        g["ShowOrig"].Value := 1
        g["ShowFill"].Value := 1
        g._heatmapColors := GetDefaultHeatmapColors()
        g._defaultSettings := CaptureUiSettings(g)
        UpdateMainGradient(g)
        g["NavInfo"].Value := "No image selected"
        g["NavTimer"].Value := ""
        g["StatusText"].Value := "Settings reset to defaults."
    } finally {
        g._applyingSettings := false
    }
}

ShowPreview(g, result) {
    g["ReportText"].Value := result.report

    ; Create thumbnail for filled, heatmap, overlay
    settings := CaptureUiSettings(g)
    g["FillLabel"].Value := "Filled (" NormalizeHexColor(settings.fillColor) ")"
    fillDisp := GetDisplayBitmap(g, result, "fill", "", settings)
    overlayDisp := GetDisplayBitmap(g, result, "overlay", "", settings)
    pFillThumb := fillDisp.bmp ? GDI.CreateThumbnail(fillDisp.bmp, 360, 170) : 0
    pHumThumb := result.HasOwnProp("heatmap") && result.heatmap ? GDI.CreateThumbnail(result.heatmap, 360, 170) : 0
    pOvThumb := overlayDisp.bmp ? GDI.CreateThumbnail(overlayDisp.bmp, 360, 170) : 0

    fillFile := pFillThumb ? GDI.SaveToBmpFile(pFillThumb) : ""
    humFile := pHumThumb ? GDI.SaveToBmpFile(pHumThumb) : ""
    ovFile := pOvThumb ? GDI.SaveToBmpFile(pOvThumb) : ""

    GDI.DisposeImage(pFillThumb)
    GDI.DisposeImage(pHumThumb)
    GDI.DisposeImage(pOvThumb)
    if fillDisp.owned
        GDI.DisposeImage(fillDisp.bmp)
    if overlayDisp.owned
        GDI.DisposeImage(overlayDisp.bmp)

    if result.HasOwnProp("origPreviewFile") && FileExist(result.origPreviewFile)
        g["OrigPreview"].Value := result.origPreviewFile

    g["FillPreview"].Value := fillFile
    g["HeatPreview"].Value := humFile
    g["DupPreview"].Value := ovFile

    g["StatusText"].Value := "Showing: " result.fileName
        . " - " result.transparentCount " transparent pixels ("
        . result.transparentPercent "%)"

    ; Show duration in nav bar
    durStr := result.HasOwnProp("durationMs") ? FormatDuration(result.durationMs) : ""
    totalStr := g.HasOwnProp("_totalDuration") && g._totalDuration ? FormatDuration(g._totalDuration) : ""
    g["NavInfo"].Value := "[" g._currentIndex "/" g._files.Length "] " result.fileName
    g["NavTimer"].Value := "process image: " durStr "  process all: " totalStr
}

; ===================================================================
; Full-View Zoom / Pan Window
; ===================================================================
ShowZoomWindow(g, which) {
    ; Close existing zoom window if any
    if g.HasOwnProp("_zoomWindow") && g._zoomWindow {
        try {
            _ZoomClose(g._zoomWindow)
            g._zoomWindow.Destroy()
        }
        g._zoomWindow := 0
    }

    idx := g._currentIndex
    if idx < 1 || idx > g._files.Length
        return
    filePath := g._files[idx]
    SplitPath(filePath, &fileName)

    result := 0
    for r in g._results {
        if ResultMatchesFile(r, filePath) {
            result := r
            break
        }
    }

    if which != "orig" && !result {
        g.Opt("+OwnDialogs")
        MsgBox("Process this image first to view the " which " output.", "Zoom View", 48)
        return
    }

    zoomSettings := CaptureUiSettings(g)
    disp := GetDisplayBitmap(g, result, which, filePath, zoomSettings)
    pBitmap := disp.bmp
    isExternal := disp.owned
    dims := pBitmap ? GDI.GetDimensions(pBitmap) : 0
    origW := dims ? dims.w : 0
    origH := dims ? dims.h : 0
    if !pBitmap || !origW
        return

    zw := Gui("+Resize +MinSize400x300 +ToolWindow +AlwaysOnTop"
        , "Zoom View [" GetZoomViewLabel(which) "] - " fileName)
    zw.BackColor := "1E1E1E"
    zw.SetFont("s8", "Segoe UI")

    zw.AddText("x8 y6 cAAAAAA", "Zoom:")
    btnIn := zw.AddButton("x48 y4 w24 h20 cFFFFFF Background3A3C42", "+")
    btnOut := zw.AddButton("x74 y4 w24 h20 cFFFFFF Background3A3C42", "-")
    btnFit := zw.AddButton("x100 y4 w30 h20 cFFFFFF Background3A3C42", "Fit")
    zt := zw.AddText("x135 y6 cFFFFFF w30 vZText", "100%")
    zw.AddButton("x172 y4 w55 h20 cFFFFFF Background3A3C42", "Refresh")
        .OnEvent("Click", _ZoomRefresh.Bind(zw))
    modeText := zw.AddText("x238 y6 cAAAAAA w470 vZMode"
        , GetZoomViewLabel(which) " | " origW "x" origH " | wheel zoom, drag pan")

    zw.AddText("x8 y30 cAAAAAA", "Compare:")
    offBtn := zw.AddButton("x63 y28 w42 h20 cFFFFFF Background3A3C42", "Off")
    offBtn.OnEvent("Click", (*) => _ZoomClearCompare(zw))

    compareTargets := IsObject(result) ? GetZoomCompareTargets(which) : []
    zw._compareButtons := Map()
    cmpX := 112
    for target in compareTargets {
        cmpBtn := zw.AddButton("x" cmpX " y28 w64 h20 cFFFFFF Background3A3C42"
            , GetZoomViewLabel(target))
        cmpBtn.OnEvent("Click", _ZoomSetCompare.Bind(zw, target))
        zw._compareButtons[target] := cmpBtn
        cmpX += 69
    }

    zwPic := zw.AddPic("x0 y54 w100 h100 Background000000 vZPic")
    zw._zwPic := zwPic
    zw._imgX := 0
    zw._imgY := 0
    zw._dragging := false

    zoomLevel := 1.0
    zw._pBitmap := pBitmap
    zw._isExt := isExternal
    zw._origW := origW
    zw._origH := origH
    zw._zoomLevel := zoomLevel
    zw._zt := zt
    zw._modeText := modeText
    zw._zwPic := zwPic
    zw._g := g
    zw._baseWhich := which
    zw._sourceResult := result
    zw._sourceFilePath := filePath
    zw._sourceSettings := zoomSettings
    zw._compareBitmap := 0
    zw._compareOwned := false
    zw._compareWhich := ""

    btnIn.OnEvent("Click", (*) => _ZoomIn(zw))
    btnOut.OnEvent("Click", (*) => _ZoomOut(zw))
    btnFit.OnEvent("Click", (*) => _ZoomFit(zw))

    zw.OnEvent("Size", (*) => _ZoomOnSize(zw))
    zw.OnEvent("Close", (*) => _ZoomClose(zw))
    zw._panDownFn := _ZoomPanDown.Bind(zw)
    zw._panMoveFn := _ZoomPanMove.Bind(zw)
    zw._panUpFn := _ZoomPanUp.Bind(zw)
    OnMessage(0x0201, zw._panDownFn)
    OnMessage(0x0200, zw._panMoveFn)
    OnMessage(0x0202, zw._panUpFn)
    ; Mouse wheel via message
    zw._wheelFn := _WheelZoom.Bind(zw)
    OnMessage(0x020A, zw._wheelFn)

    g._zoomWindow := zw
    zw.Show("w" Min(origW + 40, 1280) " h" Min(origH + 110, 980))
    _ZoomApply(zw, zoomLevel)
}

_ZoomIn(zw) {
    levels := [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0]
    for i, l in levels {
        if l > zw._zoomLevel + 0.001 {
            _ZoomApply(zw, l)
            return
        }
    }
}

_ZoomOut(zw) {
    levels := [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0]
    best := 0
    for i, l in levels {
        if l < zw._zoomLevel - 0.001 && l > best
            best := l
    }
    if best
        _ZoomApply(zw, best)
}

_ZoomFit(zw) {
    zw.GetPos(&x, &y, &ww, &wh)
    cw := ww
    ch := wh - 54
    if cw < 1 || ch < 1
        return
    zx := cw / zw._origW
    zy := ch / zw._origH
    _ZoomApply(zw, Min(zx, zy))
}

_WheelZoom(zw, wParam, lParam, msg, hwnd) {
    ; Check if this message is for our zoom window
    hwnd := 0
    try hwnd := zw.Hwnd
    if !hwnd
        return
    ; Get the window under the cursor
    pt := Buffer(8, 0)
    NumPut("UInt", lParam & 0xFFFF, pt, 0)
    NumPut("UInt", (lParam >> 16) & 0xFFFF, pt, 4)
    hOver := DllCall("WindowFromPoint", "Int64", NumGet(pt, 0, "Int64"), "UPtr")
    if hOver != hwnd && !_IsChildWindow(hOver, hwnd)
        return

    delta := (wParam >> 16) & 0xFFFF
    if delta > 32768
        delta -= 65536
    if delta > 0
        _ZoomIn(zw)
    else if delta < 0
        _ZoomOut(zw)
}

_ZoomSetCompare(zw, compareWhich, *) {
    if !zw.HasOwnProp("_g") || !zw.HasOwnProp("_sourceResult")
        return
    if zw.HasOwnProp("_compareOwned") && zw._compareOwned && zw.HasOwnProp("_compareBitmap") && zw._compareBitmap {
        GDI.DisposeImage(zw._compareBitmap)
    }
    disp := GetDisplayBitmap(zw._g, zw._sourceResult, compareWhich, zw._sourceFilePath, zw._sourceSettings)
    if !disp.bmp {
        zw._compareBitmap := 0
        zw._compareOwned := false
        zw._compareWhich := ""
        _ZoomApply(zw, zw._zoomLevel)
        return
    }
    zw._compareBitmap := disp.bmp
    zw._compareOwned := disp.owned
    zw._compareWhich := compareWhich
    _ZoomApply(zw, zw._zoomLevel)
}

_ZoomClearCompare(zw) {
    if zw.HasOwnProp("_compareOwned") && zw._compareOwned && zw.HasOwnProp("_compareBitmap") && zw._compareBitmap {
        GDI.DisposeImage(zw._compareBitmap)
    }
    zw._compareBitmap := 0
    zw._compareOwned := false
    zw._compareWhich := ""
    _ZoomApply(zw, zw._zoomLevel)
}

_IsChildWindow(hChild, hParent) {
    loop {
        if hChild = hParent
            return true
        hChild := DllCall("GetParent", "UPtr", hChild, "UPtr")
        if !hChild
            return false
    }
}

_ZoomApply(zw, newZoom) {
    newZoom := Max(0.1, Min(newZoom, 16))
    zw._zoomLevel := newZoom
    _RenderZoom(zw, zw._pBitmap, zw._origW, zw._origH, newZoom, zw._zt)
}

_ZoomOnSize(zw) {
    _ZoomApply(zw, zw._zoomLevel)
}

_ZoomClose(zw) {
    try OnMessage(0x0201, zw._panDownFn, 0)
    try OnMessage(0x0200, zw._panMoveFn, 0)
    try OnMessage(0x0202, zw._panUpFn, 0)
    try OnMessage(0x020A, zw._wheelFn, 0)
    if zw.HasOwnProp("_dragging") && zw._dragging {
        zw._dragging := false
        try DllCall("ReleaseCapture")
    }
    if zw._isExt && zw._pBitmap
        GDI.DisposeImage(zw._pBitmap)
    if zw.HasOwnProp("_compareOwned") && zw._compareOwned && zw.HasOwnProp("_compareBitmap") && zw._compareBitmap
        GDI.DisposeImage(zw._compareBitmap)
    if zw.HasOwnProp("_g") && zw._g.HasOwnProp("_zoomWindow")
        zw._g._zoomWindow := 0
}

_ZoomRefresh(zw, *) {
    g := zw._g
    which := zw._baseWhich
    if !g.HasOwnProp("_currentIndex")
        return
    idx := g._currentIndex
    if idx < 1 || idx > g._files.Length
        return
    filePath := g._files[idx]
    SplitPath(filePath, &fileName)

    result := 0
    for r in g._results {
        if ResultMatchesFile(r, filePath) {
            result := r
            break
        }
    }

    zoomSettings := CaptureUiSettings(g)
    disp := GetDisplayBitmap(g, result, which, filePath, zoomSettings)
    if !disp.bmp
        return
    dims := GDI.GetDimensions(disp.bmp)
    if !dims.w || !dims.h {
        if disp.owned
            GDI.DisposeImage(disp.bmp)
        return
    }

    if zw._isExt && zw._pBitmap
        GDI.DisposeImage(zw._pBitmap)
    zw._pBitmap := disp.bmp
    zw._isExt := disp.owned
    zw._origW := dims.w
    zw._origH := dims.h
    zw._imgX := 0
    zw._imgY := 0

    if zw.HasOwnProp("_compareOwned") && zw._compareOwned && zw.HasOwnProp("_compareBitmap") && zw._compareBitmap {
        GDI.DisposeImage(zw._compareBitmap)
    }
    zw._compareBitmap := 0
    zw._compareOwned := false
    zw._compareWhich := ""

    try zw.Title := "Zoom View [" GetZoomViewLabel(which) "] - " fileName
    _ZoomApply(zw, zw._zoomLevel)
}

_RenderZoom(zw, pBitmap, ow, oh, zl, zt) {
    if !pBitmap {
        try zw._zwPic.Value := ""
        zt.Text := Round(zl * 100) "%"
        return
    }
    nw := Max(1, Round(ow * zl))
    nh := Max(1, Round(oh * zl))
    zw.GetPos(&gx, &gy, &ww, &wh)
    compareMode := zw.HasOwnProp("_compareBitmap") && zw._compareBitmap
    topH := 54
    canvasW := Max(1, ww)
    canvasH := Max(1, wh - topH)

    modeLabel := GetZoomViewLabel(zw._baseWhich)
    if compareMode
        modeLabel .= " vs " GetZoomViewLabel(zw._compareWhich)
    if zw.HasOwnProp("_modeText")
        zw._modeText.Text := modeLabel " | " ow "x" oh " | wheel zoom, drag pan"

    if compareMode {
        gap := 4
        paneW := Max(1, Floor((canvasW - gap) / 2))
        leftCanvas := CreateCheckerboardBitmap(paneW, canvasH)
        rightCanvas := CreateCheckerboardBitmap(paneW, canvasH)
        fullCanvas := CreateCheckerboardBitmap(canvasW, canvasH)
        if !leftCanvas || !rightCanvas || !fullCanvas {
            if leftCanvas
                GDI.DisposeImage(leftCanvas)
            if rightCanvas
                GDI.DisposeImage(rightCanvas)
            if fullCanvas
                GDI.DisposeImage(fullCanvas)
            try zw._zwPic.Value := ""
            zt.Text := Round(zl * 100) "%"
            return
        }
        leftPan := _ZoomClampPanPane(zw, zw._imgX, zw._imgY, nw, nh, paneW, canvasH)
        rightPan := _ZoomClampPanPane(zw, zw._imgX, zw._imgY, nw, nh, paneW, canvasH)
        GDI.DrawBitmap(leftCanvas, pBitmap, leftPan.x, leftPan.y, nw, nh, 0, 0, ow, oh)
        GDI.DrawBitmap(rightCanvas, zw._compareBitmap, rightPan.x, rightPan.y, nw, nh, 0, 0, ow, oh)
        GDI.DrawBitmap(fullCanvas, leftCanvas, 0, 0, paneW, canvasH, 0, 0, paneW, canvasH)
        GDI.DrawBitmap(fullCanvas, rightCanvas, paneW + gap, 0, paneW, canvasH, 0, 0, paneW, canvasH)
        GDI.DisposeImage(leftCanvas)
        GDI.DisposeImage(rightCanvas)
        hBitmap := GDI.GetHBITMAP(fullCanvas)
        GDI.DisposeImage(fullCanvas)
        if !hBitmap {
            try zw._zwPic.Value := ""
            zt.Text := Round(zl * 100) "%"
            return
        }
        try zw._zwPic.Value := ""
        try zw._zwPic.Value := "HBITMAP:" hBitmap
        zw._zwPic.Move(0, topH, canvasW, canvasH)
        zt.Text := Round(zl * 100) "%"
        return
    }

    pCanvas := CreateCheckerboardBitmap(canvasW, canvasH)
    if !pCanvas {
        try zw._zwPic.Value := ""
        zt.Text := Round(zl * 100) "%"
        return
    }
    drawX := zw._imgX
    drawY := zw._imgY
    pan := _ZoomClampPanPane(zw, drawX, drawY, nw, nh, canvasW, canvasH)
    drawX := pan.x
    drawY := pan.y
    zw._imgX := drawX
    zw._imgY := drawY
    GDI.DrawBitmap(pCanvas, pBitmap, drawX, drawY, nw, nh, 0, 0, ow, oh)
    hBitmap := GDI.GetHBITMAP(pCanvas)
    GDI.DisposeImage(pCanvas)
    if !hBitmap {
        try zw._zwPic.Value := ""
        zt.Text := Round(zl * 100) "%"
        return
    }
    try zw._zwPic.Value := ""
    try zw._zwPic.Value := "HBITMAP:" hBitmap
    zw._zwPic.Move(0, topH, canvasW, canvasH)
    zt.Text := Round(zl * 100) "%"
}

_ZoomClampPanPane(zw, x, y, nw, nh, vw := 0, vh := 0) {
    if !vw || !vh {
        zw.GetPos(&gx, &gy, &ww, &wh)
        vw := ww
        vh := wh - 54
    }
    if vw < 1 || vh < 1
        return {x: x, y: y}
    vw := Max(1, vw)
    vh := Max(1, vh)

    if nw <= vw
        x := Round((vw - nw) / 2)
    else
        x := Max(vw - nw, Min(x, 0))

    if nh <= vh
        y := Round((vh - nh) / 2)
    else
        y := Max(vh - nh, Min(y, 0))

    return {x: x, y: y}
}

_ZoomClampPan(zw, x, y, nw, nh) {
    return _ZoomClampPanPane(zw, x, y, nw, nh)
}

_ZoomPanDown(zw, wParam, lParam, msg, hwnd) {
    MouseGetPos(&sx, &sy, &win, &ctrl, 2)
    if ctrl != zw._zwPic.Hwnd
        return
    zw._dragging := true
    zw._dragStartX := sx
    zw._dragStartY := sy
    zw._dragBaseX := zw._imgX
    zw._dragBaseY := zw._imgY
    try DllCall("SetCapture", "Ptr", zw.Hwnd)
}

_ZoomPanMove(zw, wParam, lParam, msg, hwnd) {
    if !zw.HasOwnProp("_dragging") || !zw._dragging
        return
    if !(wParam & 0x0001)
        return

    MouseGetPos(&sx, &sy, &win, &ctrl, 2)
    pan := _ZoomClampPan(zw
        , zw._dragBaseX + (sx - zw._dragStartX)
        , zw._dragBaseY + (sy - zw._dragStartY)
        , Round(zw._origW * zw._zoomLevel)
        , Round(zw._origH * zw._zoomLevel))

    zw._imgX := pan.x
    zw._imgY := pan.y
    _ZoomApply(zw, zw._zoomLevel)
}

_ZoomPanUp(zw, wParam, lParam, msg, hwnd) {
    if zw.HasOwnProp("_dragging") && zw._dragging {
        zw._dragging := false
        try DllCall("ReleaseCapture")
    }
}

ShowGuide(g, *) {
    guide := Gui("+AlwaysOnTop +ToolWindow", "Paint Checker Guide")
    guide.BackColor := "2B2D31"
    guide.SetFont("s10 w600", "Segoe UI")
    guide.Add("Text", "cFFFFFF x10 y10", "Paint Checker - User Guide")
    guide.SetFont("s9 w400", "Segoe UI")

    guide.SetFont("s8 w400", "Segoe UI")
    guide.Add("Text", "cAAAAAA x10 y+2 w420"
        , "This tool detects transparent (alpha) pixels in images.`n"
        . "Supports PNG, JPG, JPEG, BMP, TIFF, TGA.`n`n"
        . "How it works:`n"
        . "1. Transparent pixels are filled with the chosen hex color.`n"
        . "2. Non-transparent areas become transparent in filled output.`n"
        . "3. Overlay shows the original image, then heatmap at the chosen opacity, then fill markers.`n"
        . "4. Heatmap uses a customizable 7-color gradient (fill/edge1-5/far)`n"
        . "   to visualize transparency density with edge falloff bands.`n"
        . "5. A text report gives exact coordinates and cluster analysis.`n"
        . "6. Alpha Threshold slider (0-255) controls transparency`n"
        . "   sensitivity: 128 marks pixels with alpha < 128 as`n"
        . "   transparent. Lower values treat more pixels as transparent.`n"
        . "7. Fill Color lets you type a hex color or click a color swatch.`n"
        . "8. Fill On Top toggles whether the fill layer stays above the other overlay layers.`n"
        . "9. Full-view compare mode lets you compare any output against the others.`n`n"
        . "Output files (per image):`n"
        . "  - xxx_filled.png`n"
        . "  - xxx_heatmap.png`n"
        . "  - xxx_overlay.png`n"
        . "  - xxx_report.txt`n`n"
        . "Supported formats: PNG, JPG, JPEG, BMP, TIFF, TIF, TGA.`n"
        . "TGA is supported natively, with no external dependencies.")

    guide.Add("Text", "cCFCFCF x10 y+15", "Tips:")
    guide.Add("Text", "cAAAAAA x10 y+2 w420",
        "- Drop a single file for single-image mode`n"
        . "- Drop a folder to batch process all images`n"
        . "- Check 'Create subfolder' to keep files organized`n"
        . "- Check 'Include subfolders' for recursive batch scanning`n"
        . "- Adjust Alpha Threshold slider to control sensitivity`n"
        . "  (0 = all pixels treated transparent, 255 = only fully transparent treated)`n"
        . "- Heatmap / Original / Fill control which layers are blended into the overlay preview and export`n"
        . "- Overlay Heatmap Opacity slider controls how strong the heatmap looks in overlays`n"
        . "- Fill Color lets you type a hex code or click a color swatch`n"
        . "- Fill On Top toggles whether the fill layer is drawn above the other overlay layers`n"
        . "- Save Outputs defaults to Overlay only; turn on others if needed`n"
        . "- Save All opens a checkbox dialog so you can choose what to save for every processed image`n"
        . "- Save All can also open the output folder after saving`n"
        .         "- File info is always shown below the previews`n"
        . "- Heatmap Colors opens a dialog with 7 color inputs, live swatches, 10 presets, and gradient preview`n"
        . "- Refresh button turns orange ('Apply!') when settings change; click to reprocess current image`n"
        . "- Refresh shows a progress bar, per-image timing, and status updates`n"
        . "- Double-click any preview to open a zoomable full-view window with compare mode`n"
        . "- Check 'Export as ZIP' to bundle all outputs into a single archive")

    guide.Show("w460 h750")
}

; ===================================================================
; FormatDuration - converts milliseconds to "Xm Ys.Z" or "Y.Zs"
; ===================================================================
FormatDuration(ms) {
    if ms < 1000
        return ms "ms"
    totalSec := ms / 1000
    if totalSec < 60
        return Round(totalSec, 1) "s"
    m := Floor(totalSec / 60)
    s := Round(Mod(totalSec, 60), 1)
    return m "m " s "s"
}

; ===================================================================
; ShowResultDialog - dark-themed completion window
; ===================================================================
ShowResultDialog(msg, title) {
    dlg := Gui("+AlwaysOnTop +ToolWindow", title)
    dlg.BackColor := "2B2D31"
    dlg.SetFont("s9 w400", "Segoe UI")
    lines := 1
    loop parse msg, "`n"
        lines++
    textH := lines * 18 + 10
    dlg.Add("Text", "cCFCFCF x16 y14 w380 h" textH, msg)
    okBtn := dlg.Add("Button", "x160 y+10 w90 h26", "OK")
    okBtn.OnEvent("Click", (*) => dlg.Hide())
    dlg.Show("w410")
}

; ===================================================================
; OnClose
; ===================================================================
OnClose(g, *) {
    ; Close zoom window first
    if g.HasOwnProp("_zoomWindow") && g._zoomWindow {
        try {
            _ZoomClose(g._zoomWindow)
            g._zoomWindow.Destroy()
        }
        g._zoomWindow := 0
    }

    ; Ensure brush cleanup from GDI+ - should be clean already
    ; Dispose all result bitmaps
    for r in g._results {
        if r.HasOwnProp("filled") && r.filled
            try GDI.DisposeImage(r.filled)
        if r.HasOwnProp("heatmap") && r.heatmap
            try GDI.DisposeImage(r.heatmap)
    }
    tmpDir := A_Temp "\NastarxaPaintChecker"
    if DirExist(tmpDir) {
        loop Files tmpDir "\*.bmp"
            try FileDelete(A_LoopFileFullPath)
        try DirDelete(tmpDir)
    }
    try GDI.Shutdown()
    ExitApp()
}

; ===================================================================
; Main Entry
; ===================================================================
GDI.Startup()
g := BuildGui()
g.OnEvent("Close", OnClose)
