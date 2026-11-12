package se.movera.driver;

import android.app.Instrumentation;
import android.content.Context;
import android.location.Location;
import android.location.LocationManager;
import android.os.Build;
import android.os.Bundle;
import android.os.ParcelFileDescriptor;
import android.os.SystemClock;
import android.system.Os;
import android.util.Log;
import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.rule.ActivityTestRule;
import dev.flutter.plugins.integration_test.FlutterTestRunner;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;
import org.junit.Rule;
import org.junit.runner.RunWith;

/**
 * Owner 2026-11-12 ("U need find problems!"): runs the on-phone checks in
 * integration_test/ (Firebase Test Lab, {@code --type instrumentation}).
 *
 * <p>Sign-in values come only at run time, as instrumentation arguments
 * ({@code gcloud ... --environment-variables}, mirrored to {@code am instrument -e}).
 * They are handed to the Dart test as process environment variables before the
 * activity (and so the Dart VM) starts. Nothing is built into an APK, and no value
 * is ever logged.
 *
 * <p>The phone's position is the app's real location stack (geolocator, its
 * foreground service and wake lock, the G24 path), fed with mock fixes at the
 * zone's point because a Test Lab phone in a rack has no GPS signal.
 */
@RunWith(FlutterTestRunner.class)
public class MainActivityTest {
  private static final String TAG = "MoveraTL";

  /** Instrumentation argument -> environment variable read by the Dart test. */
  private static final String[][] ARGS = {
    {"movera_tl_phone", "MOVERA_TL_PHONE"},
    {"movera_tl_code", "MOVERA_TL_CODE"},
    {"movera_tl_lat", "MOVERA_TL_LAT"},
    {"movera_tl_lng", "MOVERA_TL_LNG"},
    {"movera_tl_shots", "MOVERA_TL_SHOTS"},
  };

  /** Central Stockholm (zone Z001) unless the run names another point. */
  private static final double DEFAULT_LAT = 59.3326;

  private static final double DEFAULT_LNG = 18.0649;

  static {
    prepare();
  }

  @Rule
  public ActivityTestRule<MainActivity> rule =
      new ActivityTestRule<>(MainActivity.class, true, false);

  private static void prepare() {
    Bundle args;
    Instrumentation instrumentation;
    try {
      instrumentation = InstrumentationRegistry.getInstrumentation();
      args = InstrumentationRegistry.getArguments();
    } catch (IllegalStateException e) {
      Log.w(TAG, "no instrumentation registry: " + e.getClass().getSimpleName());
      return;
    }
    int handed = 0;
    for (String[] pair : ARGS) {
      String value = args.getString(pair[0]);
      if (value == null || value.isEmpty()) continue;
      try {
        Os.setenv(pair[1], value, true);
        handed++;
      } catch (Exception e) {
        Log.w(TAG, "could not hand over " + pair[0] + ": " + e.getClass().getSimpleName());
      }
    }
    // Names only, never values.
    Log.i(TAG, "run-time values handed to the test: " + handed);

    Context app = instrumentation.getTargetContext();
    File out = app.getExternalFilesDir("tl");
    if (out != null) {
      try {
        Os.setenv("MOVERA_TL_OUT", out.getAbsolutePath(), true);
      } catch (Exception e) {
        Log.w(TAG, "no output folder: " + e.getClass().getSimpleName());
      }
    }

    if (!"0".equals(args.getString("movera_tl_mock_location"))) {
      double lat = parse(args.getString("movera_tl_lat"), DEFAULT_LAT);
      double lng = parse(args.getString("movera_tl_lng"), DEFAULT_LNG);
      startMockLocation(instrumentation, app, lat, lng);
    }
  }

  private static double parse(String value, double fallback) {
    if (value == null) return fallback;
    try {
      return Double.parseDouble(value);
    } catch (NumberFormatException e) {
      return fallback;
    }
  }

  private static void shell(Instrumentation instrumentation, String command) {
    ParcelFileDescriptor pfd = instrumentation.getUiAutomation().executeShellCommand(command);
    try (InputStream in = new FileInputStream(pfd.getFileDescriptor())) {
      byte[] buffer = new byte[256];
      while (in.read(buffer) != -1) {
        // Drain: the command ends when its output is read.
      }
    } catch (IOException e) {
      Log.w(TAG, "shell: " + e.getClass().getSimpleName());
    } finally {
      try {
        pfd.close();
      } catch (IOException ignored) {
        // Closed already.
      }
    }
  }

  private static void startMockLocation(
      Instrumentation instrumentation, Context app, double lat, double lng) {
    shell(instrumentation, "appops set " + app.getPackageName() + " android:mock_location allow");
    final LocationManager manager =
        (LocationManager) app.getSystemService(Context.LOCATION_SERVICE);
    final List<String> providers = new ArrayList<>();
    List<String> wanted = new ArrayList<>();
    wanted.add(LocationManager.GPS_PROVIDER);
    wanted.add(LocationManager.NETWORK_PROVIDER);
    if (Build.VERSION.SDK_INT >= 31) wanted.add("fused");
    for (String provider : wanted) {
      try {
        manager.addTestProvider(
            provider, false, false, false, false, true, true, true, /* power low */ 1,
            /* accuracy fine */ 1);
        manager.setTestProviderEnabled(provider, true);
        providers.add(provider);
      } catch (RuntimeException e) {
        Log.w(TAG, "mock provider " + provider + ": " + e.getClass().getSimpleName());
      }
    }
    final Object fused = fusedClient(app);
    Log.i(TAG, "mock location providers=" + providers + " fused=" + (fused != null));
    Thread feeder =
        new Thread(
            () -> {
              while (true) {
                for (String provider : providers) {
                  try {
                    manager.setTestProviderLocation(provider, fix(provider, lat, lng));
                  } catch (RuntimeException e) {
                    // Provider gone (test ending).
                  }
                }
                if (fused != null) {
                  try {
                    Method set = fused.getClass().getMethod("setMockLocation", Location.class);
                    set.invoke(fused, fix("fused", lat, lng));
                  } catch (Exception e) {
                    // Play services refused one fix; the next second tries again.
                  }
                }
                SystemClock.sleep(1000);
              }
            },
            "movera-tl-mock-location");
    feeder.setDaemon(true);
    feeder.start();
  }

  /** Google Play services' fused provider in mock mode, without a compile dependency. */
  private static Object fusedClient(Context app) {
    try {
      Class<?> services = Class.forName("com.google.android.gms.location.LocationServices");
      Object client =
          services.getMethod("getFusedLocationProviderClient", Context.class).invoke(null, app);
      client.getClass().getMethod("setMockMode", boolean.class).invoke(client, true);
      return client;
    } catch (Exception e) {
      Log.w(TAG, "fused mock: " + e.getClass().getSimpleName());
      return null;
    }
  }

  private static Location fix(String provider, double lat, double lng) {
    Location location = new Location(provider);
    location.setLatitude(lat);
    location.setLongitude(lng);
    location.setAccuracy(5f);
    location.setAltitude(20);
    location.setSpeed(0f);
    location.setBearing(0f);
    location.setTime(System.currentTimeMillis());
    location.setElapsedRealtimeNanos(SystemClock.elapsedRealtimeNanos());
    if (Build.VERSION.SDK_INT >= 26) {
      location.setVerticalAccuracyMeters(5f);
      location.setSpeedAccuracyMetersPerSecond(1f);
      location.setBearingAccuracyDegrees(10f);
    }
    return location;
  }
}
