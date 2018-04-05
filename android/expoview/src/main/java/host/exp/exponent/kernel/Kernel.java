// Copyright 2015-present 650 Industries. All rights reserved.

package host.exp.exponent.kernel;

import android.app.Activity;
import android.app.ActivityManager;
import android.app.Application;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.graphics.Bitmap;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.provider.Settings;
import android.support.v4.content.pm.ShortcutInfoCompat;
import android.support.v4.content.pm.ShortcutManagerCompat;
import android.support.v4.graphics.drawable.IconCompat;
import android.support.v7.app.AlertDialog;
import android.util.Log;
import android.widget.Toast;

import com.facebook.proguard.annotations.DoNotStrip;
import com.facebook.react.ReactInstanceManager;
import com.facebook.react.ReactInstanceManagerBuilder;
import com.facebook.react.ReactRootView;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.common.LifecycleState;
import com.facebook.react.modules.network.OkHttpClientProvider;
import com.facebook.react.modules.network.ReactCookieJarContainer;
import com.facebook.react.shell.MainReactPackage;
import com.facebook.soloader.SoLoader;

import org.json.JSONException;
import org.json.JSONObject;

import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.TimeUnit;

import javax.inject.Inject;

import de.greenrobot.event.EventBus;
import host.exp.exponent.AppLoader;
import host.exp.exponent.ExponentDevActivity;
import host.exp.exponent.LauncherActivity;
import host.exp.exponent.ReactNativeStaticHelpers;
import host.exp.exponent.experience.ShellAppActivity;
import host.exp.exponent.di.NativeModuleDepsProvider;
import host.exp.exponent.experience.BaseExperienceActivity;
import host.exp.exponent.experience.ExperienceActivity;
import host.exp.exponent.experience.HomeActivity;
import host.exp.exponent.notifications.ExponentNotification;
import host.exp.expoview.BuildConfig;
import host.exp.exponent.Constants;
import host.exp.exponent.ExponentManifest;
import host.exp.expoview.Exponent;
import host.exp.expoview.ExpoViewBuildConfig;
import host.exp.expoview.R;
import host.exp.exponent.RNObject;
import host.exp.exponent.analytics.EXL;
import host.exp.exponent.exceptions.ExceptionUtils;
import host.exp.exponent.network.ExponentNetwork;
import host.exp.exponent.storage.ExponentSharedPreferences;
import host.exp.exponent.utils.AsyncCondition;
import host.exp.exponent.utils.JSONBundleConverter;
import expolib_v1.okhttp3.OkHttpClient;
import versioned.host.exp.exponent.ExponentPackage;
import versioned.host.exp.exponent.ReactUnthemedRootView;
import versioned.host.exp.exponent.ReadableObjectUtils;

// TOOD: need to figure out when we should reload the kernel js. Do we do it every time you visit
// the home screen? only when the app gets kicked out of memory?
public class Kernel extends KernelInterface {

  private static final String TAG = Kernel.class.getSimpleName();

  private static Kernel sInstance;

  public static class KernelStartedRunningEvent {
  }

  public static class ExperienceActivityTask {
    public final String manifestUrl;
    public int taskId;
    public WeakReference<ExperienceActivity> experienceActivity;
    public int activityId;
    public String bundleUrl;

    public ExperienceActivityTask(String manifestUrl) {
      this.manifestUrl = manifestUrl;
    }
  }

  // React
  private ReactInstanceManager mReactInstanceManager;

  // Contexts
  @Inject
  Context mContext;

  @Inject
  Application mApplicationContext;

  private Activity mActivityContext;

  // Activities/Tasks
  private static Map<String, ExperienceActivityTask> sManifestUrlToExperienceActivityTask = new HashMap<>();
  private ExperienceActivity mOptimisticActivity;
  private Integer mOptimisticTaskId;
  private ExperienceActivityTask experienceActivityTaskForTaskId(int taskId) {
    for (ExperienceActivityTask task : sManifestUrlToExperienceActivityTask.values()) {
      if (task.taskId == taskId) {
        return task;
      }
    }

    return null;
  }

  // Misc
  private boolean mIsStarted = false;
  private boolean mIsRunning = false;
  private boolean mHasError = false;

  @Inject
  ExponentManifest mExponentManifest;

  @Inject
  ExponentSharedPreferences mExponentSharedPreferences;

  private static final Map<String, KernelConstants.ExperienceOptions> mManifestUrlToOptions = new HashMap<>();

  @Inject
  ExponentNetwork mExponentNetwork;

  public Kernel() {
    NativeModuleDepsProvider.getInstance().inject(Kernel.class, this);

    sInstance = this;

    updateKernelRNOkHttp();
  }

  private void updateKernelRNOkHttp() {
    OkHttpClient.Builder client = new OkHttpClient.Builder()
        .connectTimeout(0, TimeUnit.MILLISECONDS)
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .writeTimeout(0, TimeUnit.MILLISECONDS)
        .cookieJar(new ReactCookieJarContainer())
        .cache(mExponentNetwork.getCache());

    if (BuildConfig.DEBUG) {
      // FIXME: 8/9/17
      // broke with lib versioning
      // clientBuilder.addNetworkInterceptor(new StethoInterceptor());
    }

    mExponentNetwork.addInterceptors(client);
    ReactNativeStaticHelpers.setExponentNetwork(mExponentNetwork);
  }

