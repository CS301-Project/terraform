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

  String env(String k) {
    return System.getenv(k);
  }

  boolean has(String v) {
    return v != null && !v.isBlank();
  }

  @Override
  public String handleRequest(Map<String, Object> event, Context ctx) {
    String host = System.getenv("SFTP_HOST");
    int port = Integer.parseInt(System.getenv("SFTP_PORT"));
    String user = System.getenv("SFTP_USER");
    String ssmParam = env("SSM_KEY_P"); // name of SSM parameter when in AWS
    String keyPem = env("SFTP_PRIVATE_KEY"); // optional: local PEM text
    String dir = System.getenv("SFTP_DIR"); // e.g. "/upload/incoming"
    if (dir == null || dir.isBlank()) {
      dir = "/incoming"; // sensible default
    }
    if (has(ssmParam)) {
      keyPem = fetchPrivateKey(ssmParam); // AWS path
    } else {
      ctx.getLogger().log("Local mode: skipping SSM. Using SFTP_PASSWORD or SFTP_PRIVATE_KEY if provided.\n");
    }

    ctx.getLogger().log("Connecting to " + host + ":" + port + " as " + user + "\n");

    try (SSHClient ssh = new SSHClient()) {
      ssh.addHostKeyVerifier(new PromiscuousVerifier());
      ssh.connect(host, port);
      String password = System.getenv("SFTP_PASSWORD");

      if (password != null && !password.isBlank()) {
        ssh.authPassword(user, password);
      } else {
        ssh.authPublickey(user, new InMemoryKeyProvider(keyPem));
      }
      try (SFTPClient sftp = ssh.newSFTPClient()) {
        List<RemoteResourceInfo> files = sftp.ls(dir);
        for (RemoteResourceInfo f : files) {
          if (!f.isRegularFile() || !f.getName().endsWith(".csv"))
            continue;

          String fileName = f.getName();

          // 1️⃣ DB connection info
          String jdbcUrl = System.getenv("DB_URL");
          String dbUser = System.getenv("DB_USER");
          String dbPass = System.getenv("DB_PASSWORD");

          try (Connection conn = DriverManager.getConnection(jdbcUrl, dbUser, dbPass)) {
            conn.setAutoCommit(false);

            // 2️⃣ Check if file already processed
            try (PreparedStatement check = conn.prepareStatement(
                "SELECT 1 FROM fetched_files WHERE filename = ?")) {
              check.setString(1, fileName);
              ResultSet rs = check.executeQuery();
              if (rs.next()) {
                ctx.getLogger().log("⚠️ Skipping already processed file: " + fileName + "\n");
                continue;
              }
            }

            // 3️⃣ Download file content from SFTP
            try (RemoteFile rf = sftp.open(f.getPath())) {
              long len = rf.length();
              if (len > Integer.MAX_VALUE)
                throw new RuntimeException("File too large: " + f.getName());
              byte[] buf = new byte[(int) len];
              int offset = 0;
              while (offset < buf.length) {
                int r = rf.read(offset, buf, offset, buf.length - offset);
                if (r < 0)
                  break; // EOF
                offset += r;
              }
              String content = new String(buf, StandardCharsets.UTF_8);
              ctx.getLogger().log("---- " + f.getName() + " ----\n" + content + "\n");

              // 4️⃣ Insert or update into Transaction table
              String sql = """
                  INSERT INTO `Transaction` (`ID`, `ClientID`, `Transaction`, `Amount`, `Date`, `Status`)
                  VALUES (?, ?, ?, ?, ?, ?)
                  ON DUPLICATE KEY UPDATE
                    `ClientID`=VALUES(`ClientID`),
                    `Transaction`=VALUES(`Transaction`),
                    `Amount`=VALUES(`Amount`),
                    `Date`=VALUES(`Date`),
                    `Status`=VALUES(`Status`)
                  """;

              try (PreparedStatement ps = conn.prepareStatement(sql)) {
                for (String raw : content.split("\\r?\\n")) {
                  String line = raw.trim();
                  if (line.isEmpty())
                    continue;
                  if (line.startsWith("\"") && line.endsWith("\"") && line.length() >= 2)
                    line = line.substring(1, line.length() - 1);
                  String headerProbe = line.replace("\"", "").trim().toLowerCase();
                  if (headerProbe.startsWith("id,clientid,transaction,amount,date,status"))
                    continue;

                  String[] parts = line.split(",", -1);
                  if (parts.length < 6) {
                    ctx.getLogger().log("Skipping malformed line: " + raw + "\n");
                    continue;
                  }

                  for (int i = 0; i < parts.length; i++) {
                    String p = parts[i].trim();
                    if (p.startsWith("\"") && p.endsWith("\"") && p.length() >= 2)
                      p = p.substring(1, p.length() - 1);
                    parts[i] = p.trim();
                  }

                  String id = parts[0];
                  String clientId = parts[1];
                  String txnTypeStr = parts[2].toUpperCase();
                  String amtStr = parts[3];
                  String dateStr = parts[4];
                  String statusStr = parts[5];

                  if (!(txnTypeStr.equals("D") || txnTypeStr.equals("W")))
                    continue;
                  String amtClean = amtStr.replaceAll("[^0-9.\\-]", "");
                  if (amtClean.isEmpty())
                    continue;

                  BigDecimal amount = new BigDecimal(amtClean);
                  ps.setString(1, id);
                  ps.setString(2, clientId);
                  ps.setString(3, txnTypeStr);
                  ps.setBigDecimal(4, amount);
                  ps.setDate(5, java.sql.Date.valueOf(dateStr.trim()));
                  ps.setString(6, normalizeStatus(statusStr));
                  ps.addBatch();
                }
                ps.executeBatch();
              }

              // 5️⃣ Log processed file
              try (PreparedStatement insertLog = conn.prepareStatement(
                  "INSERT INTO fetched_files (filename) VALUES (?)")) {
                insertLog.setString(1, fileName);
                insertLog.executeUpdate();
              }

              conn.commit();
              ctx.getLogger().log("✅ Inserted/updated rows from " + fileName + "\n");
            }
          } catch (Exception dbEx) {
            ctx.getLogger().log("❌ Error while processing " + fileName + ": " + dbEx + "\n");
          }
        }

      }
    } catch (Exception e) {
      throw new RuntimeException(e);
    }
    return "ok";
  }

  private static String normalizeStatus(String s) {
    String t = s.trim().toLowerCase();
    if (t.startsWith("comp"))
      return "Completed";
    if (t.startsWith("pend"))
      return "Pending";
    if (t.startsWith("fail"))
      return "Failed";
    return "Pending"; // default fallback
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

  // -------------------------------------------------------------------
  // Local test runner
  // -------------------------------------------------------------------
  public static void main(String[] args) {
    try {
      SftpFetchHandler handler = new SftpFetchHandler();

      // Simulate a Lambda call (no event needed)
      handler.handleRequest(Map.of(), new com.amazonaws.services.lambda.runtime.Context() {
        @Override
        public String getAwsRequestId() {
          return "local-test";
        }

        @Override
        public String getLogGroupName() {
          return "local";
        }

        @Override
        public String getLogStreamName() {
          return "local";
        }

        @Override
        public String getFunctionName() {
          return "sftp-test";
        }

        @Override
        public String getFunctionVersion() {
          return "1";
        }

        @Override
        public String getInvokedFunctionArn() {
          return "arn:aws:lambda:local:test";
        }

        @Override
        public com.amazonaws.services.lambda.runtime.CognitoIdentity getIdentity() {
          return null;
        }

        @Override
        public com.amazonaws.services.lambda.runtime.ClientContext getClientContext() {
          return null;
        }

        @Override
        public int getRemainingTimeInMillis() {
          return 300000;
        }

        @Override
        public int getMemoryLimitInMB() {
          return 512;
        }

        @Override
        public com.amazonaws.services.lambda.runtime.LambdaLogger getLogger() {
          return new com.amazonaws.services.lambda.runtime.LambdaLogger() {
            @Override
            public void log(String message) {
              System.out.println(message);
            }

            @Override
            public void log(byte[] message) {
              System.out.println(new String(message));
            }
          };
        }

      });

    } catch (Exception e) {
      e.printStackTrace();
    }
  }

}
