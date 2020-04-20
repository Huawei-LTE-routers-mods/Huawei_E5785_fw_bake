# Huawei_E5785_fw_bake
The baker for E5785 and E5885 custom router firmware

# Using

To use this tool save the APP partition of your firmware as *APP.E5785.orig.bin* or *APP.E5885.orig.bin* and the System partition as *System.E5785.orig.bin* or *APP.E5885.orig.bin*.

Then launch **baker.py** (Python 3.8 is required) and it will generate *APP.E5785.bin*, *APP.E5885.bin*, *System.E5785.bin*, *System.E5785.bin*.

Replace partitions in your firmwares with generated ones.

For operations with firmware partitions the [qhuaweiflash tool](https://github.com/forth32/qhuaweiflash) can be used.
