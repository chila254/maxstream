// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer;

import static androidx.media3.common.C.ENCODING_PCM_16BIT;
import static androidx.media3.common.C.ENCODING_PCM_FLOAT;

import androidx.annotation.NonNull;
import androidx.media3.common.Format;
import androidx.media3.common.audio.BaseAudioProcessor;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.common.util.Util;
import java.nio.ByteBuffer;
import java.nio.FloatBuffer;
import java.nio.ShortBuffer;

/**
 * Scales PCM audio by the gain requested through {@link VolumeBoost}. Only
 * active for PCM input (16-bit or float); every other format passes through
 * untouched. Because the gain is read per buffer, changing it while playing
 * applies instantly without recreating the player.
 */
public final class GainAudioProcessor extends BaseAudioProcessor {
  private int sampleRate = Format.NO_VALUE;
  private int channelCount = Format.NO_VALUE;
  private int encoding = Format.NO_VALUE;

  private boolean isSupportedEncoding() {
    return encoding == ENCODING_PCM_16BIT || encoding == ENCODING_PCM_FLOAT;
  }

  @UnstableApi
  @NonNull
  @Override
  public AudioFormat onConfigure(@NonNull AudioFormat inputAudioFormat) {
    sampleRate = inputAudioFormat.sampleRate;
    channelCount = inputAudioFormat.channelCount;
    encoding = inputAudioFormat.encoding;
    return inputAudioFormat;
  }

  @UnstableApi
  @Override
  public boolean isActive() {
    // Only apply the gain once a valid PCM format is configured; a missing
    // sample rate or channel count would otherwise produce a bogus frame size.
    return isSupportedEncoding()
        && sampleRate != Format.NO_VALUE
        && channelCount > 0
        && Math.abs(VolumeBoost.getGainDb()) > 1e-3f;
  }

  @UnstableApi
  @Override
  public void queueInput(@NonNull ByteBuffer inputBuffer) {
    if (!isSupportedEncoding()) {
      return;
    }
    int position = inputBuffer.position();
    int limit = inputBuffer.limit();
    int frameSize = Util.getPcmFrameSize(encoding, channelCount);
    if (frameSize <= 0) {
      // Invalid frame size; consume the chunk so the sink does not re-feed it.
      inputBuffer.position(limit);
      return;
    }
    int frameCount = (limit - position) / frameSize;
    if (frameCount == 0) {
      inputBuffer.position(limit);
      return;
    }
    final float scale = (float) Math.pow(10.0, VolumeBoost.getGainDb() / 20.0);
    ByteBuffer output = replaceOutputBuffer(frameSize * frameCount);
    output.order(inputBuffer.order());
    if (encoding == ENCODING_PCM_16BIT) {
      ShortBuffer in = inputBuffer.asShortBuffer();
      ShortBuffer out = output.asShortBuffer();
      for (int i = 0; i < frameCount * channelCount; i++) {
        int scaled = (int) (in.get() * scale);
        out.put((short) Math.max(-32768, Math.min(32767, scaled)));
      }
    } else {
      FloatBuffer in = inputBuffer.asFloatBuffer();
      FloatBuffer out = output.asFloatBuffer();
      for (int i = 0; i < frameCount * channelCount; i++) {
        out.put(in.get() * scale);
      }
    }
    output.position(0);
    output.limit(frameSize * frameCount);
    // The sink keeps re-feeding a buffer while it still has remaining input, so
    // the whole chunk must be marked consumed. Otherwise the same data is
    // processed over and over, which comes out as a continuous buzz.
    inputBuffer.position(limit);
  }
}
