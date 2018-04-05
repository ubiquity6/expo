/**
 * Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#include "ABI26_0_0YGNode.h"
#include <iostream>
#include "ABI26_0_0Utils.h"

void* ABI26_0_0YGNode::getContext() const {
  return context_;
}

ABI26_0_0YGPrintFunc ABI26_0_0YGNode::getPrintFunc() const {
  return print_;
}

bool ABI26_0_0YGNode::getHasNewLayout() const {
  return hasNewLayout_;
}

ABI26_0_0YGNodeType ABI26_0_0YGNode::getNodeType() const {
  return nodeType_;
}

ABI26_0_0YGMeasureFunc ABI26_0_0YGNode::getMeasure() const {
  return measure_;
}

ABI26_0_0YGBaselineFunc ABI26_0_0YGNode::getBaseline() const {
  return baseline_;
}

ABI26_0_0YGDirtiedFunc ABI26_0_0YGNode::getDirtied() const {
  return dirtied_;
}

ABI26_0_0YGStyle& ABI26_0_0YGNode::getStyle() {
  return style_;
}

ABI26_0_0YGLayout& ABI26_0_0YGNode::getLayout() {
  return layout_;
}

uint32_t ABI26_0_0YGNode::getLineIndex() const {
  return lineIndex_;
}

ABI26_0_0YGNodeRef ABI26_0_0YGNode::getParent() const {
  return parent_;
}

ABI26_0_0YGVector ABI26_0_0YGNode::getChildren() const {
  return children_;
}

uint32_t ABI26_0_0YGNode::getChildrenCount() const {
  return static_cast<uint32_t>(children_.size());
}

ABI26_0_0YGNodeRef ABI26_0_0YGNode::getChild(uint32_t index) const {
  return children_.at(index);
}

ABI26_0_0YGNodeRef ABI26_0_0YGNode::getNextChild() const {
  return nextChild_;
}

ABI26_0_0YGConfigRef ABI26_0_0YGNode::getConfig() const {
  return config_;
}

bool ABI26_0_0YGNode::isDirty() const {
  return isDirty_;
}

ABI26_0_0YGValue ABI26_0_0YGNode::getResolvedDimension(int index) {
  return resolvedDimensions_[index];
}

std::array<ABI26_0_0YGValue, 2> ABI26_0_0YGNode::getResolvedDimensions() const {
  return resolvedDimensions_;
}

float ABI26_0_0YGNode::getLeadingPosition(
    const ABI26_0_0YGFlexDirection axis,
    const float axisSize) {
  if (ABI26_0_0YGFlexDirectionIsRow(axis)) {
    const ABI26_0_0YGValue* leadingPosition =
        ABI26_0_0YGComputedEdgeValue(style_.position, ABI26_0_0YGEdgeStart, &ABI26_0_0YGValueUndefined);
    if (leadingPosition->unit != ABI26_0_0YGUnitUndefined) {
      return ABI26_0_0YGResolveValue(*leadingPosition, axisSize);
    }
  }

  const ABI26_0_0YGValue* leadingPosition =
      ABI26_0_0YGComputedEdgeValue(style_.position, leading[axis], &ABI26_0_0YGValueUndefined);

  return leadingPosition->unit == ABI26_0_0YGUnitUndefined
      ? 0.0f
      : ABI26_0_0YGResolveValue(*leadingPosition, axisSize);
}

float ABI26_0_0YGNode::getTrailingPosition(
    const ABI26_0_0YGFlexDirection axis,
    const float axisSize) {
  if (ABI26_0_0YGFlexDirectionIsRow(axis)) {
    const ABI26_0_0YGValue* trailingPosition =
        ABI26_0_0YGComputedEdgeValue(style_.position, ABI26_0_0YGEdgeEnd, &ABI26_0_0YGValueUndefined);
    if (trailingPosition->unit != ABI26_0_0YGUnitUndefined) {
      return ABI26_0_0YGResolveValue(*trailingPosition, axisSize);
    }
  }

  const ABI26_0_0YGValue* trailingPosition =
      ABI26_0_0YGComputedEdgeValue(style_.position, trailing[axis], &ABI26_0_0YGValueUndefined);

  return trailingPosition->unit == ABI26_0_0YGUnitUndefined
      ? 0.0f
      : ABI26_0_0YGResolveValue(*trailingPosition, axisSize);
}

bool ABI26_0_0YGNode::isLeadingPositionDefined(const ABI26_0_0YGFlexDirection axis) {
  return (ABI26_0_0YGFlexDirectionIsRow(axis) &&
          ABI26_0_0YGComputedEdgeValue(style_.position, ABI26_0_0YGEdgeStart, &ABI26_0_0YGValueUndefined)
                  ->unit != ABI26_0_0YGUnitUndefined) ||
      ABI26_0_0YGComputedEdgeValue(style_.position, leading[axis], &ABI26_0_0YGValueUndefined)
          ->unit != ABI26_0_0YGUnitUndefined;
}

bool ABI26_0_0YGNode::isTrailingPosDefined(const ABI26_0_0YGFlexDirection axis) {
  return (ABI26_0_0YGFlexDirectionIsRow(axis) &&
          ABI26_0_0YGComputedEdgeValue(style_.position, ABI26_0_0YGEdgeEnd, &ABI26_0_0YGValueUndefined)
                  ->unit != ABI26_0_0YGUnitUndefined) ||
      ABI26_0_0YGComputedEdgeValue(style_.position, trailing[axis], &ABI26_0_0YGValueUndefined)
          ->unit != ABI26_0_0YGUnitUndefined;
}

float ABI26_0_0YGNode::getLeadingMargin(
    const ABI26_0_0YGFlexDirection axis,
    const float widthSize) {
  if (ABI26_0_0YGFlexDirectionIsRow(axis) &&
      style_.margin[ABI26_0_0YGEdgeStart].unit != ABI26_0_0YGUnitUndefined) {
    return ABI26_0_0YGResolveValueMargin(style_.margin[ABI26_0_0YGEdgeStart], widthSize);
  }

  return ABI26_0_0YGResolveValueMargin(
      *ABI26_0_0YGComputedEdgeValue(style_.margin, leading[axis], &ABI26_0_0YGValueZero),
      widthSize);
}

float ABI26_0_0YGNode::getTrailingMargin(
    const ABI26_0_0YGFlexDirection axis,
    const float widthSize) {
  if (ABI26_0_0YGFlexDirectionIsRow(axis) &&
      style_.margin[ABI26_0_0YGEdgeEnd].unit != ABI26_0_0YGUnitUndefined) {
    return ABI26_0_0YGResolveValueMargin(style_.margin[ABI26_0_0YGEdgeEnd], widthSize);
  }

  return ABI26_0_0YGResolveValueMargin(
      *ABI26_0_0YGComputedEdgeValue(style_.margin, trailing[axis], &ABI26_0_0YGValueZero),
      widthSize);
}

float ABI26_0_0YGNode::getMarginForAxis(
    const ABI26_0_0YGFlexDirection axis,
    const float widthSize) {
  return getLeadingMargin(axis, widthSize) + getTrailingMargin(axis, widthSize);
}

// Setters

void ABI26_0_0YGNode::setContext(void* context) {
  context_ = context;
}

void ABI26_0_0YGNode::setPrintFunc(ABI26_0_0YGPrintFunc printFunc) {
  print_ = printFunc;
}

void ABI26_0_0YGNode::setHasNewLayout(bool hasNewLayout) {
  hasNewLayout_ = hasNewLayout;
}

void ABI26_0_0YGNode::setNodeType(ABI26_0_0YGNodeType nodeType) {
  nodeType_ = nodeType;
}

void ABI26_0_0YGNode::setStyleFlexDirection(ABI26_0_0YGFlexDirection direction) {
  style_.flexDirection = direction;
}

void ABI26_0_0YGNode::setStyleAlignContent(ABI26_0_0YGAlign alignContent) {
  style_.alignContent = alignContent;
}

void ABI26_0_0YGNode::setMeasureFunc(ABI26_0_0YGMeasureFunc measureFunc) {
  if (measureFunc == nullptr) {
    measure_ = nullptr;
    // TODO: t18095186 Move nodeType to opt-in function and mark appropriate
    // places in Litho
    nodeType_ = ABI26_0_0YGNodeTypeDefault;
  } else {
    ABI26_0_0YGAssertWithNode(
        this,
        children_.size() == 0,
        "Cannot set measure function: Nodes with measure functions cannot have children.");
    measure_ = measureFunc;
    // TODO: t18095186 Move nodeType to opt-in function and mark appropriate
    // places in Litho
    setNodeType(ABI26_0_0YGNodeTypeText);
  }

  measure_ = measureFunc;
}

void ABI26_0_0YGNode::setBaseLineFunc(ABI26_0_0YGBaselineFunc baseLineFunc) {
  baseline_ = baseLineFunc;
}

void ABI26_0_0YGNode::setDirtiedFunc(ABI26_0_0YGDirtiedFunc dirtiedFunc) {
  dirtied_ = dirtiedFunc;
}

void ABI26_0_0YGNode::setStyle(ABI26_0_0YGStyle style) {
  style_ = style;
}

void ABI26_0_0YGNode::setLayout(ABI26_0_0YGLayout layout) {
  layout_ = layout;
}

void ABI26_0_0YGNode::setLineIndex(uint32_t lineIndex) {
  lineIndex_ = lineIndex;
}

void ABI26_0_0YGNode::setParent(ABI26_0_0YGNodeRef parent) {
  parent_ = parent;
}

void ABI26_0_0YGNode::setChildren(ABI26_0_0YGVector children) {
  children_ = children;
}

void ABI26_0_0YGNode::setNextChild(ABI26_0_0YGNodeRef nextChild) {
  nextChild_ = nextChild;
}

void ABI26_0_0YGNode::replaceChild(ABI26_0_0YGNodeRef child, uint32_t index) {
  children_[index] = child;
}

void ABI26_0_0YGNode::replaceChild(ABI26_0_0YGNodeRef oldChild, ABI26_0_0YGNodeRef newChild) {
  std::replace(children_.begin(), children_.end(), oldChild, newChild);
}

void ABI26_0_0YGNode::insertChild(ABI26_0_0YGNodeRef child, uint32_t index) {
  children_.insert(children_.begin() + index, child);
}

void ABI26_0_0YGNode::setConfig(ABI26_0_0YGConfigRef config) {
  config_ = config;
}

void ABI26_0_0YGNode::setDirty(bool isDirty) {
  if (isDirty == isDirty_) {
    return;
  }
  isDirty_ = isDirty;
  if (isDirty && dirtied_) {
    dirtied_(this);
  }
}

bool ABI26_0_0YGNode::removeChild(ABI26_0_0YGNodeRef child) {
  std::vector<ABI26_0_0YGNodeRef>::iterator p =
      std::find(children_.begin(), children_.end(), child);
  if (p != children_.end()) {
    children_.erase(p);
    return true;
  }
  return false;
}

void ABI26_0_0YGNode::removeChild(uint32_t index) {
  children_.erase(children_.begin() + index);
}

void ABI26_0_0YGNode::setLayoutDirection(ABI26_0_0YGDirection direction) {
  layout_.direction = direction;
}

void ABI26_0_0YGNode::setLayoutMargin(float margin, int index) {
  layout_.margin[index] = margin;
}

void ABI26_0_0YGNode::setLayoutBorder(float border, int index) {
  layout_.border[index] = border;
}

void ABI26_0_0YGNode::setLayoutPadding(float padding, int index) {
  layout_.padding[index] = padding;
}

void ABI26_0_0YGNode::setLayoutLastParentDirection(ABI26_0_0YGDirection direction) {
  layout_.lastParentDirection = direction;
}

void ABI26_0_0YGNode::setLayoutComputedFlexBasis(float computedFlexBasis) {
  layout_.computedFlexBasis = computedFlexBasis;
}

void ABI26_0_0YGNode::setLayoutPosition(float position, int index) {
  layout_.position[index] = position;
}

void ABI26_0_0YGNode::setLayoutComputedFlexBasisGeneration(
    uint32_t computedFlexBasisGeneration) {
  layout_.computedFlexBasisGeneration = computedFlexBasisGeneration;
}

void ABI26_0_0YGNode::setLayoutMeasuredDimension(float measuredDimension, int index) {
  layout_.measuredDimensions[index] = measuredDimension;
}

void ABI26_0_0YGNode::setLayoutHadOverflow(bool hadOverflow) {
  layout_.hadOverflow = hadOverflow;
}

void ABI26_0_0YGNode::setLayoutDimension(float dimension, int index) {
  layout_.dimensions[index] = dimension;
}

// If both left and right are defined, then use left. Otherwise return
// +left or -right depending on which is defined.
float ABI26_0_0YGNode::relativePosition(
    const ABI26_0_0YGFlexDirection axis,
    const float axisSize) {
  return isLeadingPositionDefined(axis) ? getLeadingPosition(axis, axisSize)
                                        : -getTrailingPosition(axis, axisSize);
}

void ABI26_0_0YGNode::setPosition(
    const ABI26_0_0YGDirection direction,
    const float mainSize,
    const float crossSize,
    const float parentWidth) {
  /* Root nodes should be always layouted as LTR, so we don't return negative
   * values. */
  const ABI26_0_0YGDirection directionRespectingRoot =
      parent_ != nullptr ? direction : ABI26_0_0YGDirectionLTR;
  const ABI26_0_0YGFlexDirection mainAxis =
      ABI26_0_0YGResolveFlexDirection(style_.flexDirection, directionRespectingRoot);
  const ABI26_0_0YGFlexDirection crossAxis =
      ABI26_0_0YGFlexDirectionCross(mainAxis, directionRespectingRoot);

  const float relativePositionMain = relativePosition(mainAxis, mainSize);
  const float relativePositionCross = relativePosition(crossAxis, crossSize);

  setLayoutPosition(
      getLeadingMargin(mainAxis, parentWidth) + relativePositionMain,
      leading[mainAxis]);
  setLayoutPosition(
      getTrailingMargin(mainAxis, parentWidth) + relativePositionMain,
      trailing[mainAxis]);
  setLayoutPosition(
      getLeadingMargin(crossAxis, parentWidth) + relativePositionCross,
      leading[crossAxis]);
  setLayoutPosition(
      getTrailingMargin(crossAxis, parentWidth) + relativePositionCross,
      trailing[crossAxis]);
}

