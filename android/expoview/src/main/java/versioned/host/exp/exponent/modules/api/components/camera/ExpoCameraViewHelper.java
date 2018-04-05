package versioned.host.exp.exponent.modules.api.components.camera;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.media.CamcorderProfile;
import android.os.Build;
import android.support.media.ExifInterface;
import android.util.SparseArray;
import android.view.ViewGroup;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.uimanager.UIManagerModule;
import com.google.android.cameraview.CameraView;
import com.google.android.gms.vision.barcode.Barcode;
import com.google.android.gms.vision.face.Face;

import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Locale;

import versioned.host.exp.exponent.modules.api.ImagePickerModule;
import versioned.host.exp.exponent.modules.api.components.camera.events.BarCodeReadEvent;
import versioned.host.exp.exponent.modules.api.components.camera.events.CameraMountErrorEvent;
import versioned.host.exp.exponent.modules.api.components.camera.events.CameraReadyEvent;
import versioned.host.exp.exponent.modules.api.components.camera.events.FaceDetectionErrorEvent;
import versioned.host.exp.exponent.modules.api.components.camera.events.FacesDetectedEvent;
import versioned.host.exp.exponent.modules.api.components.camera.utils.ImageDimensions;
import versioned.host.exp.exponent.modules.api.components.facedetector.ExpoFaceDetector;

public class ExpoCameraViewHelper {
  // Mount error event

  public static void emitMountErrorEvent(ViewGroup view, String message) {
    CameraMountErrorEvent event = CameraMountErrorEvent.obtain(view.getId(), message);
    ReactContext reactContext = (ReactContext) view.getContext();
    reactContext.getNativeModule(UIManagerModule.class).getEventDispatcher().dispatchEvent(event);
  }

  // Camera ready event

  public static void emitCameraReadyEvent(ViewGroup view) {
    CameraReadyEvent event = CameraReadyEvent.obtain(view.getId());
    ReactContext reactContext = (ReactContext) view.getContext();
    reactContext.getNativeModule(UIManagerModule.class).getEventDispatcher().dispatchEvent(event);
  }

  // Face detection events

  public static void emitFacesDetectedEvent(
      ViewGroup view,
      SparseArray<Face> faces,
      ImageDimensions dimensions
      ) {
    float density = view.getResources().getDisplayMetrics().density;

    double scaleX = (double) view.getWidth() / (dimensions.getWidth() * density);
    double scaleY = (double) view.getHeight() / (dimensions.getHeight() * density);

    FacesDetectedEvent event = FacesDetectedEvent.obtain(
        view.getId(),
        faces,
        dimensions,
        scaleX,
        scaleY
    );

    ReactContext reactContext = (ReactContext) view.getContext();
    reactContext.getNativeModule(UIManagerModule.class).getEventDispatcher().dispatchEvent(event);
  }

  public static void emitFaceDetectionErrorEvent(ViewGroup view, ExpoFaceDetector faceDetector) {
    FaceDetectionErrorEvent event = FaceDetectionErrorEvent.obtain(view.getId(), faceDetector);
    ReactContext reactContext = (ReactContext) view.getContext();
    reactContext.getNativeModule(UIManagerModule.class).getEventDispatcher().dispatchEvent(event);
  }

  // Bar code read event

  public static void emitBarCodeReadEvent(ViewGroup view, Barcode barCode) {
    BarCodeReadEvent event = BarCodeReadEvent.obtain(view.getId(), barCode);
    ReactContext reactContext = (ReactContext) view.getContext();
    reactContext.getNativeModule(UIManagerModule.class).getEventDispatcher().dispatchEvent(event);
  }

  // Utilities

  public static int getCorrectCameraRotation(int rotation, int facing) {
    if (facing == CameraView.FACING_FRONT) {
      return (rotation - 90 + 360) % 360;
    } else {
      return (-rotation + 90 + 360) % 360;
    }
  }

  public static CamcorderProfile getCamcorderProfile(int quality) {
    CamcorderProfile profile = CamcorderProfile.get(CamcorderProfile.QUALITY_HIGH);
    switch (quality) {
      case CameraModule.VIDEO_2160P:
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
          profile = CamcorderProfile.get(CamcorderProfile.QUALITY_2160P);
        }
        break;
      case CameraModule.VIDEO_1080P:
        profile = CamcorderProfile.get(CamcorderProfile.QUALITY_1080P);
        break;
      case CameraModule.VIDEO_720P:
        profile = CamcorderProfile.get(CamcorderProfile.QUALITY_720P);
        break;
      case CameraModule.VIDEO_480P:
        profile = CamcorderProfile.get(CamcorderProfile.QUALITY_480P);
        break;
      case CameraModule.VIDEO_4x3:
        profile = CamcorderProfile.get(CamcorderProfile.QUALITY_480P);
        profile.videoFrameWidth = 640;
        break;
    }
    return profile;
  }

  public static WritableMap getExifData(ExifInterface exifInterface) {
    WritableMap exifMap = Arguments.createMap();
    for (String[] tagInfo : ImagePickerModule.exifTags) {
      String name = tagInfo[1];
      if (exifInterface.getAttribute(name) != null) {
        String type = tagInfo[0];
        switch (type) {
          case "string":
            exifMap.putString(name, exifInterface.getAttribute(name));
            break;
          case "int":
            exifMap.putInt(name, exifInterface.getAttributeInt(name, 0));
            break;
          case "double":
            exifMap.putDouble(name, exifInterface.getAttributeDouble(name, 0));
            break;
        }
      }
    }

    double[] latLong = exifInterface.getLatLong();
    if (latLong != null) {
      exifMap.putDouble(ExifInterface.TAG_GPS_LATITUDE, latLong[0]);
      exifMap.putDouble(ExifInterface.TAG_GPS_LONGITUDE, latLong[1]);
      exifMap.putDouble(ExifInterface.TAG_GPS_ALTITUDE, exifInterface.getAltitude(0));
    }

    return exifMap;
  }

  public static Bitmap generateSimulatorPhoto(int width, int height) {
    Bitmap fakePhoto = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
    Canvas canvas = new Canvas(fakePhoto);
    Paint background = new Paint();
    background.setColor(Color.BLACK);
    canvas.drawRect(0, 0, width, height, background);
    Paint textPaint = new Paint();
    textPaint.setColor(Color.YELLOW);
    textPaint.setTextSize(35);
    Calendar calendar = Calendar.getInstance();
    SimpleDateFormat simpleDateFormat = new SimpleDateFormat("dd.MM.yy HH:mm:ss", Locale.US);
    canvas.drawText(simpleDateFormat.format(calendar.getTime()), width * 0.1f, height * 0.9f, textPaint);
    return fakePhoto;
  }
}
