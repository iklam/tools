package com.example.springboot;

import java.io.*;
import java.net.*;
import java.nio.*;
import java.nio.channels.FileChannel;
import java.nio.charset.StandardCharsets;
import java.nio.file.attribute.FileTime;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.net.URI;
import java.net.URLDecoder;
import java.net.URLEncoder;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Base64;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.zip.CRC32;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;
import java.util.zip.ZipOutputStream;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;

//import java.io.*;
//import java.nio.*;
//import java.nio.file.*;
import java.security.*;
import java.security.spec.*;
import javax.crypto.*;
import javax.crypto.spec.*;


@RestController
public class HelloController {
    static {
        System.out.println("token = " + Util.token);
        System.out.println("key   = " + Crypto.secretKey);
    }
    @GetMapping("/")
    public String index() {
        return "Greetings from Spring Boot!\n";
    }

    // Client does this before uploading a directory to the server
    // - Client posts its own directory listing to the server
    // - Server deletes the files that are in server only
    // - Server returns a list of files that the client needs to upload
    //
    // - encoding - the POST data must start with a single dir=<dir>, followed by zero or more file=
    // dir=<dir>&
    // file=<file>&cksum=<cksum>
    @RequestMapping(path = "/diffup", method = RequestMethod.POST)
    public String diffup(@RequestBody String request) throws Exception {
        try {
            ChecksumRequest cksumReq = new ChecksumRequest(request);
            HashSet<String> clientFiles = new HashSet<>();
            File baseDir = new File(cksumReq.dir);

            StringBuilder result = new StringBuilder();
            result.append("status=ok");

            for (FileInfo fi : cksumReq.files) {
                clientFiles.add(fi.file);
                if (isOutdated(baseDir, fi)) {
                    result.append("&upload=" + Util.encode(fi.file));
                }
            }

            // FIXME -- we also need to delete directories on server that don't exist on client
            // but the client needs to upload its list of empty directories.
            int skipDir = cksumReq.dir.length() + 1;
            serverSideDelete(baseDir, skipDir, clientFiles);

            return Crypto.encrypt(result.toString());
        } catch (Throwable t) {
            t.printStackTrace();
            return Crypto.encrypt("error=" +  URLEncoder.encode(t.toString()));
        }
    }

    private static boolean isOutdated(File baseDir, FileInfo fi) throws IOException {
        File f = new File(baseDir, fi.file);
        boolean upload = false;
        if (!f.exists()) {
            return true;
        } else if (!f.isFile()) {
            System.out.println("===== delete " + fi.file);
            Util.deleteDirectory(f);
            return true;
        } else {
            long crc = Util.crc32(f.getPath());
            if (crc != fi.cksum) {
                return true;
            }
        }
        return false;
    }

    static void serverSideDelete(File file, int skipDir, HashSet<String> clientFiles) {
        if (file.isFile()) {
            String fileName = file.toString().substring(skipDir);
            if (!clientFiles.contains(fileName)) {
                System.out.println("===== delete " + fileName);
                file.delete();
            }
        } else if (file.isDirectory()) {
            File[] files = file.listFiles();
            Arrays.sort(files);
            for (File f : files) {
                serverSideDelete(f, skipDir, clientFiles);
            }
        }
    }

    // Client does this after calling /diffup. It posts a list of files and their contents
    //
    // encoding - the POST data must start with a single dir=<dir>, followed by zero or more file=
    // dir=<dir>&
    // file=<file>&date=<date>&set=<initial_data>
    // file=<file>&date=<date>&append=<extra_data>
    //
    // Each POST is limited to no more than 1MB of data
    @RequestMapping(path = "/up", method = RequestMethod.POST)
    public String up(@RequestBody String request) throws Exception {
        UploadRequest req = new UploadRequest(request);
        File baseDir = new File(req.dir);

        for (FileInfo fi : req.files) {
            serverSideUpdateFile(baseDir, fi);
        }

        return Crypto.encrypt("ok");
    }

    static void serverSideUpdateFile(File baseDir, FileInfo fi) throws Exception {
        File f = new File(baseDir, fi.file);
        Util.prepareDirectoryFor(f);
        boolean append = fi.offset > 0;
        try (FileOutputStream fos = new FileOutputStream(f, append)) {
            byte[] data = Base64.getDecoder().decode(fi.data);
	    System.out.println("Updating: " + f + "@" + fi.offset + "[" + data.length + "]");
            fos.write(data);
        }
        f.setLastModified(fi.modTime);
    }