ABI26_0_0YGNode::ABI26_0_0YGNode()
    : context_(nullptr),
      print_(nullptr),
      hasNewLayout_(true),
      nodeType_(ABI26_0_0YGNodeTypeDefault),
      measure_(nullptr),
      baseline_(nullptr),
      dirtied_(nullptr),
      style_(gABI26_0_0YGNodeStyleDefaults),
      layout_(gABI26_0_0YGNodeLayoutDefaults),
      lineIndex_(0),
      parent_(nullptr),
      children_(ABI26_0_0YGVector()),
      nextChild_(nullptr),
      config_(nullptr),
      isDirty_(false),
      resolvedDimensions_({{ABI26_0_0YGValueUndefined, ABI26_0_0YGValueUndefined}}) {}

ABI26_0_0YGNode::ABI26_0_0YGNode(const ABI26_0_0YGNode& node)
    : context_(node.context_),
      print_(node.print_),
      hasNewLayout_(node.hasNewLayout_),
      nodeType_(node.nodeType_),
      measure_(node.measure_),
      baseline_(node.baseline_),
      dirtied_(node.dirtied_),
      style_(node.style_),
      layout_(node.layout_),
      lineIndex_(node.lineIndex_),
      parent_(node.parent_),
      children_(node.children_),
      nextChild_(node.nextChild_),
      config_(node.config_),
      isDirty_(node.isDirty_),
      resolvedDimensions_(node.resolvedDimensions_) {}

