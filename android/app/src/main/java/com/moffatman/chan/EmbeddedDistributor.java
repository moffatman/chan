package com.moffatman.chan;

import org.unifiedpush.android.embedded_fcm_distributor.EmbeddedDistributorReceiver;
import org.unifiedpush.android.embedded_fcm_distributor.Gateway;

public class EmbeddedDistributor extends EmbeddedDistributorReceiver {
    @Override
    public Gateway getGateway() {
        return new Gateway() {
            @Override
            public String getVapid() {
                return "BIWLEnki-wBHz1nqXomyJ82jlMRma-gJib52yxXXeGeOQDu5h5nPXR4DBaJTwKrJDrOPaKhFR7wC9YxHMQBFZHc";
            }

            @Override
            public String getEndpoint(String token) {
                // This returns the endpoint of your FCM Rewrite-Proxy
                return String.format("https://up-rewrite-proxy.chance.surf/wpfcm?t=%s", token);
            }
        };
    }
}