    // Client does this before downloading a directory from the server
    // - Client posts its own directory listing to the server
    // - Server returns the list of files that the client needs to update or delete
    //    - The response is a JAR file
    //    - a special file .delete.txt lists all the files that need to be deleted.
    @RequestMapping(path = "/down", produces = "application/zip", method = RequestMethod.POST)
    public ResponseEntity<byte[]> serverDown(@RequestBody String request) throws Exception {
        byte[] zip = makeDownZipFile(request);

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_PDF); // no APPLICATION_ZIP
        headers.setContentDispositionFormData("attachment", "x.zip");
        zip = Crypto.encrypt(zip);
        headers.setContentLength(zip.length);
        return new ResponseEntity<byte[]>(zip, headers, HttpStatus.OK);
    }

    byte[] makeDownZipFile(String request) throws Exception {
        ChecksumRequest cksumReq = new ChecksumRequest(request);
        HashSet<String> clientFiles = new HashSet<>();
        HashSet<String> deleteFiles = new HashSet<>();
        HashSet<String> downloadFiles = new HashSet<>();
        File baseDir = new File(cksumReq.dir);

        for (FileInfo fi : cksumReq.files) {
            clientFiles.add(fi.file);

            File f = new File(baseDir, fi.file);
            if (!f.exists() || !f.isFile()) {
                deleteFiles.add(fi.file);
                System.out.println("===== deleted        " + fi.file);
            } else {
                long crc = Util.crc32(f.getPath());
                if (crc != fi.cksum) {
                    downloadFiles.add(fi.file);
                    System.out.println("===== download (old) " + fi.file);
                }
            }
        }

        int skipDir = cksumReq.dir.length() + 1;
        collectNewFiles(baseDir, skipDir, clientFiles, downloadFiles);

        File tempFile = File.createTempFile("httpft-", "-zip");
        writeZip(tempFile, baseDir, deleteFiles, downloadFiles);
        byte data[] = Files.readAllBytes(tempFile.toPath());
        tempFile.delete();
        return data;
    }

    // Collect files that are on server but not on client
    static void collectNewFiles(File file, int skipDir, HashSet<String> clientFiles, HashSet<String> downloadFiles) {
        if (file.isFile()) {
            String fileName = file.toString().substring(skipDir);
            if (!clientFiles.contains(fileName)) {
                System.out.println("===== download (new) " + fileName);
                downloadFiles.add(fileName);
            }
        } else if (file.isDirectory()) {
            File[] files = file.listFiles();
            Arrays.sort(files);
            for (File f : files) {
               collectNewFiles(f, skipDir, clientFiles, downloadFiles);
            }
        }
    }

    private static void writeZip(File zipFile, File baseDir, HashSet<String> deleteFiles, HashSet<String> downloadFiles) throws IOException {
        zipFile.delete();
        FileOutputStream fos = new FileOutputStream(zipFile);
        ZipOutputStream zos = new ZipOutputStream(fos);

        try (ByteArrayOutputStream baos = new ByteArrayOutputStream();
             Writer writer = new OutputStreamWriter(baos, "UTF-8"))
        {
             Iterator<String> iter = deleteFiles.iterator();
             while (iter.hasNext()) {
                 writer.write(iter.next() + "\n");
             }
             writer.close();
             byte bytes[] = baos.toByteArray();

             ZipEntry ze = new ZipEntry(".deleted.txt");
             zos.putNextEntry(ze);
             zos.write(bytes);
        }

        {
            Iterator<String> iter = downloadFiles.iterator();
            while (iter.hasNext()) {
                addZipEntry(zos, baseDir, iter.next());
            }
        }

        zos.close();
        fos.close();
    }

    private static void addZipEntry(ZipOutputStream zos, File baseDir, String entryName) throws IOException {
        File f = new File(baseDir, entryName);
        try (InputStream is = new FileInputStream(f)) {
            ZipEntry ze = new ZipEntry(entryName);
            ze.setLastModifiedTime(FileTime.fromMillis(f.lastModified()));
            zos.putNextEntry(ze);
            byte[] buf = new byte[1024];
            int len;
            while ((len = is.read(buf))>0){
                zos.write(buf, 0, len);
            }
        }
    }


    private static HashMap<Integer, Socket> openSockets = new HashMap<>();
    private static ArrayList<Socket> allSockets = new ArrayList<>();
    private static int numSockets = 0;

    // Client calls this first to ask the server to make a socket connection to the
    // specified host/port
    @RequestMapping(path = "/sockopen", method = RequestMethod.POST)
    public String socketOpen(@RequestBody String request) throws Exception {
        SocketOpenRequest req = new SocketOpenRequest(request);
        Socket sock = new Socket(req.host, req.port);

        synchronized (openSockets) {
            int max_concurrent = 2;
            while (allSockets.size() >= max_concurrent) {
                Socket s = allSockets.remove(0);
                openSockets.values().remove(s);
                System.out.println("Remove " + s + " to avoid having too many connections ");
                try {
                    s.close();
                    System.out.println("---> " + "closed");
                } catch (Throwable t) {
                    System.out.println("---> " + s);
                }

            }

            int num = numSockets ++;
            openSockets.put(Integer.valueOf(num), sock);
            allSockets.add(sock);
            System.out.println("Total opened sockets = " + openSockets.size() + "/" + allSockets.size());
            return Crypto.encrypt("" + num + " " +  allSockets.size());
        }
    }

    // Client calls to read from a socket (should read at least one byte)
    @RequestMapping(path = "/sockread", method = RequestMethod.POST)
    public ResponseEntity<byte[]> socketRead(@RequestBody String request) throws Exception {
        SocketReadRequest req = new SocketReadRequest(request);

        HttpStatusCode status = HttpStatus.OK;
        byte[] result = new byte[req.bytes];
        int n = -1;
        
        try {
            n = req.sock.getInputStream().read(result);
        } catch (Throwable e) {
            synchronized (openSockets) {
                System.out.println("Socket is probably closed. Open count = " + openSockets.size() + "/" + allSockets.size());
            }
            status = HttpStatus.NOT_FOUND;
        }
        if (n < 0) {
            n = 0;
        }
        if (n != result.length) {
            byte[] buf = new byte[n];
            System.arraycopy(result, 0, buf, 0, n);
            result = buf;
        }
        result = Crypto.encrypt(result);
        //System.out.println("result.length = " + result.length);
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_OCTET_STREAM);
        headers.setContentLength(result.length);
        return new ResponseEntity<byte[]>(result, headers, status);
    }

    // Client calls to write into a socket
    @RequestMapping(path = "/sockwrite", method = RequestMethod.POST)
    public String socketWrite(@RequestBody String request) throws Exception {
        SocketWriteRequest req = new SocketWriteRequest(request);
        OutputStream out = req.sock.getOutputStream();
        String decoded = URLDecoder.decode(req.data, StandardCharsets.UTF_8.name());
        byte[] data = Base64.getDecoder().decode(decoded);
        out.write(data);
        return Crypto.encrypt("ok");
    }

    // Client calls to close a socket
    @RequestMapping(path = "/sockclose", method = RequestMethod.POST)
    public String socketClose(@RequestBody String request) throws Exception {
        SocketCloseRequest req = new SocketCloseRequest(request);
        req.sock.close();
        synchronized (openSockets) {
            allSockets.remove(req.sock);
            openSockets.remove(Integer.valueOf(req.sockID));
        }
        return Crypto.encrypt("ok");
    }

    static Socket getSocketFromID(int sockID) {
        synchronized (openSockets) {
            return openSockets.get(Integer.valueOf(sockID));
        }
    }
}