  // Don't call this until a loading screen is up, since it has to do some work on the main thread.
  public void startJSKernel() {
    if (Constants.isShellApp()) {
      return;
    }

    SoLoader.init(mContext, false);

    synchronized (this) {
      if (mIsStarted && !mHasError) {
        return;
      }
      mIsStarted = true;
    }

    mHasError = false;

    if (!mExponentSharedPreferences.shouldUseInternetKernel()) {
      try {
        // Make sure we can get the manifest successfully. This can fail in dev mode
        // if the kernel packager is not running.
        mExponentManifest.getKernelManifest();
      } catch (Throwable e) {
        Exponent.getInstance().runOnUiThread(new Runnable() {
          @Override
          public void run() {
            // Hack to make this show up for a while. Can't use an Alert because LauncherActivity has a transparent theme. This should only be seen by internal developers.
            for (int i = 0; i < 3; i++) {
              Toast.makeText(mActivityContext, "Kernel manifest invalid. Make sure `expu start` is running inside of exponent/js and rebuild the app.", Toast.LENGTH_LONG).show();
            }
          }
        });
        return;
      }
    }

    // On first run use the embedded kernel js but fire off a request for the new js in the background.
    final String bundleUrl = getBundleUrl() + (ExpoViewBuildConfig.DEBUG ? "" : "?versionName=" + ExpoViewKernel.getInstance().getVersionName());

    if (mExponentSharedPreferences.shouldUseInternetKernel() &&
        mExponentSharedPreferences.getBoolean(ExponentSharedPreferences.IS_FIRST_KERNEL_RUN_KEY)) {
      kernelBundleListener().onBundleLoaded(Constants.EMBEDDED_KERNEL_PATH);

      // Now preload bundle for next run
      new Handler().postDelayed(new Runnable() {
        @Override
        public void run() {
          Exponent.getInstance().loadJSBundle(null, bundleUrl, KernelConstants.KERNEL_BUNDLE_ID, RNObject.UNVERSIONED, new Exponent.BundleListener() {
            @Override
            public void onBundleLoaded(String localBundlePath) {
              mExponentSharedPreferences.setBoolean(ExponentSharedPreferences.IS_FIRST_KERNEL_RUN_KEY, false);
              EXL.d(TAG, "Successfully preloaded kernel bundle");
            }

            @Override
            public void onError(Exception e) {
              EXL.e(TAG, "Error preloading kernel bundle: " + e.toString());
            }
          });
        }
      }, KernelConstants.DELAY_TO_PRELOAD_KERNEL_JS);
    } else {
      boolean shouldNotUseKernelCache = mExponentSharedPreferences.getBoolean(ExponentSharedPreferences.SHOULD_NOT_USE_KERNEL_CACHE);

      if (!ExpoViewBuildConfig.DEBUG) {
        String oldKernelRevisionId = mExponentSharedPreferences.getString(ExponentSharedPreferences.KERNEL_REVISION_ID, "");

        if (!oldKernelRevisionId.equals(getKernelRevisionId())) {
          shouldNotUseKernelCache = true;
        }
      }

      Exponent.getInstance().loadJSBundle(null, bundleUrl, KernelConstants.KERNEL_BUNDLE_ID, RNObject.UNVERSIONED, kernelBundleListener(), shouldNotUseKernelCache);
    }
  }

  public void reloadJSBundle() {
    if (Constants.isShellApp()) {
      return;
    }
    String bundleUrl = getBundleUrl();
    mHasError = false;
    Exponent.getInstance().loadJSBundle(null, bundleUrl, KernelConstants.KERNEL_BUNDLE_ID, RNObject.UNVERSIONED, kernelBundleListener(), true);
  }

