/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ABI26_0_0RCTTextShadowView.h"

#import <ReactABI26_0_0/ABI26_0_0RCTBridge.h>
#import <ReactABI26_0_0/ABI26_0_0RCTShadowView+Layout.h>
#import <ReactABI26_0_0/ABI26_0_0RCTUIManager.h>
#import <YogaABI26_0_0/ABI26_0_0Yoga.h>

#import "ABI26_0_0NSTextStorage+FontScaling.h"
#import "ABI26_0_0RCTTextView.h"

@implementation ABI26_0_0RCTTextShadowView
{
  __weak ABI26_0_0RCTBridge *_bridge;
  BOOL _needsUpdateView;
  NSMapTable<id, NSTextStorage *> *_cachedTextStorages;
}

- (instancetype)initWithBridge:(ABI26_0_0RCTBridge *)bridge
{
  if (self = [super init]) {
    _bridge = bridge;
    _cachedTextStorages = [NSMapTable strongToStrongObjectsMapTable];
    _needsUpdateView = YES;
    ABI26_0_0YGNodeSetMeasureFunc(self.yogaNode, ABI26_0_0RCTTextShadowViewMeasure);
  }

  return self;
}

- (BOOL)isYogaLeafNode
{
  return YES;
}

- (void)dirtyLayout
{
  [super dirtyLayout];
  ABI26_0_0YGNodeMarkDirty(self.yogaNode);
  [self invalidateCache];
}

- (void)invalidateCache
{
  [_cachedTextStorages removeAllObjects];
  _needsUpdateView = YES;
}

#pragma mark - ABI26_0_0RCTUIManagerObserver

- (void)uiManagerWillPerformMounting
{
  if (ABI26_0_0YGNodeIsDirty(self.yogaNode)) {
    return;
  }

  if (!_needsUpdateView) {
    return;
  }
  _needsUpdateView = NO;

  CGRect contentFrame = self.contentFrame;
  NSTextStorage *textStorage = [self textStorageAndLayoutManagerThatFitsSize:self.contentFrame.size
                                                          exclusiveOwnership:YES];

  NSNumber *tag = self.ReactABI26_0_0Tag;
  NSMutableArray<NSNumber *> *descendantViewTags = [NSMutableArray new];
  [textStorage enumerateAttribute:ABI26_0_0RCTBaseTextShadowViewEmbeddedShadowViewAttributeName
                          inRange:NSMakeRange(0, textStorage.length)
                          options:0
                       usingBlock:
   ^(ABI26_0_0RCTShadowView *shadowView, NSRange range, __unused BOOL *stop) {
     if (!shadowView) {
       return;
     }

     [descendantViewTags addObject:shadowView.ReactABI26_0_0Tag];
   }
  ];

  [_bridge.uiManager addUIBlock:^(ABI26_0_0RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    ABI26_0_0RCTTextView *textView = (ABI26_0_0RCTTextView *)viewRegistry[tag];
    if (!textView) {
      return;
    }

    NSMutableArray<UIView *> *descendantViews =
      [NSMutableArray arrayWithCapacity:descendantViewTags.count];
    [descendantViewTags enumerateObjectsUsingBlock:^(NSNumber *_Nonnull descendantViewTag, NSUInteger index, BOOL *_Nonnull stop) {
      UIView *descendantView = viewRegistry[descendantViewTag];
      if (!descendantView) {
        return;
      }

      [descendantViews addObject:descendantView];
    }];

    // Removing all references to Shadow Views to avoid unnececery retainning.
    [textStorage removeAttribute:ABI26_0_0RCTBaseTextShadowViewEmbeddedShadowViewAttributeName range:NSMakeRange(0, textStorage.length)];

    [textView setTextStorage:textStorage
                contentFrame:contentFrame
             descendantViews:descendantViews];
  }];
}

- (void)postprocessAttributedText:(NSMutableAttributedString *)attributedText
{
  __block CGFloat maximumLineHeight = 0;

  [attributedText enumerateAttribute:NSParagraphStyleAttributeName
                             inRange:NSMakeRange(0, attributedText.length)
                             options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                          usingBlock:
    ^(NSParagraphStyle *paragraphStyle, __unused NSRange range, __unused BOOL *stop) {
      if (!paragraphStyle) {
        return;
      }

      maximumLineHeight = MAX(paragraphStyle.maximumLineHeight, maximumLineHeight);
    }
  ];

  if (maximumLineHeight == 0) {
    // `lineHeight` was not specified, nothing to do.
    return;
  }

  [attributedText beginEditing];

  [attributedText enumerateAttribute:NSFontAttributeName
                             inRange:NSMakeRange(0, attributedText.length)
                             options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                          usingBlock:
    ^(UIFont *font, NSRange range, __unused BOOL *stop) {
      if (!font) {
        return;
      }

      if (maximumLineHeight <= font.lineHeight) {
        return;
      }

      CGFloat baseLineOffset = maximumLineHeight / 2.0 - font.lineHeight / 2.0;

      [attributedText addAttribute:NSBaselineOffsetAttributeName
                             value:@(baseLineOffset)
                             range:range];
     }
   ];

   [attributedText endEditing];
}