class Crypto {
    static SecretKey secretKey;

    static {
        try {
            secretKey = init();
        } catch (Throwable t) {
            t.printStackTrace();
            System.exit(1);
        }
    }

    static SecretKey init() throws Exception {
        KeyStore ks = KeyStore.getInstance("pkcs12");
        ks.load(null, null);


        String keyStorePath = System.getProperty("httpft.key.store");
        if (keyStorePath == null) {
            System.out.println("-Dhttpft.key.store must be specified");
            System.exit(1);
        }

        char[] password = "keystorepassword".toCharArray();
        KeyStore.ProtectionParameter protParam = 
            new KeyStore.PasswordProtection(password);
        
        if ((new File(keyStorePath)).exists()) {
            System.out.println("Loading from keystore: " + keyStorePath);
            try (FileInputStream fis = new FileInputStream(keyStorePath)) {
                ks.load(fis, null);
            }

            KeyStore.Entry ent = ks.getEntry("secretKeyAlias", protParam);
            return ((KeyStore.SecretKeyEntry)ent).getSecretKey();
        } else {
            SecretKey sk = generateKey(256);
            KeyStore.SecretKeyEntry skEntry = new KeyStore.SecretKeyEntry(sk);
            ks.setEntry("secretKeyAlias", skEntry, protParam);

            try (FileOutputStream fos = new FileOutputStream(keyStorePath)) {
                ks.store(fos, null);
            }

            System.out.println("\n\n\n\n\n\n");
            System.out.println("Created new keystore: " + keyStorePath);
            System.out.println("\n\n\n\n\n\n");
            return sk;
        }
    }

    static GCMParameterSpec gcmSpec = generateIv();
    static String algorithm = "AES/GCM/NoPadding";

    public static GCMParameterSpec generateIv() {
        byte[] iv = Util.token.getBytes();
        return new GCMParameterSpec(128, iv);
    }

