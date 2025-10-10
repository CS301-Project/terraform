package com.example;

import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
import java.sql.*;
import java.math.BigDecimal;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;

import net.schmizz.sshj.SSHClient;
import net.schmizz.sshj.sftp.RemoteFile;
import net.schmizz.sshj.sftp.RemoteResourceInfo;
import net.schmizz.sshj.sftp.SFTPClient;
import net.schmizz.sshj.transport.verification.PromiscuousVerifier;
import software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.ssm.SsmClient;
import software.amazon.awssdk.services.ssm.model.GetParameterRequest;

public class SftpFetchHandler implements RequestHandler<Map<String, Object>, String> {

  @Override
  public String handleRequest(Map<String, Object> event, Context ctx) {
    String host = System.getenv("SFTP_HOST");
    int port = Integer.parseInt(System.getenv("SFTP_PORT"));
    String user = System.getenv("SFTP_USER");
    String ssmParam = System.getenv("SSM_KEY_P");
    String dir = System.getenv("SFTP_DIR");

    String keyPem = fetchPrivateKey(ssmParam);
    ctx.getLogger().log("Connecting to " + host + ":" + port + " as " + user + "\n");

    try (SSHClient ssh = new SSHClient()) {
      ssh.addHostKeyVerifier(new PromiscuousVerifier());
      ssh.connect(host, port);
      ssh.authPublickey(user, new InMemoryKeyProvider(keyPem));

      try (SFTPClient sftp = ssh.newSFTPClient()) {
        List<RemoteResourceInfo> files = sftp.ls(dir);
        for (RemoteResourceInfo f : files) {
          if (!f.isRegularFile() || !f.getName().endsWith(".csv")) continue;

          // 1️⃣ Read file bytes
          try (RemoteFile rf = sftp.open(f.getPath())) {
            long len = rf.length();
            if (len > Integer.MAX_VALUE)
              throw new RuntimeException("File too large: " + f.getName());
            byte[] buf = new byte[(int) len];
            rf.read(0, buf, 0, (int) len);
            String content = new String(buf, StandardCharsets.UTF_8);
            ctx.getLogger().log("---- " + f.getName() + " ----\n" + content + "\n");

            // 2️⃣ DB connection info
            String jdbcUrl  = System.getenv("DB_URL");
            String dbUser   = System.getenv("DB_USER");
            String dbPass   = System.getenv("DB_PASSWORD");

            // 3️⃣ Insert or update into Transaction table
            try (Connection conn = DriverManager.getConnection(jdbcUrl, dbUser, dbPass)) {
              conn.setAutoCommit(false);

              String sql = """
                  INSERT INTO Transaction (ID, ClientID, Transaction, Amount, Date, Status)
                  VALUES (?, ?, ?, ?, ?, ?)
                  ON DUPLICATE KEY UPDATE
                    ClientID=VALUES(ClientID),
                    Transaction=VALUES(Transaction),
                    Amount=VALUES(Amount),
                    Date=VALUES(Date),
                    Status=VALUES(Status)
                  """;
              PreparedStatement ps = conn.prepareStatement(sql);

              for (String line : content.split("\\r?\\n")) {
                if (line.startsWith("ID") || line.isBlank()) continue;
                String[] parts = line.split(",");
                if (parts.length < 6) continue;

                ps.setString(1, parts[0].trim());
                ps.setString(2, parts[1].trim());
                ps.setString(3, parts[2].trim());
                ps.setBigDecimal(4, new BigDecimal(parts[3].trim()));
                ps.setDate(5, java.sql.Date.valueOf(parts[4].trim()));
                ps.setString(6, parts[5].trim());
                ps.addBatch();
              }

              ps.executeBatch();
              conn.commit();
              ctx.getLogger().log("✅ Inserted/updated rows from " + f.getName() + "\n");
            } catch (Exception dbEx) {
              ctx.getLogger().log("❌ DB insert failed for " + f.getName() + ": " + dbEx + "\n");
            }
          }
        }
      }
    } catch (Exception e) {
      throw new RuntimeException(e);
    }
    return "ok";
  }

  private String fetchPrivateKey(String paramName) {
    try (SsmClient ssm = SsmClient.builder()
        .region(Region.of(System.getenv("AWS_REGION")))
        .credentialsProvider(DefaultCredentialsProvider.create())
        .build()) {
      return ssm.getParameter(GetParameterRequest.builder()
          .name(paramName).withDecryption(true).build())
          .parameter().value();
    }
  }
}
