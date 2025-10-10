package com.example;

import java.io.IOException;
import java.io.StringReader;
import java.security.PrivateKey;
import java.security.PublicKey;

import net.schmizz.sshj.userauth.keyprovider.KeyProvider;
import net.schmizz.sshj.userauth.keyprovider.PKCS8KeyFile;

public class InMemoryKeyProvider implements KeyProvider {
    private final PKCS8KeyFile key = new PKCS8KeyFile();

    public InMemoryKeyProvider(String pem) {
        key.init(new StringReader(pem)); // loads PEM text directly
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
