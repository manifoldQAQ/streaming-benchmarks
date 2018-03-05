/**
 * Licensed under the terms of the Apache License 2.0. Please see LICENSE file in the project root for terms.
 */
package apex.benchmark;

import benchmark.common.advertising.CampaignProcessorCommon;
import com.datatorrent.api.Context;
import com.datatorrent.api.DefaultInputPort;
import com.datatorrent.common.util.BaseOperator;

public class CampaignProcessor extends BaseOperator {
    private transient CampaignProcessorCommon campaignProcessorCommon;
    public transient DefaultInputPort<Tuple> input = new DefaultInputPort<Tuple>() {
        @Override
        public void process(Tuple tuple) {
            try {
                campaignProcessorCommon.execute(String.valueOf(tuple.campaignId), String.valueOf(tuple.event_time));
            } catch (Exception exception) {
                throw new RuntimeException("" + tuple.campaignId + ", " + tuple.event_time);
            }
        }
    };
    private String redisServerHost;

    public String getRedisServerHost() {
        return redisServerHost;
    }

    public void setRedisServerHost(String redisServerHost) {
        this.redisServerHost = redisServerHost;
    }

    public void setup(Context.OperatorContext context) {
        campaignProcessorCommon = new CampaignProcessorCommon(redisServerHost);
        this.campaignProcessorCommon.prepare();
    }
}

