#import <Gosu/Platform.hpp>

#if defined(GOSU_IS_IPHONE) || defined(__LP64__)

#import <Gosu/Text.hpp>
#import <Gosu/Bitmap.hpp>
#import <Gosu/Utility.hpp>
#import <GosuImpl/MacUtility.hpp>
#import <map>
#import <cmath>
using namespace std;

#if defined(GOSU_IS_IPHONE)
#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
typedef UIFont OSXFont;
#else
#import <AppKit/AppKit.h>
typedef NSFont OSXFont;
#endif

namespace
{
    using Gosu::ObjRef;
    using Gosu::CFRef;

    // If a font is a filename, loads the font and returns its family name that can be used
    // like any system font. Otherwise, just returns the family name.
    std::wstring normalizeFont(const std::wstring& fontName)
    {
        #ifdef GOSU_IS_IPHONE
        return fontName;
        #else
        static map<wstring, wstring> familyOfFiles;
        
        // Not a path name: It is already a family name
        if (fontName.find(L"/") == std::wstring::npos)
            return fontName;
        
        // Already activated font & extracted family name
        if (familyOfFiles.count(fontName) > 0)
            return familyOfFiles[fontName];
        
        CFRef<CFStringRef> urlString(
            CFStringCreateWithBytes(NULL,
                reinterpret_cast<const UInt8*>(fontName.c_str()),
                fontName.length() * sizeof(wchar_t),
                kCFStringEncodingUTF32LE, NO));
        CFRef<CFURLRef> url(
            CFURLCreateWithFileSystemPath(NULL, urlString.obj(),
                kCFURLPOSIXPathStyle, YES));
        if (!url.get())
            return familyOfFiles[fontName] = Gosu::defaultFontName();
            
        CFRef<CFArrayRef> array(
            CTFontManagerCreateFontDescriptorsFromURL(url.obj()));

        if (array.get() == NULL || CFArrayGetCount(array.obj()) < 1 ||
            !CTFontManagerRegisterFontsForURL(url.obj(),
                    kCTFontManagerScopeProcess, NULL))
            return familyOfFiles[fontName] = Gosu::defaultFontName();

        CTFontDescriptorRef ref =
            (CTFontDescriptorRef)CFArrayGetValueAtIndex(array.get(), 0);
        CFRef<CFStringRef> fontNameStr(
            (CFStringRef)CTFontDescriptorCopyAttribute(ref, kCTFontFamilyNameAttribute));
                
        const char* utf8FontName =
            [(NSString*)fontNameStr.obj() cStringUsingEncoding: NSUTF8StringEncoding];
        return familyOfFiles[fontName] = Gosu::utf8ToWstring(utf8FontName);
        #endif
    }

    OSXFont* getFont(wstring fontName, unsigned fontFlags, double height)
    {
        fontName = normalizeFont(fontName);
    
        static map<pair<wstring, pair<unsigned, double> >, OSXFont*> usedFonts;
        
        OSXFont* result = usedFonts[make_pair(fontName, make_pair(fontFlags, height))];
        if (!result)
        {
            ObjRef<NSString> name([[NSString alloc] initWithUTF8String: Gosu::wstringToUTF8(fontName).c_str()]);
            #ifdef GOSU_IS_IPHONE
            result = [OSXFont fontWithName: name.obj() size: height];
            #else
            NSFontDescriptor* desc = [[NSFontDescriptor fontDescriptorWithFontAttributes:nil] fontDescriptorWithFamily:name.obj()];
            result = [[NSFont fontWithDescriptor:desc size:height] retain];
            if (result && (fontFlags & Gosu::ffBold))
                result = [[NSFontManager sharedFontManager] convertFont:result toHaveTrait:NSFontBoldTrait];
            if (result && (fontFlags & Gosu::ffItalic))
                result = [[NSFontManager sharedFontManager] convertFont:result toHaveTrait:NSFontItalicTrait];
            #endif
            if (!result && fontName != Gosu::defaultFontName())
                result = getFont(Gosu::defaultFontName(), 0, height);
            assert(result);
            usedFonts[make_pair(fontName, make_pair(fontFlags, height))] = [result retain];
        }
        return result;
    }
}

wstring Gosu::defaultFontName()
{
    // OF COURSE Helvetica is better - but the dots above my capital umlauts get
    // eaten when I use it with Gosu. Until this is fixed, keep Arial. (TODO)
    return L"Arial";
}

