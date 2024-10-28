package com.example.springboot;

import java.io.*;
import java.nio.*;
import java.nio.channels.FileChannel;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.net.URI;
import java.net.URLDecoder;
import java.net.URLEncoder;
import java.util.ArrayList;
import java.util.Arrays;
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
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;

@RestController
public class HelloController {
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
    public String diffup(@RequestBody String request) throws IOException {
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

            return result.toString();
        } catch (Throwable t) {
            t.printStackTrace();
            return "error=" +  URLEncoder.encode(t.toString());
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
    public String up(@RequestBody String request) throws IOException {
        System.out.println(">" + request + "<");
        return "Hello\n";
    }

    // Client does this before downloading a directory from the server
    // - Client posts its own directory listing to the server
    // - Server returns the list of files that the client needs to update or delete
    //    - The response is a JAR file
    //    - a special file .delete.txt lists all the files that need to be deleted.
    @RequestMapping(path = "/down", produces = "application/zip", method = RequestMethod.POST)
    public ResponseEntity<byte[]> serverDown(@RequestBody String request) throws IOException {
        byte[] zip = makeDownZipFile(request);

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_PDF); // no APPLICATION_ZIP
        headers.setContentDispositionFormData("attachment", "x.zip");
        headers.setContentLength(zip.length);
        return new ResponseEntity<byte[]>(zip, headers, HttpStatus.OK);
    }

    byte[] makeDownZipFile(String request) throws IOException {
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
        try (InputStream is = new FileInputStream(new File(baseDir, entryName))) {
            ZipEntry ze = new ZipEntry(entryName);
            zos.putNextEntry(ze);
            byte[] buf = new byte[1024];
            int len;
            while ((len = is.read(buf))>0){
                zos.write(buf, 0, len);
            }
        }
    }
}

class Util {
    static Values split(String req) throws IOException {
        String tmp[] = req.split("&");
        String data[] = new String[tmp.length * 2];
        int i = 0;
        String name = StandardCharsets.UTF_8.name();
        for (String s: tmp) {
            String v[] = s.split("=");
            data[i++] = URLDecoder.decode(v[0], name);
            if (v.length > 0) {
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
        return v;
    }

    boolean end() {
        return i >= data.length;
    }
}

class FileInfo {
    String file;
    long cksum;

    FileInfo(String f, long c) {
        file = f;
        cksum = c;
    }
}

class ChecksumRequest {
    String dir;
    ArrayList<FileInfo> files = new ArrayList<>();

    ChecksumRequest(String req) throws IOException {
        Values v = Util.split(req);
        dir = Util.trimDir(v.get("dir"));

        //System.out.println(v.i);
        //System.out.println(v.end());
        while (!v.end()) {
            String file = v.get("file");
            long cksum = Long.parseLong(v.get("cksum"));
            files.add(new FileInfo(file, cksum));
            //System.out.println(file + " :: " + cksum);
        }
    }
}

class CommandLine {
    public static void main(String args[]) throws Exception {
        if (args[0].equals("up")) {
            clientUp(args[1], args[2], args[3]);   // copy from (local  args[2]) -> (remote args[3])
        } else if (args[0].equals("down")) {
            clientDown(args[1], args[2], args[3]); // copy from (remote args[2]) -> (local  args[3])
        }
    }

    static void clientUp(String url, String localDir, String remoteDir) throws Exception {
        String post = postString(localDir, remoteDir);
        HttpClient client = HttpClient.newHttpClient();
        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(url + "/diffup"))
            .POST(HttpRequest.BodyPublishers.ofString(post))
            .build();

        HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());

        upload(response.body());
    }

    static void clientDown(String url, String remoteDir, String localDir) throws Exception {
        String post = postString(localDir, remoteDir);
        HttpClient client = HttpClient.newHttpClient();
        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(url + "/down"))
            .POST(HttpRequest.BodyPublishers.ofString(post))
            .build();

        HttpResponse<byte[]> response = client.send(request, HttpResponse.BodyHandlers.ofByteArray());
        byte[] body = response.body();
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
        File parent = f.getParentFile();
        if (!parent.exists()) {
            parent.mkdirs();
        } else if (!parent.isDirectory()) {
            System.out.println("is not a directory? " + parent);
            parent.delete();
            parent.mkdirs();
        }
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
        sb.append(Util.pair("0.dir", remoteDir));
        count = 0;
        int skipDir = localDir.length() + 1; // skip "<dirname>/"
        findAllFiles(sb, skipDir, new File(localDir));

        return sb.toString();
    }

    static void upload(String response) throws Exception {
        Values v = Util.split(response);
        String status = v.get("status");
        if (!status.equals("ok")) {
            throw new RuntimeException("Status is not ok = " + status);
        }

        while (!v.end()) {
            String file = v.get("upload");
            System.out.println("need to upload: " + file);
        }
    }


    static void findAllFiles(StringBuilder sb, int skipDir, File file) throws Exception {
        if (file.isFile()) {
            String fileName = file.toString();
            sb.append("&" + count + ".file=" + Util.encode(fileName.substring(skipDir)) +
                      "&" + count + ".cksum=" + Util.crc32(fileName));
            count ++;
        } else if (file.isDirectory()) {
            File[] files = file.listFiles();
            Arrays.sort(files);
            for (File f : files) {
                findAllFiles(sb, skipDir, f);
            }
        }
    }
}
