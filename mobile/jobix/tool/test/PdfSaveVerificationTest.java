import com.mhflow.jobix.PdfSaveVerification;
import java.io.ByteArrayInputStream;
import java.io.IOException;

/** Dependency-free JVM regression checks, without an Android device or network. */
public final class PdfSaveVerificationTest {
    public static void main(String[] args) {
        byte[] pdf = "%PDF-synthetic".getBytes(java.nio.charset.StandardCharsets.US_ASCII);
        check(PdfSaveVerification.verifiedSize(0L, pdf,
                () -> new ByteArrayInputStream(pdf)) == pdf.length, "zero metadata read-back");
        check(PdfSaveVerification.verifiedSize(null, pdf,
                () -> new ByteArrayInputStream(pdf)) == pdf.length, "missing metadata read-back");
        check(PdfSaveVerification.verifiedSize(1L, pdf,
                () -> new ByteArrayInputStream(pdf)) == pdf.length, "stale positive metadata");
        check(PdfSaveVerification.verifiedSize(0L, pdf,
                () -> new ByteArrayInputStream(new byte[0])) == 0, "empty destination");
        check(PdfSaveVerification.verifiedSize(0L, pdf,
                () -> new ByteArrayInputStream(java.util.Arrays.copyOf(pdf, pdf.length - 1)))
                == pdf.length - 1, "partial read-back");
        check(PdfSaveVerification.verifiedSize(0L, pdf,
                () -> new ByteArrayInputStream(new byte[pdf.length])) == -1, "corrupt destination");
        Long unknown = PdfSaveVerification.verifiedSize(0L, pdf,
                () -> { throw new IOException("unavailable"); });
        check(unknown == null, "zero metadata is unavailable, not a measured size");
        check(PdfSaveVerification.completeWrite(pdf.length, (long) pdf.length,
                true, true, true, unknown), "exact closed stream evidence");
        check(!PdfSaveVerification.completeWrite(pdf.length, 1L,
                true, true, true, null), "partial write");
        check(!PdfSaveVerification.completeWrite(pdf.length, (long) pdf.length,
                true, true, false, null), "failed close");
        check(!PdfSaveVerification.completeWrite(pdf.length, (long) pdf.length,
                true, true, true, 0L), "actual empty read-back");
        check(PdfSaveVerification.verifiedSize(1L, pdf,
                () -> { throw new IOException("unavailable"); }) == 1, "retain positive mismatch");
        check(PdfSaveVerification.verifiedSize(0L, pdf,
                () -> new java.io.InputStream() {
                    public int read() throws IOException { throw new IOException("read failed"); }
                }) == -1, "read-back failure is not unavailable metadata");
        check(PdfSaveVerification.verifiedSize(0L, pdf,
                () -> new ByteArrayInputStream(pdf) {
                    public void close() throws IOException { throw new IOException("close failed"); }
                }) == -1, "read-back close failure");
        System.out.println("PASS: 14 PDF save verification checks");
    }

    private static void check(boolean value, String name) {
        if (!value) throw new AssertionError(name);
    }
}