- (NSAttributedString *)attributedTextWithMeasuredAttachmentsThatFitSize:(CGSize)size
{
  NSMutableAttributedString *attributedText =
    [[NSMutableAttributedString alloc] initWithAttributedString:[self attributedTextWithBaseTextAttributes:nil]];

  [attributedText beginEditing];

  [attributedText enumerateAttribute:ABI26_0_0RCTBaseTextShadowViewEmbeddedShadowViewAttributeName
                               inRange:NSMakeRange(0, attributedText.length)
                               options:0
                            usingBlock:
    ^(ABI26_0_0RCTShadowView *shadowView, NSRange range, __unused BOOL *stop) {
      if (!shadowView) {
        return;
      }

      CGSize fittingSize = [shadowView sizeThatFitsMinimumSize:CGSizeZero
                                                   maximumSize:size];
      NSTextAttachment *attachment = [NSTextAttachment new];
      attachment.bounds = (CGRect){CGPointZero, fittingSize};
      [attributedText addAttribute:NSAttachmentAttributeName value:attachment range:range];
    }
  ];

  [attributedText endEditing];

  return [attributedText copy];
}

- (NSTextStorage *)textStorageAndLayoutManagerThatFitsSize:(CGSize)size
                                        exclusiveOwnership:(BOOL)exclusiveOwnership
{
  NSValue *key = [NSValue valueWithCGSize:size];
  NSTextStorage *cachedTextStorage = [_cachedTextStorages objectForKey:key];

  if (cachedTextStorage) {
    if (exclusiveOwnership) {
      [_cachedTextStorages removeObjectForKey:key];
    }

    return cachedTextStorage;
  }

  NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:size];

  textContainer.lineFragmentPadding = 0.0; // Note, the default value is 5.
  textContainer.lineBreakMode =
    _maximumNumberOfLines > 0 ? _lineBreakMode : NSLineBreakByClipping;
  textContainer.maximumNumberOfLines = _maximumNumberOfLines;

  NSLayoutManager *layoutManager = [NSLayoutManager new];
  [layoutManager addTextContainer:textContainer];

  NSTextStorage *textStorage =
    [[NSTextStorage alloc] initWithAttributedString:[self attributedTextWithMeasuredAttachmentsThatFitSize:size]];

  [self postprocessAttributedText:textStorage];

  [textStorage addLayoutManager:layoutManager];

  if (_adjustsFontSizeToFit) {
    CGFloat minimumFontSize =
      MAX(_minimumFontScale * (self.textAttributes.effectiveFont.pointSize), 4.0);
    [textStorage abi26_0_0_rct_scaleFontSizeToFitSize:size
                        minimumFontSize:minimumFontSize
                        maximumFontSize:self.textAttributes.effectiveFont.pointSize];
  }

  if (!exclusiveOwnership) {
    [_cachedTextStorages setObject:textStorage forKey:key];
  }

  return textStorage;
}

- (void)applyLayoutNode:(ABI26_0_0YGNodeRef)node
      viewsWithNewFrame:(NSMutableSet<ABI26_0_0RCTShadowView *> *)viewsWithNewFrame
       absolutePosition:(CGPoint)absolutePosition
{
  if (ABI26_0_0YGNodeGetHasNewLayout(self.yogaNode)) {
    // If the view got new layout, we have to redraw it because `contentFrame`
    // and sizes of embedded views may change.
    _needsUpdateView = YES;
  }

  [super applyLayoutNode:node
       viewsWithNewFrame:viewsWithNewFrame
        absolutePosition:absolutePosition];
}

- (void)applyLayoutWithFrame:(CGRect)frame
             layoutDirection:(UIUserInterfaceLayoutDirection)layoutDirection
      viewsWithUpdatedLayout:(NSMutableSet<ABI26_0_0RCTShadowView *> *)viewsWithUpdatedLayout
            absolutePosition:(CGPoint)absolutePosition
{
  if (self.textAttributes.layoutDirection != layoutDirection) {
    self.textAttributes.layoutDirection = layoutDirection;
    [self invalidateCache];
  }

  [super applyLayoutWithFrame:frame
              layoutDirection:layoutDirection
       viewsWithUpdatedLayout:viewsWithUpdatedLayout
             absolutePosition:absolutePosition];
}

