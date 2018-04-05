/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ABI26_0_0NSTextStorage+FontScaling.h"

#import <ReactABI26_0_0/ABI26_0_0RCTLog.h>

typedef NS_OPTIONS(NSInteger, ABI26_0_0RCTTextSizeComparisonOptions) {
  ABI26_0_0RCTTextSizeComparisonSmaller     = 1 << 0,
  ABI26_0_0RCTTextSizeComparisonLarger      = 1 << 1,
  ABI26_0_0RCTTextSizeComparisonWithinRange = 1 << 2,
};

@implementation NSTextStorage (FontScaling)

- (void)abi26_0_0_rct_scaleFontSizeToFitSize:(CGSize)size
               minimumFontSize:(CGFloat)minimumFontSize
               maximumFontSize:(CGFloat)maximumFontSize
{
  CGFloat bottomRatio = 1.0/128.0;
  CGFloat topRatio = 128.0;
  CGFloat ratio = 1.0;

  NSAttributedString *originalAttributedString = [self copy];

  CGFloat lastRatioWhichFits = 0.02;

  while (true) {
    [self abi26_0_0_rct_scaleFontSizeWithRatio:ratio
                 minimumFontSize:minimumFontSize
                 maximumFontSize:maximumFontSize];

    ABI26_0_0RCTTextSizeComparisonOptions comparsion =
      [self abi26_0_0_rct_compareToSize:size thresholdRatio:0.01];

    if (
        (comparsion & ABI26_0_0RCTTextSizeComparisonWithinRange) &&
        (comparsion & ABI26_0_0RCTTextSizeComparisonSmaller)
    ) {
      return;
    } else if (comparsion & ABI26_0_0RCTTextSizeComparisonSmaller) {
      bottomRatio = ratio;
      lastRatioWhichFits = ratio;
    } else {
      topRatio = ratio;
    }

    ratio = (topRatio + bottomRatio) / 2.0;

    CGFloat kRatioThreshold = 0.005;
    if (
        ABS(topRatio - bottomRatio) < kRatioThreshold ||
        ABS(topRatio - ratio) < kRatioThreshold ||
        ABS(bottomRatio - ratio) < kRatioThreshold
    ) {
      [self replaceCharactersInRange:(NSRange){0, self.length}
                withAttributedString:originalAttributedString];

      [self abi26_0_0_rct_scaleFontSizeWithRatio:lastRatioWhichFits
                   minimumFontSize:minimumFontSize
                   maximumFontSize:maximumFontSize];
      return;
    }

    [self replaceCharactersInRange:(NSRange){0, self.length}
              withAttributedString:originalAttributedString];
  }
}


- (ABI26_0_0RCTTextSizeComparisonOptions)abi26_0_0_rct_compareToSize:(CGSize)size thresholdRatio:(CGFloat)thresholdRatio
{
  NSLayoutManager *layoutManager = self.layoutManagers.firstObject;
  NSTextContainer *textContainer = layoutManager.textContainers.firstObject;

  [layoutManager ensureLayoutForTextContainer:textContainer];

  // Does it fit the text container?
  NSRange glyphRange = [layoutManager glyphRangeForTextContainer:textContainer];
  NSRange truncatedGlyphRange = [layoutManager truncatedGlyphRangeInLineFragmentForGlyphAtIndex:glyphRange.length - 1];

  if (truncatedGlyphRange.location != NSNotFound) {
    return ABI26_0_0RCTTextSizeComparisonLarger;
  }

  CGSize measuredSize = [layoutManager usedRectForTextContainer:textContainer].size;

  // Does it fit the size?
  BOOL fitsSize =
    size.width >= measuredSize.width &&
    size.height >= measuredSize.height;

  CGSize thresholdSize = (CGSize){
    size.width * thresholdRatio,
    size.height * thresholdRatio,
  };

  ABI26_0_0RCTTextSizeComparisonOptions result = 0;

  result |= (fitsSize) ? ABI26_0_0RCTTextSizeComparisonSmaller : ABI26_0_0RCTTextSizeComparisonLarger;

  if (ABS(measuredSize.width - size.width) < thresholdSize.width) {
    result = result | ABI26_0_0RCTTextSizeComparisonWithinRange;
  }

  return result;
}

- (void)abi26_0_0_rct_scaleFontSizeWithRatio:(CGFloat)ratio
               minimumFontSize:(CGFloat)minimumFontSize
               maximumFontSize:(CGFloat)maximumFontSize
{
  [self beginEditing];

  [self enumerateAttribute:NSFontAttributeName
                   inRange:(NSRange){0, self.length}
                   options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                usingBlock:
    ^(UIFont *_Nullable font, NSRange range, BOOL *_Nonnull stop) {
      if (!font) {
        return;
      }

      CGFloat fontSize = MAX(MIN(font.pointSize * ratio, maximumFontSize), minimumFontSize);

      UIFont *scaledFont = [font fontWithSize:fontSize];
      if (scaledFont) {
        [self addAttribute:NSFontAttributeName
                    value:scaledFont
                    range:range];
      } else {
        ABI26_0_0RCTLogError(@"Font \"%@"" doesn't support automatic scaling.", font.familyName);
      }
    }
  ];

  [self endEditing];
}

@end
