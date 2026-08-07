// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer;

/**
 * Holds the currently requested audio gain (in decibels) applied to every
 * ExoPlayer instance created by this plugin. It is updated from Dart at
 * runtime, and {@link GainAudioProcessor} reads it for each audio buffer, so
 * changes take effect immediately while playing.
 */
public final class VolumeBoost {
  private static volatile float gainDb = 0f;

  private VolumeBoost() {}

  public static float getGainDb() {
    return gainDb;
  }

  public static void setGainDb(float db) {
    gainDb = db;
  }
}