    public static String encrypt(String input, SecretKey key)
        throws NoSuchPaddingException, NoSuchAlgorithmException,
               InvalidAlgorithmParameterException, InvalidKeyException,
               BadPaddingException, IllegalBlockSizeException
    {

        Cipher cipher = Cipher.getInstance(algorithm);
        cipher.init(Cipher.ENCRYPT_MODE, key, gcmSpec);
        byte[] cipherText = cipher.doFinal(input.getBytes());
        return Base64.getEncoder()
            .encodeToString(cipherText);
    }

    public static String decrypt(String cipherText, SecretKey key)
        throws NoSuchPaddingException, NoSuchAlgorithmException,
               InvalidAlgorithmParameterException, InvalidKeyException,
               BadPaddingException, IllegalBlockSizeException
    {
        Cipher cipher = Cipher.getInstance(algorithm);
        cipher.init(Cipher.DECRYPT_MODE, key, gcmSpec);
        byte[] plainText = cipher.doFinal(Base64.getDecoder()
                                          .decode(cipherText));
        return new String(plainText);
    }


    public static String encrypt(String s) throws Exception {
        return encrypt(s, secretKey);
    }

    public static String decrypt(String s) throws Exception {
        return decrypt(s, secretKey);
    }


    public static byte[] encrypt(byte[] input, SecretKey key)
        throws NoSuchPaddingException, NoSuchAlgorithmException,
               InvalidAlgorithmParameterException, InvalidKeyException,
               BadPaddingException, IllegalBlockSizeException
    {

        Cipher cipher = Cipher.getInstance(algorithm);
        cipher.init(Cipher.ENCRYPT_MODE, key, gcmSpec);
        return cipher.doFinal(input);
    }

    public static byte[] decrypt(byte[] cipherText, SecretKey key)
        throws NoSuchPaddingException, NoSuchAlgorithmException,
               InvalidAlgorithmParameterException, InvalidKeyException,
               BadPaddingException, IllegalBlockSizeException
    {
        Cipher cipher = Cipher.getInstance(algorithm);
        cipher.init(Cipher.DECRYPT_MODE, key, gcmSpec);
        return cipher.doFinal(cipherText);
    }


    public static byte[] encrypt(byte[] s) throws Exception {
        return encrypt(s, secretKey);
    }

    public static byte[] decrypt(byte[] s) throws Exception {
        return decrypt(s, secretKey);
    }

    public static SecretKey generateKey(int n) throws NoSuchAlgorithmException {
        KeyGenerator keyGenerator = KeyGenerator.getInstance("AES");
        keyGenerator.init(n);
        SecretKey key = keyGenerator.generateKey();
        return key;
    }

/*
    static PublicKey publicKey;
    static PrivateKey privateKey;

    static {
        try {
            publicKey = readPublicKey("/tmp/public.der");
            privateKey = readPrivateKey("/tmp/private.der");
        } catch (Throwable t) {
            t.printStackTrace();
            System.exit(1);
        }
    }

    private static byte[] readFileBytes(String filename) throws IOException {
        Path path = Paths.get(filename);
        return Files.readAllBytes(path);        
    }

    private static PublicKey readPublicKey(String filename)
        throws IOException, NoSuchAlgorithmException, InvalidKeySpecException
    {
        X509EncodedKeySpec publicSpec = new X509EncodedKeySpec(readFileBytes(filename));
        KeyFactory keyFactory = KeyFactory.getInstance("RSA");
        return keyFactory.generatePublic(publicSpec);       
    }

    private static PrivateKey readPrivateKey(String filename) 
        throws IOException, NoSuchAlgorithmException, InvalidKeySpecException
    {
        PKCS8EncodedKeySpec keySpec = new PKCS8EncodedKeySpec(readFileBytes(filename));
        KeyFactory keyFactory = KeyFactory.getInstance("RSA");
        return keyFactory.generatePrivate(keySpec);     
    }


    private static byte[] encrypt(PublicKey key, byte[] plaintext)
        throws NoSuchAlgorithmException, NoSuchPaddingException, InvalidKeyException, IllegalBlockSizeException, BadPaddingException
    {
        Cipher cipher = Cipher.getInstance("RSA/ECB/OAEPWithSHA1AndMGF1Padding");   
        cipher.init(Cipher.ENCRYPT_MODE, key);  
        return cipher.doFinal(plaintext);
    }

    private static byte[] decrypt(PrivateKey key, byte[] ciphertext)
        throws NoSuchAlgorithmException, NoSuchPaddingException, InvalidKeyException, IllegalBlockSizeException, BadPaddingException
    {
        Cipher cipher = Cipher.getInstance("RSA/ECB/OAEPWithSHA1AndMGF1Padding");   
        cipher.init(Cipher.DECRYPT_MODE, key);  
        return cipher.doFinal(ciphertext);
    }

*/

}