ABI26_0_0YGNode::ABI26_0_0YGNode(const ABI26_0_0YGConfigRef newConfig) : ABI26_0_0YGNode() {
  config_ = newConfig;
}

ABI26_0_0YGNode::ABI26_0_0YGNode(
    void* context,
    ABI26_0_0YGPrintFunc print,
    bool hasNewLayout,
    ABI26_0_0YGNodeType nodeType,
    ABI26_0_0YGMeasureFunc measure,
    ABI26_0_0YGBaselineFunc baseline,
    ABI26_0_0YGDirtiedFunc dirtied,
    ABI26_0_0YGStyle style,
    ABI26_0_0YGLayout layout,
    uint32_t lineIndex,
    ABI26_0_0YGNodeRef parent,
    ABI26_0_0YGVector children,
    ABI26_0_0YGNodeRef nextChild,
    ABI26_0_0YGConfigRef config,
    bool isDirty,
    std::array<ABI26_0_0YGValue, 2> resolvedDimensions)
    : context_(context),
      print_(print),
      hasNewLayout_(hasNewLayout),
      nodeType_(nodeType),
      measure_(measure),
      baseline_(baseline),
      dirtied_(dirtied),
      style_(style),
      layout_(layout),
      lineIndex_(lineIndex),
      parent_(parent),
      children_(children),
      nextChild_(nextChild),
      config_(config),
      isDirty_(isDirty),
      resolvedDimensions_(resolvedDimensions) {}

