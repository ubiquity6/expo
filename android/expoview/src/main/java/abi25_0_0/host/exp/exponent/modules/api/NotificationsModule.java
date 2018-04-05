// Copyright 2015-present 650 Industries. All rights reserved.

package abi25_0_0.host.exp.exponent.modules.api;

import android.support.v4.app.NotificationManagerCompat;

import abi25_0_0.com.facebook.react.bridge.Arguments;
import abi25_0_0.com.facebook.react.bridge.Promise;
import abi25_0_0.com.facebook.react.bridge.ReactApplicationContext;
import abi25_0_0.com.facebook.react.bridge.ReactContextBaseJavaModule;
import abi25_0_0.com.facebook.react.bridge.ReactMethod;
import abi25_0_0.com.facebook.react.bridge.ReadableMap;
import abi25_0_0.com.facebook.react.bridge.ReadableNativeMap;
import abi25_0_0.com.facebook.react.bridge.WritableMap;
import com.google.android.gms.gcm.GoogleCloudMessaging;
import com.google.android.gms.iid.InstanceID;
import com.google.firebase.iid.FirebaseInstanceId;

import host.exp.exponent.Constants;
import host.exp.exponent.analytics.EXL;
import host.exp.exponent.network.ExponentNetwork;
import host.exp.exponent.notifications.NotificationHelper;
import host.exp.exponent.notifications.ExponentNotificationManager;
import org.json.JSONException;
import org.json.JSONObject;

import java.security.InvalidParameterException;
import java.util.HashMap;
import java.util.Map;
import java.util.Random;

import javax.inject.Inject;

import host.exp.exponent.ExponentManifest;
import host.exp.exponent.di.NativeModuleDepsProvider;
import host.exp.exponent.storage.ExponentSharedPreferences;

public class NotificationsModule extends ReactContextBaseJavaModule {

  private static final String TAG = NotificationsModule.class.getSimpleName();

  @Inject
  ExponentSharedPreferences mExponentSharedPreferences;

  @Inject
  ExponentManifest mExponentManifest;

  @Inject
  ExponentNetwork mExponentNetwork;

  private final JSONObject mManifest;

  public NotificationsModule(ReactApplicationContext reactContext,
                             JSONObject manifest, Map<String, Object> experienceProperties) {
    super(reactContext);
    NativeModuleDepsProvider.getInstance().inject(NotificationsModule.class, this);
    mManifest = manifest;
  }

  @Override
  public String getName() {
    return "ExponentNotifications";
  }

  @ReactMethod
  public void getDevicePushTokenAsync(final ReadableMap config, final Promise promise) {
    if (!Constants.isShellApp()) {
      promise.reject("getDevicePushTokenAsync is only accessible within standalone applications");
    }
    try {
      if (Constants.FCM_ENABLED) {
        String token = FirebaseInstanceId.getInstance().getToken();
        if (token == null) {
          promise.reject("FCM token has not been set");
        } else {
          WritableMap params = Arguments.createMap();
          params.putString("type", "fcm");
          params.putString("data", token);
          promise.resolve(params);
        }
      } else {
        InstanceID instanceID = InstanceID.getInstance(this.getReactApplicationContext());
        String gcmSenderId = config.getString("gcmSenderId");
        if (gcmSenderId == null || gcmSenderId.length() == 0) {
          throw new InvalidParameterException("GCM Sender ID is null/empty");
        }
        final String token = instanceID.getToken(gcmSenderId, GoogleCloudMessaging.INSTANCE_ID_SCOPE, null);
        if (token == null) {
          promise.reject("GCM token has not been set");
        } else {
          WritableMap params = Arguments.createMap();
          params.putString("type", "gcm");
          params.putString("data", token);
          promise.resolve(params);
        }
      }
    } catch (Exception e) {
      EXL.e(TAG, e.getMessage());
      promise.reject(e.getMessage());
    }
  }

