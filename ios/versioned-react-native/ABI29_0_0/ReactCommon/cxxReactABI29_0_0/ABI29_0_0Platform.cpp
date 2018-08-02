// Copyright 2004-present Facebook. All Rights Reserved.

#include "ABI29_0_0Platform.h"

namespace facebook {
namespace ReactABI29_0_0 {

#if __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wglobal-constructors"
#endif

namespace ReactABI29_0_0Marker {

LogTaggedMarker logTaggedMarker = nullptr;
void logMarker(const ReactABI29_0_0MarkerId markerId) {
  logTaggedMarker(markerId, nullptr);
}

}

namespace JSCNativeHooks {

Hook loggingHook = nullptr;
Hook nowHook = nullptr;
ConfigurationHook installPerfHooks = nullptr;

}

#if __clang__
#pragma clang diagnostic pop
#endif

} }
