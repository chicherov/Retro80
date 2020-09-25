include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME = Retro80
PACKAGE_VERSION = 0.92

APP_NAME = Retro80
Retro80_TOOL_LIBS  = -ldispatch
Retro80_TOOL_LIBS += -lGL -lGLU

Retro80_OBJCFLAGS = \
	-include GNUstep-Prefix.pch 	\
	-Wobjc-property-no-attribute 	\
	-fobjc-arc

Base_Source = 						\
		Document.h					\
		Document.m					\
		DocumentController.h		\
		DocumentController.m		\
		WindowController.h			\
		WindowController.m			\
		Application.h				\
		Application.m				\
		ComputerFactory.h			\
		ComputerFactory.m			\
		Computer.h					\
		Computer.m					\
		Display.h					\
		Display.m					\
		Digit.h						\
		Digit.m						\
		tvnoise.vs					\
		tvnoise.fs					\
		digits.png					\
		Sound.h						\
		GNUstep-Sound.m				\
		Debug.h						\
		Debug.m

X8080_Source =						\
		Retro80.h					\
		Retro80.m					\
		x8080.h						\
		x8080.m						\
		Dbg80.h						\
		Dbg80.m						\
		x8253.h						\
		x8253.m						\
		x8257.h						\
		x8257.m						\
		x8275.h						\
		x8275.m						\
		x8255.h						\
		x8255.m						\
		mem.h						\
		mem.m						\
		vg93.h						\
		vg93.m

Radio86RK_Source =					\
		Radio86RKFactory.h			\
		Radio86RKFactory.m			\
		RKKeyboard.h				\
		RKKeyboard.m				\
		RKRecorder.h				\
		RKRecorder.m				\
		RK86Base.h					\
		RK86Base.m					\
		Radio86RK.h					\
		Radio86RK.m					\
		Microsha.h					\
		Microsha.m					\
		MicroshaKeyboard.m			\
		Apogeo.h					\
		Apogeo.m					\
		Partner.h					\
		Partner.m					\
		ROMDisk.h					\
		ROMDisk.m					\
		RKSDCard.h					\
		RKSDCard.m					\
		RKFloppy.h					\
		RKFloppy.m

Micro80_Source =					\
		Micro80Factory.h			\
		Micro80Factory.m			\
		Micro80.h					\
		Micro80.m					\
		Micro80Keyboard.h			\
		Micro80Keyboard.m			\
		Micro80Recorder.h			\
		Micro80Recorder.m			\
		Micro80Screen.h				\
		Micro80Screen.m				\
		UT88.h						\
		UT88.m						\
		UT88Keyboard.h				\
		UT88Keyboard.m				\
		UT88Screen.h				\
		UT88Screen.m				\
		UT88System.h				\
		UT88System.m

Specialist_Source =					\
		SpecialistFactory.h			\
		SpecialistFactory.m			\
		Specialist.h				\
		Specialist.m				\
		SpecialistKeyboard.h		\
		SpecialistKeyboard.m		\
		SpecialistScreen.h			\
		SpecialistScreen.m			\
		SpecialistSDCard.h			\
		SpecialistSDCard.m			\
		SpecialistSP580.h			\
		SpecialistSP580.m			\
		SpecialistMX.h				\
		SpecialistMX.m				\
		SpecialistMXKeyboard.h		\
		SpecialistMXKeyboard.m		\
		SpecialistMXSystem.m		\
		SpecialistMX2Flash.h		\
		SpecialistMX2Flash.m

Orion128_Source =					\
		Orion128Factory.h			\
		Orion128Factory.m			\
		Orion128.h					\
		Orion128.m					\
		Orion128Screen.h			\
		Orion128Screen.m			\
		Orion128Floppy.h			\
		Orion128Floppy.m

Retro80_OBJC_FILES = 						\
		$(filter %.m,$(Base_Source))		\
		$(filter %.m,$(X8080_Source)) 		\
		$(filter %.m,$(Radio86RK_Source)) 	\
		$(filter %.m,$(Micro80_Source)) 	\
		$(filter %.m,$(Specialist_Source)) 	\
		$(filter %.m,$(Orion128_Source))	\
		GNUstep-Stub.m						\
		main.m

Retro80_RESOURCE_FILES =			\
		ru.lproj/InfoPlist.strings	\
		ru.lproj/Document.xib		\
		ru.lproj/MainMenu.xib		\
		digits.png					\
		tvnoise.*					\
		ROM/*

include $(GNUSTEP_MAKEFILES)/application.make