#ifndef GOSU_IS_IPHONE
namespace
{
    NSDictionary* attributeDictionary(NSFont* font, Gosu::Color color, unsigned fontFlags)
    {
        static std::map<Gosu::Color, NSColor*> colorCache;
        
        // Because of the way we later copy the buffer directly to a Gosu::Bitmap, we
        // need to swap the color components already.
        color = color.abgr();
        
        if (!colorCache[color])
            colorCache[color] = [[NSColor colorWithDeviceRed:color.red()/255.0
                green:color.green()/255.0 blue:color.blue()/255.0 alpha:color.alpha()/255.0] retain];
        
        NSMutableDictionary* dict =
            [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                font, NSFontAttributeName,
                colorCache[color], NSForegroundColorAttributeName,
                nil];
        if (fontFlags & Gosu::ffUnderline)
        {
            Gosu::ObjRef<NSNumber> underline([[NSNumber alloc] initWithInt:NSUnderlineStyleSingle]);
            [dict setValue: underline.obj() forKey:NSUnderlineStyleAttributeName];
        }
        return dict;
    }
}
#endif

unsigned Gosu::textWidth(const wstring& text,
    const wstring& fontName, unsigned fontHeight, unsigned fontFlags)
{
    OSXFont* font = getFont(fontName, fontFlags, fontHeight);
    
    // This will, of course, compute a too large size; fontHeight is in pixels,
    // the method expects point.
    ObjRef<NSString> string([[NSString alloc] initWithUTF8String: wstringToUTF8(text).c_str()]);
    #ifndef GOSU_IS_IPHONE
    ObjRef<NSDictionary> attributes(attributeDictionary(font, 0xffffffff, fontFlags));
    NSSize size = [string.obj() sizeWithAttributes: attributes.get()];
    #else
    CGSize size = [string.obj() sizeWithFont: font];
    #endif
                           
    // Now adjust the scaling...
    return ceil(size.width / size.height * fontHeight);
}

void Gosu::drawText(Bitmap& bitmap, const wstring& text, int x, int y,
    Color c, const wstring& fontName, unsigned fontHeight,
    unsigned fontFlags)
{
    OSXFont* font = getFont(fontName, fontFlags, fontHeight);
    ObjRef<NSString> string([[NSString alloc] initWithUTF8String: wstringToUTF8(text).c_str()]);

    // This will, of course, compute a too large size; fontHeight is in pixels, the method expects point.
    #ifndef GOSU_IS_IPHONE
    ObjRef<NSDictionary> attributes(attributeDictionary(font, c, fontFlags));
    NSSize size = [string.obj() sizeWithAttributes: attributes.get()];
    #else
    CGSize size = [string.obj() sizeWithFont: font];
    #endif
    
    unsigned width = ceil(size.width / size.height * fontHeight);

    // Get the width and height of the image
    Bitmap bmp;
    bmp.resize(width, fontHeight);
    
    // Use a temporary context to draw the CGImage to the buffer.
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context =
        CGBitmapContextCreate(bmp.data(),
                              bmp.width(), bmp.height(), 8, bmp.width() * 4,
                              colorSpace,
                              kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);
    #ifdef GOSU_IS_IPHONE
    CGFloat color[] = { c.green() / 255.0, c.blue() / 255.0, c.red() / 255.0, 0 };
    CGContextSetStrokeColor(context, color);
    CGContextSetFillColor(context, color);
    #endif
    
    // Use new font with proper size this time.
    font = getFont(fontName, fontFlags, fontHeight * fontHeight / size.height);

    #ifdef GOSU_IS_IPHONE
    CGContextTranslateCTM(context, 0, fontHeight);
    CGContextScaleCTM(context, 1, -1);
    UIGraphicsPushContext(context);
        [string.obj() drawAtPoint: CGPointZero withFont: font];
    UIGraphicsPopContext();
    #else
    NSPoint NSPointZero = { 0, 0 };
    attributes.reset(attributeDictionary(font, c, fontFlags));
    
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:
        [NSGraphicsContext graphicsContextWithGraphicsPort:(void *)context flipped:false]];
    [string.obj() drawAtPoint: NSPointZero withAttributes: attributes.get()];
    [NSGraphicsContext restoreGraphicsState];
    #endif
    CGContextRelease(context);

    // Done!
    bitmap.insert(bmp, x, y);
}

#endif
