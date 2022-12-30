package com.moffatman.chan;

import android.content.Context;
import org.unifiedpush.android.foss_embedded_fcm_distributor.EmbeddedDistributorReceiver;

public class EmbeddedDistributor extends EmbeddedDistributorReceiver {
	@Override
    public String getGoogleProjectNumber() {
		return "500583514678"; // This value comes from the google-services.json
	}

	@Override
    public String getEndpoint(Context context, String token, String instance) {
        // This returns the endpoint of your FCM Rewrite-Proxy
        return String.format("https://up-rewrite-proxy.chance.surf/FCM?v2&instance=%s&token=%s", instance, token);
    }
}