ABI26_0_0YGNode& ABI26_0_0YGNode::operator=(const ABI26_0_0YGNode& node) {
  if (&node == this) {
    return *this;
  }

  for (auto child : children_) {
    delete child;
  }

  context_ = node.getContext();
  print_ = node.getPrintFunc();
  hasNewLayout_ = node.getHasNewLayout();
  nodeType_ = node.getNodeType();
  measure_ = node.getMeasure();
  baseline_ = node.getBaseline();
  dirtied_ = node.getDirtied();
  style_ = node.style_;
  layout_ = node.layout_;
  lineIndex_ = node.getLineIndex();
  parent_ = node.getParent();
  children_ = node.getChildren();
  nextChild_ = node.getNextChild();
  config_ = node.getConfig();
  isDirty_ = node.isDirty();
  resolvedDimensions_ = node.getResolvedDimensions();

  return *this;
}

ABI26_0_0YGValue ABI26_0_0YGNode::marginLeadingValue(const ABI26_0_0YGFlexDirection axis) const {
  if (ABI26_0_0YGFlexDirectionIsRow(axis) &&
      style_.margin[ABI26_0_0YGEdgeStart].unit != ABI26_0_0YGUnitUndefined) {
    return style_.margin[ABI26_0_0YGEdgeStart];
  } else {
    return style_.margin[leading[axis]];
  }
}

