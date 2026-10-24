ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LumaBar
LumaBar_FILES = Tweak.x LBSettings.m LBActions.m LBDebug.m
LumaBar_CFLAGS = -fobjc-arc
LumaBar_FRAMEWORKS = UIKit

SUBPROJECTS += lumabarprefs

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
