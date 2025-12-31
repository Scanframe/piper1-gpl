# Set the target name using the current directory name as a suffix.
get_filename_component(PROJECT_SUFFIX ${CMAKE_CURRENT_SOURCE_DIR} NAME)
set(APP_TARGET "${PROJECT_NAME}-${PROJECT_SUFFIX}")

add_executable("${APP_TARGET}")

set_target_properties("${APP_TARGET}" PROPERTIES
	RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/bin"
)

target_sources("${APP_TARGET}" PRIVATE
	main.cpp
	helpers.cpp helpers.h
	CommandLine.cpp CommandLine.h
)

#target_link_libraries("${APP_TARGET}" PRIVATE piper::shared)
target_link_libraries("${APP_TARGET}" PRIVATE piper::static)

##!
# Downloads the model files in the models directory.
#
function(Sf_PiperDownloadModel _models_dir _language _region _dataset _quality)
	set(_BaseUrl "https://huggingface.co/rhasspy/piper-voices/resolve/main/${_language}/${_language}_${_region}/${_dataset}/${_quality}")
	set(_Model "${_language}_${_region}-${_dataset}-${_quality}")
	set(_File "${_models_dir}/${_Model}.onnx")
	if (NOT EXISTS "${_File}")
		file(DOWNLOAD "${_BaseUrl}/${_Model}.onnx" "${_File}" TIMEOUT 10 SHOW_PROGRESS)
	endif ()
	set(_File "${_models_dir}/${_Model}.onnx.json")
	if (NOT EXISTS "${_File}")
		file(DOWNLOAD "${_BaseUrl}/${_Model}.onnx.json" "${_File}" TIMEOUT 10 SHOW_PROGRESS)
	endif ()
endfunction()


Sf_PiperDownloadModel("${CMAKE_SOURCE_DIR}/bin/models" "en" "US" "hfc_female" "medium")
Sf_PiperDownloadModel("${CMAKE_SOURCE_DIR}/bin/models" "en" "US" "hfc_male" "medium")
#[[
Sf_PiperDownloadModel("${CMAKE_SOURCE_DIR}/bin/models" "en" "GB" "cori" "high")
Sf_PiperDownloadModel("${CMAKE_SOURCE_DIR}/bin/models" "en" "US" "lessac" "medium")
Sf_PiperDownloadModel("${CMAKE_SOURCE_DIR}/bin/models" "en" "US" "ljspeech" "medium")
Sf_PiperDownloadModel("${CMAKE_SOURCE_DIR}/bin/models" "nl" "NL" "pim" "medium")
Sf_PiperDownloadModel("${CMAKE_SOURCE_DIR}/bin/models" "en" "GB" "vctk" "medium")
]]

if (BUILD_TESTING)
	if (WIN32)
		if (CMAKE_CROSSCOMPILING)
			# Check if wine is installed.
			find_program(_WineExe "wine")
			if (NOT _WineExe)
				message(NOTICE "Wine is not installed, skipping wine test.")
			else ()
				# Do not use variable _WineExe since it will fail, just use 'wine'.
				execute_process(
					COMMAND ${CMAKE_COMMAND} -E env winepath -w ${WINE_PATH_EXT}
					ECHO_OUTPUT_VARIABLE
					OUTPUT_VARIABLE _WinePath
					OUTPUT_STRIP_TRAILING_WHITESPACE
				)
				# Use the double escape to prevent the string is considered to be a CMake list.
				string(REPLACE "\n" "\\\\;" _WinePath "${_WinePath}")
				# Add the test using the target executable filename.
				add_test(NAME "wine-${APP_TARGET}"
					COMMAND ${CMAKE_COMMAND} -E env wine "$<TARGET_FILE_NAME:${APP_TARGET}>" --play --text
					"Success! When you here this text is looks like the for Windows cross-compiled 'Piper' library is working."
					#COMMAND ${CMAKE_COMMAND} -E env wine cmd /c echo %PATH%
					WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/bin"
				)
				# Set the WINEPATH env var to modify the resulting Windows PATH.
				set_property(TEST "wine-${APP_TARGET}" PROPERTY ENVIRONMENT WINEPATH=${_WinePath})
			endif ()
		endif ()
	else ()
		# Add the test using the target executable filename.
		add_test(NAME "wine-${APP_TARGET}"
			COMMAND "$<TARGET_FILE_NAME:${APP_TARGET}>" --play --text
			"Success! When you here this text is looks like the for Linux compiled 'Piper' library is working."
			#COMMAND ${CMAKE_COMMAND} -E env wine cmd /c echo %PATH%
			WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/bin"
		)
	endif ()
endif ()
