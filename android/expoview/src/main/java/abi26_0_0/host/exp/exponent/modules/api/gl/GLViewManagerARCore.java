package abi26_0_0.host.exp.exponent.modules.api.gl;

import android.util.Log;

import abi20_0_0.com.facebook.react.bridge.ReactMethod;
import abi26_0_0.com.facebook.react.common.MapBuilder;
import abi26_0_0.com.facebook.react.uimanager.SimpleViewManager;
import abi26_0_0.com.facebook.react.uimanager.ThemedReactContext;

import java.util.Map;

import javax.annotation.Nullable;

import com.google.ar.core.Anchor;
import com.google.ar.core.ArCoreApk;
import com.google.ar.core.Camera;
import com.google.ar.core.Config;
import com.google.ar.core.Frame;
import com.google.ar.core.HitResult;
import com.google.ar.core.Plane;
import com.google.ar.core.Point;
import com.google.ar.core.Point.OrientationMode;
import com.google.ar.core.PointCloud;
import com.google.ar.core.Session;
import com.google.ar.core.Trackable;
import com.google.ar.core.TrackingState;
import com.google.ar.core.exceptions.UnavailableApkTooOldException;
import com.google.ar.core.exceptions.UnavailableArcoreNotInstalledException;
import com.google.ar.core.exceptions.UnavailableSdkTooOldException;
import com.google.ar.core.exceptions.UnavailableUserDeclinedInstallationException;

public class GLViewManagerARCore extends SimpleViewManager<GLView> {
    public static final String REACT_CLASS = "ExponentGLViewManager";

    @Override
    public String getName() {
        return REACT_CLASS;
    }

    @Override
    public GLView createViewInstance(ThemedReactContext context) {
        return new GLView(context);
    }

    @Override
    public @Nullable Map getExportedCustomDirectEventTypeConstants() {
        return MapBuilder.of(
                "surfaceCreate",
                MapBuilder.of("registrationName", "onSurfaceCreate"));
    }

    @ReactMethod
    public void startARSessionAsync() {
        Log.d("ARCore", "startARSessionAsync");
        return;
    }

    @ReactMethod
    public void getARMatrices(){
        Log.d("ARCore", "getARMatrices");
        return;
    }

    @ReactMethod
    public void getARLightEstimation(){
        Log.d("ARCore", "getARLightEstimation");
        return;
    }

    @ReactMethod
    public void getRawFeaturePoints(){
        Log.d("ARCore", "getRawFeturePoints");
        return;
    }

    @ReactMethod
    public void getPlanes(){
        Log.d("ARCore", "getPlanes");
        return;
    }

    @ReactMethod
    public void setIsLightEstimationEnabled(boolean lightEstimation){
        Log.d("ARCore", "setLightEstimation");
        return;
    }

    @ReactMethod
    public void setWorldAlignment(){
        Log.d("ARCore", "setLightEstimation");
        return;
    }

    @ReactMethod
    public void setIsPlaneDetectionEnabled(boolean planeDetection){
        Log.d("ARCore", "setPlaneDetection");
        return;
    }

}

