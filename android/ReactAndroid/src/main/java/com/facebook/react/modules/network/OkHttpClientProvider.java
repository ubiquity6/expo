/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */
package com.facebook.react.modules.network;

import android.os.Build;
import com.facebook.common.logging.FLog;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;
import javax.annotation.Nullable;
import expolib_v1.okhttp3.ConnectionSpec;
import expolib_v1.okhttp3.OkHttpClient;
import expolib_v1.okhttp3.TlsVersion;

/**
 * Helper class that provides the same OkHttpClient instance that will be used for all networking
 * requests.
 */
public class OkHttpClientProvider {

    // Centralized OkHttpClient for all networking requests.
    @Nullable
    public static OkHttpClient sClient;

    // User-provided OkHttpClient factory
    @Nullable
    public static OkHttpClientFactory sFactory;

    public static void setOkHttpClientFactory(OkHttpClientFactory factory) {
        sFactory = factory;
    }

    public static OkHttpClient getOkHttpClient() {
        if (sClient == null) {
            sClient = createClient();
        }
        return sClient;
    }

    // okhttp3 OkHttpClient is immutable
    // This allows app to init an OkHttpClient with custom settings.
    public static void replaceOkHttpClient(OkHttpClient client) {
        sClient = client;
    }

    public static OkHttpClient createClient() {
        try {
            return (OkHttpClient) Class.forName("host.exp.exponent.ReactNativeStaticHelpers").getMethod("getOkHttpClient", Class.class).invoke(null, OkHttpClientProvider.class);
        } catch (Exception expoHandleErrorException) {
            expoHandleErrorException.printStackTrace();
            return null;
        }
    }

    /*
    On Android 4.1-4.4 (API level 16 to 19) TLS 1.1 and 1.2 are
    available but not enabled by default. The following method
    enables it.
   */
    public static OkHttpClient.Builder enableTls12OnPreLollipop(OkHttpClient.Builder client) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN && Build.VERSION.SDK_INT <= Build.VERSION_CODES.KITKAT) {
            try {
                client.sslSocketFactory(new TLSSocketFactory());
                ConnectionSpec cs = new ConnectionSpec.Builder(ConnectionSpec.MODERN_TLS).tlsVersions(TlsVersion.TLS_1_2).build();
                List<ConnectionSpec> specs = new ArrayList<>();
                specs.add(cs);
                specs.add(ConnectionSpec.COMPATIBLE_TLS);
                specs.add(ConnectionSpec.CLEARTEXT);
                client.connectionSpecs(specs);
            } catch (Exception exc) {
                FLog.e("OkHttpClientProvider", "Error while enabling TLS 1.2", exc);
            }
        }
        return client;
    }
}
