#import "ABI29_0_0RNSVGFontData.h"
#import "ABI29_0_0RNSVGPropHelper.h"
#import "ABI29_0_0RNSVGTextProperties.h"
#import "ABI29_0_0RNSVGNode.h"

#define ABI29_0_0RNSVG_DEFAULT_KERNING 0.0
#define ABI29_0_0RNSVG_DEFAULT_WORD_SPACING 0.0
#define ABI29_0_0RNSVG_DEFAULT_LETTER_SPACING 0.0
static NSString *KERNING = @"kerning";
static NSString *FONT_SIZE = @"fontSize";
static NSString *FONT_DATA = @"fontData";
static NSString *FONT_STYLE = @"fontStyle";
static NSString *FONT_WEIGHT = @"fontWeight";
static NSString *FONT_FAMILY = @"fontFamily";
static NSString *TEXT_ANCHOR = @"textAnchor";
static NSString *WORD_SPACING = @"wordSpacing";
static NSString *LETTER_SPACING = @"letterSpacing";
static NSString *TEXT_DECORATION = @"textDecoration";
static NSString *FONT_FEATURE_SETTINGS = @"fontFeatureSettings";
static NSString *FONT_VARIANT_LIGATURES = @"fontVariantLigatures";

ABI29_0_0RNSVGFontData *ABI29_0_0RNSVGFontData_Defaults;

@implementation ABI29_0_0RNSVGFontData

+ (instancetype)Defaults {
    if (!ABI29_0_0RNSVGFontData_Defaults) {
        ABI29_0_0RNSVGFontData *self = [ABI29_0_0RNSVGFontData alloc];
        self->fontData = nil;
        self->fontFamily = @"";
        self->fontStyle = ABI29_0_0RNSVGFontStyleNormal;
        self->fontWeight = ABI29_0_0RNSVGFontWeightNormal;
        self->fontFeatureSettings = @"";
        self->fontVariantLigatures = ABI29_0_0RNSVGFontVariantLigaturesNormal;
        self->textAnchor = ABI29_0_0RNSVGTextAnchorStart;
        self->textDecoration = ABI29_0_0RNSVGTextDecorationNone;
        self->manualKerning = false;
        self->kerning = ABI29_0_0RNSVG_DEFAULT_KERNING;
        self->fontSize = ABI29_0_0RNSVG_DEFAULT_FONT_SIZE;
        self->wordSpacing = ABI29_0_0RNSVG_DEFAULT_WORD_SPACING;
        self->letterSpacing = ABI29_0_0RNSVG_DEFAULT_LETTER_SPACING;
        ABI29_0_0RNSVGFontData_Defaults = self;
    }
    return ABI29_0_0RNSVGFontData_Defaults;
}

+ (double)toAbsoluteWithNSString:(NSString *)string
                           scale:(double)scale
                        fontSize:(double)fontSize {
    return [ABI29_0_0RNSVGPropHelper fromRelativeWithNSString:string
                                         relative:0
                                           offset:0
                                            scale:scale
                                         fontSize:fontSize];
}

+ (instancetype)initWithNSDictionary:(NSDictionary *)font
                              parent:(ABI29_0_0RNSVGFontData *)parent
                               scale:(double)scale {
    ABI29_0_0RNSVGFontData *data = [ABI29_0_0RNSVGFontData alloc];
    double parentFontSize = parent->fontSize;
    if ([font objectForKey:FONT_SIZE]) {
        NSString *string = [font objectForKey:FONT_SIZE];
        data->fontSize = [ABI29_0_0RNSVGPropHelper fromRelativeWithNSString:string
                                                       relative:parentFontSize
                                                         offset:0
                                                          scale:scale
                                                       fontSize:parentFontSize];
    }
    else {
        data->fontSize = parentFontSize;
    }
    data->fontData = [font objectForKey:FONT_DATA] ? [font objectForKey:FONT_DATA] : parent->fontData;
    data->fontFamily = [font objectForKey:FONT_FAMILY] ? [font objectForKey:FONT_FAMILY] : parent->fontFamily;
    NSString* style = [font objectForKey:FONT_STYLE];
    data->fontStyle = style ? ABI29_0_0RNSVGFontStyleFromString(style) : parent->fontStyle;
    NSString* weight = [font objectForKey:FONT_WEIGHT];
    data->fontWeight = weight ? ABI29_0_0RNSVGFontWeightFromString(weight) : parent->fontWeight;
    NSString* feature = [font objectForKey:FONT_FEATURE_SETTINGS];
    data->fontFeatureSettings = feature ? [font objectForKey:FONT_FEATURE_SETTINGS] : parent->fontFeatureSettings;
    NSString* variant = [font objectForKey:FONT_VARIANT_LIGATURES];
    data->fontVariantLigatures = variant ? ABI29_0_0RNSVGFontVariantLigaturesFromString(variant) : parent->fontVariantLigatures;
    NSString* anchor = [font objectForKey:TEXT_ANCHOR];
    data->textAnchor = anchor ? ABI29_0_0RNSVGTextAnchorFromString(anchor) : parent->textAnchor;
    NSString* decoration = [font objectForKey:TEXT_DECORATION];
    data->textDecoration = decoration ? ABI29_0_0RNSVGTextDecorationFromString(decoration) : parent->textDecoration;
    NSString* kerning = [font objectForKey:KERNING];
    data->manualKerning = (kerning || parent->manualKerning );
    data->kerning = kerning ? [ABI29_0_0RNSVGFontData toAbsoluteWithNSString:kerning
                                                         scale:scale
                                                      fontSize:data->fontSize ] : parent->kerning;
    NSString* wordSpacing = [font objectForKey:WORD_SPACING];
    data->wordSpacing = wordSpacing ? [ABI29_0_0RNSVGFontData toAbsoluteWithNSString:wordSpacing
                                                                 scale:scale
                                                              fontSize:data->fontSize ] : parent->wordSpacing;
    NSString* letterSpacing = [font objectForKey:LETTER_SPACING];
    data->letterSpacing = letterSpacing ? [ABI29_0_0RNSVGFontData toAbsoluteWithNSString:letterSpacing
                                                                     scale:scale
                                                                  fontSize:data->fontSize ] : parent->letterSpacing;
    return data;
}


@end
