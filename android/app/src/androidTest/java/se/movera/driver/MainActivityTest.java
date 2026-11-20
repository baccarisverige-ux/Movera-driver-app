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
import java.util.Random;
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
    // Trip lifecycle test: the rider played over HTTP, and which scenario.
    {"movera_tl_rider_phone", "MOVERA_TL_RIDER_PHONE"},
    {"movera_tl_scenario", "MOVERA_TL_SCENARIO"},
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
      targetLat = parse(args.getString("movera_tl_lat"), DEFAULT_LAT);
      targetLng = parse(args.getString("movera_tl_lng"), DEFAULT_LNG);
      // The Dart test moves the mock position at run time by writing
      // "lat,lng" into this file (app-private; coordinates only).
      File target = new File(app.getFilesDir(), "tl-mock-target");
      if (target.exists() && !target.delete()) {
        Log.w(TAG, "old mock target not removed");
      }
      targetFile = target;
      try {
        Os.setenv("MOVERA_TL_MOCK_FILE", target.getAbsolutePath(), true);
      } catch (Exception e) {
        Log.w(TAG, "no mock target file: " + e.getClass().getSimpleName());
      }
      // T7 (owner 2026-11-19 "You test with Firebase"): the Dart test turns
      // the phone's Location or network off/on by writing one word into
      // this file (location-off, location-on, net-off, net-on); the feeder
      // runs it through the shell and writes what the phone then reports
      // into the same name + ".ack". No values, only switch states.
      File control = new File(app.getFilesDir(), "tl-control");
      if (control.exists() && !control.delete()) {
        Log.w(TAG, "old control file not removed");
      }
      controlFile = control;
      try {
        Os.setenv("MOVERA_TL_CONTROL_FILE", control.getAbsolutePath(), true);
      } catch (Exception e) {
        Log.w(TAG, "no control file: " + e.getClass().getSimpleName());
      }
      startMockLocation(instrumentation, app);
    }
    // Device proof M1: offer notices may show (granted once, before the app starts).
    if (Build.VERSION.SDK_INT >= 33) {
      shell(instrumentation, "pm grant se.movera.driver android.permission.POST_NOTIFICATIONS");
    }
  }

  private static File controlFile;

  private static long controlStamp;

  /** When the network was cut (0 = on): it is put back after [NET_OFF_MAX_MS] whatever the test does. */
  private static long netOffSince;

  private static final long NET_OFF_MAX_MS = 5 * 60 * 1000;

  private static String shellOut(Instrumentation instrumentation, String command) {
    ParcelFileDescriptor pfd = instrumentation.getUiAutomation().executeShellCommand(command);
    StringBuilder text = new StringBuilder();
    try (InputStream in = new FileInputStream(pfd.getFileDescriptor())) {
      byte[] buffer = new byte[256];
      int n;
      while ((n = in.read(buffer)) != -1 && text.length() < 200) {
        text.append(new String(buffer, 0, n, java.nio.charset.StandardCharsets.US_ASCII));
      }
    } catch (IOException e) {
      return "?";
    } finally {
      try {
        pfd.close();
      } catch (IOException ignored) {
        // Closed already.
      }
    }
    return text.toString().trim().replace('\n', ' ');
  }

  private static void net(Instrumentation instrumentation, boolean on) {
    shell(instrumentation, "cmd connectivity airplane-mode " + (on ? "disable" : "enable"));
    shell(instrumentation, "svc wifi " + (on ? "enable" : "disable"));
    shell(instrumentation, "svc data " + (on ? "enable" : "disable"));
    netOffSince = on ? 0 : SystemClock.elapsedRealtime();
  }

  private static void location(Instrumentation instrumentation, boolean on) {
    shell(instrumentation, "cmd location set-location-enabled " + on);
    shell(instrumentation, "settings put secure location_mode " + (on ? "3" : "0"));
  }

  /** Runs a new word from [controlFile] (see prepare()); unknown words are ignored. */
  private static void readControl(Instrumentation instrumentation) {
    if (netOffSince != 0 && SystemClock.elapsedRealtime() - netOffSince > NET_OFF_MAX_MS) {
      Log.w(TAG, "network off too long: put back on");
      net(instrumentation, true);
    }
    File file = controlFile;
    if (file == null || !file.exists()) return;
    long stamp = file.lastModified() ^ file.length();
    if (stamp == controlStamp) return;
    controlStamp = stamp;
    byte[] buffer = new byte[32];
    int n;
    try (InputStream in = new FileInputStream(file)) {
      n = in.read(buffer);
    } catch (IOException e) {
      return;
    }
    if (n <= 0) return;
    String word = new String(buffer, 0, n, java.nio.charset.StandardCharsets.US_ASCII).trim();
    int hash = word.indexOf('#');
    if (hash >= 0) word = word.substring(0, hash);
    switch (word) {
      case "location-off": location(instrumentation, false); break;
      case "location-on": location(instrumentation, true); break;
      case "net-off": net(instrumentation, false); break;
      case "net-on": net(instrumentation, true); break;
      // Device proof 2026-11-20 (M1, M4): the app really to the background
      // and back, the offer notices in the phone's list, the top screen.
      case "home":
        shell(instrumentation, "input keyevent KEYCODE_HOME");
        break;
      case "front":
        shell(instrumentation, "am start -n se.movera.driver/.MainActivity");
        break;
      case "notif":
      case "top":
        break;
      default: return;
    }
    String state;
    if (word.equals("notif")) {
      state = word + " " + offerNotices(instrumentation);
    } else if (word.equals("home") || word.equals("front") || word.equals("top")) {
      SystemClock.sleep(1500);
      String[] top = topAndTel(instrumentation);
      state = word + " top=" + top[0] + " telact=" + top[1];
      if (word.equals("top")) state += " dialer=" + dialHandler(instrumentation);
    } else {
      SystemClock.sleep(1500);
      state = locationState(instrumentation, word);
    }
    Log.i(TAG, "control " + state);
    File ack = new File(file.getAbsolutePath() + ".ack");
    try (java.io.FileOutputStream outStream = new java.io.FileOutputStream(ack)) {
      outStream.write(state.getBytes(java.nio.charset.StandardCharsets.US_ASCII));
    } catch (IOException e) {
      Log.w(TAG, "control ack: " + e.getClass().getSimpleName());
    }
  }

  /** The whole output of a shell command (at most [max] bytes), for dumpsys. */
  private static String shellAll(Instrumentation instrumentation, String command, int max) {
    ParcelFileDescriptor pfd = instrumentation.getUiAutomation().executeShellCommand(command);
    java.io.ByteArrayOutputStream text = new java.io.ByteArrayOutputStream();
    try (InputStream in = new FileInputStream(pfd.getFileDescriptor())) {
      byte[] buffer = new byte[8192];
      int n;
      while ((n = in.read(buffer)) != -1) {
        if (text.size() < max) text.write(buffer, 0, Math.min(n, max - text.size()));
      }
    } catch (IOException e) {
      return "";
    } finally {
      try {
        pfd.close();
      } catch (IOException ignored) {
        // Closed already.
      }
    }
    return new String(text.toByteArray(), java.nio.charset.StandardCharsets.UTF_8);
  }

  /**
   * Posted notices of this app on the offer channels (movera_offers*):
   * "offers=N keys=id:when,..." (notification ids and post times only).
   */
  private static String offerNotices(Instrumentation instrumentation) {
    String dump = shellAll(instrumentation, "dumpsys notification --noredact", 4 << 20);
    java.util.regex.Pattern idP = java.util.regex.Pattern.compile(" id=(-?\\d+)");
    java.util.regex.Pattern whenP = java.util.regex.Pattern.compile("when=(\\d+)");
    int count = 0;
    StringBuilder keys = new StringBuilder();
    for (String line : dump.split("\n")) {
      if (line.contains("NotificationRecord(")
          && line.contains("pkg=se.movera.driver")
          && line.contains("channel=movera_offers")) {
        count++;
        java.util.regex.Matcher id = idP.matcher(line);
        java.util.regex.Matcher when = whenP.matcher(line);
        if (keys.length() > 0) keys.append(',');
        keys.append(id.find() ? id.group(1) : "?")
            .append(':')
            .append(when.find() ? when.group(1) : "?");
      }
    }
    return "offers=" + count + " keys=" + (keys.length() == 0 ? "-" : keys.toString());
  }

  /** The package that handles ACTION_DIAL tel: on this phone ("none": no dialer). */
  private static String dialHandler(Instrumentation instrumentation) {
    String out =
        shellAll(
            instrumentation,
            "cmd package resolve-activity --brief -a android.intent.action.DIAL -d tel:112",
            4096);
    java.util.regex.Pattern comp = java.util.regex.Pattern.compile("^([A-Za-z0-9_.]+)/");
    String pkg = "none";
    for (String line : out.split("\n")) {
      java.util.regex.Matcher m = comp.matcher(line.trim());
      if (m.find()) pkg = m.group(1);
    }
    return pkg;
  }

  /**
   * The resumed activity (component) and the action of the newest activity
   * intent with a tel: uri ("none" when none). Names only: no number.
   */
  private static String[] topAndTel(Instrumentation instrumentation) {
    String dump = shellAll(instrumentation, "dumpsys activity activities", 4 << 20);
    String top = "?";
    String tel = "none";
    java.util.regex.Pattern component =
        java.util.regex.Pattern.compile("([A-Za-z0-9_.]+/[A-Za-z0-9_.$]+)");
    java.util.regex.Pattern act =
        java.util.regex.Pattern.compile("act=([A-Za-z0-9_.]+)[^}]*dat=tel:");
    for (String line : dump.split("\n")) {
      if (top.equals("?")
          && (line.contains("topResumedActivity") || line.contains("mResumedActivity"))) {
        java.util.regex.Matcher m = component.matcher(line);
        if (m.find()) top = m.group(1);
      }
      if (tel.equals("none")) {
        java.util.regex.Matcher m = act.matcher(line);
        if (m.find()) tel = m.group(1);
      }
    }
    return new String[] {top, tel};
  }

  private static String locationState(Instrumentation instrumentation, String word) {
    return word
            + " location_mode="
            + shellOut(instrumentation, "settings get secure location_mode")
            + " location="
            + shellOut(instrumentation, "cmd location is-location-enabled")
            + " airplane="
            + shellOut(instrumentation, "settings get global airplane_mode_on");
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

  // Where the mock fixes go now; moved by the Dart test through targetFile.
  // No initializers: prepare() runs from the static block above, before
  // field initializers further down, and an initializer here would reset
  // what it set.
  private static volatile double targetLat;

  private static volatile double targetLng;

  private static File targetFile;

  private static long targetStamp;

  /** Speed of the mock fixes in m/s (third value in the target file, default 0 = standing). */
  private static volatile float targetSpeed;

  /** Reads a new "lat,lng" from [targetFile] when it changed; bad text is ignored. */
  private static void readTarget() {
    File file = targetFile;
    if (file == null || !file.exists()) return;
    long stamp = file.lastModified() ^ file.length();
    if (stamp == targetStamp) return;
    targetStamp = stamp;
    byte[] buffer = new byte[64];
    int n;
    try (InputStream in = new FileInputStream(file)) {
      n = in.read(buffer);
    } catch (IOException e) {
      return;
    }
    if (n <= 0) return;
    String[] parts = new String(buffer, 0, n, java.nio.charset.StandardCharsets.US_ASCII)
        .trim().split(",");
    if (parts.length != 2 && parts.length != 3) return;
    float speed = 0f;
    if (parts.length == 3) {
      double parsed = parse(parts[2], Double.NaN);
      if (Double.isNaN(parsed) || parsed < 0 || parsed > 60) return;
      speed = (float) parsed;
    }
    double lat = parse(parts[0], Double.NaN);
    double lng = parse(parts[1], Double.NaN);
    if (Double.isNaN(lat) || Double.isNaN(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) {
      return;
    }
    targetLat = lat;
    targetLng = lng;
    targetSpeed = speed;
    // Coordinates are not personal data; logged so a run shows the moves.
    Log.i(TAG, "mock target moved");
  }

  private static void startMockLocation(Instrumentation instrumentation, Context app) {
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
                readControl(instrumentation);
                readTarget();
                final double lat = targetLat;
                final double lng = targetLng;
                for (String provider : providers) {
                  try {
                    manager.setTestProviderLocation(provider, fix(provider, lat, lng));
                  } catch (RuntimeException e) {
                    // Provider gone (test ending).
                  }
                }
                if (fused != null) {
                  try {
                    Method set =
                        Class.forName(FUSED_CLIENT).getMethod("setMockLocation", Location.class);
                    set.invoke(fused, fix("fused", lat, lng));
                  } catch (Exception e) {
                    // Play services refused one fix; the next second tries again.
                  }
                }
                round++;
                SystemClock.sleep(1000);
              }
            },
            "movera-tl-mock-location");
    feeder.setDaemon(true);
    feeder.start();
  }

  private static final String FUSED_CLIENT =
      "com.google.android.gms.location.FusedLocationProviderClient";

  /** Google Play services' fused provider in mock mode, without a compile dependency. */
  private static Object fusedClient(Context app) {
    try {
      Class<?> services = Class.forName("com.google.android.gms.location.LocationServices");
      Object client =
          services.getMethod("getFusedLocationProviderClient", Context.class).invoke(null, app);
      // Look the methods up on the public interface: the implementation class
      // may not be public, and invoking through it would throw
      // IllegalAccessException (fused mocking silently off).
      Class.forName(FUSED_CLIENT).getMethod("setMockMode", boolean.class).invoke(client, true);
      return client;
    } catch (Exception e) {
      Log.w(TAG, "fused mock: " + e.getClass().getSimpleName());
      return null;
    }
  }

  /** About 10 m in degrees of latitude (1 degree is about 111 km). */
  private static final double JITTER_DEG = 10.0 / 111_000.0;

  private static final Random JITTER = new Random();

  /** Feeder rounds so far (one per second); picks the jitter side. */
  private static volatile int round = 0;

  private static Location fix(String provider, double lat, double lng) {
    Location location = new Location(provider);
    // +/-10 m jitter, north and south of the point in turn (5-10 m each
    // way, so two rounds are >= 10 m apart): the app's 8 m distance filter
    // sees movement, and a G24 FAIL cannot come from a stationary mock.
    double side = (round % 2 == 0) ? 1 : -1;
    location.setLatitude(lat + side * (0.5 + 0.5 * JITTER.nextDouble()) * JITTER_DEG);
    location.setLongitude(
        lng + (JITTER.nextDouble() * 2 - 1) * JITTER_DEG / Math.cos(Math.toRadians(lat)));
    location.setAccuracy(5f);
    location.setAltitude(20);
    location.setSpeed(targetSpeed);
    location.setBearing(targetSpeed > 0 ? 90f : 0f);
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
