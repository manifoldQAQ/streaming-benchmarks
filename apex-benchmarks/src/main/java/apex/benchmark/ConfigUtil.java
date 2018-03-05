/**
 * Licensed under the terms of the Apache License 2.0. Please see LICENSE file in the project root for terms.
 */
package apex.benchmark;

import com.datatorrent.api.Context.DAGContext;
import com.datatorrent.api.DAG;
import org.apache.hadoop.conf.Configuration;

import java.net.URI;

public class ConfigUtil {
    public static final String PROP_GATEWAY_ADDRESS = "dt.gateway.listenAddress";

    public static URI getAppDataQueryPubSubURI(DAG dag, Configuration conf) {
        return URI.create(getAppDataQueryPubSubUriString(dag, conf));
    }

    public static String getAppDataQueryPubSubUriString(DAG dag, Configuration conf) {
        return "ws://" + getGatewayAddress(dag, conf) + "/pubsub";
    }

    public static String getGatewayAddress(DAG dag, Configuration conf) {
        String gatewayAddress = dag.getValue(DAGContext.GATEWAY_CONNECT_ADDRESS);
        if (gatewayAddress == null) {
            gatewayAddress = conf.get(PROP_GATEWAY_ADDRESS);
        }
        return gatewayAddress;
    }
}
