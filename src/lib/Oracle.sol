// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

library Oracle {
    struct Observation {
        uint32 timestamp;
        // 累计的tick，tick * time
        int56 tickCumulative;
        bool initialized;
    }

    function initialize(Observation[65535] storage self, uint32 time)
        internal
        returns (uint16 cardinality, uint16 cardinalityNext)
    {
        self[0] = Observation({timestamp: time, tickCumulative: 0, initialized: true});
        return (1, 1);
    }

    // 写入新的观测数据，注意这里不是增加"扩容"(即记录更多的数据)当前有多少个
    // cardinality就写多少个数据，超出便覆盖掉老数据
    function write(
        Observation[65535] storage self,
        uint16 index,
        uint32 timestamp,
        int24 tick,
        uint16 cardinality,
        uint16 cardinalityNext
    ) internal returns (uint16 indexUpdated, uint16 cardinalityUpdated) {
        Observation memory last = self[index];
        // 如果当前区块存在过观测数据，跳过写操作
        if (last.timestamp == timestamp) return (index, cardinality);

        // 如果Next大于当前值，且index是当前值-1(从0开始计算，也就是刚好占满)，扩容
        if (cardinalityNext > cardinality && index == (cardinality - 1)) {
            cardinalityUpdated = cardinalityNext;
        } else {
            cardinalityUpdated = cardinality;
        }

        indexUpdated = (index + 1) % cardinalityUpdated;
        self[indexUpdated] = transform(last, timestamp, tick);
    }

    // 将旧的观测值转化为新的
    function transform(Observation memory last, uint32 timestamp, int24 tick)
        internal
        pure
        returns (Observation memory)
    {
        uint56 delta = timestamp - last.timestamp;

        return Observation({
            timestamp: timestamp,
            tickCumulative: last.tickCumulative + int56(tick) * int56(delta),
            initialized: true
        });
    }

    function grow(Observation[65535] storage self, uint16 current, uint16 next) internal returns (uint16) {
        if (next <= current) return current;

        for (uint16 i = current; i < next; i++) {
            self[i].timestamp = 1;
        }
        return next;
    }

    function observe(
        Observation[65535] storage self,
        uint32 time,
        uint32[] memory secondsAgos,
        int24 tick,
        uint16 index,
        uint16 cardinality
    ) internal view returns (int56[] memory tickCumulatives) {
        tickCumulatives = new int56[](secondsAgos.length);

        for (uint256 i = 0; i < secondsAgos.length; i++) {
            tickCumulatives[i] = observeSingle(self, time, secondsAgos[i], tick, index, cardinality);
        }
    }

    // 如果请求的时间点是最新的观测，直接返回子最新观测中的数据
    // 如果请求时间点在最新观测之后，可以调用transform来找到当前时间点上的累积价格
    // 如果请求时间点在最新观测之前，需要使用二分查找
    /// @param secondsAgo 获取多少秒之前的数据
    /// @param time 当前区块的时间戳
    function observeSingle(
        Observation[65535] storage self,
        uint32 time,
        uint32 secondsAgo,
        int24 tick,
        uint16 index,
        uint16 cardinality
    ) internal view returns (int56 tickCumulative) {
        if(secondsAgo == 0){
            Observation memory last = self[index];
            if(last.timestamp != time) last = transform(last, time, tick);
            return last.tickCumulative;
        }else{
            
        }
    }

    // 获取目标之前或之后的观测值
    function binarySearch(Observation[65535] storage self, uint32 time, uint32 target, uint16 index, uint16 cardinality) private view returns(Observation memory beforeOrAt, Observation memory arOrAfter){
        // 最新的index+1取模后，就是最旧的数据，因为数组是个环形的
        uint256 l = (index + 1) % cardinality;
        uint256 r = l + cardinality - 1;
    }
}
