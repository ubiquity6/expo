/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#pragma once

namespace facebook {
namespace ReactABI29_0_0 {

/**
 * An interface for FabricUIManager to perform platform-specific UI operations, like updating native UIView's in iOS.
 */
class IFabricPlatformUIOperationManager {
public:
  // TODO: add meaningful methods
  virtual void performUIOperation() = 0;
};

} // namespace ReactABI29_0_0
} // namespace facebook
