export THEOS_DEVICE_IP=192.168.11.23

ARCHS = arm64 arm64e
GO_EASY_ON_ME = 1
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BottomControlX
BottomControlX_FILES = Tweak.xm

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
#SUBPROJECTS += bottomcontrolxpreferences
include $(THEOS_MAKE_PATH)/aggregate.mk
