ARCHS = arm64
TARGET = iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = GameOverlay
GameOverlay_FILES = Tweak.mm KittyMemory/KittyMemory.cpp KittyMemory/KittyUtils.cpp KittyMemory/KittyAsm.cpp KittyMemory/KittyIOFile.cpp

include $(THEOS)/makefiles/tweak.mk