ABI26_0_0YGValue ABI26_0_0YGNode::marginTrailingValue(const ABI26_0_0YGFlexDirection axis) const {
  if (ABI26_0_0YGFlexDirectionIsRow(axis) &&
      style_.margin[ABI26_0_0YGEdgeEnd].unit != ABI26_0_0YGUnitUndefined) {
    return style_.margin[ABI26_0_0YGEdgeEnd];
  } else {
    return style_.margin[trailing[axis]];
  }
}

ABI26_0_0YGValue ABI26_0_0YGNode::resolveFlexBasisPtr() const {
  ABI26_0_0YGValue flexBasis = style_.flexBasis;
  if (flexBasis.unit != ABI26_0_0YGUnitAuto && flexBasis.unit != ABI26_0_0YGUnitUndefined) {
    return flexBasis;
  }
  if (!ABI26_0_0YGFloatIsUndefined(style_.flex) && style_.flex > 0.0f) {
    return config_->useWebDefaults ? ABI26_0_0YGValueAuto : ABI26_0_0YGValueZero;
  }
  return ABI26_0_0YGValueAuto;
}

void ABI26_0_0YGNode::resolveDimension() {
  for (uint32_t dim = ABI26_0_0YGDimensionWidth; dim < ABI26_0_0YGDimensionCount; dim++) {
    if (getStyle().maxDimensions[dim].unit != ABI26_0_0YGUnitUndefined &&
        ABI26_0_0YGValueEqual(
            getStyle().maxDimensions[dim], style_.minDimensions[dim])) {
      resolvedDimensions_[dim] = style_.maxDimensions[dim];
    } else {
      resolvedDimensions_[dim] = style_.dimensions[dim];
    }
  }
}

ABI26_0_0YGDirection ABI26_0_0YGNode::resolveDirection(const ABI26_0_0YGDirection parentDirection) {
  if (style_.direction == ABI26_0_0YGDirectionInherit) {
    return parentDirection > ABI26_0_0YGDirectionInherit ? parentDirection
                                                : ABI26_0_0YGDirectionLTR;
  } else {
    return style_.direction;
  }
}

void ABI26_0_0YGNode::clearChildren() {
  children_.clear();
  children_.shrink_to_fit();
}

ABI26_0_0YGNode::~ABI26_0_0YGNode() {
  // All the member variables are deallocated externally, so no need to
  // deallocate here
}

// Other Methods