class Util {
    static final String token;

    static HttpRequest.BodyPublisher encryptPostString(String postString) throws Exception {
        String e = Crypto.encrypt(postString);
        return HttpRequest.BodyPublishers.ofString(e);
    }

    static HttpRequest.BodyPublisher encryptPostString(StringBuilder sb) throws Exception {
        return encryptPostString(sb.toString());
    }

    static {
        try {
            String path = System.getProperty("httpft.token");
            byte[] bytes = Files.readAllBytes(Paths.get(path));
            token = new String(bytes, "UTF-8");
        } catch (Throwable t) {
            throw new RuntimeException(t);
        }
    }

    static Values decryptAndSplit(String req) throws Exception {
        req = Crypto.decrypt(req);
	//System.out.println("\n" + req + "\n");
        String tmp[] = req.split("&");
        String data[] = new String[tmp.length * 2];
        int i = 0;
        String name = StandardCharsets.UTF_8.name();
        for (String s: tmp) {
	    //System.out.println("*\n" + s + "\n+\n");
            String v[] = s.split("=");
            data[i++] = URLDecoder.decode(v[0], name);
            if (v.length > 1) {
                data[i++] = URLDecoder.decode(v[1], name);
            } else {
                data[i++] = "";
            }
        }
        return new Values(data);
    }
    static String pair(String n, String v) throws IOException {
        return n + "=" + URLEncoder.encode(v, StandardCharsets.UTF_8.name());
    }

    static String encode(String s) throws IOException {
        return URLEncoder.encode(s, StandardCharsets.UTF_8.name());
    }

    static String trimDir(String f) {
        while (f.length() > 0 && f.charAt(f.length() - 1) == '/') {
            f = f.substring(0, f.length() - 1);
        }
        return f;
    }

    static long crc32(String file) throws IOException {
        try (RandomAccessFile aFile = new RandomAccessFile(file, "r");
             FileChannel inChannel = aFile.getChannel();) {

            MappedByteBuffer buffer = inChannel
                .map(FileChannel.MapMode.READ_ONLY, 0, inChannel.size());
            buffer.load();
            CRC32 crc32 = new CRC32();
            crc32.update(buffer);
            return crc32.getValue();
        }
    }

    static void deleteDirectory(File file) {
        for (File subfile : file.listFiles()) {
            if (subfile.isDirectory()) {
                deleteDirectory(subfile);
            } else {
                subfile.delete();
            }
        }
        file.delete();
    }

    static byte[] getData(String localDir, String file) throws IOException {
        File f = new File(new File(localDir), file);
        return Files.readAllBytes(f.toPath());
    }

    static long getModTime(String localDir, String file) throws IOException {
        File f = new File(new File(localDir), file);
        return f.lastModified();
    }

    static void prepareDirectoryFor(File f) throws IOException {
        File parent = f.getParentFile();
        if (!parent.exists()) {
            parent.mkdirs();
        } else if (!parent.isDirectory()) {
            System.out.println("is not a directory? " + parent);
            parent.delete();
            parent.mkdirs();
        }
    }
}

class Values {
    int i;
    String data[];
    Values(String data[]) {
        this.data = data;
        i = 0;
    }

    String get(String key) throws IOException {
        if (i + 2 > data.length) {
            throw new IOException("Not enough POST data for " + key);
        }
        String k = data[i];
        int c = k.indexOf('.');
        if (c >= 0) {
            k = k.substring(c+1);
        }
        if (!k.equals(key)) {
            throw new IOException("Expect " + key + " but got " + k + " at " + i);
        }
        String v = data[i+1];
        i += 2;

        //System.out.println(key + " = " + v);
        return v;
    }

    boolean end() {
        return i >= data.length;
    }
}

class FileInfo {
    String file;
    long cksum;
    long modTime;
    int offset;
    String data;

    FileInfo(String f, long c) {
        file = f;
        cksum = c;
    }

    FileInfo(String f, int o, long m, String d) {
        file = f;
        offset = o;
        modTime = m;
        data = d;
    }
}

class BaseRequest {
    String dir;
    ArrayList<FileInfo> files = new ArrayList<>();
    Values v;

    BaseRequest(String req) throws Exception {
        v = Util.decryptAndSplit(req);
        String token = v.get("token");
        if (!token.equals(Util.token)) {
            throw new RuntimeException("Token not equal: " + token);
        }
        dir = Util.trimDir(v.get("dir"));
    }
}

class ChecksumRequest extends BaseRequest {
    ChecksumRequest(String req) throws Exception {
        super(req);

        while (!v.end()) {
            String file = v.get("file");
            long cksum = Long.parseLong(v.get("cksum"));
            files.add(new FileInfo(file, cksum));
        }
    }
}

