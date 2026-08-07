// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer;

import android.content.Context;
import androidx.annotation.NonNull;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.DefaultRenderersFactory;
import androidx.media3.exoplayer.audio.AudioSink;
import androidx.media3.exoplayer.audio.DefaultAudioSink;

/**
 * A {@link DefaultRenderersFactory} that injects a {@link GainAudioProcessor}
 * into the audio sink so playback can be boosted above the source level. Keeps
 * the decoder-fallback behavior the TV build relies on for stable playback.
 */
public final class GainRenderersFactory extends DefaultRenderersFactory {

  @UnstableApi
  public GainRenderersFactory(@NonNull Context context) {
    super(context);
    setEnableDecoderFallback(true);
  }

  @UnstableApi
  @NonNull
  @Override
  protected AudioSink buildAudioSink(
      @NonNull Context context,
      boolean enableFloatOutput,
      boolean enableAudioTrackPlaybackParams) {
    return new DefaultAudioSink.Builder(context)
        .setEnableFloatOutput(enableFloatOutput)
        .setEnableAudioTrackPlaybackParams(enableAudioTrackPlaybackParams)
        .setAudioProcessors(new GainAudioProcessor[] {new GainAudioProcessor()})
        .build();
  }
}
