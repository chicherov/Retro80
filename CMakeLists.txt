cmake_minimum_required(VERSION 3.20)
#set(CMAKE_OSX_ARCHITECTURES "arm64;x86_64" CACHE STRING "" FORCE)
project(Retro80 VERSION 0.92 LANGUAGES OBJC)

set(CMAKE_OBJC_STANDARD 99)
add_compile_options(-Werror -fobjc-arc -fmodules)
set(CMAKE_OSX_DEPLOYMENT_TARGET 10.13)

set(CMAKE_OBJCXX_COMPILER clang++)
set(CMAKE_CXX_COMPILER clang++)

enable_language(CXX OBJCXX)
set(CMAKE_CXX_STANDARD 20)

if(NOT APPLE)

	find_path(GNUSTEP_HEADERS Cocoa/Cocoa.h
			PATHS
			/usr/GNUstep/System/Library/Headers
			/usr/GNUstep/Local/Library/Headers
			/include/GNUstep
			REQUIRED)

	include_directories(${GNUSTEP_HEADERS})

	find_path(GNUSTEP_LIBRARIES gnustep-gui
			PATHS
			/usr/GNUstep/System/Library/Libraries
			/usr/GNUstep/Local/Library/Libraries
			/lib/GNUstep
			REQUIRED)

	link_directories(${GNUSTEP_LIBRARIES})

	add_compile_options(-fobjc-runtime=gnustep-2.2 -fblocks)
	add_compile_definitions(GNUSTEP)

endif()

##
## Retro80 Files
##

set(RETRO80_BASE_SOURCES
		Retro80/Document.h
		Retro80/Document.m
		Retro80/DocumentController.h
		Retro80/DocumentController.m
		Retro80/WindowController.h
		Retro80/WindowController.m
		Retro80/Application.h
		Retro80/Application.m
		Retro80/ComputerFactory.h
		Retro80/ComputerFactory.m
		Retro80/Computer.h
		Retro80/Computer.m
		Retro80/Display.h
		Retro80/Display.m
		Retro80/Digit.h
		Retro80/Digit.m
		Retro80/Debug.h
		Retro80/Debug.m
		Retro80/Sound.h)

if(APPLE)
	set(RETRO80_BASE_SOURCES
			${RETRO80_BASE_SOURCES}
			Retro80/Sound.m)
else()
	set(RETRO80_BASE_SOURCES
			${RETRO80_BASE_SOURCES}
			Retro80/GNUstep-Sound.m
			Retro80/GNUstep-Stub.m)
endif()

set(RETRO80_X8080_SOURCES
		Retro80/Retro80.h
		Retro80/Retro80.m
		Retro80/x8080.h
		Retro80/x8080.mm
		Retro80/Dbg80.h
		Retro80/Dbg80.m
		Retro80/x8253.h
		Retro80/x8253.m
		Retro80/x8257.h
		Retro80/x8257.m
		Retro80/x8275.h
		Retro80/x8275.m
		Retro80/x8255.h
		Retro80/x8255.m
		Retro80/mem.h
		Retro80/mem.m
		Retro80/vg93.h
		Retro80/vg93.m
)

set(RETRO80_RADIO86RK_SOURCES
		Retro80/Radio86RKFactory.h
		Retro80/Radio86RKFactory.m
		Retro80/RKKeyboard.h
		Retro80/RKKeyboard.m
		Retro80/RKRecorder.h
		Retro80/RKRecorder.m
		Retro80/RK86Base.h
		Retro80/RK86Base.m
		Retro80/Radio86RK.h
		Retro80/Radio86RK.m
		Retro80/Microsha.h
		Retro80/Microsha.m
		Retro80/MicroshaKeyboard.m
		Retro80/Apogeo.h
		Retro80/Apogeo.m
		Retro80/Partner.h
		Retro80/Partner.m
		Retro80/ROMDisk.h
		Retro80/ROMDisk.m
		Retro80/RKSDCard.h
		Retro80/RKSDCard.m
		Retro80/RKFloppy.h
		Retro80/RKFloppy.m)

set(RETRO80_MICRO80_SOURCES
		Retro80/Micro80Factory.h
		Retro80/Micro80Factory.m
		Retro80/Micro80.h
		Retro80/Micro80.m
		Retro80/Micro80Keyboard.h
		Retro80/Micro80Keyboard.m
		Retro80/Micro80Recorder.h
		Retro80/Micro80Recorder.m
		Retro80/Micro80Screen.h
		Retro80/Micro80Screen.m
		Retro80/UT88.h
		Retro80/UT88.m
		Retro80/UT88Keyboard.h
		Retro80/UT88Keyboard.m
		Retro80/UT88Screen.h
		Retro80/UT88Screen.m
		Retro80/UT88System.h
		Retro80/UT88System.m)