void ABI26_0_0YGNode::cloneChildrenIfNeeded() {
  // ABI26_0_0YGNodeRemoveChild in yoga.cpp has a forked variant of this algorithm
  // optimized for deletions.

  const uint32_t childCount = static_cast<uint32_t>(children_.size());
  if (childCount == 0) {
    // This is an empty set. Nothing to clone.
    return;
  }

  const ABI26_0_0YGNodeRef firstChild = children_.front();
  if (firstChild->getParent() == this) {
    // If the first child has this node as its parent, we assume that it is
    // already unique. We can do this because if we have it has a child, that
    // means that its parent was at some point cloned which made that subtree
    // immutable. We also assume that all its sibling are cloned as well.
    return;
  }

  const ABI26_0_0YGNodeClonedFunc cloneNodeCallback = config_->cloneNodeCallback;
  for (uint32_t i = 0; i < childCount; ++i) {
    const ABI26_0_0YGNodeRef oldChild = children_[i];
    const ABI26_0_0YGNodeRef newChild = ABI26_0_0YGNodeClone(oldChild);
    replaceChild(newChild, i);
    newChild->setParent(this);
    if (cloneNodeCallback) {
      cloneNodeCallback(oldChild, newChild, this, i);
    }
  }
}

void ABI26_0_0YGNode::markDirtyAndPropogate() {
  if (!isDirty_) {
    setDirty(true);
    setLayoutComputedFlexBasis(ABI26_0_0YGUndefined);
    if (parent_) {
      parent_->markDirtyAndPropogate();
    }
  }
}

void ABI26_0_0YGNode::markDirtyAndPropogateDownwards() {
  isDirty_ = true;
  for_each(children_.begin(), children_.end(), [](ABI26_0_0YGNodeRef childNode) {
    childNode->markDirtyAndPropogateDownwards();
  });
}

float ABI26_0_0YGNode::resolveFlexGrow() {
  // Root nodes flexGrow should always be 0
  if (parent_ == nullptr) {
    return 0.0;
  }
  if (!ABI26_0_0YGFloatIsUndefined(style_.flexGrow)) {
    return style_.flexGrow;
  }
  if (!ABI26_0_0YGFloatIsUndefined(style_.flex) && style_.flex > 0.0f) {
    return style_.flex;
  }
  return kDefaultFlexGrow;
}

float ABI26_0_0YGNode::resolveFlexShrink() {
  if (parent_ == nullptr) {
    return 0.0;
  }
  if (!ABI26_0_0YGFloatIsUndefined(style_.flexShrink)) {
    return style_.flexShrink;
  }
  if (!config_->useWebDefaults && !ABI26_0_0YGFloatIsUndefined(style_.flex) &&
      style_.flex < 0.0f) {
    return -style_.flex;
  }
  return config_->useWebDefaults ? kWebDefaultFlexShrink : kDefaultFlexShrink;
}

bool ABI26_0_0YGNode::isNodeFlexible() {
  return (
      (style_.positionType == ABI26_0_0YGPositionTypeRelative) &&
      (resolveFlexGrow() != 0 || resolveFlexShrink() != 0));
}

float ABI26_0_0YGNode::getLeadingBorder(const ABI26_0_0YGFlexDirection axis) {
  if (ABI26_0_0YGFlexDirectionIsRow(axis) &&
      style_.border[ABI26_0_0YGEdgeStart].unit != ABI26_0_0YGUnitUndefined &&
      style_.border[ABI26_0_0YGEdgeStart].value >= 0.0f) {
    return style_.border[ABI26_0_0YGEdgeStart].value;
  }

  return fmaxf(
      ABI26_0_0YGComputedEdgeValue(style_.border, leading[axis], &ABI26_0_0YGValueZero)->value,
      0.0f);
}

float ABI26_0_0YGNode::getTrailingBorder(const ABI26_0_0YGFlexDirection flexDirection) {
  if (ABI26_0_0YGFlexDirectionIsRow(flexDirection) &&
      style_.border[ABI26_0_0YGEdgeEnd].unit != ABI26_0_0YGUnitUndefined &&
      style_.border[ABI26_0_0YGEdgeEnd].value >= 0.0f) {
    return style_.border[ABI26_0_0YGEdgeEnd].value;
  }

  return fmaxf(
      ABI26_0_0YGComputedEdgeValue(style_.border, trailing[flexDirection], &ABI26_0_0YGValueZero)
          ->value,
      0.0f);
}

