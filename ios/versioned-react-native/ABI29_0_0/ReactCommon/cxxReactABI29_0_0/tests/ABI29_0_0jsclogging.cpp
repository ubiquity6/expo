// Copyright 2004-present Facebook. All Rights Reserved.

#include <gtest/gtest.h>
#include <cxxReactABI29_0_0/ABI29_0_0JSCExecutor.h>

using namespace facebook;
using namespace facebook::ReactABI29_0_0;

/*
static const char* expectedLogMessageSubstring = NULL;
static bool hasSeenExpectedLogMessage = false;

static void mockLogHandler(int pri, const char *tag, const char *msg) {
  if (expectedLogMessageSubstring == NULL) {
    return;
  }

  hasSeenExpectedLogMessage |= (strstr(msg, expectedLogMessageSubstring) != NULL);
}

class JSCLoggingTest : public testing::Test {
  protected:
    virtual void SetUp() override {
      setLogHandler(&mockLogHandler);
    }

    virtual void TearDown() override {
      setLogHandler(NULL);
      expectedLogMessageSubstring = NULL;
      hasSeenExpectedLogMessage = false;
    }

};

TEST_F(JSCLoggingTest, LogException) {
  auto jsText = "throw new Error('I am a banana!');";
  expectedLogMessageSubstring = "I am a banana!";

  JSCExecutor e;
  e.loadApplicationScript(jsText, "");

  ASSERT_TRUE(hasSeenExpectedLogMessage);
}
*/
