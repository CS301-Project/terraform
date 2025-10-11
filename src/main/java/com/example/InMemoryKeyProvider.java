package com.example;

import net.schmizz.sshj.userauth.keyprovider.KeyProvider;
import net.schmizz.sshj.userauth.keyprovider.OpenSSHKeyFile;

import java.io.StringReader;
import java.io.IOException;
import java.security.PrivateKey;
import java.security.PublicKey;

public class InMemoryKeyProvider implements KeyProvider {
    private final OpenSSHKeyFile key = new OpenSSHKeyFile();

    // Pass the *contents* of your OpenSSH private key (BEGIN OPENSSH PRIVATE KEY)
    public InMemoryKeyProvider(String openSshPem) {
        key.init(new StringReader(openSshPem));
    }

    @Override
    public net.schmizz.sshj.common.KeyType getType() throws IOException {
        return key.getType();
    }

    @Override
    public PrivateKey getPrivate() throws IOException {
        return key.getPrivate();
    }

    @Override
    public PublicKey getPublic() throws IOException {
        return key.getPublic();
    }
}
