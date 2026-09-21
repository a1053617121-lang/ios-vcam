THEOS_PACKAGE_SCHEME = rootless
TARGET = iphone:clang:latest:14.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = VCamConfig

VCamConfig_FILES = main.m VCamConfig.m
VCamConfig_CFLAGS = -fobjc-arc
VCamConfig_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/application.mk
