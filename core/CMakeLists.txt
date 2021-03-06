############################################################################
# CMakeLists.txt file for building ROOT (global) core package
############################################################################

add_subdirectory(clib)
add_subdirectory(clingutils)
add_subdirectory(cont)
add_subdirectory(dictgen)
add_subdirectory(foundation)
add_subdirectory(meta)
add_subdirectory(metacling)
add_subdirectory(multiproc)
add_subdirectory(rint)
add_subdirectory(textinput)
add_subdirectory(thread)
add_subdirectory(imt)
add_subdirectory(zip)
add_subdirectory(lzma)

if(NOT WIN32)
  add_subdirectory(newdelete)
endif()

if(UNIX)
  add_subdirectory(unix)
  set(unix_objects $<TARGET_OBJECTS:Unix>)
  set(dict_opts -DSYSTEM_TYPE_unix ${dict_opts})
endif()
if(WIN32)
  add_subdirectory(winnt)
  set(winnt_objects $<TARGET_OBJECTS:Winnt>)
  set(dict_opts -DSYSTEM_TYPE_winnt ${dict_opts})
endif()
if(cocoa)
  add_subdirectory(macosx)
  set(macosx_objects $<TARGET_OBJECTS:Macosx>)
  set(dict_opts -DSYSTEM_TYPE_macosx ${dict_opts})
endif()

set(CORE_OS_DICT_CXX_FLAGS ${dict_opts} PARENT_SCOPE)

# Must come after the OS specific subdirs:
add_subdirectory(base)

set(objectlibs $<TARGET_OBJECTS:Base>
               $<TARGET_OBJECTS:Clib>
               $<TARGET_OBJECTS:Cont>
               $<TARGET_OBJECTS:Foundation>
               $<TARGET_OBJECTS:Lzma>
               $<TARGET_OBJECTS:Zip>
               $<TARGET_OBJECTS:Meta>
               $<TARGET_OBJECTS:TextInput>
               ${macosx_objects}
               ${unix_objects}
               ${winnt_objects})

#---Generation of RGitCommit.h-----------------------------------------------------------
foreach(exp ${objectlibs})
  string(REGEX REPLACE "^[$]<TARGET_OBJECTS:(.+)>" "\\1" lib ${exp})
  get_target_property(objs ${lib} OBJECTS)
  list(APPEND dep_objects ${objs})
  list(APPEND dep_targets ${lib})
endforeach()

add_custom_command(OUTPUT ${CMAKE_BINARY_DIR}/include/RGitCommit.h
                   COMMAND ${CMAKE_COMMAND} -E copy_if_different ${CMAKE_BINARY_DIR}/RGitCommit.h.tmp ${CMAKE_BINARY_DIR}/include/RGitCommit.h
                   COMMENT ""
                   DEPENDS ${CMAKE_BINARY_DIR}/RGitCommit.h.tmp
                   WORKING_DIRECTORY ${CMAKE_BINARY_DIR})
if(WIN32)
  add_custom_command(OUTPUT  ${CMAKE_BINARY_DIR}/RGitCommit.h.tmp
                     COMMAND ${CMAKE_SOURCE_DIR}/build/win/gitinfo.bat ${CMAKE_SOURCE_DIR}
                     COMMAND ${CMAKE_SOURCE_DIR}/build/win/githeader.bat RGitCommit.h.tmp
                     COMMENT "Recording the git revision now"
                     DEPENDS ${dep_objects} move_artifacts
                     WORKING_DIRECTORY ${CMAKE_BINARY_DIR})
else()
  add_custom_command(OUTPUT  ${CMAKE_BINARY_DIR}/RGitCommit.h.tmp
                     COMMAND ${CMAKE_SOURCE_DIR}/build/unix/gitinfo.sh ${CMAKE_SOURCE_DIR}
                     COMMAND ${CMAKE_SOURCE_DIR}/build/unix/githeader.sh RGitCommit.h.tmp
                     COMMENT "Recording the git revision now"
                     DEPENDS ${dep_objects} move_artifacts
                     WORKING_DIRECTORY ${CMAKE_BINARY_DIR})
endif()
add_custom_target(gitcommit ALL DEPENDS ${CMAKE_BINARY_DIR}/RGitCommit.h.tmp)
set_source_files_properties(${CMAKE_BINARY_DIR}/RGitCommit.h.tmp PROPERTIES GENERATED TRUE)
add_dependencies(gitcommit ${dep_targets})

set_source_files_properties(${CMAKE_BINARY_DIR}/include/RGitCommit.h
                            PROPERTIES GENERATED TRUE HEADER_FILE_ONLY TRUE)

ROOT_OBJECT_LIBRARY(BaseTROOT ${CMAKE_SOURCE_DIR}/core/base/src/TROOT.cxx ${CMAKE_BINARY_DIR}/include/RGitCommit.h)
add_dependencies(BaseTROOT gitcommit)
install(FILES ${CMAKE_BINARY_DIR}/include/RGitCommit.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
#----------------------------------------------------------------------------------------

if(WIN32)
  set(corelinklibs shell32.lib WSock32.lib Oleaut32.lib Iphlpapi.lib)
elseif(APPLE)
  if(cocoa)
     set(corelinklibs "-framework Cocoa -F/System/Library/PrivateFrameworks -framework CoreSymbolication")
  else()
     set(corelinklibs "-F/System/Library/PrivateFrameworks -framework CoreSymbolication")
  endif()
endif()

add_subdirectory(rootcling_stage1)

#-------------------------------------------------------------------------------
ROOT_LINKER_LIBRARY(Core
                    $<TARGET_OBJECTS:BaseTROOT>
                    ${objectlibs}
                    LIBRARIES ${PCRE_LIBRARIES} ${LZMA_LIBRARIES} ${ZLIB_LIBRARIES}
                              ${CMAKE_DL_LIBS} ${CMAKE_THREAD_LIBS_INIT} ${corelinklibs}
                    BUILTINS PCRE LZMA)

if(cling)
  add_dependencies(Core CLING)
endif()

#----------------------------------------------------------------------------------------
