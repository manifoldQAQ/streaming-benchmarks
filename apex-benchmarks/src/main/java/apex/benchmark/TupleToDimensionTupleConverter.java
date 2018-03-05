package apex.benchmark;

import com.datatorrent.api.DefaultInputPort;
import com.datatorrent.api.DefaultOutputPort;
import com.datatorrent.common.util.BaseOperator;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class TupleToDimensionTupleConverter extends BaseOperator {
    private static final transient Logger logger = LoggerFactory.getLogger(TupleToDimensionTupleConverter.class);
    public final transient DefaultOutputPort<DimensionTuple> outputPort = new DefaultOutputPort<DimensionTuple>();
    protected long invalidTuples = 0;
    protected transient long invalidTuplesInWindow = 0;
    public transient DefaultInputPort<Tuple> inputPort = new DefaultInputPort<Tuple>() {
        @Override
        public void process(Tuple tuple) {
            processTuple(tuple);
        }
    };

    public void processTuple(Tuple tuple) {
        DimensionTuple dt = DimensionTuple.fromTuple(tuple);
        if (dt == null) {
            invalidTuples++;
            invalidTuplesInWindow++;
            return;
        }
        outputPort.emit(dt);
    }

    @Override
    public void beginWindow(long windowId) {
        invalidTuplesInWindow = 0;
    }

    @Override
    public void endWindow() {
        if (invalidTuplesInWindow > 0) {
            logger.info("Invalid tuples in this window: {}; Total invalid tuples: {}", invalidTuplesInWindow, invalidTuples);
        }
    }
}
