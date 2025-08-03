package io.flutter.app;

import android.app.Application;
import android.content.Context;
import io.flutter.view.FlutterMain;

/**
 * Flutter implementation of {@link android.app.Application}, managing
 * application-level global initializations.
 */
public class FlutterApplication extends Application {
  @Override
  public void onCreate() {
    super.onCreate();
    FlutterMain.startInitialization(this);
  }

  private static FlutterApplication application;

  public static FlutterApplication getInstance() {
    return application;
  }

  @Override
  protected void attachBaseContext(Context base) {
    super.attachBaseContext(base);
    application = this;
  }
}