- (void)applyLayoutToChildren:(ABI26_0_0YGNodeRef)node
            viewsWithNewFrame:(NSMutableSet<ABI26_0_0RCTShadowView *> *)viewsWithNewFrame
             absolutePosition:(CGPoint)absolutePosition
{
  NSTextStorage *textStorage =
    [self textStorageAndLayoutManagerThatFitsSize:self.availableSize
                               exclusiveOwnership:NO];
  NSLayoutManager *layoutManager = textStorage.layoutManagers.firstObject;
  NSTextContainer *textContainer = layoutManager.textContainers.firstObject;
  NSRange glyphRange = [layoutManager glyphRangeForTextContainer:textContainer];
  NSRange characterRange = [layoutManager characterRangeForGlyphRange:glyphRange
                                                     actualGlyphRange:NULL];

  [textStorage enumerateAttribute:ABI26_0_0RCTBaseTextShadowViewEmbeddedShadowViewAttributeName
                                        inRange:characterRange
                                        options:0
                                     usingBlock:
    ^(ABI26_0_0RCTShadowView *shadowView, NSRange range, BOOL *stop) {
      if (!shadowView) {
        return;
      }

      CGRect glyphRect = [layoutManager boundingRectForGlyphRange:range
                                                  inTextContainer:textContainer];

      NSTextAttachment *attachment =
        [textStorage attribute:NSAttachmentAttributeName atIndex:range.location effectiveRange:nil];

      CGSize attachmentSize = attachment.bounds.size;

      UIFont *font = [textStorage attribute:NSFontAttributeName atIndex:range.location effectiveRange:nil];

      CGRect frame = {{
        ABI26_0_0RCTRoundPixelValue(glyphRect.origin.x),
        ABI26_0_0RCTRoundPixelValue(glyphRect.origin.y + glyphRect.size.height - attachmentSize.height + font.descender)
      }, {
        ABI26_0_0RCTRoundPixelValue(attachmentSize.width),
        ABI26_0_0RCTRoundPixelValue(attachmentSize.height)
      }};

      UIUserInterfaceLayoutDirection layoutDirection = self.textAttributes.layoutDirection;

      ABI26_0_0YGNodeCalculateLayout(
        shadowView.yogaNode,
        frame.size.width,
        frame.size.height,
        layoutDirection == UIUserInterfaceLayoutDirectionLeftToRight ? ABI26_0_0YGDirectionLTR : ABI26_0_0YGDirectionRTL);

      [shadowView applyLayoutWithFrame:frame
                       layoutDirection:layoutDirection
                viewsWithUpdatedLayout:viewsWithNewFrame
                      absolutePosition:absolutePosition];
    }
  ];
}

static ABI26_0_0YGSize ABI26_0_0RCTTextShadowViewMeasure(ABI26_0_0YGNodeRef node, float width, ABI26_0_0YGMeasureMode widthMode, float height, ABI26_0_0YGMeasureMode heightMode)
{
  CGSize maximumSize = (CGSize){
    widthMode == ABI26_0_0YGMeasureModeUndefined ? CGFLOAT_MAX : ABI26_0_0RCTCoreGraphicsFloatFromYogaFloat(width),
    heightMode == ABI26_0_0YGMeasureModeUndefined ? CGFLOAT_MAX : ABI26_0_0RCTCoreGraphicsFloatFromYogaFloat(height),
  };

  ABI26_0_0RCTTextShadowView *shadowTextView = (__bridge ABI26_0_0RCTTextShadowView *)ABI26_0_0YGNodeGetContext(node);

  NSTextStorage *textStorage =
    [shadowTextView textStorageAndLayoutManagerThatFitsSize:maximumSize
                                         exclusiveOwnership:NO];

  NSLayoutManager *layoutManager = textStorage.layoutManagers.firstObject;
  NSTextContainer *textContainer = layoutManager.textContainers.firstObject;
  [layoutManager ensureLayoutForTextContainer:textContainer];
  CGSize size = [layoutManager usedRectForTextContainer:textContainer].size;

  CGFloat letterSpacing = shadowTextView.textAttributes.letterSpacing;
  if (!isnan(letterSpacing) && letterSpacing < 0) {
    size.width -= letterSpacing;
  }

  size = (CGSize){
    MIN(ABI26_0_0RCTCeilPixelValue(size.width), maximumSize.width),
    MIN(ABI26_0_0RCTCeilPixelValue(size.height), maximumSize.height)
  };

  return (ABI26_0_0YGSize){
    ABI26_0_0RCTYogaFloatFromCoreGraphicsFloat(size.width),
    ABI26_0_0RCTYogaFloatFromCoreGraphicsFloat(size.height)
  };
}

@end