set(RETRO80_SPECIALIST_SOURCES
		Retro80/SpecialistFactory.h
		Retro80/SpecialistFactory.m
		Retro80/Specialist.h
		Retro80/Specialist.m
		Retro80/SpecialistKeyboard.h
		Retro80/SpecialistKeyboard.m
		Retro80/SpecialistScreen.h
		Retro80/SpecialistScreen.m
		Retro80/SpecialistSDCard.h
		Retro80/SpecialistSDCard.m
		Retro80/SpecialistSP580.h
		Retro80/SpecialistSP580.m
		Retro80/SpecialistMX.h
		Retro80/SpecialistMX.m
		Retro80/SpecialistMXKeyboard.h
		Retro80/SpecialistMXKeyboard.m
		Retro80/SpecialistMXSystem.m
		Retro80/SpecialistMX2Flash.h
		Retro80/SpecialistMX2Flash.m)

set(RETRO80_ORION_SOURCES
		Retro80/Orion128Factory.h
		Retro80/Orion128Factory.m
		Retro80/Orion128.h
		Retro80/Orion128.m
		Retro80/Orion128Screen.h
		Retro80/Orion128Screen.m
		Retro80/Orion128Floppy.h
		Retro80/Orion128Floppy.m)

set(RETRO80_CXX_SOURCES
		Retro80/cpu80.h
		Retro80/cpu80.cpp)

set(RETRO80_SOURCES
		${RETRO80_BASE_SOURCES}
		${RETRO80_X8080_SOURCES}
		${RETRO80_RADIO86RK_SOURCES}
		${RETRO80_MICRO80_SOURCES}
		${RETRO80_SPECIALIST_SOURCES}
		${RETRO80_ORION_SOURCES}
		${RETRO80_CXX_SOURCES}
        Retro80/main.m)

set(RETRO80_GLOBAL_RESOURCES
        Retro80.icns
        Retro80/ROM/Apogeo.bin
        Retro80/ROM/Basic.bin
        Retro80/ROM/Lik.bin
        Retro80/ROM/M3-EXT-1.3.rom
        Retro80/ROM/M80RK86.bin
        Retro80/ROM/Micro80.bin
        Retro80/ROM/Micro80.fnt
        Retro80/ROM/Microsha.bin
        Retro80/ROM/ORDOS-2.40.rom
        Retro80/ROM/ORDOS-4.03.rom
        Retro80/ROM/Orion128-1.bin
        Retro80/ROM/Orion128-2.bin
        Retro80/ROM/Orion128-3.1.bin
        Retro80/ROM/Orion128-3.2.bin
        Retro80/ROM/Orion128-3.3.bin
        Retro80/ROM/Partner.bin
        Retro80/ROM/Radio86RK.bin
        Retro80/ROM/SYMGEN.BIN
        Retro80/ROM/Specialist-2.7.bin
        Retro80/ROM/Specialist-3.3.bin
        Retro80/ROM/Specialist1.bin
        Retro80/ROM/Specialist2.bin
        Retro80/ROM/Specialist2SD.bin
        Retro80/ROM/SpecialistMX2.bin
        Retro80/ROM/SpecialistMX_Commander.bin
        Retro80/ROM/SpecialistMX_RAMFOS.bin
        Retro80/ROM/SpecialistSP580.bin
        Retro80/ROM/UT88-0.bin
        Retro80/ROM/UT88-F.bin
        Retro80/ROM/dos29.bin
        Retro80/ROM/fdd.bin
        Retro80/ROM/mcpg.bin
        Retro80/digits.png
        Retro80/tvnoise.fs
        Retro80/tvnoise.vs)

set(RETRO80_RU_RESOURCES
		Retro80/ru.lproj/InfoPlist.strings
        Retro80/ru.lproj/Document.xib
        Retro80/ru.lproj/MainMenu.xib)

set(RETRO80_RESOURCES
        ${RETRO80_GLOBAL_RESOURCES}
        ${RETRO80_RU_RESOURCES})

set_source_files_properties(
		${RETRO80_RESOURCES}
		PROPERTIES MACOSX_PACKAGE_LOCATION Resources
)

##
## Retro80
##

add_executable(Retro80 MACOSX_BUNDLE
        ${RETRO80_SOURCES}
        ${RETRO80_RESOURCES})

if(APPLE)

	set_target_properties(Retro80 PROPERTIES MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/Retro80/Retro80-Info.plist)
	target_precompile_headers(Retro80 PRIVATE Retro80/Retro80-Prefix.pch)

else()

	target_precompile_headers(Retro80 PRIVATE Retro80/GNUstep-Prefix.pch)
	target_link_libraries(Retro80 objc dispatch gnustep-base gnustep-gui GL GLU m)

	add_custom_command(
			TARGET Retro80 POST_BUILD
			WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
			COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_CURRENT_BINARY_DIR}/Resources
			COMMAND ${CMAKE_COMMAND} -E copy ${RETRO80_RESOURCES} ${CMAKE_CURRENT_BINARY_DIR}/Resources
			COMMAND plmerge ${CMAKE_CURRENT_BINARY_DIR}/Resources/Info-gnustep.plist Retro80/Retro80-Info.plist
	)

endif()
