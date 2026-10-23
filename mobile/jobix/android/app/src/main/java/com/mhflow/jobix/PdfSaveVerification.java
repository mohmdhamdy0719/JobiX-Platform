package com.mhflow.jobix;

import java.io.IOException;
import java.io.InputStream;

/** Pure verification logic; never stores or logs a URI or document contents. */
public final class PdfSaveVerification {
    private PdfSaveVerification() {}

    public interface ReadBack {
        InputStream open() throws IOException;
    }

    public static Long verifiedSize(Long metadata, byte[] expected, ReadBack source) {
        if (metadata != null && metadata > 0 && metadata == expected.length) return metadata;
        // A known positive mismatch must survive an unavailable read-back.
        Long fallback = metadata != null && metadata > 0 ? metadata : null;
        final InputStream opened;
        try {
            opened = source.open();
        } catch (IOException | SecurityException unavailable) {
            return fallback;
        }
        if (opened == null) return fallback;
        try (InputStream input = opened) {
            byte[] buffer = new byte[8192];
            long count = 0;
            int length;
            while ((length = input.read(buffer)) != -1) {
                for (int i = 0; i < length; i++) {
                    if (count + i >= expected.length ||
                            buffer[i] != expected[(int) count + i]) return -1L;
                }
                count += length;
            }
            return count;
        } catch (IOException | SecurityException failedVerification) {
            // A stream that opened but failed to read/close is not merely
            // unavailable metadata. Do not turn failed verification into success.
            return -1L;
        }
    }

    public static boolean completeWrite(long expected, Long written, boolean opened,
            boolean completed, boolean closed, Long verifiedSize) {
        // Unknown metadata alone is not success: all direct write/close evidence
        // must be present and exact. A read-back or positive size mismatch fails.
        return expected > 0 && written != null && written == expected &&
                opened && completed && closed &&
                (verifiedSize == null || verifiedSize == expected);
    }
}