  @ReactMethod
  public void getExponentPushTokenAsync(final Promise promise) {
    String uuid = mExponentSharedPreferences.getUUID();
    if (uuid == null) {
      // This should have been set by ExponentNotificationIntentService when Activity was created/resumed.
      promise.reject("Couldn't get GCM token on device.");
      return;
    }

    try {
      String experienceId = mManifest.getString(ExponentManifest.MANIFEST_ID_KEY);
      NotificationHelper.getPushNotificationToken(uuid, experienceId, mExponentNetwork, mExponentSharedPreferences, new NotificationHelper.TokenListener() {
        @Override
        public void onSuccess(String token) {
          promise.resolve(token);
        }

        @Override
        public void onFailure(Exception e) {
          promise.reject("E_GET_GCM_TOKEN_FAILED", "Couldn't get GCM token for device " + e.toString(), e);
        }
      });
    } catch (JSONException e) {
      promise.reject("E_GET_GCM_TOKEN_FAILED", "Couldn't get GCM token for device " + e.toString(), e);
      return;
    }
  }

  @ReactMethod
  public void cancelNotification(final int notificationId) {
    NotificationManagerCompat notificationManager = NotificationManagerCompat.from(getReactApplicationContext());
    notificationManager.cancel(notificationId);
  }

  @ReactMethod
  public void presentLocalNotification(final ReadableMap data, final Promise promise) {
    HashMap<String, java.io.Serializable> details = new HashMap<>();

    details.put("data", ((ReadableNativeMap) data).toHashMap());

    try {
      details.put("experienceId", mManifest.getString(ExponentManifest.MANIFEST_ID_KEY));
    } catch (Exception e) {
      promise.reject("Requires Experience Id");
      return;
    }

    int notificationId = new Random().nextInt();

    NotificationHelper.showNotification(
            getReactApplicationContext(),
            notificationId,
            details,
            mExponentManifest,
            new NotificationHelper.Listener() {
              public void onSuccess(int id) {
                promise.resolve(id);
              }
              public void onFailure(Exception e) {
                promise.reject(e);
              }
            });
  }

  @ReactMethod
  public void scheduleLocalNotification(final ReadableMap data, final ReadableMap options, final Promise promise) {
    int notificationId = new Random().nextInt();

    NotificationHelper.scheduleLocalNotification(
        getReactApplicationContext(),
        notificationId,
        ((ReadableNativeMap) data).toHashMap(),
        ((ReadableNativeMap) options).toHashMap(),
        mManifest,
        new NotificationHelper.Listener() {
          public void onSuccess(int id) {
            promise.resolve(id);
          }
          public void onFailure(Exception e) {
            promise.reject(e);
          }
        });
  }

  @ReactMethod
  public void dismissNotification(final int notificationId, final Promise promise) {
    try {
      ExponentNotificationManager manager = new ExponentNotificationManager(getReactApplicationContext());
      manager.cancel(
              mManifest.getString(ExponentManifest.MANIFEST_ID_KEY),
              notificationId
      );
      promise.resolve(true);
    } catch (JSONException e) {
      promise.reject(e);
    }
  }

  @ReactMethod
  public void dismissAllNotifications(final Promise promise) {
    try {
      ExponentNotificationManager manager = new ExponentNotificationManager(getReactApplicationContext());
      manager.cancelAll(mManifest.getString(ExponentManifest.MANIFEST_ID_KEY));
      promise.resolve(true);
    } catch (JSONException e) {
      promise.reject(e);
    }
  }

  @ReactMethod
  public void cancelScheduledNotification(final int notificationId, final Promise promise) {
    try {
      ExponentNotificationManager manager = new ExponentNotificationManager(getReactApplicationContext());
      manager.cancelScheduled(mManifest.getString(ExponentManifest.MANIFEST_ID_KEY), notificationId);
      promise.resolve(true);
    } catch (Exception e) {
      promise.reject(e);
    }
  }

  @ReactMethod
  public void cancelAllScheduledNotifications(final Promise promise) {
    try {
      ExponentNotificationManager manager = new ExponentNotificationManager(getReactApplicationContext());
      manager.cancelAllScheduled(mManifest.getString(ExponentManifest.MANIFEST_ID_KEY));
      promise.resolve(true);
    } catch (Exception e) {
      promise.reject(e);
    }
  }
}
