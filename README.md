# Huawei_E5785_fw_bake
The baker for E5785 custom router firmware

# Using

To use this tool save the APP partition of your firmware as *APP.bin* and the System partition as *System.bin*.

Then launch **baker.py** (Python 3.8 is required) and it will generate APP.mod.bin and *System.mod.bin*.

Replace partitions in your firmware with generated ones.

For operations with firmware partitions the [qhuaweiflash tool](https://github.com/forth32/qhuaweiflash) can be used.
