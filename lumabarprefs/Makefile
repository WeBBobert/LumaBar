ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = LumaBarPrefs
LumaBarPrefs_FILES = LBRootListController.m
LumaBarPrefs_FRAMEWORKS = UIKit
LumaBarPrefs_PRIVATE_FRAMEWORKS = Preferences
LumaBarPrefs_INSTALL_PATH = /Library/PreferenceBundles
LumaBarPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