float ABI26_0_0YGNode::getLeadingPadding(
    const ABI26_0_0YGFlexDirection axis,
    const float widthSize) {
  if (ABI26_0_0YGFlexDirectionIsRow(axis) &&
      style_.padding[ABI26_0_0YGEdgeStart].unit != ABI26_0_0YGUnitUndefined &&
      ABI26_0_0YGResolveValue(style_.padding[ABI26_0_0YGEdgeStart], widthSize) >= 0.0f) {
    return ABI26_0_0YGResolveValue(style_.padding[ABI26_0_0YGEdgeStart], widthSize);
  }
  return fmaxf(
      ABI26_0_0YGResolveValue(
          *ABI26_0_0YGComputedEdgeValue(style_.padding, leading[axis], &ABI26_0_0YGValueZero),
          widthSize),
      0.0f);
}

float ABI26_0_0YGNode::getTrailingPadding(
    const ABI26_0_0YGFlexDirection axis,
    const float widthSize) {
  if (ABI26_0_0YGFlexDirectionIsRow(axis) &&
      style_.padding[ABI26_0_0YGEdgeEnd].unit != ABI26_0_0YGUnitUndefined &&
      ABI26_0_0YGResolveValue(style_.padding[ABI26_0_0YGEdgeEnd], widthSize) >= 0.0f) {
    return ABI26_0_0YGResolveValue(style_.padding[ABI26_0_0YGEdgeEnd], widthSize);
  }
  return fmaxf(
      ABI26_0_0YGResolveValue(
          *ABI26_0_0YGComputedEdgeValue(style_.padding, trailing[axis], &ABI26_0_0YGValueZero),
          widthSize),
      0.0f);
}

float ABI26_0_0YGNode::getLeadingPaddingAndBorder(
    const ABI26_0_0YGFlexDirection axis,
    const float widthSize) {
  return getLeadingPadding(axis, widthSize) + getLeadingBorder(axis);
}

float ABI26_0_0YGNode::getTrailingPaddingAndBorder(
    const ABI26_0_0YGFlexDirection axis,
    const float widthSize) {
  return getTrailingPadding(axis, widthSize) + getTrailingBorder(axis);
}

bool ABI26_0_0YGNode::didUseLegacyFlag() {
  bool didUseLegacyFlag = layout_.didUseLegacyFlag;
  if (didUseLegacyFlag) {
    return true;
  }
  for (const auto& child : children_) {
    if (child->layout_.didUseLegacyFlag) {
      didUseLegacyFlag = true;
      break;
    }
  }
  return didUseLegacyFlag;
}

void ABI26_0_0YGNode::setAndPropogateUseLegacyFlag(bool useLegacyFlag) {
  config_->useLegacyStretchBehaviour = useLegacyFlag;
  for_each(children_.begin(), children_.end(), [=](ABI26_0_0YGNodeRef childNode) {
    childNode->getConfig()->useLegacyStretchBehaviour = useLegacyFlag;
  });
}

void ABI26_0_0YGNode::setLayoutDoesLegacyFlagAffectsLayout(
    bool doesLegacyFlagAffectsLayout) {
  layout_.doesLegacyStretchFlagAffectsLayout = doesLegacyFlagAffectsLayout;
}

void ABI26_0_0YGNode::setLayoutDidUseLegacyFlag(bool didUseLegacyFlag) {
  layout_.didUseLegacyFlag = didUseLegacyFlag;
}

bool ABI26_0_0YGNode::isLayoutTreeEqualToNode(const ABI26_0_0YGNode& node) const {
  if (children_.size() != node.children_.size()) {
    return false;
  }
  if (layout_ != node.layout_) {
    return false;
  }
  if (children_.size() == 0) {
    return true;
  }

  bool isLayoutTreeEqual = true;
  ABI26_0_0YGNodeRef otherNodeChildren = nullptr;
  for (std::vector<ABI26_0_0YGNodeRef>::size_type i = 0; i < children_.size(); ++i) {
    otherNodeChildren = node.children_[i];
    isLayoutTreeEqual =
        children_[i]->isLayoutTreeEqualToNode(*otherNodeChildren);
    if (!isLayoutTreeEqual) {
      return false;
    }
  }
  return isLayoutTreeEqual;
}
