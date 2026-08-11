// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer.platformview;

import android.content.Context;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;
import androidx.media3.common.MediaItem;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.DefaultLoadControl;
import androidx.media3.exoplayer.ExoPlayer;
import io.flutter.plugins.videoplayer.ExoPlayerEventListener;
import io.flutter.plugins.videoplayer.VideoAsset;
import io.flutter.plugins.videoplayer.VideoPlayer;
import io.flutter.plugins.videoplayer.VideoPlayerCallbacks;
import io.flutter.plugins.videoplayer.VideoPlayerOptions;
import io.flutter.view.TextureRegistry.SurfaceProducer;

/**
 * A subclass of {@link VideoPlayer} that adds functionality related to platform view as a way of
 * displaying the video in the app.
 */
public class PlatformViewVideoPlayer extends VideoPlayer {
  // TODO: Migrate to stable API, see https://github.com/flutter/flutter/issues/147039.
  @UnstableApi
  @VisibleForTesting
  public PlatformViewVideoPlayer(
      @NonNull VideoPlayerCallbacks events,
      @NonNull MediaItem mediaItem,
      @NonNull VideoPlayerOptions options,
      @NonNull ExoPlayerProvider exoPlayerProvider) {
    this(events, mediaItem, options, exoPlayerProvider, null);
  }

  // TODO: Migrate to stable API, see https://github.com/flutter/flutter/issues/147039.
  @UnstableApi
  @VisibleForTesting
  public PlatformViewVideoPlayer(
      @NonNull VideoPlayerCallbacks events,
      @NonNull MediaItem mediaItem,
      @NonNull VideoPlayerOptions options,
      @NonNull ExoPlayerProvider exoPlayerProvider,
      @Nullable Context context) {
    super(events, mediaItem, options, /* surfaceProducer */ null, exoPlayerProvider, context);
  }

  /**
   * Creates a platform view video player.
   *
   * @param context application context.
   * @param events event callbacks.
   * @param asset asset to play.
   * @param options options for playback.
   * @return a video player instance.
   */
  // TODO: Migrate to stable API, see https://github.com/flutter/flutter/issues/147039.
  @UnstableApi
  @NonNull
  public static PlatformViewVideoPlayer create(
      @NonNull Context context,
      @NonNull VideoPlayerCallbacks events,
      @NonNull VideoAsset asset,
      @NonNull VideoPlayerOptions options) {
    return new PlatformViewVideoPlayer(
        events,
        asset.getMediaItem(),
        options,
        () -> {
          androidx.media3.exoplayer.DefaultRenderersFactory renderersFactory =
              new androidx.media3.exoplayer.DefaultRenderersFactory(context);
          renderersFactory.setEnableDecoderFallback(true);
          ExoPlayer.Builder builder = new ExoPlayer.Builder(context, renderersFactory);
          DefaultLoadControl.Builder loadControlBuilder = new DefaultLoadControl.Builder();
          boolean hasLoadControlOptions = false;
          if (options.backBufferDurationMs != null) {
            if (options.backBufferDurationMs < 0) {
              throw new IllegalArgumentException("backBufferDurationMs must be at least 0");
            }
            if (options.backBufferDurationMs > 0) {
              // Clamp the value to ensure it fits within the int range expected by
              // DefaultLoadControl.
              int backBufferInt =
                  (int) Math.min(options.backBufferDurationMs.longValue(), Integer.MAX_VALUE);
              loadControlBuilder.setBackBuffer(
                  backBufferInt, /* retainBackBufferFromKeyframe= */ true);
              hasLoadControlOptions = true;
            }
          }
          if (options.maxBufferDurationMs != null) {
            if (options.maxBufferDurationMs < 0) {
              throw new IllegalArgumentException("maxBufferDurationMs must be at least 0");
            }
            if (options.maxBufferDurationMs > 0) {
              // Let the player buffer far ahead of the current position so slow
              // CDN bursts don't stall playback. This is especially useful for TV
              // devices with slower CPUs where decode + network compete.
              int maxBufferInt =
                  (int) Math.min(options.maxBufferDurationMs.longValue(), Integer.MAX_VALUE);
              int minBufferMs = Math.max(15000, Math.min(25000, maxBufferInt / 4));
              loadControlBuilder
                  .setBufferDurationsMs(
                      minBufferMs,
                      maxBufferInt,
                      DefaultLoadControl.DEFAULT_BUFFER_FOR_PLAYBACK_MS,
                      DefaultLoadControl.DEFAULT_BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS);
              hasLoadControlOptions = true;
            }
          }
          if (hasLoadControlOptions) {
            builder.setLoadControl(loadControlBuilder.build());
          }
          androidx.media3.exoplayer.trackselection.DefaultTrackSelector trackSelector =
              new androidx.media3.exoplayer.trackselection.DefaultTrackSelector(context);
          builder
              .setTrackSelector(trackSelector)
              .setMediaSourceFactory(asset.getMediaSourceFactory(context));
          return builder.build();
        },
        context);
  }

  @NonNull
  @Override
  protected ExoPlayerEventListener createExoPlayerEventListener(
      @NonNull ExoPlayer exoPlayer, @Nullable SurfaceProducer surfaceProducer) {
    return new PlatformViewExoPlayerEventListener(exoPlayer, videoPlayerEvents);
  }
}
