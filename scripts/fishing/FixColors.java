import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.awt.image.DataBufferByte;
import java.io.File;
import java.util.*;

public class FixColors {
    record Info (int pixel, int slope, int depth, int substrate, int color, String info) {}
    static Info[] infos = new Info[256];
    static {
        Info src[] = {
            // zone 2 = intertidal ~ 30m
            new Info( 1,   1, 2, 1, 0x91b694, "Fine to medium grained smooth sediment"),
            new Info( 2,   1, 2, 2, 0xc1c694, "Mixed smooth sediment and rock"),
            new Info( 3,   1, 2, 3, 0xb77f83, "Rock and boulders, rugose"),
            new Info( 4,   1, 2, 4, 0xad955b, "Medium to coarse grained, rippled sediment"),

            // zone 3 = 30m ~ 100m
            new Info(11,   1, 3, 1, 0x538563, "Fine to medium grained smooth sediment"),
            new Info(12,   1, 3, 2, 0xbdb285, "Mixed smooth sediment and rock"),
            new Info(13,   1, 3, 3, 0x8c4c54, "Rock and boulders, rugose"),
            new Info(14,   1, 3, 4, 0xcdca12, "Medium to coarse grained, rippled sediment"),

            // zone 4 = 100m ~ 200m
            new Info(21,   1, 4, 1, 0x38794d, "Fine to medium grained smooth sediment"),
            new Info(22,   1, 4, 2, 0xaa9b51, "Mixed smooth sediment and rock"),
            new Info(23,   1, 4, 3, 0x762933, "Rock and boulders, rugose"),
            new Info(24,   1, 4, 4, 0x97950d, "Medium to coarse grained, rippled sediment"),

            // zone 5 > 200m
            new Info(31,   1, 5, 1, 0x196230, "Fine to medium grained smooth sediment"),
            new Info(32,   1, 5, 2, 0x75662b, "Mixed smooth sediment and rock"),
            new Info(33,   1, 5, 3, 0x711520, "Rock and boulders, rugose"),
            new Info(34,   1, 5, 4, 0xcdca12, "Medium to coarse grained, rippled sediment"),

            // What is this zone???
            new Info(41,   1, 6, 1, 0x538563, "Fine to medium grained smooth sediment"), // << need fix
            new Info(42,   1, 6, 2, 0xbdb285, "Mixed smooth sediment and rock"), // << need fix
            new Info(43,   1, 6, 3, 0x8c4c54, "Rock and boulders, rugose"), // << need fix
            new Info(44,   1, 6, 4, 0xcdca12, "Medium to coarse grained, rippled sediment"), // << need fix
        };
        for (Info i : src) {
            infos[i.pixel] = i;
        }
    };

    public static void main(String[] args) throws Exception {
        if (args.length != 2) {
            System.err.println("Usage: java FixColors input.tif output.png");
            System.exit(1);
        }

        // Read the input TIFF.
        BufferedImage inputImage = ImageIO.read(new File(args[0]));
        if (inputImage == null) {
            throw new IllegalArgumentException("Unable to read input image: " + args[0]);
        }

        int width = inputImage.getWidth();
        int height = inputImage.getHeight();

        // Require an 8-bit grayscale input image.
        if (inputImage.getRaster().getNumBands() != 1
                || inputImage.getRaster().getDataBuffer().getDataType()
                   != java.awt.image.DataBuffer.TYPE_BYTE) {
            throw new IllegalArgumentException(
                    "Input must be an 8-bit, single-band TIFF");
        }

        // Get the input pixel buffer.
        byte[] inputPixels =
                ((DataBufferByte) inputImage.getRaster().getDataBuffer()).getData();

        // 32-bit RGBA output buffer.
        BufferedImage outputImage =
                new BufferedImage(width, height, BufferedImage.TYPE_4BYTE_ABGR);

        byte[] outputPixels =
                ((DataBufferByte) outputImage.getRaster().getDataBuffer()).getData();

        int notfound[] = new int[256];
        int found[] = new int[256];

        /*
         * TYPE_4BYTE_ABGR stores each pixel as:
         *
         *   A B G R
         *
         * The requested operation is:
         *
         *   output[x][y] = input[x][y] * 256
         *
         * We interpret that 16-bit result as a color value and put its
         * high byte into R/G/B. Alpha is preserved as fully opaque.
         *
         * For an 8-bit input p (0..255):
         *   value = p * 256 = 0xPP00
         *
         * Thus:
         *   R = p
         *   G = 0
         *   B = 0
         *   A = 255
         */
        for (int i = 0; i < width * height; i++) {
            int input = inputPixels[i] & 0xFF;

            input %= 50;

            int r = 0;
            int g = 0;
            int b = 0;
            int a = 0;

            Info info = infos[input];
            int type = input % 10;

            if (info != null) {
                int color = info.color;
                r = color >> 16;
                g = color >> 8;
                b = color >> 0;
                a = 0xff;
                found[type] ++;
            } else if (input != 0) {
                int color;
                switch (type) {
                case 1: color = 0x91b694; break; // Fine to medium grained smooth sediment
                case 2: color = 0xc1c694; break; // Mixed smooth sediment and rock
                case 3: color = 0xb77f83; break; // Rock and boulders, rugose
                case 4: color = 0xad955b; break; // Medium to coarse grained, rippled sediment
                default:color = 0x707070; break; // ???
                }
                r = color >> 16;
                g = color >> 8;
                b = color >> 0;
                a = 0xff;
                found[input] ++;
            } else {
                notfound[input] ++;
            }

            int out = i * 4;

            outputPixels[out]     = (byte) a; // A
            outputPixels[out + 1] = (byte) b; // B
            outputPixels[out + 2] = (byte) g; // G
            outputPixels[out + 3] = (byte) r; // R
        }

        // Write as RGBA PNG.
        ImageIO.write(outputImage, "PNG", new File(args[1]));

        for (int i = 0; i < 256; i++) {
            if (notfound[i] > 0) {
                System.out.format("%3d = %8d\n", i, notfound[i]);
            }
        }
        for (int i = 0; i < 256; i++) {
            if (found[i] > 0) {
                System.out.format("%3d = %8d (found)\n", i, found[i]);
            }
        }
    }
}