  public static void addIntentDocumentFlags(Intent intent) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
      intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP);

      intent.addFlags(Intent.FLAG_ACTIVITY_NEW_DOCUMENT);
      intent.addFlags(Intent.FLAG_ACTIVITY_MULTIPLE_TASK);
    } else {
      intent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
    }
  }

  private Exponent.BundleListener kernelBundleListener() {
    return new Exponent.BundleListener() {
      @Override
      public void onBundleLoaded(final String localBundlePath) {
        if (!ExpoViewBuildConfig.DEBUG) {
          mExponentSharedPreferences.setString(ExponentSharedPreferences.KERNEL_REVISION_ID, getKernelRevisionId());
        }

        Exponent.getInstance().runOnUiThread(new Runnable() {
          @Override
          public void run() {
            ReactInstanceManagerBuilder builder = ReactInstanceManager.builder()
                .setApplication(mApplicationContext)
                .setJSBundleFile(localBundlePath)
                .addPackage(new MainReactPackage())
                .addPackage(ExponentPackage.kernelExponentPackage(mExponentManifest.getKernelManifest()))
                .setInitialLifecycleState(LifecycleState.RESUMED);

            if (!KernelConfig.FORCE_NO_KERNEL_DEBUG_MODE && mExponentManifest.isDebugModeEnabled(mExponentManifest.getKernelManifest())) {
              if (Exponent.getInstance().shouldRequestDrawOverOtherAppsPermission()) {
                new AlertDialog.Builder(mActivityContext)
                    .setTitle("Please enable \"Permit drawing over other apps\"")
                    .setMessage("Click \"ok\" to open settings. Once you've enabled the setting you'll have to restart the app.")
                    .setPositiveButton(android.R.string.ok, new DialogInterface.OnClickListener() {
                      public void onClick(DialogInterface dialog, int which) {
                        Intent intent = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:" + mActivityContext.getPackageName()));
                        mActivityContext.startActivityForResult(intent, KernelConstants.OVERLAY_PERMISSION_REQUEST_CODE);
                      }
                    })
                    .setCancelable(false)
                    .show();
                return;
              }

              Exponent.enableDeveloperSupport("UNVERSIONED", mExponentManifest.getKernelManifestField(ExponentManifest.MANIFEST_DEBUGGER_HOST_KEY),
                  mExponentManifest.getKernelManifestField(ExponentManifest.MANIFEST_MAIN_MODULE_NAME_KEY), RNObject.wrap(builder));
            }

            mReactInstanceManager = builder.build();
            mReactInstanceManager.createReactContextInBackground();
            if (getActivityContext() != null) {
              // RN expects an activity in some places.
              mReactInstanceManager.onHostResume(getActivityContext(), null);
            }

            mIsRunning = true;
            EventBus.getDefault().postSticky(new KernelStartedRunningEvent());
            EXL.d(TAG, "Kernel started running.");

            // Reset this flag if we crashed
            mExponentSharedPreferences.setBoolean(ExponentSharedPreferences.SHOULD_NOT_USE_KERNEL_CACHE, false);
          }
        });
      }

      @Override
      public void onError(Exception e) {
        setHasError();

        if (ExpoViewBuildConfig.DEBUG) {
          handleError("Can't load kernel. Are you sure your packager is running and your phone is on the same wifi? " + e.getMessage());
        } else {
          handleError("Expo requires an internet connection.");
          EXL.d(TAG, "Expo requires an internet connection." + e.getMessage());
        }
      }
    };
  }

  private String getBundleUrl() {
    return mExponentManifest.getKernelManifestField(ExponentManifest.MANIFEST_BUNDLE_URL_KEY);
  }

  private String getKernelRevisionId() {
    return mExponentManifest.getKernelManifestField(ExponentManifest.MANIFEST_REVISION_ID_KEY);
  }

  public Boolean isRunning() {
    return mIsRunning && !mHasError;
  }

  public Boolean isStarted() {
    return mIsStarted;
  }

  public Activity getActivityContext() {
    return mActivityContext;
  }

  public void setActivityContext(final Activity activity) {
    if (activity != null) {
      mActivityContext = activity;
    }
  }

  public ReactInstanceManager getReactInstanceManager() {
    return mReactInstanceManager;
  }

  public ReactRootView getReactRootView() {
    ReactRootView reactRootView = new ReactUnthemedRootView(mContext);
    reactRootView.startReactApplication(
        mReactInstanceManager,
        KernelConstants.HOME_MODULE_NAME,
        getKernelLaunchOptions());

    return reactRootView;
  }

  private Bundle getKernelLaunchOptions() {
    JSONObject exponentProps = new JSONObject();
    String referrer = mExponentSharedPreferences.getString(ExponentSharedPreferences.REFERRER_KEY);
    if (referrer != null) {
      try {
        exponentProps.put("referrer", referrer);
      } catch (JSONException e) {
        EXL.e(TAG, e);
      }
    }

    Bundle bundle = new Bundle();
    bundle.putBundle("exp", JSONBundleConverter.JSONToBundle(exponentProps));
    return bundle;
  }

  public Boolean hasOptionsForManifestUrl(String manifestUrl) {
    return mManifestUrlToOptions.containsKey(manifestUrl);
  }

  public KernelConstants.ExperienceOptions popOptionsForManifestUrl(String manifestUrl) {
    return mManifestUrlToOptions.remove(manifestUrl);
  }

  public ExperienceActivityTask getExperienceActivityTask(String manifestUrl) {
    ExperienceActivityTask task = sManifestUrlToExperienceActivityTask.get(manifestUrl);
    if (task != null) {
      return task;
    }

    task = new ExperienceActivityTask(manifestUrl);
    sManifestUrlToExperienceActivityTask.put(manifestUrl, task);
    return task;
  }

  public void removeExperienceActivityTask(String manifestUrl) {
    if (manifestUrl != null) {
      sManifestUrlToExperienceActivityTask.remove(manifestUrl);
    }
  }

  private void openHomeActivity() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
      ActivityManager manager = (ActivityManager) mContext.getSystemService(Context.ACTIVITY_SERVICE);
      for (ActivityManager.AppTask task : manager.getAppTasks()) {
        Intent baseIntent = task.getTaskInfo().baseIntent;

        if (HomeActivity.class.getName().equals(baseIntent.getComponent().getClassName())) {
          task.moveToFront();
          return;
        }
      }
    }

    Intent intent = new Intent(mActivityContext, HomeActivity.class);
    Kernel.addIntentDocumentFlags(intent);

    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
      // Don't want to end up in state where we have
      // ExperienceActivity - HomeActivity - ExperienceActivity
      // Want HomeActivity to be the root activity if it exists
      intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK);
    }

    mActivityContext.startActivity(intent);
  }

  private void openShellAppActivity() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
      ActivityManager manager = (ActivityManager) mContext.getSystemService(Context.ACTIVITY_SERVICE);
      for (ActivityManager.AppTask task : manager.getAppTasks()) {
        Intent baseIntent = task.getTaskInfo().baseIntent;

        if (ShellAppActivity.class.getName().equals(baseIntent.getComponent().getClassName())) {
          moveTaskToFront(task.getTaskInfo().id);
          return;
        }
      }
    }

    Class clazz = ShellAppActivity.class;
    try {
      if (Constants.isDetached()) {
        clazz = Class.forName("host.exp.exponent.MainActivity");
      }
    } catch (Exception e) {
      EXL.e(TAG, "Cannot find MainActivity, falling back to ShellAppActivity");
    }
    Intent intent = new Intent(mActivityContext, clazz);
    Kernel.addIntentDocumentFlags(intent);

    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
      // Don't want to end up in state where we have
      // ExperienceActivity - HomeActivity - ExperienceActivity
      // Want HomeActivity to be the root activity if it exists
      intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK);
    }

    mActivityContext.startActivity(intent);
  }

  /*
   *
   * Manifests
   *
   */

  public void handleIntent(Activity activity, Intent intent) {
    try {
      if (intent.getBooleanExtra("EXKernelDisableNuxDefaultsKey", false)) {
        Constants.DISABLE_NUX = true;
      }
    } catch (Throwable e) {}

    Bundle bundle = intent.getExtras();
    setActivityContext(activity);

    Uri uri = intent.getData();
    String intentUri = uri == null ? null : uri.toString();

    if (bundle != null) {
      if (bundle.getBoolean(KernelConstants.DEV_FLAG)) {
        openDevActivity(activity);
        return;
      }

      // Notification
      String notification = bundle.getString(KernelConstants.NOTIFICATION_KEY); // deprecated
      String notificationObject = bundle.getString(KernelConstants.NOTIFICATION_OBJECT_KEY);
      String notificationManifestUrl = bundle.getString(KernelConstants.NOTIFICATION_MANIFEST_URL_KEY);
      if (notificationManifestUrl != null) {
        openExperience(new KernelConstants.ExperienceOptions(notificationManifestUrl, intentUri == null ? notificationManifestUrl : intentUri, notification, ExponentNotification.fromJSONObjectString(notificationObject)));
        return;
      }

      // Shortcut
      String shortcutManifestUrl = bundle.getString(KernelConstants.SHORTCUT_MANIFEST_URL_KEY);
      if (shortcutManifestUrl != null) {
        openExperience(new KernelConstants.ExperienceOptions(shortcutManifestUrl, intentUri, null));
        return;
      }
    }

    if (uri != null) {
      if (Constants.INITIAL_URL == null) {
        // We got an "exp://" link
        openExperience(new KernelConstants.ExperienceOptions(intentUri, intentUri, null));
        return;
      } else {
        // We got a custom scheme link
        // TODO: we still might want to parse this if we're running a different experience inside a
        // shell app. For example, we are running Brighten in the List shell and go to Twitter login.
        // We might want to set the return uri to thelistapp://exp.host/@brighten/brighten+deeplink
        // But we also can't break thelistapp:// deep links that look like thelistapp://l/listid
        openExperience(new KernelConstants.ExperienceOptions(Constants.INITIAL_URL, intentUri, null));
        return;
      }
    }

    String defaultUrl = Constants.INITIAL_URL == null ? KernelConstants.HOME_MANIFEST_URL : Constants.INITIAL_URL;
    openExperience(new KernelConstants.ExperienceOptions(defaultUrl, defaultUrl, null));
  }

  private void openDevActivity(Activity activity) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
      ActivityManager manager = (ActivityManager) activity.getSystemService(Context.ACTIVITY_SERVICE);
      for (ActivityManager.AppTask task : manager.getAppTasks()) {
        Intent baseIntent = task.getTaskInfo().baseIntent;

        if (ExponentDevActivity.class.getName().equals(baseIntent.getComponent().getClassName())) {
          task.moveToFront();
          return;
        }
      }
    }

    Intent intent = new Intent(activity, ExponentDevActivity.class);
    Kernel.addIntentDocumentFlags(intent);
    activity.startActivity(intent);
  }

  public void openExperience(final KernelConstants.ExperienceOptions options) {
    openManifestUrl(getManifestUrlFromFullUri(options.manifestUri), options, true);
  }

  private String getManifestUrlFromFullUri(String uri) {
    if (uri != null) {
      int deepLinkPosition = uri.indexOf('+');
      if (deepLinkPosition >= 0) {
        uri = uri.substring(0, deepLinkPosition);
      }

      // manifest url doesn't have a trailing slash
      if (uri.length() > 0) {
        char lastUrlChar = uri.charAt(uri.length() - 1);
        if (lastUrlChar == '/') {
          uri = uri.substring(0, uri.length() - 1);
        }
      }

      return uri;
    }
    return null;
  }

  private void openManifestUrl(final String manifestUrl, final KernelConstants.ExperienceOptions options, final Boolean isOptimistic) {
    openManifestUrl(manifestUrl, options, isOptimistic, false);
  }

  private void openManifestUrl(final String manifestUrl, final KernelConstants.ExperienceOptions options, final Boolean isOptimistic, final boolean forceNetwork) {
    SoLoader.init(mContext, false);

    if (options == null) {
      mManifestUrlToOptions.remove(manifestUrl);
    } else {
      mManifestUrlToOptions.put(manifestUrl, options);
    }

    if (manifestUrl == null || manifestUrl.equals(KernelConstants.HOME_MANIFEST_URL)) {
      openHomeActivity();
      return;
    }

    if (manifestUrl.equals(Constants.INITIAL_URL)) {
      openShellAppActivity();
      return;
    }

    ExponentKernelModuleProvider.queueEvent("ExponentKernel.clearConsole", Arguments.createMap(), null);

    final List<ActivityManager.AppTask> tasks = getExperienceActivityTasks();
    ActivityManager.AppTask existingTask = null;
    if (tasks != null) {
      for (int i = 0; i < tasks.size(); i++) {
        ActivityManager.AppTask task = tasks.get(i);
        Intent baseIntent = task.getTaskInfo().baseIntent;
        if (baseIntent.hasExtra(KernelConstants.MANIFEST_URL_KEY) && baseIntent.getStringExtra(KernelConstants.MANIFEST_URL_KEY).equals(manifestUrl)) {
          existingTask = task;
          break;
        }
      }
    }

    if (isOptimistic && existingTask == null) {
      openOptimisticExperienceActivity(manifestUrl);
    }

    if (existingTask != null) {
      try {
        moveTaskToFront(existingTask.getTaskInfo().id);
      } catch (IllegalArgumentException e) {
        // Sometimes task can't be found.
        existingTask = null;
        openOptimisticExperienceActivity(manifestUrl);
      }
    }

    final ActivityManager.AppTask finalExistingTask = existingTask;
    new AppLoader(manifestUrl, mExponentManifest, mExponentSharedPreferences) {
      @Override
      public void onOptimisticManifest(final JSONObject optimisticManifest) {
        Exponent.getInstance().runOnUiThread(new Runnable() {
          @Override
          public void run() {
            sendLoadingScreenManifestToExperienceActivity(optimisticManifest);
          }
        });
      }

      @Override
      public void onManifestCompleted(final JSONObject manifest) {
        Exponent.getInstance().runOnUiThread(new Runnable() {
          @Override
          public void run() {
            try {
              openManifestUrlStep2(manifestUrl, manifest, finalExistingTask);
            } catch (JSONException e) {
              handleError(e);
            }
          }
        });
      }

      @Override
      public void onBundleCompleted(String localBundlePath) {
        sendBundleToExperienceActivity(localBundlePath);
      }

      @Override
      public void emitEvent(JSONObject params) {
        ExperienceActivityTask task = sManifestUrlToExperienceActivityTask.get(manifestUrl);
        if (task != null) {
          ExperienceActivity experienceActivity = task.experienceActivity.get();
          if (experienceActivity != null) {
            experienceActivity.emitUpdatesEvent(params);
          }
        }
      }

      @Override
      public void onError(Exception e) {
        handleError(e);
      }

      @Override
      public void onError(String e) {
        handleError(e);
      }
    }.start();
  }

  private void openManifestUrlStep2(String manifestUrl, JSONObject manifest, ActivityManager.AppTask existingTask) throws JSONException {
    String bundleUrl = ExponentUrls.toHttp(manifest.getString("bundleUrl"));
    Kernel.ExperienceActivityTask task = getExperienceActivityTask(manifestUrl);
    task.bundleUrl = bundleUrl;

    manifest = mExponentManifest.normalizeManifest(manifestUrl, manifest);
    boolean isFirstRunFinished = mExponentSharedPreferences.getBoolean(ExponentSharedPreferences.NUX_HAS_FINISHED_FIRST_RUN_KEY);

    // TODO: shouldShowNux used to be set to `!manifestUrl.equals(Constants.INITIAL_URL);`.
    // This caused nux to show up in RNPlay. What's the right behavior here?
    boolean shouldShowNux = !Constants.isShellApp() && !KernelConfig.HIDE_NUX;
    boolean loadNux = shouldShowNux && !isFirstRunFinished;
    JSONObject opts = new JSONObject();
    opts.put(KernelConstants.OPTION_LOAD_NUX_KEY, loadNux);

    if (existingTask == null) {
      sendManifestToExperienceActivity(manifestUrl, manifest, bundleUrl, opts);
    }

    if (loadNux) {
      mExponentSharedPreferences.setBoolean(ExponentSharedPreferences.NUX_HAS_FINISHED_FIRST_RUN_KEY, true);
    }

    WritableMap params = Arguments.createMap();
    params.putString("manifestUrl", manifestUrl);
    params.putString("manifestString", manifest.toString());
    ExponentKernelModuleProvider.queueEvent("ExponentKernel.addHistoryItem", params, new ExponentKernelModuleProvider.KernelEventCallback() {
      @Override
      public void onEventSuccess(ReadableMap result) {
        EXL.d(TAG, "Successfully called ExponentKernel.addHistoryItem in kernel JS.");
      }

      @Override
      public void onEventFailure(String errorMessage) {
        EXL.e(TAG, "Error calling ExponentKernel.addHistoryItem in kernel JS: " + errorMessage);
      }
    });

    killOrphanedLauncherActivities();
  }

  // Called from DevServerHelper via ReactNativeStaticHelpers
  @DoNotStrip
  public static String getBundleUrlForActivityId(final int activityId, String host,
                                                 String mainModuleId, String bundleTypeId,
                                                 boolean devMode, boolean jsMinify) {
    // NOTE: This current implementation doesn't look at the bundleTypeId (see RN's private
    // BundleType enum for the possible values) but may need to

    if (activityId == -1) {
      // This is the kernel
      return sInstance.getBundleUrl();
    }

    for (ExperienceActivityTask task : sManifestUrlToExperienceActivityTask.values()) {
      if (task.activityId == activityId) {
        return task.bundleUrl;
      }
    }

    return null;
  }

  // <= SDK 25
  @DoNotStrip
  public static String getBundleUrlForActivityId(final int activityId, String host, String jsModulePath, boolean devMode, boolean jsMinify) {
    if (activityId == -1) {
      // This is the kernel
      return sInstance.getBundleUrl();
    }

    for (ExperienceActivityTask task : sManifestUrlToExperienceActivityTask.values()) {
      if (task.activityId == activityId) {
        return task.bundleUrl;
      }
    }

    return null;
  }

  // <= SDK 21
  @DoNotStrip
  public static String getBundleUrlForActivityId(final int activityId, String host, String jsModulePath, boolean devMode, boolean hmr, boolean jsMinify) {
    if (activityId == -1) {
      // This is the kernel
      return sInstance.getBundleUrl();
    }

    for (ExperienceActivityTask task : sManifestUrlToExperienceActivityTask.values()) {
      if (task.activityId == activityId) {
        String url = task.bundleUrl;
        if (url == null) {
          return null;
        }

        if (hmr) {
          if (url.contains("hot=false")) {
            url = url.replace("hot=false", "hot=true");
          } else {
            url = url + "&hot=true";
          }
        }

        return url;
      }
    }

    return null;
  }


  /*
   *
   * Optimistic experiences
   *
   */

  public void openOptimisticExperienceActivity(String manifestUrl) {
    try {
      Intent intent = new Intent(mActivityContext, ExperienceActivity.class);
      addIntentDocumentFlags(intent);
      intent.putExtra(KernelConstants.MANIFEST_URL_KEY, manifestUrl);
      intent.putExtra(KernelConstants.IS_OPTIMISTIC_KEY, true);
      mActivityContext.startActivity(intent);
    } catch (Throwable e) {
      EXL.e(TAG, e);
    }
  }

  public void setOptimisticActivity(ExperienceActivity experienceActivity, int taskId) {
    mOptimisticActivity = experienceActivity;
    mOptimisticTaskId = taskId;

    AsyncCondition.notify(KernelConstants.OPEN_OPTIMISTIC_EXPERIENCE_ACTIVITY_KEY);
    AsyncCondition.notify(KernelConstants.OPEN_EXPERIENCE_ACTIVITY_KEY);
  }

  public void sendLoadingScreenManifestToExperienceActivity(final JSONObject manifest) {
    AsyncCondition.wait(KernelConstants.OPEN_OPTIMISTIC_EXPERIENCE_ACTIVITY_KEY, new AsyncCondition.AsyncConditionListener() {
      @Override
      public boolean isReady() {
        return mOptimisticActivity != null && mOptimisticTaskId != null;
      }

      @Override
      public void execute() {
        mOptimisticActivity.setLoadingScreenManifest(manifest);
      }
    });
  }

  public void sendManifestToExperienceActivity(
      final String manifestUrl, final JSONObject manifest, final String bundleUrl, final JSONObject kernelOptions) {
    AsyncCondition.wait(KernelConstants.OPEN_EXPERIENCE_ACTIVITY_KEY, new AsyncCondition.AsyncConditionListener() {
      @Override
      public boolean isReady() {
        return mOptimisticActivity != null && mOptimisticTaskId != null;
      }

      @Override
      public void execute() {
        mOptimisticActivity.setManifest(manifestUrl, manifest, bundleUrl, kernelOptions);
        AsyncCondition.notify(KernelConstants.LOAD_BUNDLE_FOR_EXPERIENCE_ACTIVITY_KEY);
      }
    });
  }

  public void sendBundleToExperienceActivity(final String localBundlePath) {
    AsyncCondition.wait(KernelConstants.LOAD_BUNDLE_FOR_EXPERIENCE_ACTIVITY_KEY, new AsyncCondition.AsyncConditionListener() {
      @Override
      public boolean isReady() {
        return mOptimisticActivity != null && mOptimisticTaskId != null;
      }

      @Override
      public void execute() {
        mOptimisticActivity.setBundle(localBundlePath);

        mOptimisticActivity = null;
        mOptimisticTaskId = null;
      }
    });
  }

  /*
   *
   * Tasks
   *
   */

  public List<ActivityManager.AppTask> getTasks() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
      ActivityManager manager = (ActivityManager) mContext.getSystemService(Context.ACTIVITY_SERVICE);
      return manager.getAppTasks();
    } else {
      EXL.e(TAG, "Got to getTasks on pre-Lollipop device");
      return null;
    }
  }

  // Get list of tasks in our format.
  public List<ActivityManager.AppTask> getExperienceActivityTasks() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
      return getTasks();
    } else {
      return null;
    }
  }

  // Sometimes LauncherActivity.finish() doesn't close the activity and task. Not sure why exactly.
  // Thought it was related to launchMode="singleTask" but other launchModes seem to have the same problem.
  // This can be reproduced by creating a shortcut, exiting app, clicking on shortcut, refreshing, pressing
  // home, clicking on shortcut, click recent apps button. There will be a blank LauncherActivity behind
  // the ExperienceActivity. killOrphanedLauncherActivities solves this but would be nice to figure out
  // the root cause.
  private void killOrphanedLauncherActivities() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
      try {
        // Crash with NoSuchFieldException instead of hard crashing at taskInfo.numActivities
        ActivityManager.RecentTaskInfo.class.getDeclaredField("numActivities");

        for (ActivityManager.AppTask task : getTasks()) {
          ActivityManager.RecentTaskInfo taskInfo = task.getTaskInfo();
          if (taskInfo.numActivities == 0 && taskInfo.baseIntent.getAction().equals(Intent.ACTION_MAIN)) {
            task.finishAndRemoveTask();
            return;
          }

          if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (taskInfo.numActivities == 1 && taskInfo.topActivity.getClassName().equals(LauncherActivity.class.getName())) {
              task.finishAndRemoveTask();
              return;
            }
          }
        }
      } catch (NoSuchFieldException e) {
        // Don't EXL here because this isn't actually a problem
        Log.e(TAG, e.toString());
      } catch (Throwable e) {
        EXL.e(TAG, e);
      }
    }
  }

  public void moveTaskToFront(int taskId) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
      for (ActivityManager.AppTask task : getTasks()) {
        if (task.getTaskInfo().id == taskId) {
          // If we have the task in memory, tell the ExperienceActivity to check for new options.
          // Otherwise options will be added in initialProps when the Experience starts.
          ExperienceActivityTask exponentTask = experienceActivityTaskForTaskId(taskId);
          if (exponentTask != null) {
            ExperienceActivity experienceActivity = exponentTask.experienceActivity.get();
            if (experienceActivity != null) {
              experienceActivity.shouldCheckOptions();
            }
          }

          task.moveToFront();
        }
      }
    } else {
      EXL.e(TAG, "Got to moveTaskToFront on pre-Lollipop device");
    }
  }

  public void killActivityStack(final Activity activity) {
    ExperienceActivityTask exponentTask = experienceActivityTaskForTaskId(activity.getTaskId());
    if (exponentTask != null) {
      removeExperienceActivityTask(exponentTask.manifestUrl);
    }

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
      // Kill the current task.
      ActivityManager manager = (ActivityManager) activity.getSystemService(Context.ACTIVITY_SERVICE);
      for (ActivityManager.AppTask task : manager.getAppTasks()) {
        if (task.getTaskInfo().id == activity.getTaskId()) {
          task.finishAndRemoveTask();
        }
      }
    }
  }

  @Override
  public boolean reloadVisibleExperience(String manifestUrl) {
    if (manifestUrl == null) {
      return false;
    }

    // Pre Lollipop we always just open a new activity.
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
      // TODO: make debug mode work here
      openOptimisticExperienceActivity(manifestUrl);
      openManifestUrl(manifestUrl, null, false, true);
    } else {
      ExperienceActivity activity = null;
      for (final ExperienceActivityTask experienceActivityTask : sManifestUrlToExperienceActivityTask.values()) {
        if (manifestUrl.equals(experienceActivityTask.manifestUrl)) {
          final ExperienceActivity weakActivity = experienceActivityTask.experienceActivity == null ? null : experienceActivityTask.experienceActivity.get();
          activity = weakActivity;
          if (activity == null) {
            // No activity, just force a reload
            break;
          }

          if (weakActivity.isLoading()) {
            // Already loading. Don't need to do anything.
            return true;
          } else {
            Exponent.getInstance().runOnUiThread(new Runnable() {
              @Override
              public void run() {
                weakActivity.showLoadingScreen(null);
              }
            });
            break;
          }
        }
      }

      if (activity != null) {
        killActivityStack(activity);
      }
      openManifestUrl(manifestUrl, null, true, true);
    }

    return true;
  }

  /*
   *
   * Error handling
   *
   */

  // Called using reflection from ReactAndroid.
  @DoNotStrip
  public static void handleReactNativeError(String errorMessage, Object detailsUnversioned,
                                            Integer exceptionId, Boolean isFatal) {
    handleReactNativeError(ExponentErrorMessage.developerErrorMessage(errorMessage), detailsUnversioned, exceptionId, isFatal);
  }

  // Called using reflection from ReactAndroid.
  @DoNotStrip
  public static void handleReactNativeError(Throwable throwable, String errorMessage, Object detailsUnversioned,
                                            Integer exceptionId, Boolean isFatal) {
    handleReactNativeError(ExponentErrorMessage.developerErrorMessage(errorMessage), detailsUnversioned, exceptionId, isFatal);
    if (throwable != null) {
      Exponent.logException(throwable);
    }
  }

  private static void handleReactNativeError(ExponentErrorMessage errorMessage, Object detailsUnversioned,
      Integer exceptionId, Boolean isFatal) {
    ArrayList<Bundle> stackList = new ArrayList<>();
    if (detailsUnversioned != null) {
      RNObject details = RNObject.wrap(detailsUnversioned);
      RNObject arguments = new RNObject("com.facebook.react.bridge.Arguments");
      arguments.loadVersion(details.version());

      for (int i = 0; i < (int) details.call("size"); i++) {
        try {
          Bundle bundle = (Bundle) arguments.callStatic("toBundle", details.call("getMap", i));
          stackList.add(bundle);
        } catch (Exception e) {
          e.printStackTrace();
        }
      }
    } else if (BuildConfig.DEBUG) {
      StackTraceElement[] stackTraceElements = Thread.currentThread().getStackTrace();
      // stackTraceElements starts with a bunch of stuff we don't care about.
      for (int i = 2; i < stackTraceElements.length; i++) {
        StackTraceElement element = stackTraceElements[i];
        if (element.getFileName().startsWith(Kernel.class.getSimpleName()) &&
            (element.getMethodName().equals("handleReactNativeError") ||
                element.getMethodName().equals("handleError"))) {
          // Ignore these base error handling methods.
          continue;
        }

        Bundle bundle = new Bundle();
        bundle.putInt("column", 0);
        bundle.putInt("lineNumber", element.getLineNumber());
        bundle.putString("methodName", element.getMethodName());
        bundle.putString("file", element.getFileName());
        stackList.add(bundle);
      }
    }
    Bundle[] stack = stackList.toArray(new Bundle[stackList.size()]);

    BaseExperienceActivity.addError(new ExponentError(errorMessage, stack,
        getExceptionId(exceptionId), isFatal));
  }

  public void handleError(String errorMessage) {
    handleReactNativeError(ExponentErrorMessage.developerErrorMessage(errorMessage), null, -1, true);
  }

  public void handleError(Exception exception) {
    handleReactNativeError(ExceptionUtils.exceptionToErrorMessage(exception), null, -1, true);
    Exponent.logException(exception);
  }

  private static int getExceptionId(Integer originalId) {
    if (originalId == null || originalId == -1) {
      return (int) -(Math.random() * Integer.MAX_VALUE);
    }

    return originalId;
  }

  // TODO: probably need to call this from other places.
  public void setHasError() {
    mHasError = true;
  }

  /*
   *
   * Shortcuts
   *
   */

  public void installShortcut(final String manifestUrl, final ReadableMap manifest, final String bundleUrl) {
    JSONObject manifestJson = ReadableObjectUtils.readableToJson(manifest);
    mExponentSharedPreferences.updateManifest(manifestUrl, manifestJson, bundleUrl);
    installShortcut(manifestUrl);
  }

  public void installShortcut(final String manifestUrl) {
    ExponentSharedPreferences.ManifestAndBundleUrl manifestAndBundleUrl = mExponentSharedPreferences.getManifest(manifestUrl);
    final JSONObject manifestJson = manifestAndBundleUrl.manifest;

    // TODO: show loading indicator while fetching bitmap
    final String iconUrl = manifestJson.optString(ExponentManifest.MANIFEST_ICON_URL_KEY);
    mExponentManifest.loadIconBitmap(iconUrl, new ExponentManifest.BitmapListener() {
      @Override
      public void onLoadBitmap(Bitmap bitmap) {
        Intent shortcutIntent = new Intent(mContext, LauncherActivity.class);
        shortcutIntent.setAction(Intent.ACTION_MAIN);
        shortcutIntent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
        shortcutIntent.putExtra(KernelConstants.SHORTCUT_MANIFEST_URL_KEY, manifestUrl);

        ShortcutInfoCompat pinShortcutInfo =
          new ShortcutInfoCompat.Builder(mContext, manifestUrl)
                 .setIcon(IconCompat.createWithBitmap(bitmap))
              .setShortLabel(manifestJson.optString(ExponentManifest.MANIFEST_NAME_KEY))
              .setIntent(shortcutIntent)
              .build();

        ShortcutManagerCompat.requestPinShortcut(mContext, pinShortcutInfo, null);
      }
    });
  }

  public void addDevMenu() {
    Intent shortcutIntent = new Intent(mContext, LauncherActivity.class);
    shortcutIntent.setAction(Intent.ACTION_MAIN);
    shortcutIntent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
    shortcutIntent.putExtra(KernelConstants.DEV_FLAG, true);

    ShortcutInfoCompat pinShortcutInfo =
      new ShortcutInfoCompat.Builder(mContext, "devtools_shortcut")
              .setIcon(IconCompat.createWithResource(mContext, R.mipmap.dev_icon))
          .setShortLabel("Dev Tools")
          .setIntent(shortcutIntent)
          .build();

    ShortcutManagerCompat.requestPinShortcut(mContext, pinShortcutInfo, null);
  }

  private void goToHome() {
    Intent startMain = new Intent(Intent.ACTION_MAIN);
    startMain.addCategory(Intent.CATEGORY_HOME);
    startMain.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
    mContext.startActivity(startMain);
  }
}
