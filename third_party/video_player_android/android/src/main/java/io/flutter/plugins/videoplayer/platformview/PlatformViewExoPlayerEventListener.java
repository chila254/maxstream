// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer.platformview;

import androidx.annotation.NonNull;
import androidx.annotation.OptIn;
import androidx.media3.common.Format;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.ExoPlayer;
import io.flutter.plugins.videoplayer.ExoPlayerEventListener;
import io.flutter.plugins.videoplayer.VideoPlayerCallbacks;

public final class PlatformViewExoPlayerEventListener extends ExoPlayerEventListener {
  public PlatformViewExoPlayerEventListener(
      @NonNull ExoPlayer exoPlayer, @NonNull VideoPlayerCallbacks events) {
    super(exoPlayer, events);
  }

  @OptIn(markerClass = UnstableApi.class)
  @Override
  protected void sendInitialized() {
    // The video format can be null or incomplete when READY is reached while a
    // stream is still resolving (e.g. during server switches or a dead HLS
    // playlist). Never crash on that: report a zero-size video instead, and
    // correct the dimensions again on the next event.
    Format videoFormat = exoPlayer.getVideoFormat();
    int width = 0;
    int height = 0;
    int rotationDegrees = 0;
    if (videoFormat != null && videoFormat.width > 0 && videoFormat.height > 0) {
      RotationDegrees rotationCorrection = RotationDegrees.ROTATE_0;
      try {
        rotationCorrection = RotationDegrees.fromDegrees(videoFormat.rotationDegrees);
      } catch (IllegalArgumentException e) {
        // A rotation value other than 0/90/180/270 is unexpected; apply none.
        rotationCorrection = RotationDegrees.ROTATE_0;
      }
      width = videoFormat.width;
      height = videoFormat.height;

      // Switch the width/height if video was taken in portrait mode and a rotation
      // correction was detected.
      if (rotationCorrection == RotationDegrees.ROTATE_90
          || rotationCorrection == RotationDegrees.ROTATE_270) {
        width = videoFormat.height;
        height = videoFormat.width;

        rotationCorrection = RotationDegrees.fromDegrees(0);
      }
      rotationDegrees = rotationCorrection.getDegrees();
    }

    events.onInitialized(width, height, exoPlayer.getDuration(), rotationDegrees);
  }
}
