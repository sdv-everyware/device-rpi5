# The product lives under device/rpi5/ so that no file of Google's, Linaro's or the reference
# port's is edited: the build picks up every device/*/*/AndroidProducts.mk.

PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/sdv_media_rpi5.mk

COMMON_LUNCH_CHOICES := \
    sdv_media_rpi5-trunk_staging-userdebug
