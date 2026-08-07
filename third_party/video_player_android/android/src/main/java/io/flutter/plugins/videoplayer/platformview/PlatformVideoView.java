// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer.platformview;

import android.content.Context;
import android.os.Build;
import android.view.Surface;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import androidx.annotation.NonNull;
import androidx.annotation.OptIn;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.ExoPlayer;
import io.flutter.plugin.platform.PlatformView;

/**
 * A class used to create a native video view that can be embedded in a Flutter app. It wraps an
 * {@link ExoPlayer} instance and displays its video content.
 */
public final class PlatformVideoView implements PlatformView {
  @NonNull private final SurfaceView surfaceView;
  private boolean disposed = false;

  /**
   * Constructs a new PlatformVideoView.
   *
   * @param context The context in which the view is running.
   * @param exoPlayer The ExoPlayer instance used to play the video.
   */
  @OptIn(markerClass = UnstableApi.class)
  public PlatformVideoView(@NonNull Context context, @NonNull ExoPlayer exoPlayer) {
    this.surfaceView = new VideoSurfaceView(context, exoPlayer);

    setupSurfaceWithCallback(exoPlayer);

    if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.N_MR1) {
      // Avoid blank space instead of a video on Android versions below 8 by adjusting video's
      // z-layer within the Android view hierarchy:
      surfaceView.setZOrderMediaOverlay(true);
    }
  }

  private void setupSurfaceWithCallback(@NonNull ExoPlayer exoPlayer) {
    surfaceView
        .getHolder()
        .addCallback(
            new SurfaceHolder.Callback() {
              @Override
              public void surfaceCreated(@NonNull SurfaceHolder holder) {
                // The surface may be created after the Dart-side controller was
                // disposed (e.g. while a route with the player is still animating
                // out during a server switch), so the player may already be
                // released. Never crash on that.
                if (disposed) {
                  return;
                }
                try {
                  bindPlayerToSurface(exoPlayer, holder.getSurface());
                  forceFirstFrameForAndroid9(exoPlayer);
                } catch (IllegalStateException e) {
                  // The player has been released; there is nothing to bind.
                } catch (RuntimeException e) {
                  // Some devices throw during surface teardown; ignore rather than crash.
                }
              }

              @Override
              public void surfaceChanged(
                  @NonNull SurfaceHolder holder, int format, int width, int height) {}

              @Override
              public void surfaceDestroyed(@NonNull SurfaceHolder holder) {
                // Use clearVideoSurface to ensure we only unbind if this surface is currently
                // active.
                if (disposed) {
                  return;
                }
                Surface surface = holder.getSurface();
                if (surface == null || !surface.isValid()) {
                  return;
                }
                try {
                  exoPlayer.clearVideoSurface(surface);
                } catch (IllegalStateException e) {
                  // The player may already be released if the Flutter engine disposes the
                  // platform view after the Dart-side controller.dispose() released it.
                  // Ignore, as there is nothing left to unbind.
                }
              }
            });
  }

  /** Binds the ExoPlayer to the provided surface. */
  static void bindPlayerToSurface(@NonNull ExoPlayer exoPlayer, @NonNull Surface surface) {
    if (surface.isValid()) {
      exoPlayer.setVideoSurface(surface);
    }
  }

  /**
   * Workaround for a rendering bug on Android 9 (API 28) where the decoder does not flush its
   * output buffer when a new surface is attached while the player is paused.
   */
  static void forceFirstFrameForAndroid9(@NonNull ExoPlayer exoPlayer) {
    if (Build.VERSION.SDK_INT == Build.VERSION_CODES.P && !exoPlayer.getPlayWhenReady()) {
      long position = exoPlayer.getCurrentPosition();
      exoPlayer.seekTo(position == 0 ? 1 : position);
    }
  }

  /**
   * A custom SurfaceView that re-attaches the player surface when the view becomes visible again,
   * such as after returning from a full-screen route transition.
   */
  private static class VideoSurfaceView extends SurfaceView {
    private final ExoPlayer exoPlayer;

    public VideoSurfaceView(Context context, ExoPlayer exoPlayer) {
      super(context);
      this.exoPlayer = exoPlayer;
    }

    @Override
    protected void onVisibilityChanged(@NonNull View changedView, int visibility) {
      super.onVisibilityChanged(changedView, visibility);
      // When the view becomes visible again, re-attach the current surface.
      if (visibility == View.VISIBLE && isShown()) {
        Surface surface = getHolder().getSurface();
        if (surface == null || !surface.isValid()) {
          return;
        }
        try {
          bindPlayerToSurface(exoPlayer, surface);
        } catch (IllegalStateException e) {
          // The player may already be released while this view is being torn down.
        }
      }
    }
  }

  /**
   * Returns the view associated with this PlatformView.
   *
   * @return The SurfaceView used to display the video.
   */
  @NonNull
  @Override
  public View getView() {
    return surfaceView;
  }

  /** Disposes of the resources used by this PlatformView. */
  @Override
  public void dispose() {
    disposed = true;
    Surface surface = surfaceView.getHolder().getSurface();
    if (surface == null || !surface.isValid()) {
      return;
    }
    try {
      surface.release();
    } catch (RuntimeException e) {
      // The surface may have already been released by the engine during teardown.
      // Ignore, as the surface is no longer usable.
    }
  }
}