class UploadRequest extends BaseRequest {
    UploadRequest(String req) throws Exception {
        super(req);

        while (!v.end()) {
            String file = v.get("file");
            int offset = Integer.parseInt(v.get("offset"));
            long modTime = Long.parseLong(v.get("time"));
            String data = v.get("data");
            files.add(new FileInfo(file, offset, modTime, data));
        }
    }
}


class SocketOpenRequest extends BaseRequest {
    String host;
    int port;

    SocketOpenRequest(String req) throws Exception {
        super(req);
        host = v.get("host");
        port = Integer.parseInt(v.get("port"));
    }
}

class SocketReadRequest extends BaseRequest {
    Socket sock;
    int bytes;

    SocketReadRequest(String req) throws Exception {
        super(req);
        int sockID = Integer.parseInt(v.get("sock"));
        sock = HelloController.getSocketFromID(sockID);
        bytes = Integer.parseInt(v.get("bytes"));
    }
}

class SocketWriteRequest extends BaseRequest {
    Socket sock;
    String data;

    SocketWriteRequest(String req) throws Exception {
        super(req);
        int sockID = Integer.parseInt(v.get("sock"));
        sock = HelloController.getSocketFromID(sockID);
        data = v.get("data");
    }
}

class SocketCloseRequest extends BaseRequest {
    int sockID;
    Socket sock;

    SocketCloseRequest(String req) throws Exception {
        super(req);
        sockID = Integer.parseInt(v.get("sock"));
        sock = HelloController.getSocketFromID(sockID);
    }
}

class CommandLine {
    public static void main(String args[]) throws Exception {
        if (args[0].equals("up")) {
            clientUp(args[1], args[2], args[3]);   // copy from (local  args[2]) -> (remote args[3])
        } else if (args[0].equals("down")) {
            clientDown(args[1], args[2], args[3]); // copy from (remote args[2]) -> (local  args[3])
        } else if (args[0].equals("sockopen")) {
            clientSocketOpen(args[1], args[2], args[3], args[4]); // open args[2]:args[3] as localhost:args[4]
        } else {
            System.out.println("Unknown command: " + args[0]);
        }
    }

    static void clientUp(String url, String localDir, String remoteDir) throws Exception {
        String post = postString(localDir, remoteDir);
        HttpClient client = HttpClient.newHttpClient();
        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(url + "/diffup"))
            .POST(Util.encryptPostString(post))
            .build();

        HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
        upload(response.body(), url, localDir, remoteDir);
    }

    static void clientDown(String url, String remoteDir, String localDir) throws Exception {
        String post = postString(localDir, remoteDir);
        HttpClient client = HttpClient.newHttpClient();
        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(url + "/down"))
            .POST(Util.encryptPostString(post))
            .build();

        HttpResponse<byte[]> response = client.send(request, HttpResponse.BodyHandlers.ofByteArray());
        byte[] body = Crypto.decrypt(response.body());
        byte[] buffer = new byte[2048];

        int i = 0;
        int deletedFiles = 0;
        int updatedFiles = 0;
        try (ZipInputStream zis = new ZipInputStream(new ByteArrayInputStream(body))) {
            ZipEntry entry;
            while((entry = zis.getNextEntry()) != null) {
                String name = entry.getName();
                if (i == 0) {
                    if (!name.equals(".deleted.txt")) {
                        System.out.println("First entry must always be .deleted.txt");
                        System.exit(1);
                    }
                    deletedFiles = deleteLocalFiles(localDir, zis, buffer);
                } else {
                    writeLocalFile(localDir, name, entry.getTime(), zis, buffer);
                    updatedFiles ++;
                }
                i++;
            }
        }
        System.out.println("Deleted " + deletedFiles + " files");
        System.out.println("Updated " + updatedFiles + " files");
    }

    static int deleteLocalFiles(String localDir, ZipInputStream zis, byte[] buffer) throws IOException {
        int deletedFiles = 0;
        try (ByteArrayOutputStream baos = new ByteArrayOutputStream()) {
            int len = 0;
            while ((len = zis.read(buffer)) > 0) {
                baos.write(buffer, 0, len);
            }
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(new ByteArrayInputStream(baos.toByteArray())))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    File f = new File(new File(localDir), line);
                    boolean ok = f.delete();
                    System.out.println("Delete: " + f + ((ok) ? " succeed" : " failed??"));
                    deletedFiles ++;
                }
            }
        }
        return deletedFiles;
    }

    static void writeLocalFile(String localDir, String file, long modTime, ZipInputStream zis, byte[] buffer) throws IOException {
        File f = new File(new File(localDir), file);
        Util.prepareDirectoryFor(f);
/*
        File parent = f.getParentFile();
        if (!parent.exists()) {
            parent.mkdirs();
        } else if (!parent.isDirectory()) {
            System.out.println("is not a directory? " + parent);
            parent.delete();
            parent.mkdirs();
        }
*/
        try (FileOutputStream fos = new FileOutputStream(f)) {
            int len = 0;
            while ((len = zis.read(buffer)) > 0) {
                fos.write(buffer, 0, len);
            }
        }
        boolean ok = f.setLastModified(modTime);
        System.out.println("Save: " + f + ((ok) ? " settime succeed" : " settime failed??"));
    }

    static int count = 0;
    static String postString(String localDir, String remoteDir) throws Exception{
        localDir = Util.trimDir(localDir);
        remoteDir = Util.trimDir(remoteDir);
        StringBuilder sb = new StringBuilder();
        sb.append(Util.pair("0.token", Util.token));
        sb.append(Util.pair("&0.dir", remoteDir));
        count = 0;
        int skipDir = localDir.length() + 1; // skip "<dirname>/"
        findAllFiles(sb, skipDir, new File(localDir));

        return sb.toString();
    }

    static void upload(String response, String url, String localDir, String remoteDir) throws Exception {
        Values v = Util.decryptAndSplit(response);
        String status = v.get("status");
        if (!status.equals("ok")) {
            throw new RuntimeException("Status is not ok = " + status);
        }

        count = 0;
        StringBuilder sb = newUploadChunk(remoteDir);
        while (!v.end()) {
            String file = v.get("upload");
            System.out.println("upload: " + file);
            byte data[] = Util.getData(localDir, file);
            long modTime = Util.getModTime(localDir, file);
            int n = 0;
            boolean added = false;
            while (n < data.length || !added) {
                sb = flushChunk(url, remoteDir, sb, false);
                n = appendChunk(file, modTime, sb, data, n);
                added = true;
            }
        }
        flushChunk(url, remoteDir, sb, true);
    }

    static int appendChunk(String file, long modTime, StringBuilder sb, byte[] data, int start) throws IOException {
        int available = CHUNK_LIMIT - sb.length();
        if (available < 0) {
            throw new RuntimeException("should not be here " + CHUNK_LIMIT + " vs " + sb.length());
        }
        int max_bytes = available * 7 / 10; // uuencode is about 70% efficient?
        if (max_bytes < 100) {
            max_bytes = 100; // It's OK to be over CHUNK_LIMIT a little;
        }
        int n = data.length - start;
        if (n > max_bytes) {
            n = max_bytes;
        }

        byte src[];
        if (start == 0 && n == data.length) {
            src = data;
        } else {
            src = new byte[n];
            System.arraycopy(data, start, src, 0, n);
        }
        String b64 = Base64.getEncoder().encodeToString(src);
        sb.append("&" + count + ".file=" + Util.encode(file) +
                  "&" + count + ".offset=" + start +
                  "&" + count + ".time=" + modTime +
                  "&" + count + ".data=" + Util.encode(b64));
        count ++;
        return start + n;
    }

    static final int CHUNK_LIMIT = 5 * 1024 * 1024;
    static StringBuilder flushChunk(String url, String remoteDir, StringBuilder sb, boolean force) throws Exception { 
        if (sb.length() >= CHUNK_LIMIT || force) {
            String post = sb.toString();
            HttpClient client = HttpClient.newHttpClient();
            HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(url + "/up"))
                .POST(Util.encryptPostString(post))
                .build();

            HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
            String body = Crypto.decrypt(response.body());
            if (!body.equals("ok")) {
                throw new RuntimeException("Status is not ok = " + body);
            }
            count = 0;
            return newUploadChunk(remoteDir);
        } else {
            return sb;
        }
    }

    static StringBuilder newUploadChunk(String remoteDir) throws IOException {
        StringBuilder sb = new StringBuilder();
        sb.append(Util.pair("0.token", Util.token));
        sb.append(Util.pair("&0.dir", remoteDir));
        return sb;
    }


    // skipDir == skip this number of characters from the beginning of the path
    static void findAllFiles(StringBuilder sb, int skipDir, File file) throws Exception {
        if (file.isFile()) {
            String fileName = file.toString();
            String skippedFileName = fileName.substring(skipDir);
            if (!skippedFileName.startsWith("build/")) {
                sb.append("&" + count + ".file=" + Util.encode(skippedFileName) +
                          "&" + count + ".cksum=" + Util.crc32(fileName));
                count ++;
            }
        } else if (file.isDirectory()) {
            File[] files = file.listFiles();
            Arrays.sort(files);
            for (File f : files) {
                findAllFiles(sb, skipDir, f);
            }
        }
    }

    static void clientSocketOpen(String url, String proxiedHost, String proxiedPort, String localProxiedPort) throws Exception {
        StringBuilder sb = new StringBuilder();
        sb.append(Util.pair("0.token", Util.token));
        sb.append(Util.pair("&0.dir", "dummy"));
        sb.append(Util.pair("&0.host", proxiedHost));
        sb.append(Util.pair("&0.port", proxiedPort));
        HttpClient client = HttpClient.newHttpClient();
        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(url + "/sockopen"))
            .POST(Util.encryptPostString(sb))
            .build();

        HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
        String line = Crypto.decrypt(response.body());
        String tmp[] = line.split(" ");
        String sockID = tmp[0];
        String total = tmp[1];

        System.out.println("Server has total " + total + " connections");
        System.out.println("Proxy listening on localhost: " + localProxiedPort);

        ServerSocket serverSocket = new ServerSocket(Integer.parseInt(localProxiedPort));
        Socket clientSocket = serverSocket.accept();
        serverSocket.close();

        System.out.println("Proxy accepted incoming connection: " + clientSocket);

        SocketProxyReadThread readThread = new SocketProxyReadThread(url, sockID, clientSocket.getOutputStream());
        readThread.start();

        SocketProxyWriteThread writeThread = new SocketProxyWriteThread(url, sockID, clientSocket.getInputStream());
        writeThread.start();

        readThread.join();
        writeThread.join();
    }
}

