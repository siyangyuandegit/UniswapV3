# UniswapV3

重写UniswapV3

## 池子的手续费

手续费是比较复杂的一点，特作说明，池子的手续费通过tick和position还有全局的feeGrowth0 / 1进行记录

里边其实只有两个概念，一个是外侧的手续费(f_g)，一个是全局的手续费(f_o)，外侧的含义是指某个tick与currentTick方向的反向(1, 2, 3, 4, 5假设这是部分tick，currentTick=3，tick=2那么外侧指的是2左边)

还有为了方便计算和管理，手续费记录的是单位流动性的手续费，也就是当时的总手续费/总流动性（只有在tick活跃时才会记录手续费）

1、池子被创建后，会初始化全局手续费

2、在提供流动性时，根据上下边界的tick与currentTick(当前价格对应的tick)的关系，如果tick <= currentTick初始化outsideFee0/1为全局的手续费，其他情况不做处理（默认为0）

3、通过两个tick的f_0和全局的f_g可以计算出任意两个被激活tick间的手续费，首先求出下边界左边的手续费，再求出上边界右边的手续费，再用全局手续费减去这两个，就是两个tick中间的手续费，也就是某个position应得的手续费，具体过程如下：

```solidity
if (lowerTick <= currentTick){
    feeLeft0 = lowerTick.f_o0;
    feeLeft1 = lowerTick.f_o1;
}else{
    feeLeft0 = f_g - lowerTick.f_o0;
    feeLeft1 = f_g - lowerTick.f_o1;
}
如果tick小于等于currentTick，那么该tick记录的本就是左侧的手续费，所以不需要计算
如果tick大于了current Tick，那么该tick记录的是右侧的手续费，想要左侧的需要用f_g - f_o
```

4、有了上述的position手续费，就可以初始化position（liquidity, feeInside0/1, toeknsOwed0/1），到此成功提供流动性

5、有了流动性就可以进行swap，swap的时候会造城currentTick移动，当其穿过某个被激活的tick时，该tick上记录的outsideFee会被反转为f_o = f_g - f_o，手续费是在swap中收取的，计算出feeAmount后，会除以当前总活跃的流动性，获得单位流动性应得的手续费，然后根据交易方向，将手续费更新到全局手续费中

6、用户提取手续费通过collect函数，提取时从position中读取用户应的的手续费，在提取后，从中减去用户提取的手续费(区间内累计的手续费不会变)。