// Reads from the server, and writes to the OutputStream of the proxied port
class SocketProxyReadThread extends Thread {
    String url;
    String sockID;
    OutputStream out;
    SocketProxyReadThread(String url, String sockID, OutputStream out) {
        this.url = url;
        this.sockID = sockID;
        this.out = out;
    }

    public void run() {
        while (true) {
            try {
                readLoop();
            } catch (Throwable t) {
                t.printStackTrace();
                System.out.println("Exiting due to exception");
                System.exit(0);
                return;
            }
        }
    }

    void readLoop() throws Exception {
        StringBuilder sb = new StringBuilder();
        sb.append(Util.pair("0.token", Util.token));
        sb.append(Util.pair("&0.dir", "dummy"));
        sb.append(Util.pair("&0.sock", sockID));
        sb.append(Util.pair("&0.bytes", "" + 1024 * 64));
        HttpClient client = HttpClient.newHttpClient();
        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(url + "/sockread"))
            .POST(Util.encryptPostString(sb))
            .build();

        HttpResponse<byte[]> response = client.send(request, HttpResponse.BodyHandlers.ofByteArray());
        if (response.statusCode() == 404) { // HttpStatus.NOT_FOUND
            System.out.println("Server has closed connection");
            System.exit(0);
        }
        System.out.println(response.body().length);
        byte[] body = Crypto.decrypt(response.body());

        out.write(body);
        out.flush();
    }
}

// Reads incoming data from the InputStream of the proxies port, and upload to the server
class SocketProxyWriteThread extends Thread {
    String url;
    String sockID;
    InputStream in;
    byte[] buffer = new byte[4096];
    boolean eof;

    SocketProxyWriteThread(String url, String sockID, InputStream in) {
        this.url = url;
        this.sockID = sockID;
        this.in = in;
        this.eof = false;
    }

    public void run() {
        while (!eof) {
            try {
                writeLoop();
            } catch (Throwable t) {
                t.printStackTrace();
                return;
            }
        }
    }

    void writeLoop() throws Exception {
        int n = in.read(buffer);
        if (n < 0) {
            eof = true;
            System.out.println("EOF -- closing socket in server side");

            StringBuilder sb = new StringBuilder();
            sb.append(Util.pair("0.token", Util.token));
            sb.append(Util.pair("&0.dir", "dummy"));
            sb.append(Util.pair("&0.sock", sockID));
            HttpClient client = HttpClient.newHttpClient();
            HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(url + "/sockclose"))
                .POST(Util.encryptPostString(sb))
                .build();

            HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
            System.exit(0);
        }

        byte src[];
        if (n == buffer.length) {
            src = buffer;
        } else {
            src = new byte[n];
            System.arraycopy(buffer, 0, src, 0, n);
        }
        String b64 = Base64.getEncoder().encodeToString(src);

        StringBuilder sb = new StringBuilder();
        sb.append(Util.pair("0.token", Util.token));
        sb.append(Util.pair("&0.dir", "dummy"));
        sb.append(Util.pair("&0.sock", sockID));
        sb.append(Util.pair("&0.data", Util.encode(b64)));
        HttpClient client = HttpClient.newHttpClient();
        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(url + "/sockwrite"))
            .POST(Util.encryptPostString(sb))
            .build();

        HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
    }
}
